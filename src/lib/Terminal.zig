const std = @import("std");
const Types = @import("Types.zig");
const Point2 = Types.Point2;
const Point3 = Types.Point3;
const ColorModule = @import("Color.zig");
const Color = ColorModule.Color;
const ColorError = ColorModule.ColorError;

pub const TerminalError = error{
    InitFailed,
    WriteFailed,
    ColorNotSupported,
    InvalidPosition,
    BufferFull,
};

pub const Terminal = struct {
    size: Point2,
    can_display_color: bool,
    buffer: []u8,
    cursor_x: i32,
    cursor_y: i32,
    fg_color: Color,
    bg_color: Color,
    enabled: bool,
    _out: std.fs.File.Writer,

    const BUFFER_SIZE = 4096;

    const Self = @This();

    pub fn init() TerminalError!Self {
        var size = Point2{ .x = 80, .y = 24 };

        if (std.io.getStdOut().isTty()) {
            if (std.io.tty.getDimensions(std.io.getStdOut().handle())) |dim| {
                size.x = @as(i32, @intCast(dim.width));
                size.y = @as(i32, @intCast(dim.height));
            }
        }

        return Self{
            .size = size,
            .can_display_color = true,
            .buffer = undefined,
            .cursor_x = 0,
            .cursor_y = 0,
            .fg_color = Color.initNamed(.white),
            .bg_color = Color.initNamed(.black),
            .enabled = true,
            ._out = std.io.getStdOut().writer(),
        };
    }

    pub fn initWithSize(width: i32, height: i32) Self {
        return Self{
            .size = Point2{ .x = width, .y = height },
            .can_display_color = true,
            .buffer = undefined,
            .cursor_x = 0,
            .cursor_y = 0,
            .fg_color = Color.initNamed(.white),
            .bg_color = Color.initNamed(.black),
            .enabled = true,
            ._out = std.io.getStdOut().writer(),
        };
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    pub fn write(self: *Self, text: []const u8) TerminalError!void {
        if (!self.enabled) return;

        self._out.writeAll(text) catch return TerminalError.WriteFailed;
    }

    pub fn clear(self: *Self) TerminalError!void {
        try self.write("\x1b[2J");
        try self.setCursor(0, 0);
    }

    pub fn setCursor(self: *Self, x: i32, y: i32) TerminalError!void {
        if (x < 0 or y < 0) return TerminalError.InvalidPosition;
        self.cursor_x = x;
        self.cursor_y = y;
        var buf: [32]u8 = undefined;
        const s = std.fmt.bufPrint(
            &buf,
            "\x1b[{d};{d}H",
            .{ @as(u32, @intCast(y + 1)), @as(u32, @intCast(x + 1)) },
        ) catch return TerminalError.WriteFailed;
        try self.write(s);
    }

    pub fn getCursor(self: *const Self) Point2 {
        return Point2{ .x = self.cursor_x, .y = self.cursor_y };
    }

    pub fn setForeground(self: *Self, color: Color) void {
        self.fg_color = color;
    }

    pub fn setBackground(self: *Self, color: Color) void {
        self.bg_color = color;
    }

    pub fn getForeground(self: *const Self) Color {
        return self.fg_color;
    }

    pub fn getBackground(self: *const Self) Color {
        return self.bg_color;
    }

    pub fn applyColor(self: *Self, color: Color) TerminalError!void {
        if (self.can_display_color) {
            if (color.toAnsi()) |ansi| {
                var buf: [16]u8 = undefined;
                const s = std.fmt.bufPrint(&buf, "\x1b[{d}m", .{@as(u32, ansi)}) catch return TerminalError.WriteFailed;
                try self.write(s);
            }
        }
    }

    pub fn resetColor(self: *Self) TerminalError!void {
        if (self.can_display_color) {
            try self.write("\x1b[0m");
        }
    }

    pub fn print(self: *Self, comptime format: []const u8, args: anytype) TerminalError!void {
        if (!self.enabled) return;
        var buf: [512]u8 = undefined;
        const text = std.fmt.bufPrint(&buf, format, args) catch return TerminalError.BufferFull;
        try self.write(text);
        self.updateCursorPosition(text);
    }

    pub fn printAt(self: *Self, x: i32, y: i32, comptime format: []const u8, args: anytype) TerminalError!void {
        try self.setCursor(x, y);
        try self.print(format, args);
    }

    pub fn drawChar(self: *Self, x: i32, y: i32, ch: u8, color: ?Color) TerminalError!void {
        if (!self.enabled) return;
        if (x < 0 or y < 0 or x >= self.size.x or y >= self.size.y) return TerminalError.InvalidPosition;

        try self.setCursor(x, y);
        if (color) |c| {
            try self.applyColor(c);
        }
        var buf: [1]u8 = .{ch};
        try self.write(&buf);
        if (color) |_| {
            try self.resetColor();
        }
    }

    pub fn drawString(self: *Self, x: i32, y: i32, str: []const u8, color: ?Color) TerminalError!void {
        if (!self.enabled) return;
        if (x < 0 or y < 0) return TerminalError.InvalidPosition;

        try self.setCursor(x, y);
        if (color) |c| {
            try self.applyColor(c);
        }
        try self.write(str);
        if (color) |_| {
            try self.resetColor();
        }
    }

    pub fn drawRect(self: *Self, x: i32, y: i32, w: i32, h: i32, ch: u8, color: ?Color) TerminalError!void {
        if (!self.enabled) return;
        if (w <= 0 or h <= 0) return;

        var row: i32 = 0;
        while (row < h) : (row += 1) {
            const cur_y = y + row;
            if (cur_y < 0 or cur_y >= self.size.y) continue;

            var col: i32 = 0;
            while (col < w) : (col += 1) {
                const cur_x = x + col;
                if (cur_x < 0 or cur_x >= self.size.x) continue;
                try self.drawChar(cur_x, cur_y, ch, color);
            }
        }
    }

    pub fn drawLine(
        self: *Self,
        x1: i32,
        y1: i32,
        x2: i32,
        y2: i32,
        ch: u8,
        color: ?Color,
    ) TerminalError!void {
        if (!self.enabled) return;

        const dx = @abs(x2 - x1);
        const dy = @abs(y2 - y1);
        const sx: i32 = if (x1 < x2) 1 else -1;
        const sy: i32 = if (y1 < y2) 1 else -1;
        var err: i32 = @as(i32, @intCast(dx)) - @as(i32, @intCast(dy));

        var x = x1;
        var y = y1;

        while (true) {
            if (x >= 0 and y >= 0 and x < self.size.x and y < self.size.y) {
                try self.drawChar(x, y, ch, color);
            }

            if (x == x2 and y == y2) break;

            const e2 = 2 * err;
            if (e2 > -@as(i32, @intCast(dy))) {
                err -= @as(i32, @intCast(dy));
                x += sx;
            }
            if (e2 < @as(i32, @intCast(dx))) {
                err += @as(i32, @intCast(dx));
                y += sy;
            }
        }
    }

    pub fn fill(self: *Self, ch: u8, color: ?Color) TerminalError!void {
        var y: i32 = 0;
        while (y < self.size.y) : (y += 1) {
            var x: i32 = 0;
            while (x < self.size.x) : (x += 1) {
                try self.drawChar(x, y, ch, color);
            }
        }
    }

    pub fn updateCursorPosition(self: *Self, text: []const u8) void {
        for (text) |c| {
            if (c == '\n') {
                self.cursor_x = 0;
                self.cursor_y += 1;
            } else if (c == '\r') {
                self.cursor_x = 0;
            } else if (c == '\t') {
                self.cursor_x += 4;
            } else {
                self.cursor_x += 1;
            }
        }
    }

    pub fn getWidth(self: *const Self) i32 {
        return self.size.x;
    }

    pub fn getHeight(self: *const Self) i32 {
        return self.size.y;
    }

    pub fn getSize(self: *const Self) Point2 {
        return self.size;
    }

    pub fn setEnabled(self: *Self, enabled: bool) void {
        self.enabled = enabled;
    }

    pub fn isEnabled(self: *const Self) bool {
        return self.enabled;
    }

    pub fn hideCursor(self: *Self) TerminalError!void {
        try self.write("\x1b[?25l");
    }

    pub fn showCursor(self: *Self) TerminalError!void {
        try self.write("\x1b[?25h");
    }

    pub fn enableColor(self: *Self) void {
        self.can_display_color = true;
    }

    pub fn disableColor(self: *Self) void {
        self.can_display_color = false;
    }

    pub fn canDisplayColor(self: *const Self) bool {
        return self.can_display_color;
    }
};

const t = std.testing;
const exeptEqual = t.expectEqual;

test "Terminal.initWithSize" {
    const term = Terminal.initWithSize(100, 50);
    try exeptEqual(@as(i32, 100), term.size.x);
    try exeptEqual(@as(i32, 50), term.size.y);
}

test "Terminal.getCursor" {
    const term = Terminal.initWithSize(80, 24);
    const cursor = term.getCursor();
    try exeptEqual(@as(i32, 0), cursor.x);
    try exeptEqual(@as(i32, 0), cursor.y);
}

test "Terminal.setForeground and getForeground" {
    var term = Terminal.initWithSize(80, 24);
    term.setForeground(Color.initNamed(.red));
    try exeptEqual(Color.initNamed(.red), term.getForeground());
}

test "Terminal.setBackground and getBackground" {
    var term = Terminal.initWithSize(80, 24);
    term.setBackground(Color.initNamed(.blue));
    try exeptEqual(Color.initNamed(.blue), term.getBackground());
}

test "Terminal.getWidth and getHeight" {
    const term = Terminal.initWithSize(120, 30);
    try exeptEqual(@as(i32, 120), term.getWidth());
    try exeptEqual(@as(i32, 30), term.getHeight());
}

test "Terminal.getSize" {
    const term = Terminal.initWithSize(80, 24);
    const size = term.getSize();
    try exeptEqual(@as(i32, 80), size.x);
    try exeptEqual(@as(i32, 24), size.y);
}

test "Terminal.setEnabled and isEnabled" {
    var term = Terminal.initWithSize(80, 24);
    try exeptEqual(true, term.isEnabled());

    term.setEnabled(false);
    try exeptEqual(false, term.isEnabled());

    term.setEnabled(true);
    try exeptEqual(true, term.isEnabled());
}

test "Terminal.canDisplayColor" {
    var term = Terminal.initWithSize(80, 24);
    try exeptEqual(true, term.canDisplayColor());

    term.disableColor();
    try exeptEqual(false, term.canDisplayColor());

    term.enableColor();
    try exeptEqual(true, term.canDisplayColor());
}

test "Terminal.setCursor" {
    var term = Terminal.initWithSize(80, 24);
    try term.setCursor(10, 5);
    const cursor = term.getCursor();
    try exeptEqual(@as(i32, 10), cursor.x);
    try exeptEqual(@as(i32, 5), cursor.y);
}

test "Terminal.setCursor with negative coordinates" {
    var term = Terminal.initWithSize(80, 24);
    const result = term.setCursor(-1, -1);
    try exeptEqual(TerminalError.InvalidPosition, result);
}

test "Terminal.updateCursorPosition with newline" {
    var term = Terminal.initWithSize(80, 24);
    term.updateCursorPosition("Hello\nWorld");
    try exeptEqual(@as(i32, 5), term.cursor_x);
    try exeptEqual(@as(i32, 1), term.cursor_y);
}

test "Terminal.updateCursorPosition with carriage return" {
    var term = Terminal.initWithSize(80, 24);
    term.updateCursorPosition("Hello\rWorld");
    try exeptEqual(@as(i32, 5), term.cursor_x);
    try exeptEqual(@as(i32, 0), term.cursor_y);
}

test "Terminal.updateCursorPosition with tab" {
    var term = Terminal.initWithSize(80, 24);
    term.updateCursorPosition("Hi\t!");
    try exeptEqual(@as(i32, 7), term.cursor_x);
    try exeptEqual(@as(i32, 0), term.cursor_y);
}

test "Terminal.drawChar" {
    var term = Terminal.initWithSize(80, 24);
    try term.drawChar(5, 10, '#', null);
}

test "Terminal.drawString" {
    var term = Terminal.initWithSize(80, 24);
    try term.drawString(0, 0, "Hello", null);
}

test "Terminal.drawString with color" {
    var term = Terminal.initWithSize(80, 24);
    const color = Color.initNamed(.green);
    try term.drawString(10, 5, "Test", color);
}

test "Terminal.drawRect" {
    var term = Terminal.initWithSize(80, 24);
    try term.drawRect(5, 5, 10, 5, '#', null);
}

test "Terminal.drawRect with zero width" {
    var term = Terminal.initWithSize(80, 24);
    try term.drawRect(5, 5, 0, 5, '#', null);
}

test "Terminal.drawLine" {
    var term = Terminal.initWithSize(80, 24);
    try term.drawLine(0, 0, 10, 10, '#', null);
}

test "Terminal.fill" {
    var term = Terminal.initWithSize(5, 3);
    try term.fill('.', null);
}

test "Terminal.hideCursor and showCursor" {
    var term = Terminal.initWithSize(80, 24);
    try term.hideCursor();
    try term.showCursor();
}

test "Terminal.drawChar out of bounds" {
    var term = Terminal.initWithSize(5, 5);
    const result = term.drawChar(10, 10, '#', null);
    try exeptEqual(TerminalError.InvalidPosition, result);
}

test "Terminal.print" {
    var term = Terminal.initWithSize(80, 24);
    try term.print("Hello {s}", .{"World"});
}

test "Terminal.printAt" {
    var term = Terminal.initWithSize(80, 24);
    try term.printAt(10, 5, "X: {}, Y: {}", .{ 10, 5 });
}

test "Terminal default color values" {
    const term = Terminal.initWithSize(80, 24);
    try exeptEqual(Color.initNamed(.white), term.fg_color);
    try exeptEqual(Color.initNamed(.black), term.bg_color);
}

test "Terminal can draw multiple characters" {
    var term = Terminal.initWithSize(20, 10);
    try term.drawString(0, 0, "ABCDEFGHIJ", null);
    try term.drawString(0, 1, "0123456789", null);
}
