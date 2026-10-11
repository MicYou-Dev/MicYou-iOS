// SPDX-License-Identifier: GPL-3.0-or-later

/// Bonjour instance names of desktops
public enum ServiceName {
    /// The host name inside the instance name, the desktop registers "MicYou (<hostname>)"
    public static func displayName(_ name: String) -> String {
        if name.hasPrefix("MicYou ("), name.hasSuffix(")") {
            return String(name.dropFirst("MicYou (".count).dropLast())
        }
        return name
    }
}
