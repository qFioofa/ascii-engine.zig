pub const ColorError = error{
    InvalidColor,
    InvalidHex,
    InvalidRGB,
    InvalidFloat,
    Overflow,
};

pub const Color = union(enum) {
    none: void,
    hex: u32,
    rgb: struct { r: u8, g: u8, b: u8 },
    named: NamedColor,
    float: struct { r: f32, g: f32, b: f32 },
    ansi: u8,

    pub const NamedColor = enum {
        black,
        red,
        green,
        yellow,
        blue,
        magenta,
        cyan,
        white,
        bright_black,
        bright_red,
        bright_green,
        bright_yellow,
        bright_blue,
        bright_magenta,
        bright_cyan,
        bright_white,
    };

    pub fn initHex(value: u32) ColorError!Color {
        if (value > 0xFFFFFF) {
            return ColorError.InvalidHex;
        }
        return Color{ .hex = value };
    }

    pub fn initRGB(r: u8, g: u8, b: u8) Color {
        return Color{ .rgb = .{ .r = r, .g = g, .b = b } };
    }

    pub fn initNamed(name: NamedColor) Color {
        return Color{ .named = name };
    }

    pub fn initFloat(r: f32, g: f32, b: f32) ColorError!Color {
        if (r < 0.0 or r > 1.0 or g < 0.0 or g > 1.0 or b < 0.0 or b > 1.0) {
            return ColorError.InvalidFloat;
        }
        return Color{ .float = .{ .r = r, .g = g, .b = b } };
    }

    pub fn initAnsi(code: u8) Color {
        return Color{ .ansi = code };
    }

    pub fn parseHex(str: []const u8) ColorError!Color {
        var hex_str = str;
        if (hex_str.len > 0 and (hex_str[0] == '#' or (hex_str.len > 1 and hex_str[0] == '0' and hex_str[1] == 'x'))) {
            hex_str = hex_str[1..];
            if (hex_str.len > 0 and hex_str[0] == 'x') hex_str = hex_str[1..];
        }

        if (hex_str.len == 0 or hex_str.len > 6) {
            return ColorError.InvalidHex;
        }

        var value: u32 = 0;
        var i: usize = 0;
        while (i < hex_str.len) : (i += 1) {
            const c = hex_str[i];
            const digit = switch (c) {
                '0'...'9' => c - '0',
                'a'...'f' => c - 'a' + 10,
                'A'...'F' => c - 'A' + 10,
                else => return ColorError.InvalidHex,
            };
            value = @as(u32, digit) + (value * 16);
        }

        return Color.initHex(value);
    }

    pub fn parseRGB(str: []const u8) ColorError!Color {
        if (!std.mem.startsWith(u8, str, "rgb(") or !std.mem.endsWith(u8, str, ")")) {
            return ColorError.InvalidRGB;
        }

        const inner = str[4 .. str.len - 1];
        var parts = std.mem.splitScalar(u8, inner, ',');
        var values: [3]u8 = undefined;
        var idx: usize = 0;

        while (parts.next()) |part| {
            if (idx >= 3) return ColorError.InvalidRGB;
            const trimmed = std.mem.trim(u8, part, " \t");
            if (trimmed.len == 0) return ColorError.InvalidRGB;
            values[idx] = std.fmt.parseInt(u8, trimmed, 10) catch return ColorError.InvalidRGB;
            idx += 1;
        }

        if (idx != 3) return ColorError.InvalidRGB;

        return Color.initRGB(values[0], values[1], values[2]);
    }

    pub fn fromAnsiIndex(index: u8) Color {
        return Color.initAnsi(index);
    }

    pub fn toRGB(self: Color) ?struct { u8, u8, u8 } {
        return switch (self) {
            .rgb => |c| .{ c.r, c.g, c.b },
            .hex => |h| .{
                @truncate(h >> 16),
                @truncate(h >> 8),
                @truncate(h),
            },
            .float => |f| .{
                @min(255, @as(u8, @intFromFloat(f.r * 255.0))),
                @min(255, @as(u8, @intFromFloat(f.g * 255.0))),
                @min(255, @as(u8, @intFromFloat(f.b * 255.0))),
            },
            .named => |n| switch (n) {
                .black => .{ 0, 0, 0 },
                .red => .{ 128, 0, 0 },
                .green => .{ 0, 128, 0 },
                .yellow => .{ 128, 128, 0 },
                .blue => .{ 0, 0, 128 },
                .magenta => .{ 128, 0, 128 },
                .cyan => .{ 0, 128, 128 },
                .white => .{ 192, 192, 192 },
                .bright_black => .{ 128, 128, 128 },
                .bright_red => .{ 255, 0, 0 },
                .bright_green => .{ 0, 255, 0 },
                .bright_yellow => .{ 255, 255, 0 },
                .bright_blue => .{ 0, 0, 255 },
                .bright_magenta => .{ 255, 0, 255 },
                .bright_cyan => .{ 0, 255, 255 },
                .bright_white => .{ 255, 255, 255 },
            },
            else => null,
        };
    }

    pub fn toHex(self: Color) ?u32 {
        if (self.toRGB()) |rgb| {
            return (@as(u32, rgb[0]) << 16) | (@as(u32, rgb[1]) << 8) | @as(u32, rgb[2]);
        }
        return null;
    }

    pub fn toFloat(self: Color) ?struct { f32, f32, f32 } {
        return switch (self) {
            .float => |f| .{ f.r, f.g, f.b },
            .rgb => |c| .{
                @as(f32, @floatFromInt(c.r)) / 255.0,
                @as(f32, @floatFromInt(c.g)) / 255.0,
                @as(f32, @floatFromInt(c.b)) / 255.0,
            },
            .hex => |h| .{
                @as(f32, @floatFromInt(@as(u8, @truncate(h >> 16)))) / 255.0,
                @as(f32, @floatFromInt(@as(u8, @truncate(h >> 8)))) / 255.0,
                @as(f32, @floatFromInt(@as(u8, @truncate(h)))) / 255.0,
            },
            .named => |n| switch (n) {
                .black => .{ 0.0, 0.0, 0.0 },
                .red => .{ 128.0 / 255.0, 0.0, 0.0 },
                .green => .{ 0.0, 128.0 / 255.0, 0.0 },
                .yellow => .{ 128.0 / 255.0, 128.0 / 255.0, 0.0 },
                .blue => .{ 0.0, 0.0, 128.0 / 255.0 },
                .magenta => .{ 128.0 / 255.0, 0.0, 128.0 / 255.0 },
                .cyan => .{ 0.0, 128.0 / 255.0, 128.0 / 255.0 },
                .white => .{ 192.0 / 255.0, 192.0 / 255.0, 192.0 / 255.0 },
                .bright_black => .{ 128.0 / 255.0, 128.0 / 255.0, 128.0 / 255.0 },
                .bright_red => .{ 1.0, 0.0, 0.0 },
                .bright_green => .{ 0.0, 1.0, 0.0 },
                .bright_yellow => .{ 1.0, 1.0, 0.0 },
                .bright_blue => .{ 0.0, 0.0, 1.0 },
                .bright_magenta => .{ 1.0, 0.0, 1.0 },
                .bright_cyan => .{ 0.0, 1.0, 1.0 },
                .bright_white => .{ 1.0, 1.0, 1.0 },
            },
            else => null,
        };
    }

    pub fn toAnsi(self: Color) ?u8 {
        return switch (self) {
            .ansi => |a| a,
            .named => |n| switch (n) {
                .black => 30,
                .red => 31,
                .green => 32,
                .yellow => 33,
                .blue => 34,
                .magenta => 35,
                .cyan => 36,
                .white => 37,
                .bright_black => 90,
                .bright_red => 91,
                .bright_green => 92,
                .bright_yellow => 93,
                .bright_blue => 94,
                .bright_magenta => 95,
                .bright_cyan => 96,
                .bright_white => 97,
            },
            else => null,
        };
    }
};

pub const ColorMap = struct {
    const Entry = struct {
        key: u8,
        value: ?Color,
    };

    map: [256]Entry,

    pub fn init() ColorMap {
        var entries: [256]Entry = undefined;
        var i: usize = 0;
        while (i < 256) : (i += 1) {
            entries[i] = Entry{ .key = @as(u8, @intCast(i)), .value = null };
        }
        return ColorMap{ .map = entries };
    }

    pub fn set(self: *ColorMap, index: u8, color: Color) void {
        self.map[index] = Entry{ .key = index, .value = color };
    }

    pub fn get(self: *const ColorMap, index: u8) ?Color {
        return self.map[index].value;
    }

    pub fn clear(self: *ColorMap) void {
        var i: usize = 0;
        while (i < 256) : (i += 1) {
            self.map[i] = Entry{ .key = @as(u8, @intCast(i)), .value = null };
        }
    }

    pub fn fillDefault(self: *ColorMap) void {
        self.set(0, Color.initNamed(.black));
        self.set(1, Color.initNamed(.red));
        self.set(2, Color.initNamed(.green));
        self.set(3, Color.initNamed(.yellow));
        self.set(4, Color.initNamed(.blue));
        self.set(5, Color.initNamed(.magenta));
        self.set(6, Color.initNamed(.cyan));
        self.set(7, Color.initNamed(.white));
        self.set(8, Color.initNamed(.bright_black));
        self.set(9, Color.initNamed(.bright_red));
        self.set(10, Color.initNamed(.bright_green));
        self.set(11, Color.initNamed(.bright_yellow));
        self.set(12, Color.initNamed(.bright_blue));
        self.set(13, Color.initNamed(.bright_magenta));
        self.set(14, Color.initNamed(.bright_cyan));
        self.set(15, Color.initNamed(.bright_white));

        var i: usize = 16;
        while (i < 232) : (i += 1) {
            const level = @as(u8, @intCast((i - 16) / 36));
            const level_val = @as(u8, @intFromFloat(@floor(@as(f32, @floatFromInt(level)) * 255.0 / 5.0)));
            self.set(@as(u8, @intCast(i)), Color.initRGB(level_val, level_val, level_val));
        }

        var j: usize = 232;
        while (j < 256) : (j += 1) {
            const level = @as(u8, @intFromFloat(@floor(@as(f32, @floatFromInt(j - 232)) * 255.0 / 23.0)));
            self.set(@as(u8, @intCast(j)), Color.initRGB(level, level, level));
        }
    }

    pub fn setRGB(self: *ColorMap, index: u8, r: u8, g: u8, b: u8) void {
        self.set(index, Color.initRGB(r, g, b));
    }

    pub fn setHex(self: *ColorMap, index: u8, hex: u32) ColorError!void {
        const color = try Color.initHex(hex);
        self.set(index, color);
    }

    pub fn setAnsi(self: *ColorMap, index: u8, ansi: u8) void {
        self.set(index, Color.initAnsi(ansi));
    }
};

/// Test
const std = @import("std");
const t = std.testing;
const exeptEqual = t.expectEqual;

test "Color.initHex with valid value" {
    const color = try Color.initHex(0xFF5500);
    try exeptEqual(Color{ .hex = 0xFF5500 }, color);
}

test "Color.initHex with value exceeding 24-bit" {
    const result = Color.initHex(0x1000000);
    try exeptEqual(ColorError.InvalidHex, result);
}

test "Color.initRGB" {
    const color = Color.initRGB(255, 128, 64);
    try exeptEqual(Color{ .rgb = .{ .r = 255, .g = 128, .b = 64 } }, color);
}

test "Color.initNamed" {
    const color = Color.initNamed(.red);
    try exeptEqual(Color{ .named = .red }, color);
}

test "Color.initFloat with valid values" {
    const color = try Color.initFloat(1.0, 0.5, 0.25);
    try exeptEqual(Color{ .float = .{ .r = 1.0, .g = 0.5, .b = 0.25 } }, color);
}

test "Color.initFloat with negative value returns error" {
    const result = Color.initFloat(-0.1, 0.5, 0.25);
    try exeptEqual(ColorError.InvalidFloat, result);
}

test "Color.initFloat with value > 1 returns error" {
    const result = Color.initFloat(1.0, 1.5, 0.25);
    try exeptEqual(ColorError.InvalidFloat, result);
}

test "Color.initAnsi" {
    const color = Color.initAnsi(42);
    try exeptEqual(Color{ .ansi = 42 }, color);
}

test "Color.parseHex without prefix" {
    const color = try Color.parseHex("FF5500");
    try exeptEqual(@as(u32, 0xFF5500), color.hex);
}

test "Color.parseHex with hash prefix" {
    const color = try Color.parseHex("#FF5500");
    try exeptEqual(@as(u32, 0xFF5500), color.hex);
}

test "Color.parseHex with 0x prefix" {
    const color = try Color.parseHex("0xFF5500");
    try exeptEqual(@as(u32, 0xFF5500), color.hex);
}

test "Color.parseHex with lowercase" {
    const color = try Color.parseHex("ff5500");
    try exeptEqual(@as(u32, 0xFF5500), color.hex);
}

test "Color.parseHex with mixed case" {
    const color = try Color.parseHex("Ff55Aa");
    try exeptEqual(@as(u32, 0xFF55AA), color.hex);
}

test "Color.parseHex with short hex" {
    const color = try Color.parseHex("F00");
    try exeptEqual(@as(u32, 0xF00), color.hex);
}

test "Color.parseHex with empty string returns error" {
    const result = Color.parseHex("");
    try exeptEqual(ColorError.InvalidHex, result);
}

test "Color.parseHex with invalid character returns error" {
    const result = Color.parseHex("GG0000");
    try exeptEqual(ColorError.InvalidHex, result);
}

test "Color.parseHex with too long string returns error" {
    const result = Color.parseHex("FF5500AA");
    try exeptEqual(ColorError.InvalidHex, result);
}

test "Color.parseRGB with valid values" {
    const color = try Color.parseRGB("rgb(255, 128, 64)");
    const rgb = color.toRGB();
    try exeptEqual(@as(u8, 255), rgb.?[0]);
    try exeptEqual(@as(u8, 128), rgb.?[1]);
    try exeptEqual(@as(u8, 64), rgb.?[2]);
}

test "Color.parseRGB with spaces" {
    const color = try Color.parseRGB("rgb( 255 , 128 , 64 )");
    const rgb = color.toRGB();
    try exeptEqual(@as(u8, 255), rgb.?[0]);
    try exeptEqual(@as(u8, 128), rgb.?[1]);
    try exeptEqual(@as(u8, 64), rgb.?[2]);
}

test "Color.parseRGB with missing closing paren returns error" {
    const result = Color.parseRGB("rgb(255, 128, 64");
    try exeptEqual(ColorError.InvalidRGB, result);
}

test "Color.parseRGB with missing opening paren returns error" {
    const result = Color.parseRGB("255, 128, 64)");
    try exeptEqual(ColorError.InvalidRGB, result);
}

test "Color.parseRGB with wrong number of values returns error" {
    const result = Color.parseRGB("rgb(255, 128)");
    try exeptEqual(ColorError.InvalidRGB, result);
}

test "Color.parseRGB with negative value returns error" {
    const result = Color.parseRGB("rgb(-1, 128, 64)");
    try exeptEqual(ColorError.InvalidRGB, result);
}

test "Color.parseRGB with value > 255 returns error" {
    const result = Color.parseRGB("rgb(256, 128, 64)");
    try exeptEqual(ColorError.InvalidRGB, result);
}

test "Color.fromAnsiIndex" {
    const color = Color.fromAnsiIndex(42);
    try exeptEqual(@as(u8, 42), color.ansi);
}

test "Color.toRGB from rgb variant" {
    const color = Color.initRGB(255, 128, 64);
    const rgb = color.toRGB();
    try exeptEqual(@as(u8, 255), rgb.?[0]);
    try exeptEqual(@as(u8, 128), rgb.?[1]);
    try exeptEqual(@as(u8, 64), rgb.?[2]);
}

test "Color.toRGB from hex variant" {
    const color = try Color.initHex(0xFF8800);
    const rgb = color.toRGB();
    try exeptEqual(@as(u8, 255), rgb.?[0]);
    try exeptEqual(@as(u8, 136), rgb.?[1]);
    try exeptEqual(@as(u8, 0), rgb.?[2]);
}

test "Color.toRGB from float variant" {
    const color = try Color.initFloat(1.0, 0.5, 0.0);
    const rgb = color.toRGB();
    try exeptEqual(@as(u8, 255), rgb.?[0]);
    try exeptEqual(@as(u8, 127), rgb.?[1]);
    try exeptEqual(@as(u8, 0), rgb.?[2]);
}

test "Color.toRGB from named red" {
    const color = Color.initNamed(.red);
    const rgb = color.toRGB();
    try exeptEqual(@as(u8, 128), rgb.?[0]);
    try exeptEqual(@as(u8, 0), rgb.?[1]);
    try exeptEqual(@as(u8, 0), rgb.?[2]);
}

test "Color.toRGB from none returns null" {
    const color = Color{ .none = {} };
    try exeptEqual(@as(?struct { u8, u8, u8 }, null), color.toRGB());
}

test "Color.toHex from hex variant" {
    const color = try Color.initHex(0xFF8800);
    const hex = color.toHex();
    try exeptEqual(@as(?u32, 0xFF8800), hex);
}

test "Color.toHex from rgb variant" {
    const color = Color.initRGB(255, 128, 64);
    const hex = color.toHex();
    try exeptEqual(@as(?u32, 0xFF8040), hex);
}

test "Color.toHex from none returns null" {
    const color = Color{ .none = {} };
    try exeptEqual(@as(?u32, null), color.toHex());
}

test "Color.toFloat from float variant" {
    const color = try Color.initFloat(0.5, 0.25, 0.125);
    const f = color.toFloat();
    try exeptEqual(@as(?struct { f32, f32, f32 }, .{ 0.5, 0.25, 0.125 }), f);
}

test "Color.toFloat from rgb variant" {
    const color = Color.initRGB(128, 64, 32);
    const f = color.toFloat();
    try exeptEqual(@as(?struct { f32, f32, f32 }, .{ 128.0 / 255.0, 64.0 / 255.0, 32.0 / 255.0 }), f);
}

test "Color.toFloat from none returns null" {
    const color = Color{ .none = {} };
    try exeptEqual(@as(?struct { f32, f32, f32 }, null), color.toFloat());
}

test "Color.toAnsi from ansi variant" {
    const color = Color.initAnsi(42);
    const ansi = color.toAnsi();
    try exeptEqual(@as(?u8, 42), ansi);
}

test "Color.toAnsi from named red" {
    const color = Color.initNamed(.red);
    const ansi = color.toAnsi();
    try exeptEqual(@as(?u8, 31), ansi);
}

test "Color.toAnsi from named bright_green" {
    const color = Color.initNamed(.bright_green);
    const ansi = color.toAnsi();
    try exeptEqual(@as(?u8, 92), ansi);
}

test "Color.toAnsi from rgb returns null" {
    const color = Color.initRGB(255, 128, 64);
    try exeptEqual(@as(?u8, null), color.toAnsi());
}

test "ColorMap.init creates empty map" {
    const cmap = ColorMap.init();
    try exeptEqual(@as(u8, 0), cmap.map[0].key);
    try exeptEqual(@as(?Color, null), cmap.map[0].value);
}

test "ColorMap.set and get" {
    var cmap = ColorMap.init();
    const color = Color.initRGB(255, 128, 64);
    cmap.set(42, color);
    const retrieved = cmap.get(42);
    try exeptEqual(color, retrieved.?);
}

test "ColorMap.get returns null for unset index" {
    var cmap = ColorMap.init();
    try exeptEqual(@as(?Color, null), cmap.get(100));
}

test "ColorMap.clear resets all entries" {
    var cmap = ColorMap.init();
    cmap.set(0, Color.initRGB(255, 0, 0));
    cmap.set(100, Color.initRGB(0, 255, 0));
    cmap.clear();
    try exeptEqual(@as(?Color, null), cmap.get(0));
    try exeptEqual(@as(?Color, null), cmap.get(100));
}

test "ColorMap.fillDefault sets 16 base colors" {
    var cmap = ColorMap.init();
    cmap.fillDefault();

    try exeptEqual(Color.initNamed(.black), cmap.get(0).?);
    try exeptEqual(Color.initNamed(.red), cmap.get(1).?);
    try exeptEqual(Color.initNamed(.green), cmap.get(2).?);
    try exeptEqual(Color.initNamed(.yellow), cmap.get(3).?);
    try exeptEqual(Color.initNamed(.blue), cmap.get(4).?);
    try exeptEqual(Color.initNamed(.magenta), cmap.get(5).?);
    try exeptEqual(Color.initNamed(.cyan), cmap.get(6).?);
    try exeptEqual(Color.initNamed(.white), cmap.get(7).?);
    try exeptEqual(Color.initNamed(.bright_black), cmap.get(8).?);
    try exeptEqual(Color.initNamed(.bright_red), cmap.get(9).?);
    try exeptEqual(Color.initNamed(.bright_green), cmap.get(10).?);
    try exeptEqual(Color.initNamed(.bright_yellow), cmap.get(11).?);
    try exeptEqual(Color.initNamed(.bright_blue), cmap.get(12).?);
    try exeptEqual(Color.initNamed(.bright_magenta), cmap.get(13).?);
    try exeptEqual(Color.initNamed(.bright_cyan), cmap.get(14).?);
    try exeptEqual(Color.initNamed(.bright_white), cmap.get(15).?);
}

test "ColorMap.fillDefault fills all 256 entries" {
    var cmap = ColorMap.init();
    cmap.fillDefault();

    var i: usize = 0;
    while (i < 256) : (i += 1) {
        _ = cmap.get(@as(u8, @intCast(i))) orelse return error.TestExpectedValue;
    }
}

test "ColorMap.setRGB" {
    var cmap = ColorMap.init();
    cmap.setRGB(50, 100, 150, 200);
    const color = cmap.get(50).?;
    const rgb = color.toRGB().?;
    try exeptEqual(@as(u8, 100), rgb[0]);
    try exeptEqual(@as(u8, 150), rgb[1]);
    try exeptEqual(@as(u8, 200), rgb[2]);
}

test "ColorMap.setHex" {
    var cmap = ColorMap.init();
    try cmap.setHex(50, 0x123456);
    const color = cmap.get(50).?;
    const hex = color.toHex().?;
    try exeptEqual(@as(u32, 0x123456), hex);
}

test "ColorMap.setHex with invalid value returns error" {
    var cmap = ColorMap.init();
    const result = cmap.setHex(50, 0x1000000);
    try exeptEqual(ColorError.InvalidHex, result);
}

test "ColorMap.setAnsi" {
    var cmap = ColorMap.init();
    cmap.setAnsi(50, 42);
    const color = cmap.get(50).?;
    try exeptEqual(@as(u8, 42), color.ansi);
}

test "ColorMap overwrites existing entry" {
    var cmap = ColorMap.init();
    cmap.set(10, Color.initRGB(255, 0, 0));
    cmap.set(10, Color.initRGB(0, 255, 0));
    const color = cmap.get(10).?;
    const rgb = color.toRGB().?;
    try exeptEqual(@as(u8, 0), rgb[0]);
    try exeptEqual(@as(u8, 255), rgb[1]);
    try exeptEqual(@as(u8, 0), rgb[2]);
}

test "Color named colors toRGB" {
    const black = Color.initNamed(.black).toRGB().?;
    try exeptEqual(@as(u8, 0), black[0]);
    try exeptEqual(@as(u8, 0), black[1]);
    try exeptEqual(@as(u8, 0), black[2]);

    const white = Color.initNamed(.white).toRGB().?;
    try exeptEqual(@as(u8, 192), white[0]);
    try exeptEqual(@as(u8, 192), white[1]);
    try exeptEqual(@as(u8, 192), white[2]);

    const bright_white = Color.initNamed(.bright_white).toRGB().?;
    try exeptEqual(@as(u8, 255), bright_white[0]);
    try exeptEqual(@as(u8, 255), bright_white[1]);
    try exeptEqual(@as(u8, 255), bright_white[2]);
}

test "Color named colors toAnsi" {
    try exeptEqual(@as(?u8, 30), Color.initNamed(.black).toAnsi());
    try exeptEqual(@as(?u8, 31), Color.initNamed(.red).toAnsi());
    try exeptEqual(@as(?u8, 32), Color.initNamed(.green).toAnsi());
    try exeptEqual(@as(?u8, 33), Color.initNamed(.yellow).toAnsi());
    try exeptEqual(@as(?u8, 34), Color.initNamed(.blue).toAnsi());
    try exeptEqual(@as(?u8, 35), Color.initNamed(.magenta).toAnsi());
    try exeptEqual(@as(?u8, 36), Color.initNamed(.cyan).toAnsi());
    try exeptEqual(@as(?u8, 37), Color.initNamed(.white).toAnsi());
    try exeptEqual(@as(?u8, 90), Color.initNamed(.bright_black).toAnsi());
    try exeptEqual(@as(?u8, 91), Color.initNamed(.bright_red).toAnsi());
    try exeptEqual(@as(?u8, 92), Color.initNamed(.bright_green).toAnsi());
    try exeptEqual(@as(?u8, 93), Color.initNamed(.bright_yellow).toAnsi());
    try exeptEqual(@as(?u8, 94), Color.initNamed(.bright_blue).toAnsi());
    try exeptEqual(@as(?u8, 95), Color.initNamed(.bright_magenta).toAnsi());
    try exeptEqual(@as(?u8, 96), Color.initNamed(.bright_cyan).toAnsi());
    try exeptEqual(@as(?u8, 97), Color.initNamed(.bright_white).toAnsi());
}
