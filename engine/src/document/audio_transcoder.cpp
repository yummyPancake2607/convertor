#include "audio_transcoder.hpp"

#include "../ffmpeg/ffmpeg_error.hpp"
#include "../ffmpeg/frame.hpp"
#include "../ffmpeg/packet.hpp"
#include <convertor/logging.hpp>

#include <algorithm>

using namespace std;

namespace convertor {

namespace {

AVSampleFormat pick_sample_format(const AVCodec* encoder) {
    const void* configs = nullptr;
    int count = 0;
    if (avcodec_get_supported_config(nullptr, encoder, AV_CODEC_CONFIG_SAMPLE_FORMAT,
                                     0, &configs, &count) < 0 ||
        !configs || count <= 0) {
        return AV_SAMPLE_FMT_FLTP;
    }
    return static_cast<const AVSampleFormat*>(configs)[0];
}

int pick_sample_rate(const AVCodec* encoder, int preferred) {
    const void* configs = nullptr;
    int count = 0;
    if (avcodec_get_supported_config(nullptr, encoder, AV_CODEC_CONFIG_SAMPLE_RATE,
                                     0, &configs, &count) < 0 ||
        !configs || count <= 0) {
        return preferred > 0 ? preferred : 44100;
    }
    const int* rates = static_cast<const int*>(configs);
    for (int i = 0; i < count; ++i) {
        if (rates[i] == preferred) return preferred;
    }
    int best = rates[0];
    for (int i = 1; i < count; ++i) best = max(best, rates[i]);
    return best;
}

} // namespace

Error AudioTranscoder::open(AVFormatContext* in_fmt, unsigned in_index,
                            ffmpeg::FormatContext& out_ctx,
                            const AudioSettings& settings) {
    in_index_ = in_index;
    AVStream* in_stream = in_fmt->streams[in_index];

    Error err = decoder_.open_decoder(in_stream->codecpar);
    if (!err.ok()) return err;

    AVFormatContext* out_fmt = out_ctx.output_ctx();
    AVCodecID codec_id = out_fmt->oformat->audio_codec;
    if (settings.codec.has_value()) {
        const AVCodec* named = avcodec_find_encoder_by_name(settings.codec->c_str());
        if (named) codec_id = named->id;
    }

    const AVCodec* encoder = avcodec_find_encoder(codec_id);
    if (!encoder) {
        return Error(ErrorCode::kUnsupportedFormat,
                     "No audio encoder for this container");
    }

    const int in_channels = decoder_.ctx()->ch_layout.nb_channels;
    channels_ = settings.channels.value_or(in_channels > 0 ? in_channels : 2);
    sample_rate_ = pick_sample_rate(
        encoder, settings.sample_rate.value_or(decoder_.ctx()->sample_rate));
    sample_fmt_ = pick_sample_format(encoder);

    enc_ctx_.reset(avcodec_alloc_context3(encoder));
    if (!enc_ctx_) return Error(ErrorCode::kOutOfMemory, "Cannot allocate encoder");

    enc_ctx_->sample_rate = sample_rate_;
    enc_ctx_->sample_fmt = sample_fmt_;
    av_channel_layout_default(&enc_ctx_->ch_layout, channels_);
    enc_ctx_->time_base = AVRational{1, sample_rate_};
    if (settings.bit_rate.has_value()) enc_ctx_->bit_rate = settings.bit_rate.value();
    if (out_fmt->oformat->flags & AVFMT_GLOBALHEADER) {
        enc_ctx_->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }

    err = ffmpeg::ffmpeg_error(avcodec_open2(enc_ctx_.get(), encoder, nullptr));
    if (!err.ok()) return err;

    // Codecs with a variable frame size (PCM, FLAC) report 0; pick a block.
    frame_size_ = enc_ctx_->frame_size > 0 ? enc_ctx_->frame_size : 1024;

    out_stream_ = avformat_new_stream(out_fmt, nullptr);
    if (!out_stream_) return Error(ErrorCode::kOutOfMemory, "Cannot create stream");
    out_stream_->time_base = enc_ctx_->time_base;
    err = ffmpeg::ffmpeg_error(
        avcodec_parameters_from_context(out_stream_->codecpar, enc_ctx_.get()));
    if (!err.ok()) return err;
    out_index_ = out_stream_->index;

    err = resampler_.init(sample_rate_, channels_, sample_fmt_,
                          decoder_.ctx()->sample_rate, in_channels,
                          decoder_.ctx()->sample_fmt);
    if (!err.ok()) return err;

    fifo_.reset(av_audio_fifo_alloc(sample_fmt_, channels_, frame_size_));
    if (!fifo_) return Error(ErrorCode::kOutOfMemory, "Cannot allocate audio FIFO");

    Logger::instance().info(string("AudioTranscoder: ") + encoder->name + " " +
                            to_string(channels_) + "ch @" + to_string(sample_rate_) +
                            "Hz, frame_size=" + to_string(frame_size_));
    return Error::success();
}

Error AudioTranscoder::feed(AVPacket* pkt, ffmpeg::FormatContext& out_ctx) {
    Error err = decoder_.send_packet(pkt);
    if (!err.ok() && err.code() != ErrorCode::kInternal) return err;
    return drain_decoder(out_ctx);
}

Error AudioTranscoder::finish(ffmpeg::FormatContext& out_ctx) {
    decoder_.send_packet(nullptr);
    Error err = drain_decoder(out_ctx);
    if (!err.ok()) return err;

    // Flush the resampler's internal delay before draining the FIFO.
    while (true) {
        ffmpeg::Frame flushed;
        err = flushed.allocate_audio(frame_size_, sample_fmt_, channels_);
        if (!err.ok()) return err;

        int got = swr_convert(resampler_.ctx(), flushed.frame()->extended_data,
                              frame_size_, nullptr, 0);
        if (got <= 0) break;
        if (av_audio_fifo_write(fifo_.get(),
                                reinterpret_cast<void**>(flushed.frame()->extended_data),
                                got) < got) {
            return Error(ErrorCode::kOutOfMemory, "Audio FIFO write failed");
        }
    }

    // Only the final frame may be shorter than frame_size.
    while (av_audio_fifo_size(fifo_.get()) > 0) {
        const int available = av_audio_fifo_size(fifo_.get());
        err = emit_frame(out_ctx, min(frame_size_, available));
        if (!err.ok()) return err;
    }

    avcodec_send_frame(enc_ctx_.get(), nullptr);
    return drain_encoder(out_ctx);
}

Error AudioTranscoder::drain_decoder(ffmpeg::FormatContext& out_ctx) {
    while (true) {
        ffmpeg::Frame decoded;
        int ret = avcodec_receive_frame(decoder_.ctx(), decoded.get());
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
        if (ret < 0) return ffmpeg::ffmpeg_error(ret);

        AVFrame* src = decoded.frame();
        const int out_samples = static_cast<int>(av_rescale_rnd(
            swr_get_delay(resampler_.ctx(), src->sample_rate) + src->nb_samples,
            sample_rate_, src->sample_rate, AV_ROUND_UP));
        if (out_samples <= 0) continue;

        ffmpeg::Frame resampled;
        Error err = resampled.allocate_audio(out_samples, sample_fmt_, channels_);
        if (!err.ok()) return err;

        ret = swr_convert(resampler_.ctx(), resampled.frame()->extended_data,
                          out_samples,
                          const_cast<const uint8_t**>(src->extended_data),
                          src->nb_samples);
        if (ret < 0) return ffmpeg::ffmpeg_error(ret);

        if (ret > 0 &&
            av_audio_fifo_write(fifo_.get(),
                                reinterpret_cast<void**>(resampled.frame()->extended_data),
                                ret) < ret) {
            return Error(ErrorCode::kOutOfMemory, "Audio FIFO write failed");
        }

        while (av_audio_fifo_size(fifo_.get()) >= frame_size_) {
            err = emit_frame(out_ctx, frame_size_);
            if (!err.ok()) return err;
        }
    }
    return Error::success();
}

Error AudioTranscoder::emit_frame(ffmpeg::FormatContext& out_ctx, int samples) {
    ffmpeg::Frame frame;
    Error err = frame.allocate_audio(samples, sample_fmt_, channels_);
    if (!err.ok()) return err;

    if (av_audio_fifo_read(fifo_.get(),
                           reinterpret_cast<void**>(frame.frame()->extended_data),
                           samples) < samples) {
        return Error(ErrorCode::kInternal, "Audio FIFO read failed");
    }

    frame.frame()->nb_samples = samples;
    frame.frame()->sample_rate = sample_rate_;
    av_channel_layout_default(&frame.frame()->ch_layout, channels_);
    frame.set_pts(next_pts_);
    next_pts_ += samples;

    int ret = avcodec_send_frame(enc_ctx_.get(), frame.frame());
    if (ret < 0) return ffmpeg::ffmpeg_error(ret);
    return drain_encoder(out_ctx);
}

Error AudioTranscoder::drain_encoder(ffmpeg::FormatContext& out_ctx) {
    while (true) {
        ffmpeg::Packet pkt;
        int ret = avcodec_receive_packet(enc_ctx_.get(), pkt.get());
        if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) break;
        if (ret < 0) return ffmpeg::ffmpeg_error(ret);

        av_packet_rescale_ts(pkt.get(), enc_ctx_->time_base, out_stream_->time_base);
        pkt.get()->stream_index = out_index_;
        Error err = out_ctx.write_packet(pkt.get());
        av_packet_unref(pkt.get());
        if (!err.ok()) return err;
    }
    return Error::success();
}

} // namespace convertor
