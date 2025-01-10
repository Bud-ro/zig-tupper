const std = @import("std");

const c = @cImport({
    @cDefine("SDL_DISABLE_OLD_NAMES", {});
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3/SDL_revision.h");
    // For programs that provide their own entry points instead of relying on SDL's main function
    // macro magic, 'SDL_MAIN_HANDLED' should be defined before including 'SDL_main.h'.
    @cDefine("SDL_MAIN_HANDLED", {});
    @cInclude("SDL3/SDL_main.h");
});

pub fn main() !void {
    errdefer |err| if (err == error.SdlError) std.log.err("SDL error: {s}", .{c.SDL_GetError()});

    std.log.debug("SDL build time version: {d}.{d}.{d}", .{
        c.SDL_MAJOR_VERSION,
        c.SDL_MINOR_VERSION,
        c.SDL_MICRO_VERSION,
    });
    std.log.debug("SDL build time revision: {s}", .{c.SDL_REVISION});
    {
        const version = c.SDL_GetVersion();
        std.log.debug("SDL runtime version: {d}.{d}.{d}", .{
            c.SDL_VERSIONNUM_MAJOR(version),
            c.SDL_VERSIONNUM_MINOR(version),
            c.SDL_VERSIONNUM_MICRO(version),
        });
        const revision: [*:0]const u8 = c.SDL_GetRevision();
        std.log.debug("SDL runtime revision: {s}", .{revision});
    }

    // For programs that provide their own entry points instead of relying on SDL's main function
    // macro magic, 'SDL_SetMainReady' should be called before calling 'SDL_Init'.
    c.SDL_SetMainReady();

    try errify(c.SDL_SetAppMetadata("Hello World", "0.0.0", "com.budro.tupper"));

    try errify(c.SDL_Init(c.SDL_INIT_VIDEO)); // | c.SDL_INIT_GAMEPAD
    defer c.SDL_Quit();

    std.log.debug("SDL video drivers: {}", .{fmtSdlDrivers(
        c.SDL_GetCurrentVideoDriver().?,
        c.SDL_GetNumVideoDrivers(),
        c.SDL_GetVideoDriver,
    )});

    const window_w = 640;
    const window_h = 480;
    errify(c.SDL_SetHint(c.SDL_HINT_RENDER_VSYNC, "1")) catch {};

    const window: *c.SDL_Window, const renderer: *c.SDL_Renderer = create_window_and_renderer: {
        var window: ?*c.SDL_Window = null;
        var renderer: ?*c.SDL_Renderer = null;
        try errify(c.SDL_CreateWindowAndRenderer("Hello World", window_w, window_h, 0, &window, &renderer));
        errdefer comptime unreachable;

        break :create_window_and_renderer .{ window.?, renderer.? };
    };
    defer c.SDL_DestroyRenderer(renderer);
    defer c.SDL_DestroyWindow(window);

    std.log.debug("SDL render drivers: {}", .{fmtSdlDrivers(
        c.SDL_GetRendererName(renderer).?,
        c.SDL_GetNumRenderDrivers(),
        c.SDL_GetRenderDriver,
    )});

    // var gamepad: ?*c.SDL_Gamepad = detect_gamepad: {
    //     var count: c_int = 0;
    //     const gamepads: [*]c.SDL_JoystickID = try errify(c.SDL_GetGamepads(&count));
    //     defer c.SDL_free(gamepads);

    //     break :detect_gamepad if (count > 0) try errify(c.SDL_OpenGamepad(gamepads[0])) else null;
    // };
    // defer c.SDL_CloseGamepad(gamepad);

    // var phcon: PhysicalControllerState = .{};
    // var prev_phcon = phcon;
    // var vcon: VirtualControllerState = .{};
    // var prev_vcon = vcon;

    var timekeeper: Timekeeper = .{ .tocks_per_s = c.SDL_GetPerformanceFrequency() };

    // var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}).init;
    // defer _ = general_purpose_allocator.deinit();
    // const gpa = general_purpose_allocator.allocator();

    // var k = try std.math.big.int.Managed.init(gpa);
    // try k.ensureTwosCompCapacity(2048); // Need ~1803 bits to do the original Tupper's Self-Referential Formula

    main_loop: while (true) {
        // Process SDL events
        {
            var event: c.SDL_Event = undefined;
            while (c.SDL_PollEvent(&event)) {
                switch (event.type) {
                    c.SDL_EVENT_QUIT => {
                        break :main_loop;
                    },
                    // c.SDL_EVENT_KEY_DOWN, c.SDL_EVENT_KEY_UP => {
                    //     const down = event.type == c.SDL_EVENT_KEY_DOWN;
                    //     switch (event.key.scancode) {
                    //         c.SDL_SCANCODE_LEFT => phcon.k_left = down,
                    //         c.SDL_SCANCODE_RIGHT => phcon.k_right = down,
                    //         c.SDL_SCANCODE_LSHIFT => phcon.k_lshift = down,
                    //         c.SDL_SCANCODE_SPACE => phcon.k_space = down,
                    //         c.SDL_SCANCODE_R => phcon.k_r = down,
                    //         c.SDL_SCANCODE_ESCAPE => phcon.k_escape = down,
                    //         else => {},
                    //     }
                    // },
                    // c.SDL_EVENT_MOUSE_BUTTON_DOWN, c.SDL_EVENT_MOUSE_BUTTON_UP => {
                    //     const down = event.type == c.SDL_EVENT_MOUSE_BUTTON_DOWN;
                    //     switch (event.button.button) {
                    //         c.SDL_BUTTON_LEFT => phcon.m_left = down,
                    //         else => {},
                    //     }
                    // },
                    // c.SDL_EVENT_MOUSE_MOTION => {
                    //     phcon.m_xrel += event.motion.xrel;
                    // },
                    else => {},
                }
            }
        }

        // Update the game state
        while (timekeeper.consume()) {
            // Do nothing for now
        }

        // Draw
        {
            try errify(c.SDL_SetRenderDrawColor(renderer, 0, 0, 0, c.SDL_ALPHA_OPAQUE));
            try errify(c.SDL_RenderClear(renderer));

            {
                try errify(c.SDL_SetRenderDrawColor(renderer, 230, 230, 230, c.SDL_ALPHA_OPAQUE));
                const padding = 50;
                // X-axis & Y-axis
                const x_axis_end = c.SDL_FPoint{ .x = window_w - padding, .y = window_h - padding };
                const x_arrow = [3]c.SDL_Vertex{
                    .{ .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 }, .position = .{ .x = x_axis_end.x, .y = x_axis_end.y - 10 } },
                    .{ .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 }, .position = .{ .x = x_axis_end.x, .y = x_axis_end.y + 10 } },
                    .{ .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 }, .position = .{ .x = x_axis_end.x + 20.0 / std.math.sqrt2, .y = x_axis_end.y } },
                };

                const y_axis_end = c.SDL_FPoint{ .x = padding, .y = padding };
                const y_arrow = [3]c.SDL_Vertex{
                    .{ .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 }, .position = .{ .x = y_axis_end.x - 10, .y = y_axis_end.y } },
                    .{ .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 }, .position = .{ .x = y_axis_end.x + 10, .y = y_axis_end.y } },
                    .{ .color = .{ .r = 1.0, .g = 1.0, .b = 1.0, .a = 1.0 }, .position = .{ .x = y_axis_end.x, .y = y_axis_end.y - 20.0 / std.math.sqrt2 } },
                };

                try errify(c.SDL_RenderLine(renderer, padding, window_h - padding, x_axis_end.x, x_axis_end.y));
                try errify(c.SDL_RenderGeometry(renderer, null, &x_arrow, x_arrow.len, null, 0));
                try errify(c.SDL_RenderLine(renderer, padding, window_h - padding, y_axis_end.x, y_axis_end.y));
                try errify(c.SDL_RenderGeometry(renderer, null, &y_arrow, y_arrow.len, null, 0));
            }

            try errify(c.SDL_RenderPresent(renderer));
        }

        timekeeper.produce(c.SDL_GetPerformanceCounter());
    }
}

/// Facilitates updating the game logic at a fixed rate.
/// Inspired <https://github.com/TylerGlaiel/FrameTimingControl> and the linked article.
const Timekeeper = struct {
    const updates_per_s = 60;
    const max_accumulated_updates = 8;
    const snap_frame_rates = .{ updates_per_s, 30, 120, 144 };
    const ticks_per_tock = 720; // Least common multiple of 'snap_frame_rates'
    const snap_tolerance_us = 200;
    const us_per_s = 1_000_000;

    tocks_per_s: u64,
    accumulated_ticks: u64 = 0,
    previous_timestamp: ?u64 = null,

    fn consume(timekeeper: *Timekeeper) bool {
        const ticks_per_s: u64 = timekeeper.tocks_per_s * ticks_per_tock;
        const ticks_per_update: u64 = @divExact(ticks_per_s, updates_per_s);
        if (timekeeper.accumulated_ticks >= ticks_per_update) {
            timekeeper.accumulated_ticks -= ticks_per_update;
            return true;
        } else {
            return false;
        }
    }

    fn produce(timekeeper: *Timekeeper, current_timestamp: u64) void {
        if (timekeeper.previous_timestamp) |previous_timestamp| {
            const ticks_per_s: u64 = timekeeper.tocks_per_s * ticks_per_tock;
            const elapsed_ticks: u64 = (current_timestamp -% previous_timestamp) *| ticks_per_tock;
            const snapped_elapsed_ticks: u64 = inline for (snap_frame_rates) |snap_frame_rate| {
                const target_ticks: u64 = @divExact(ticks_per_s, snap_frame_rate);
                const abs_diff = @max(elapsed_ticks, target_ticks) - @min(elapsed_ticks, target_ticks);
                if (abs_diff *| us_per_s <= snap_tolerance_us *| ticks_per_s) {
                    break target_ticks;
                }
            } else elapsed_ticks;
            const ticks_per_update: u64 = @divExact(ticks_per_s, updates_per_s);
            const max_accumulated_ticks: u64 = max_accumulated_updates * ticks_per_update;
            timekeeper.accumulated_ticks = @min(timekeeper.accumulated_ticks +| snapped_elapsed_ticks, max_accumulated_ticks);
        }
        timekeeper.previous_timestamp = current_timestamp;
    }
};

fn fmtSdlDrivers(
    current_driver: [*:0]const u8,
    num_drivers: c_int,
    getDriver: *const fn (c_int) callconv(.C) ?[*:0]const u8,
) std.fmt.Formatter(formatSdlDrivers) {
    return .{ .data = .{
        .current_driver = current_driver,
        .num_drivers = num_drivers,
        .getDriver = getDriver,
    } };
}

fn formatSdlDrivers(
    context: struct {
        current_driver: [*:0]const u8,
        num_drivers: c_int,
        getDriver: *const fn (c_int) callconv(.C) ?[*:0]const u8,
    },
    comptime _: []const u8,
    _: std.fmt.FormatOptions,
    writer: anytype,
) !void {
    var i: c_int = 0;
    while (i < context.num_drivers) : (i += 1) {
        if (i != 0) {
            try writer.writeAll(", ");
        }
        const driver = context.getDriver(i).?;
        try writer.writeAll(std.mem.span(driver));
        if (std.mem.orderZ(u8, context.current_driver, driver) == .eq) {
            try writer.writeAll(" (current)");
        }
    }
}

/// Converts the return value of an SDL function to an error union.
inline fn errify(value: anytype) error{SdlError}!switch (@import("shims").typeInfo(@TypeOf(value))) {
    .bool => void,
    .pointer, .optional => @TypeOf(value.?),
    .int => |info| switch (info.signedness) {
        .signed => @TypeOf(@max(0, value)),
        .unsigned => @TypeOf(value),
    },
    else => @compileError("unerrifiable type: " ++ @typeName(@TypeOf(value))),
} {
    return switch (@import("shims").typeInfo(@TypeOf(value))) {
        .bool => if (!value) error.SdlError,
        .pointer, .optional => value orelse error.SdlError,
        .int => |info| switch (info.signedness) {
            .signed => if (value >= 0) @max(0, value) else error.SdlError,
            .unsigned => if (value != 0) value else error.SdlError,
        },
        else => comptime unreachable,
    };
}
