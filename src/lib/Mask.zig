const Types = @import("Types.zig");
const Point2 = Types.Point2;

pub const MASK_DEFAULT_FILL = ' ';

pub const MaskError = error{
    InvalidSize,
    InvalidContent,
};

pub const MaskContent = struct {
    content: ?[]const u8,

    pub fn init(content: ?[]const u8) !MaskContent {
        if (content) |c| {
            if (c.len <= 0) {
                return MaskError.InvalidContent;
            }
        }
        return MaskContent{
            .content = content,
        };
    }
};

pub const Mask = struct {
    size: ?Point2,
    char_space: u8,
    char_fill: ?u8 = null,
    content: ?MaskContent,

    pub const default = Mask{
        .size = null,
        .char_space = MASK_DEFAULT_FILL,
        .char_fill = null,
        .content = null,
    };

    pub fn init(char_space: ?u8, char_fill: ?u8, size: ?Point2, content: ?MaskContent) MaskError!Mask {
        if (size) |s| {
            if (!Point2.matrix.validSize(&s)) {
                return MaskError.InvalidSize;
            }
        }

        const d = Mask.default;

        return Mask{
            .size = size orelse d.size,
            .char_space = char_space orelse d.char_space,
            .char_fill = char_fill orelse d.char_fill,
            .content = content orelse d.content,
        };
    }
};

const std = @import("std");
const t = std.testing;
const exeptEqual = t.expectEqual;
const expectEqualStrings = t.expectEqualStrings;

test "MaskContent.init with valid content" {
    const content = try MaskContent.init("test");
    try expectEqualStrings("test", content.content.?);
}

test "MaskContent.init with null content" {
    const content = try MaskContent.init(null);
    try exeptEqual(@as(?[]const u8, null), content.content);
}

test "MaskContent.init with empty string returns InvalidContent error" {
    const result = MaskContent.init("");
    try exeptEqual(MaskError.InvalidContent, result);
}

test "MaskContent.init with content of length 1" {
    const content = try MaskContent.init("a");
    try expectEqualStrings("a", content.content.?);
}

test "MaskContent.init with whitespace content" {
    const content = try MaskContent.init("   ");
    try expectEqualStrings("   ", content.content.?);
}

test "MaskContent.init with newline content" {
    const content = try MaskContent.init("\n");
    try expectEqualStrings("\n", content.content.?);
}

test "MaskContent.init with special ASCII content" {
    const content = try MaskContent.init("!@#$%^&*()");
    try expectEqualStrings("!@#$%^&*()", content.content.?);
}

test "MaskContent.init preserves original string reference" {
    const original = "hello world";
    const content = try MaskContent.init(original);
    try exeptEqual(original.len, content.content.?.len);
}

test "Mask.default has correct initial values" {
    const m = Mask.default;
    try exeptEqual(@as(?Point2, null), m.size);
    try exeptEqual(@as(u8, ' '), m.char_space);
    try exeptEqual(@as(?u8, null), m.char_fill);
    try exeptEqual(@as(?MaskContent, null), m.content);
}

test "Mask.init with all parameters provided and valid size" {
    const size = Point2{ .x = 10, .y = 5 };
    const content = try MaskContent.init("test");
    const m = try Mask.init(' ', '#', size, content);

    try exeptEqual(size, m.size);
    try exeptEqual(@as(u8, ' '), m.char_space);
    try exeptEqual(@as(u8, '#'), m.char_fill.?);
    try expectEqualStrings("test", m.content.?.content.?);
}

test "Mask.init with null size uses default" {
    const m = try Mask.init(' ', '#', null, null);
    try exeptEqual(@as(?Point2, null), m.size);
    try exeptEqual(@as(u8, ' '), m.char_space);
    try exeptEqual(@as(u8, '#'), m.char_fill.?);
    try exeptEqual(@as(?MaskContent, null), m.content);
}

test "Mask.init with null char_space uses default" {
    const size = Point2{ .x = 10, .y = 5 };
    const m = try Mask.init(null, '#', size, null);
    try exeptEqual(@as(u8, ' '), m.char_space);
}

test "Mask.init with null char_fill uses default" {
    const size = Point2{ .x = 10, .y = 5 };
    const m = try Mask.init(' ', null, size, null);
    try exeptEqual(@as(?u8, null), m.char_fill);
}

test "Mask.init with invalid size x=0 returns InvalidSize error" {
    const invalid_size = Point2{ .x = 0, .y = 5 };
    const result = Mask.init(' ', '#', invalid_size, null);
    try exeptEqual(MaskError.InvalidSize, result);
}

test "Mask.init with invalid size y=0 returns InvalidSize error" {
    const invalid_size = Point2{ .x = 10, .y = 0 };
    const result = Mask.init(' ', '#', invalid_size, null);
    try exeptEqual(MaskError.InvalidSize, result);
}

test "Mask.init with invalid size x=-1 returns InvalidSize error" {
    const invalid_size = Point2{ .x = -1, .y = 5 };
    const result = Mask.init(' ', '#', invalid_size, null);
    try exeptEqual(MaskError.InvalidSize, result);
}

test "Mask.init with invalid size y=-5 returns InvalidSize error" {
    const invalid_size = Point2{ .x = 10, .y = -5 };
    const result = Mask.init(' ', '#', invalid_size, null);
    try exeptEqual(MaskError.InvalidSize, result);
}

test "Mask.init with custom char_space character" {
    const size = Point2{ .x = 10, .y = 5 };
    const m = try Mask.init('*', '#', size, null);
    try exeptEqual(@as(u8, '*'), m.char_space);
    try exeptEqual(@as(u8, '#'), m.char_fill.?);
}

test "Mask.init preserves content" {
    const size = Point2{ .x = 10, .y = 5 };
    const test_content = "Hello, World!";
    const content = try MaskContent.init(test_content);
    const m = try Mask.init(' ', '#', size, content);

    try expectEqualStrings(test_content, m.content.?.content.?);
}

test "Mask.init with special characters" {
    const size = Point2{ .x = 5, .y = 5 };
    const m = try Mask.init('#', '.', size, null);
    try exeptEqual(@as(u8, '#'), m.char_space);
    try exeptEqual(@as(u8, '.'), m.char_fill.?);
}

test "Mask initialization chain with partial defaults" {
    const size = Point2{ .x = 20, .y = 10 };
    const m = try Mask.init(null, null, size, null);

    try exeptEqual(size, m.size);
    try exeptEqual(@as(u8, ' '), m.char_space);
    try exeptEqual(@as(?u8, null), m.char_fill);
}

test "Mask with same char_space and char_fill" {
    const size = Point2{ .x = 5, .y = 5 };
    const m = try Mask.init('#', '#', size, null);
    try exeptEqual(@as(u8, '#'), m.char_space);
    try exeptEqual(@as(u8, '#'), m.char_fill.?);
}

test "Mask with Point2 minimum valid size 1,1" {
    const size = Point2{ .x = 1, .y = 1 };
    const m = try Mask.init(' ', '#', size, null);
    try exeptEqual(size, m.size);
}

test "Mask with larger Point2 size" {
    const size = Point2{ .x = 100, .y = 50 };
    const m = try Mask.init(' ', '#', size, null);
    try exeptEqual(size, m.size);
}

test "Mask with maximum reasonable Point2 size" {
    const size = Point2{ .x = 1000, .y = 1000 };
    const m = try Mask.init(' ', '#', size, null);
    try exeptEqual(size, m.size);
}

test "Mask.init with null content uses default" {
    const size = Point2{ .x = 10, .y = 5 };
    const m = try Mask.init(' ', '#', size, null);
    try exeptEqual(@as(?MaskContent, null), m.content);
}

test "MaskContent.init with empty string returns error" {
    const result = MaskContent.init("");
    try exeptEqual(MaskError.InvalidContent, result);
}

test "Mask.init with all nulls uses all defaults" {
    const m = try Mask.init(null, null, null, null);

    try exeptEqual(@as(?Point2, null), m.size);
    try exeptEqual(@as(u8, ' '), m.char_space);
    try exeptEqual(@as(?u8, null), m.char_fill);
    try exeptEqual(@as(?MaskContent, null), m.content);
}
