const std = @import("std");
pub const pipespa = @cImport({
    @cInclude("pipewire/pipewire.h");
    @cInclude("spa/param/audio/format-utils.h");
});

const data = ?struct {
    loop: *pipespa.pw_main_loop,
    stream: *pipespa.pw_stream,
    accumulator: f32,
};

const DEFAULT_RATE = 44100;
const DEFAULT_CHANNELS = 2;
const DEFAULT_VOLUME = 0.4;
const M_PI_M2 = std.math.pi + std.math.pi;
pub fn on_process(userdata: *void) void {
    var thedata: *pipespa.data = userdata;
    var b: *pipespa.pw_buffer = null;
    var buf: *pipespa.spa_buffer = null;

    var i: c_int = null;
    var c: c_int = null;
    var n_frames: c_int = null;
    var stride: c_int = null;
    var dst: *i16 = null;
    var val: i16 = null;

    b = pipespa.pw_stream_dequeue_buffer(thedata.*.stream);
    if (b == null) {
        pipespa.pw_log_warn("Lol");
        return;
    }
    buf = b.*.buffer;
    dst = buf.*.datas[0].data;
    if (dst == null) return;

    stride = @sizeOf(i16) * DEFAULT_CHANNELS;
    n_frames = buf.*.datas[0].maxsize / stride;
    while (i < n_frames) {
        data.*.accumulator += M_PI_M2 * 440 / DEFAULT_RATE;
        if (data.*.accumulator >= M_PI_M2)
            data.*.accumulator = M_PI_M2;
        val = std.math.sin(data.*.accumulator) * DEFAULT_VOLUME * 16767.0;
        while (c < DEFAULT_CHANNELS) {
            dst.* = val;
            dst += @sizeOf(@TypeOf(dst));
            c += 1;
        }
        i += 1;
    }
    buf.*.datas[0].chunk.*.offset = 0;
    buf.*.datas[0].chunk.*.stride = stride;
    buf.*.datas[0].chunk.*.size = n_frames * stride;
    pipespa.pw_stream_queue_buffer(data.*.stream, b);
}

pub const stream_events: pipespa.pw_stream_events = .{ .version = pipespa.PW_VERSION_STREAM_EVENTS, .process = on_process };

pub fn main() anyerror!void {
    var thedata: data = undefined;
    var params: *[1]pipespa.spa_pod = undefined;
    var buffer: [1024]i8 = undefined;
    var b: pipespa.spa_pod_builder = pipespa.SPA_POD_BUILDER_INIT(buffer, @sizeOf(buffer));

    pipespa.pw_init(&.{}, &.{});

    thedata.loop = pipespa.pw_main_loop_new(null);
    thedata.stream = pipespa.pw_stream_new_simple(
        pipespa.pw_main_loop_get_loop(thedata.loop),
        "audio-lol",
        pipespa.pw_properties_new(pipespa.PW_KEY_MEDIA_TYPE, "Audio", pipespa.PW_KEY_MEDIA_CATEGORY, "Playback", pipespa.PW_KEY_MEDIA_ROLE, "Music", null),
        &stream_events,
        &thedata,
    );
    params[0] = pipespa.spa_format_audio_raw_build(
        &b,
        pipespa.SPA_PARAM_EnumFormat,
        &pipespa.spa_audio_info_raw {
        .format=pipespa.SPA_AUDIO_FORMAT_S16,
        .channels=DEFAULT_CHANNELS,
        .rate=DEFAULT_RATE, },
    );
    pipespa.pw_stream_conenct(thedata.stream,
        pipespa.PW_DIRECTION_OUT,
        pipespa.PW_ID_ANY,
        pipespa.PW_STREAM_FLAG_AUTOCONNECT |
        pipespa.PW_STREAM_MAP_BUFFERS |
        pipespa.PW_STREAM_FLAG_RT_PROCESS, params, 1
    );
    pipespa.pw_main_loop_run(thedata.loop);
    pipespa.pw_stream_destory(thedata.stream);
    pipespa.pw_main_loop_destroy(thedata.loop);
    std.log.info("All your codebase are belong to us.", .{});
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
