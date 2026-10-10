#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Minimal stand-in for the MicYou desktop receiver, for testing the iOS client

Accepts one client at a time, answers the handshake, pings every 500 ms,
prints control messages and packet statistics, and writes PCM audio to a WAV
file. Opus packets are counted and, with --opus-out, stored as length
prefixed raw packets. With --mdns the service is published through avahi
"""

import argparse
import socket
import struct
import sys
import subprocess
import threading
import time
import wave

TCP_MAGIC = 0x4D696359
UDP_MAGIC = 0x4D696355


def varint(buf, i):
    shift = result = 0
    while True:
        b = buf[i]
        i += 1
        result |= (b & 0x7F) << shift
        if not b & 0x80:
            return result, i
        shift += 7


def fields(buf):
    """Yields (field, wire_type, value) for a protobuf message"""
    i = 0
    while i < len(buf):
        key, i = varint(buf, i)
        field, wt = key >> 3, key & 7
        if wt == 0:
            value, i = varint(buf, i)
        elif wt == 2:
            n, i = varint(buf, i)
            value, i = buf[i:i + n], i + n
        elif wt == 1:
            value, i = buf[i:i + 8], i + 8
        elif wt == 5:
            value, i = buf[i:i + 4], i + 4
        else:
            raise ValueError(f"wire type {wt}")
        yield field, wt, value


def signed64(v):
    return v - (1 << 64) if v >= 1 << 63 else v


def decode_audio(buf):
    ordered = {"lengths": []}
    for f, wt, v in fields(buf):
        if f == 1 and wt == 0:
            ordered["seq"] = signed64(v)
        elif f == 2:
            ordered["packet"] = {ff: vv for ff, _, vv in fields(v)}
        elif f == 3:
            ordered["ts"] = v
        elif f == 4:
            ordered["fec"] = v
        elif f == 5:
            ordered["fec_seq"] = v
        elif f == 6:
            ordered["session"] = signed64(v)
        elif f == 7:
            if wt == 2:
                j = 0
                while j < len(v):
                    n, j = varint(v, j)
                    ordered["lengths"].append(n)
            else:
                ordered["lengths"].append(v)
    return ordered


def frame(payload):
    return struct.pack(">II", TCP_MAGIC, len(payload)) + payload


def ping(ts):
    inner = bytes([0x08]) + enc_varint(ts)
    return bytes([0x2A]) + enc_varint(len(inner)) + inner


def mute(value):
    return bytes([0x1A, 0x02, 0x08, 1 if value else 0])


def enc_varint(v):
    out = bytearray()
    while v >= 0x80:
        out.append((v & 0x7F) | 0x80)
        v >>= 7
    out.append(v)
    return bytes(out)


class Stats:
    def __init__(self, args):
        self.args = args
        self.lock = threading.Lock()
        self.reset()

    def reset(self):
        self.session = None
        self.packets = self.fec = self.bytes = self.lost = 0
        self.last_seq = None
        self.wav = None
        self.opus = None
        self.fmt = None

    def audio(self, buf, via):
        a = decode_audio(buf)
        p = a.get("packet", {})
        with self.lock:
            if self.session is not None and a.get("session") != self.session:
                print(f"  ! session mismatch {a.get('session')} != {self.session}")
                return
            if a.get("fec"):
                self.fec += 1
                assert len(a["lengths"]) == 12, a["lengths"]
                return
            seq = a.get("seq", 0)
            if self.last_seq is not None and seq != self.last_seq + 1:
                self.lost += max(0, seq - self.last_seq - 1)
            self.last_seq = seq
            self.packets += 1
            data = p.get(1, b"")
            self.bytes += len(data)
            fmt = (p.get(2, 0), p.get(3, 0), p.get(4, 0), p.get(5, 0))
            if fmt != self.fmt:
                print(f"  format via {via}: rate={fmt[0]} ch={fmt[1]} audioFormat={fmt[2]} codec={'opus' if fmt[3] == 1 else 'pcm'}")
                self.fmt = fmt
                if fmt[3] == 0 and fmt[2] == 2 and self.wav is None:
                    self.wav = wave.open(self.args.wav, "wb")
                    self.wav.setnchannels(fmt[1])
                    self.wav.setsampwidth(2)
                    self.wav.setframerate(fmt[0])
                if fmt[3] == 1 and self.args.opus_out and self.opus is None:
                    self.opus = open(self.args.opus_out, "wb")
            if self.wav and fmt[3] == 0:
                self.wav.writeframes(data)
            if self.opus and fmt[3] == 1:
                self.opus.write(struct.pack("<H", len(data)) + data)

    def close(self):
        with self.lock:
            if self.wav:
                self.wav.close()
                print(f"  wrote {self.args.wav}")
            if self.opus:
                self.opus.close()
            self.reset()


def udp_loop(sock, stats, peer):
    while True:
        data, addr = sock.recvfrom(65536)
        if peer[0] and addr[0] != peer[0]:
            print(f"  ! UDP from {addr[0]}, TCP peer is {peer[0]}")
            continue
        magic, length = struct.unpack(">II", data[:8])
        if magic != UDP_MAGIC or length != len(data) - 8:
            print(f"  ! bad UDP datagram magic={magic:#x} len={length}/{len(data) - 8}")
            continue
        if len(data) > 1472:
            print(f"  ! datagram of {len(data)} bytes exceeds 1472")
        for f, _, v in fields(data[8:]):
            if f == 1:
                stats.audio(v, "udp")


def recv_exact(conn, n):
    buf = b""
    while len(buf) < n:
        chunk = conn.recv(n - len(buf))
        if not chunk:
            raise ConnectionError("closed")
        buf += chunk
    return buf


def serve_client(conn, addr, stats, args, peer):
    peer[0] = addr[0]
    print(f"client {addr[0]}:{addr[1]}")
    conn.settimeout(10)
    hello = recv_exact(conn, 12)
    if hello != b"MicYouCheck1":
        print(f"  bad handshake {hello!r}")
        return
    conn.sendall(b"MicYouCheck2")
    alive = [True]

    def pinger():
        muted = False
        n = 0
        while alive[0]:
            try:
                conn.sendall(frame(ping(int(time.time() * 1000))))
                n += 1
                if args.toggle_mute and n % (args.toggle_mute * 2) == 0:
                    muted = not muted
                    print(f"  -> desktop mute {muted}")
                    conn.sendall(frame(mute(muted)))
            except OSError:
                return
            time.sleep(0.5)

    threading.Thread(target=pinger, daemon=True).start()
    started = time.time()
    last_report = started
    first = True
    try:
        while True:
            magic, length = struct.unpack(">II", recv_exact(conn, 8))
            if magic != TCP_MAGIC:
                print(f"  bad magic {magic:#x}")
                return
            body = recv_exact(conn, length)
            for f, _, v in fields(body):
                if f == 2:
                    sid = signed64(next((vv for ff, _, vv in fields(v) if ff == 1), 0))
                    print(f"  connect session={sid}")
                    stats.session = sid
                elif first:
                    print("  ! first frame is not Connect")
                if f == 3:
                    val = next((vv for ff, _, vv in fields(v) if ff == 1), None)
                    print(f"  mute {bool(val) if val is not None else 'absent'}")
                elif f == 6:
                    ts = next((vv for ff, _, vv in fields(v) if ff == 1), 0)
                    rtt = int(time.time() * 1000) - ts
                    if args.verbose:
                        print(f"  pong rtt={rtt} ms")
                elif f == 1:
                    stats.audio(v, "tcp")
                first = False
            now = time.time()
            if now - last_report >= 2:
                last_report = now
                with stats.lock:
                    kbps = stats.bytes * 8 / (now - started) / 1000
                    print(f"  packets={stats.packets} fec={stats.fec} lost={stats.lost} payload={kbps:.0f} kbps")
    except (ConnectionError, OSError, socket.timeout) as e:
        print(f"  disconnected: {e}")
    finally:
        alive[0] = False
        conn.close()
        stats.close()


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--port", type=int, default=8554)
    ap.add_argument("--wav", default="mock_capture.wav")
    ap.add_argument("--opus-out")
    ap.add_argument("--mdns", action="store_true", help="publish _micyou._tcp with avahi-publish")
    ap.add_argument("--name", help="computer name shown in the app, defaults to <hostname>-mock")
    ap.add_argument("--toggle-mute", type=int, metavar="SECONDS", help="flip the desktop mute every N seconds")
    ap.add_argument("-v", "--verbose", action="store_true")
    args = ap.parse_args()
    sys.stdout.reconfigure(line_buffering=True)

    stats = Stats(args)
    peer = [None]
    udp = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    udp.bind(("0.0.0.0", args.port + 1))
    threading.Thread(target=udp_loop, args=(udp, stats, peer), daemon=True).start()

    tcp = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    tcp.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    tcp.bind(("0.0.0.0", args.port))
    tcp.listen(1)
    if args.mdns:
        subprocess.Popen(["avahi-publish", "-s", f"MicYou ({args.name or socket.gethostname() + '-mock'})", "_micyou._tcp", str(args.port)])
    print(f"listening on tcp/{args.port} udp/{args.port + 1}")
    while True:
        conn, addr = tcp.accept()
        serve_client(conn, addr, stats, args, peer)


if __name__ == "__main__":
    main()
