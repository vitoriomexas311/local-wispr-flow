// MIT. One bounded in-memory PCM request per process. No audio or transcript files.
#include "whisper.h"
#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <iostream>
#include <string>
#include <thread>
#include <vector>

static void quiet(enum ggml_log_level, const char *, void *) {}
static void json_string(const char *text) {
    std::cout << '"';
    for (const unsigned char *p = reinterpret_cast<const unsigned char *>(text); *p; ++p) {
        switch (*p) {
            case '"': std::cout << "\\\""; break;
            case '\\': std::cout << "\\\\"; break;
            case '\n': std::cout << "\\n"; break;
            case '\r': std::cout << "\\r"; break;
            case '\t': std::cout << "\\t"; break;
            default:
                if (*p < 32) {
                    const char *digits = "0123456789abcdef";
                    std::cout << "\\u00" << digits[*p >> 4] << digits[*p & 15];
                } else { std::cout << *p; }
        }
    }
    std::cout << '"';
}

int main(int argc, char **argv) {
    if (argc != 2) return 2;
    // Protocol: little-endian uint32 frame count, then mono 16 kHz Float32 PCM.
    unsigned char header[4];
    if (std::fread(header, 1, 4, stdin) != 4) return 3;
    const uint32_t frames = uint32_t(header[0]) | (uint32_t(header[1]) << 8) |
        (uint32_t(header[2]) << 16) | (uint32_t(header[3]) << 24);
    if (frames == 0 || frames > 25 * 16000) return 3;
    std::vector<float> samples(frames);
    if (std::fread(samples.data(), sizeof(float), frames, stdin) != frames || std::fgetc(stdin) != EOF) return 3;
    bool audible = false;
    for (float value : samples) {
        if (!std::isfinite(value) || std::abs(value) > 1.0f) return 3;
        audible = audible || std::abs(value) > 0.0001f;
    }
    if (!audible) { std::cout << "[]\n"; return 0; }
    whisper_log_set(quiet, nullptr);
    auto config = whisper_context_default_params();
    config.use_gpu = false;
    auto *context = whisper_init_from_file_with_params(argv[1], config);
    if (!context) return 4;
    auto params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.n_threads = int(std::max(1u, std::min(4u, std::thread::hardware_concurrency())));
    params.language = "en";
    params.translate = false;
    params.no_context = true;
    params.print_special = false;
    params.print_progress = false;
    params.print_realtime = false;
    params.print_timestamps = false;
    params.suppress_blank = true;
    params.suppress_nst = true;
    params.token_timestamps = true;
    params.max_len = 1;
    params.split_on_word = true;
    params.temperature_inc = 0; // bounded single decoding attempt
    int status = whisper_full(context, params, samples.data(), int(frames));
    if (status != 0) { whisper_free(context); return 5; }
    std::cout << '[';
    int segments = whisper_full_n_segments(context);
    int emitted = 0;
    const double duration = double(frames) / 16000.0;
    for (int i = 0; i < segments; ++i) {
        const char *text = whisper_full_get_segment_text(context, i);
        const double start = double(whisper_full_get_segment_t0(context, i)) / 100.0;
        // Whisper pads short input; the final token's end can extend into that
        // padding. Keep real words and constrain ownership to captured audio.
        if (!text || !*text || start < 0 || start >= duration) continue;
        const double end = std::max(start, std::min(duration,
            double(whisper_full_get_segment_t1(context, i)) / 100.0));
        if (emitted++) std::cout << ',';
        std::cout << "{\"text\":";
        json_string(text);
        std::cout << ",\"start\":" << start << ",\"end\":" << end << '}';
    }
    std::cout << "]\n";
    whisper_free(context);
    return 0;
}
