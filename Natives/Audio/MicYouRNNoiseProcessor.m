#import "MicYouRNNoiseProcessor.h"
#import "MicYouLogger.h"

#include <rnnoise.h>

/// RNNoise fixed frame size (samples per process_frame call).
static const NSUInteger kRNNoiseFrameSize = 480;

@interface MicYouRNNoiseProcessor () {
    /// Per-channel RNNoise state. Allocated via calloc(channels, sizeof(DenoiseState *)).
    DenoiseState **_denoiseStates;

    /// Per-channel accumulation buffer (float samples in PCM16 scale,
    /// i.e. [-32768, 32767]). NULL until first process call, then grown via realloc.
    float **_accumBuffers;

    /// Per-channel current accumulation length (number of float samples).
    NSUInteger *_accumLens;

    /// Cached channel count.
    NSUInteger _channels;

    /// Cached sample rate (currently unused by RNNoise, kept for API symmetry).
    double _sampleRate;
}
@end

@implementation MicYouRNNoiseProcessor

#pragma mark - Lifecycle

- (instancetype)initWithSampleRate:(double)sampleRate
                           channels:(NSUInteger)channels {
    self = [super init];
    if (self) {
        _sampleRate = sampleRate;
        // Validate channel count; default to mono if invalid.
        _channels = (channels >= 1) ? channels : 1;

        _denoiseStates = (DenoiseState **)calloc(_channels, sizeof(DenoiseState *));
        _accumBuffers = (float **)calloc(_channels, sizeof(float *));
        _accumLens = (NSUInteger *)calloc(_channels, sizeof(NSUInteger));

        if (!_denoiseStates || !_accumBuffers || !_accumLens) {
            NSLog(@"[MicYou] RNNoiseProcessor: failed to allocate channel arrays");
            [self freeInternalState];
            return nil;
        }

        // Create an independent DenoiseState per channel to avoid RNN state
        // cross-contamination between channels.
        for (NSUInteger ch = 0; ch < _channels; ch++) {
            _denoiseStates[ch] = rnnoise_create(NULL);
            if (!_denoiseStates[ch]) {
                NSLog(@"[MicYou] RNNoiseProcessor: rnnoise_create failed for channel %lu",
                      (unsigned long)ch);
                [self freeInternalState];
                return nil;
            }
            // _accumBuffers[ch] starts as NULL; realloc(NULL, n) == malloc(n).
            // _accumLens[ch] starts as 0.
        }
    }
    return self;
}

- (void)dealloc {
    [self freeInternalState];
}

- (void)freeInternalState {
    if (_denoiseStates) {
        for (NSUInteger ch = 0; ch < _channels; ch++) {
            if (_denoiseStates[ch]) {
                rnnoise_destroy(_denoiseStates[ch]);
                _denoiseStates[ch] = NULL;
            }
        }
        free(_denoiseStates);
        _denoiseStates = NULL;
    }
    if (_accumBuffers) {
        for (NSUInteger ch = 0; ch < _channels; ch++) {
            if (_accumBuffers[ch]) {
                free(_accumBuffers[ch]);
                _accumBuffers[ch] = NULL;
            }
        }
        free(_accumBuffers);
        _accumBuffers = NULL;
    }
    if (_accumLens) {
        free(_accumLens);
        _accumLens = NULL;
    }
}

#pragma mark - Processing

/// Frame counter for throttling diagnostic logs (every 50 frames ≈ 0.5s at 48kHz).
static NSUInteger sRNNoiseProcessCount = 0;

- (NSData *)process:(NSData *)pcm16Data intensity:(float)intensity {
    // Bypass on transparent intensity, empty input or zero channels.
    if (intensity <= 0.0f || pcm16Data.length == 0 || _channels == 0) {
        return pcm16Data;
    }

    // Clamp mix to [0, 1] (wet/dry ratio: 0 = dry passthrough, 1 = full clean).
    float mix = intensity / 100.0f;
    if (mix < 0.0f) mix = 0.0f;
    if (mix > 1.0f) mix = 1.0f;

    // PCM16 byte stream -> int16 view (arm64 is little-endian, no swap needed).
    const int16_t *pcm16 = (const int16_t *)pcm16Data.bytes;
    NSUInteger totalSamples = pcm16Data.length / sizeof(int16_t);
    NSUInteger inputLen = totalSamples / _channels; // samples per channel

    if (inputLen == 0) {
        return pcm16Data;
    }

    // Diagnostic: input RMS (every 50 calls, throttled to avoid log spam).
    // Uses channel 0 only for simplicity; log on the first call so the user
    // can immediately confirm RNNoise is wired up even before 50 calls elapse.
    BOOL shouldLog = (sRNNoiseProcessCount == 0) || (sRNNoiseProcessCount % 50 == 0);
    float inputRMS = 0.0f;
    if (shouldLog) {
        double sumSq = 0.0;
        for (NSUInteger i = 0; i < inputLen; i++) {
            float s = (float)pcm16[i * _channels] / 32768.0f;
            sumSq += (double)(s * s);
        }
        inputRMS = (float)sqrt(sumSq / (double)inputLen);
    }

    // Deinterleave into per-channel float buffers (PCM16 scale: [-32768, 32767]).
    float **channelInputs = (float **)calloc(_channels, sizeof(float *));
    if (!channelInputs) {
        return pcm16Data;
    }
    for (NSUInteger ch = 0; ch < _channels; ch++) {
        channelInputs[ch] = (float *)malloc(inputLen * sizeof(float));
        if (!channelInputs[ch]) {
            // Cleanup partially allocated and bail out.
            for (NSUInteger c = 0; c <= ch; c++) {
                if (channelInputs[c]) { free(channelInputs[c]); channelInputs[c] = NULL; }
            }
            free(channelInputs);
            return pcm16Data;
        }
    }
    for (NSUInteger i = 0; i < inputLen; i++) {
        for (NSUInteger ch = 0; ch < _channels; ch++) {
            channelInputs[ch][i] = (float)pcm16[i * _channels + ch];
        }
    }

    // Per-channel RNNoise processing (mirrors PC-side
    // process_rnnoise_single_channel, except residual samples are kept in the
    // accumulation buffer for the next call instead of being drained to output;
    // see task constraint #5).
    float **channelOutputs = (float **)calloc(_channels, sizeof(float *));
    NSUInteger *channelOutputLens = (NSUInteger *)calloc(_channels, sizeof(NSUInteger));
    if (!channelOutputs || !channelOutputLens) {
        for (NSUInteger ch = 0; ch < _channels; ch++) { free(channelInputs[ch]); }
        free(channelInputs);
        free(channelOutputs);
        free(channelOutputLens);
        return pcm16Data;
    }

    float inputFrame[kRNNoiseFrameSize];
    float outputFrame[kRNNoiseFrameSize];

    for (NSUInteger ch = 0; ch < _channels; ch++) {
        // Append this chunk to the per-channel accumulation buffer.
        NSUInteger newAccumLen = _accumLens[ch] + inputLen;
        float *grown = (float *)realloc(_accumBuffers[ch], newAccumLen * sizeof(float));
        if (!grown) {
            // Allocation failure: skip this channel, output as passthrough.
            channelOutputs[ch] = NULL;
            channelOutputLens[ch] = 0;
            continue;
        }
        _accumBuffers[ch] = grown;
        memcpy(_accumBuffers[ch] + _accumLens[ch],
               channelInputs[ch],
               inputLen * sizeof(float));
        _accumLens[ch] = newAccumLen;

        // Process as many full 480-sample frames as possible.
        NSUInteger numFrames = _accumLens[ch] / kRNNoiseFrameSize;
        NSUInteger outputLen = numFrames * kRNNoiseFrameSize;
        float *output = NULL;
        if (outputLen > 0) {
            output = (float *)malloc(outputLen * sizeof(float));
            if (!output) {
                channelOutputs[ch] = NULL;
                channelOutputLens[ch] = 0;
                continue;
            }
            NSUInteger outIdx = 0;
            NSUInteger processed = 0;
            for (NSUInteger f = 0; f < numFrames; f++) {
                memcpy(inputFrame,
                       _accumBuffers[ch] + processed,
                       kRNNoiseFrameSize * sizeof(float));

                // rnnoise_process_frame returns VAD probability [0,1]; ignored.
                (void)rnnoise_process_frame(_denoiseStates[ch],
                                            outputFrame,
                                            inputFrame);

                // Wet/dry mix. inputFrame and outputFrame are both in PCM16
                // scale ([-32767, 32767] expected by RNNoise; int16 cast from
                // arm64 little-endian maps directly).
                float invMix = 1.0f - mix;
                for (NSUInteger i = 0; i < kRNNoiseFrameSize; i++) {
                    float original = inputFrame[i];
                    float clean = outputFrame[i];
                    output[outIdx++] = original * invMix + clean * mix;
                }
                processed += kRNNoiseFrameSize;
            }
        }
        channelOutputs[ch] = output;
        channelOutputLens[ch] = outputLen;

        // Retain residual (< 480) samples in the accumulation buffer for the
        // next process call. Move them to the front and shrink the buffer.
        NSUInteger processed = numFrames * kRNNoiseFrameSize;
        NSUInteger remaining = _accumLens[ch] - processed;
        if (remaining > 0 && processed > 0) {
            memmove(_accumBuffers[ch],
                    _accumBuffers[ch] + processed,
                    remaining * sizeof(float));
        }
        _accumLens[ch] = remaining;
        if (remaining > 0) {
            float *shrunk = (float *)realloc(_accumBuffers[ch],
                                             remaining * sizeof(float));
            // realloc shrink failure is harmless: old pointer still valid with
            // original size; we just keep the larger allocation.
            if (shrunk) {
                _accumBuffers[ch] = shrunk;
            }
        } else {
            // Free the accum buffer entirely to release memory; next process
            // call will realloc(NULL, n).
            free(_accumBuffers[ch]);
            _accumBuffers[ch] = NULL;
        }
    }

    // Re-interleave and align output length to input length.
    // If a channel produced fewer samples than inputLen (because residual
    // samples were retained), pad with the original input samples for that
    // channel (transparent passthrough for unprocessed tail).
    NSUInteger outputBytes = inputLen * _channels * sizeof(int16_t);
    int16_t *outPcm16 = (int16_t *)malloc(outputBytes);
    if (!outPcm16) {
        for (NSUInteger ch = 0; ch < _channels; ch++) {
            free(channelInputs[ch]);
            free(channelOutputs[ch]);
        }
        free(channelInputs);
        free(channelOutputs);
        free(channelOutputLens);
        return pcm16Data;
    }

    for (NSUInteger i = 0; i < inputLen; i++) {
        for (NSUInteger ch = 0; ch < _channels; ch++) {
            float v;
            if (i < channelOutputLens[ch] && channelOutputs[ch] != NULL) {
                v = channelOutputs[ch][i];
            } else {
                // Pad with original input (unprocessed passthrough).
                v = channelInputs[ch][i];
            }
            // Clamp to [-32767, 32767] to avoid int16 overflow on cast.
            if (v > 32767.0f) v = 32767.0f;
            if (v < -32767.0f) v = -32767.0f;
            outPcm16[i * _channels + ch] = (int16_t)v;
        }
    }

    NSData *outputData = [NSData dataWithBytesNoCopy:outPcm16
                                               length:outputBytes
                                         freeWhenDone:YES];

    // Diagnostic: output RMS and reduction ratio (throttled to every 50 calls).
    // Logs both the input and output RMS in [0.0, 1.0] PCM-normalized scale,
    // plus the dB reduction (positive = noise removed, negative = amplified).
    if (shouldLog) {
        const int16_t *outPcm16Read = (const int16_t *)outputData.bytes;
        NSUInteger outSampleCount = outputData.length / sizeof(int16_t);
        double outSumSq = 0.0;
        NSUInteger outCh0Count = 0;
        for (NSUInteger i = 0; i < outSampleCount; i += _channels) {
            float s = (float)outPcm16Read[i] / 32768.0f;
            outSumSq += (double)(s * s);
            outCh0Count++;
        }
        float outputRMS = (outCh0Count > 0) ? (float)sqrt(outSumSq / (double)outCh0Count) : 0.0f;
        float reductionDb = 20.0f * log10f((outputRMS > 1e-6f ? outputRMS : 1e-6f)
                                            / (inputRMS  > 1e-6f ? inputRMS  : 1e-6f));
        NSLog(@"[MicYou] RNNoise[%lu]: inRMS=%.4f outRMS=%.4f reduction=%.1f dB (intensity=%.0f%% mix=%.2f frames=%lu ch=%lu)",
              (unsigned long)sRNNoiseProcessCount,
              inputRMS, outputRMS, reductionDb,
              (double)intensity, (double)mix,
              (unsigned long)(outputData.length / sizeof(int16_t) / _channels / kRNNoiseFrameSize),
              (unsigned long)_channels);
        [[MicYouLogger sharedLogger] log:[NSString stringWithFormat:
            @"[RNNoise] #%lu inRMS=%.4f outRMS=%.4f reduction=%.1f dB (intensity=%.0f%% mix=%.2f frames=%lu ch=%lu)",
            (unsigned long)sRNNoiseProcessCount,
            inputRMS, outputRMS, reductionDb,
            (double)intensity, (double)mix,
            (unsigned long)(outputData.length / sizeof(int16_t) / _channels / kRNNoiseFrameSize),
            (unsigned long)_channels]];
    }
    sRNNoiseProcessCount++;

    // Cleanup per-call temporaries (channelInputs, channelOutputs,
    // channelOutputLens). _denoiseStates / _accumBuffers are kept for the
    // lifetime of the processor.
    for (NSUInteger ch = 0; ch < _channels; ch++) {
        free(channelInputs[ch]);
        free(channelOutputs[ch]);
    }
    free(channelInputs);
    free(channelOutputs);
    free(channelOutputLens);

    return outputData;
}

#pragma mark - Reset

- (void)reset {
    for (NSUInteger ch = 0; ch < _channels; ch++) {
        if (_denoiseStates[ch]) {
            rnnoise_destroy(_denoiseStates[ch]);
            _denoiseStates[ch] = rnnoise_create(NULL);
            if (!_denoiseStates[ch]) {
                NSLog(@"[MicYou] RNNoiseProcessor: rnnoise_create failed during reset for channel %lu",
                      (unsigned long)ch);
            }
        }
        // Clear accumulation buffer and release memory.
        if (_accumBuffers[ch]) {
            free(_accumBuffers[ch]);
            _accumBuffers[ch] = NULL;
        }
        _accumLens[ch] = 0;
    }
}

@end
