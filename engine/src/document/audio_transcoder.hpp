#pragma once

#include "../ffmpeg/codec_context.hpp"
#include "../ffmpeg/format_context.hpp"
#include "../ffmpeg/resampler.hpp"

#include <convertor/conversion_settings.hpp>
#include <convertor/error.hpp>

#include <memory>

extern "C" {
#include <libavformat/avformat.h>
#include <libavutil/audio_fifo.h>
}

namespace convertor {

/// Decodes one audio stream and re-encodes it into an output container.
///
/// Shared by every path that has to move audio: audio-only conversion, audio
/// extraction from video, and the audio track of a video transcode. Buffering
/// through an FIFO is what keeps the encoder fed with exactly `frame_size`
/// samples per frame, which codecs like MP3 require for every frame but the
/// last one.
class AudioTranscoder {
public:
    /// Opens the decoder/encoder pair and adds an audio stream to `out_ctx`.
    /// Must be called before `out_ctx.write_header()`.
    Error open(AVFormatContext* in_fmt, unsigned in_index,
               ffmpeg::FormatContext& out_ctx, const AudioSettings& settings);

    /// Feeds one packet from the source stream.
    Error feed(AVPacket* pkt, ffmpeg::FormatContext& out_ctx);

    /// Flushes the decoder, FIFO and encoder. Call once, after the read loop.
    Error finish(ffmpeg::FormatContext& out_ctx);

    unsigned in_index() const { return in_index_; }
    int out_index() const { return out_index_; }

    /// Seconds of audio encoded so far, for progress reporting.
    double seconds_encoded() const {
        return sample_rate_ > 0 ? static_cast<double>(next_pts_) / sample_rate_ : 0.0;
    }

private:
    Error drain_decoder(ffmpeg::FormatContext& out_ctx);
    Error emit_frame(ffmpeg::FormatContext& out_ctx, int samples);
    Error drain_encoder(ffmpeg::FormatContext& out_ctx);

    struct FifoDeleter {
        void operator()(AVAudioFifo* f) const { if (f) av_audio_fifo_free(f); }
    };

    unsigned in_index_ = 0;
    int out_index_ = -1;
    int channels_ = 2;
    int sample_rate_ = 44100;
    int frame_size_ = 1024;
    int64_t next_pts_ = 0;
    AVSampleFormat sample_fmt_ = AV_SAMPLE_FMT_FLTP;

    ffmpeg::CodecContext decoder_;
    ffmpeg::UniqueAVCodecCtx enc_ctx_;
    ffmpeg::Resampler resampler_;
    std::unique_ptr<AVAudioFifo, FifoDeleter> fifo_;
    AVStream* out_stream_ = nullptr;
};

} // namespace convertor
