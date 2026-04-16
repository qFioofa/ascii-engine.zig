const MaskModule = @import("Mask.zig");
const Mask = MaskModule.Mask;
const MaskError = MaskModule.MaskError;

const ColorModule = @import("Color.zig");
const Color = ColorModule.Color;
const ColorError = ColorModule.ColorError;

pub const AnimationError = error{
    InvalidLen,
    InvalidDelay,
    EmptyFrames,
    IndexOutOfBounds,
};

pub const Animation = struct {
    frames: []const Mask,
    delays: []const f32,
    color: union(ColorType) {
        solid: Color,
        perFrame: []const Color,
    },
    _currentFrame: usize,
    _isFinished: bool,
    _loop: bool,

    const ColorType = enum {
        solid,
        perFrame,
    };

    pub fn init(
        frames: []const Mask,
        delays: []const f32,
        color: Color,
        loop: bool,
    ) AnimationError!Animation {
        if (frames.len == 0) return AnimationError.EmptyFrames;
        if (delays.len != frames.len) return AnimationError.InvalidLen;
        if (delays.len > 0) {
            for (delays) |d| {
                if (d < 0.0) return AnimationError.InvalidDelay;
            }
        }

        return Animation{
            .frames = frames,
            .delays = delays,
            .color = .{ .solid = color },
            ._currentFrame = 0,
            ._isFinished = false,
            ._loop = loop,
        };
    }

    pub fn initPerFrameColor(
        frames: []const Mask,
        delays: []const f32,
        colors: []const Color,
        loop: bool,
    ) AnimationError!Animation {
        if (frames.len == 0) return AnimationError.EmptyFrames;
        if (delays.len != frames.len) return AnimationError.InvalidLen;
        if (colors.len != frames.len) return AnimationError.InvalidLen;
        if (delays.len > 0) {
            for (delays) |d| {
                if (d < 0.0) return AnimationError.InvalidDelay;
            }
        }

        return Animation{
            .frames = frames,
            .delays = delays,
            .color = .{ .perFrame = colors },
            ._currentFrame = 0,
            ._isFinished = false,
            ._loop = loop,
        };
    }

    pub fn getFrame(self: *const Animation, index: usize) AnimationError!Mask {
        if (index >= self.frames.len) return AnimationError.IndexOutOfBounds;
        return self.frames[index];
    }

    pub fn getCurrentFrame(self: *const Animation) AnimationError!Mask {
        return self.getFrame(self._currentFrame);
    }

    pub fn getDelay(self: *const Animation, index: usize) AnimationError!f32 {
        if (index >= self.delays.len) return AnimationError.IndexOutOfBounds;
        return self.delays[index];
    }

    pub fn getCurrentDelay(self: *const Animation) AnimationError!f32 {
        return self.getDelay(self._currentFrame);
    }

    pub fn getColor(self: *const Animation, index: ?usize) AnimationError!Color {
        const idx = index orelse self._currentFrame;
        if (idx >= self.frames.len) return AnimationError.IndexOutOfBounds;
        return switch (self.color) {
            .solid => |c| c,
            .perFrame => |colors| colors[idx],
        };
    }

    pub fn getCurrentColor(self: *const Animation) AnimationError!Color {
        return self.getColor(null);
    }

    pub fn update(self: *Animation) void {
        if (self._isFinished) return;

        if (self._currentFrame + 1 < self.frames.len) {
            self._currentFrame += 1;
        } else if (self._loop) {
            self._currentFrame = 0;
        } else {
            self._isFinished = true;
        }
    }

    pub fn next(self: *Animation) AnimationError!void {
        if (self._isFinished) return AnimationError.IndexOutOfBounds;
        self.update();
    }

    pub fn reset(self: *Animation) void {
        self._currentFrame = 0;
        self._isFinished = false;
    }

    pub fn seek(self: *Animation, index: usize) AnimationError!void {
        if (index >= self.frames.len) return AnimationError.IndexOutOfBounds;
        self._currentFrame = index;
        self._isFinished = false;
    }

    pub fn skip(self: *Animation, steps: usize) AnimationError!void {
        const newFrame = self._currentFrame + steps;
        if (newFrame >= self.frames.len) {
            if (self._loop) {
                self._currentFrame = newFrame % self.frames.len;
            } else {
                self._currentFrame = self.frames.len - 1;
                self._isFinished = true;
            }
        } else {
            self._currentFrame = newFrame;
        }
    }

    pub fn isFinished(self: *const Animation) bool {
        return self._isFinished;
    }

    pub fn isLoop(self: *const Animation) bool {
        return self._loop;
    }

    pub fn getCurrentFrameIndex(self: *const Animation) usize {
        return self._currentFrame;
    }

    pub fn getFrameCount(self: *const Animation) usize {
        return self.frames.len;
    }

    pub fn getTotalDuration(self: *const Animation) f32 {
        var total: f32 = 0;
        for (self.delays) |d| {
            total += d;
        }
        return total;
    }

    pub fn setLoop(self: *Animation, loop: bool) void {
        self._loop = loop;
    }

    pub fn setColor(self: *Animation, color: Color) void {
        self.color = .{ .solid = color };
    }

    pub fn setPerFrameColor(self: *Animation, colors: []const Color) AnimationError!void {
        if (colors.len != self.frames.len) return AnimationError.InvalidLen;
        self.color = .{ .perFrame = colors };
    }
};

const std = @import("std");
const t = std.testing;
const exeptEqual = t.expectEqual;

test "Animation.init with valid parameters" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const color = Color.initNamed(.red);

    const anim = try Animation.init(frames, delays, color, true);
    try exeptEqual(@as(usize, 2), anim.getFrameCount());
    try exeptEqual(@as(usize, 0), anim.getCurrentFrameIndex());
    try exeptEqual(false, anim.isFinished());
    try exeptEqual(true, anim.isLoop());
}

test "Animation.init with empty frames returns error" {
    const frames: []const Mask = &.{};
    const delays: []const f32 = &.{};
    const color = Color.initNamed(.red);

    const result = Animation.init(frames, delays, color, true);
    try exeptEqual(AnimationError.EmptyFrames, result);
}

test "Animation.init with mismatched delays length returns error" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{0.1};
    const color = Color.initNamed(.red);

    const result = Animation.init(frames, delays, color, true);
    try exeptEqual(AnimationError.InvalidLen, result);
}

test "Animation.init with negative delay returns error" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, -0.2 };
    const color = Color.initNamed(.red);

    const result = Animation.init(frames, delays, color, true);
    try exeptEqual(AnimationError.InvalidDelay, result);
}

test "Animation.initPerFrameColor with valid parameters" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const colors = &.{ Color.initNamed(.red), Color.initNamed(.blue) };

    const anim = try Animation.initPerFrameColor(frames, delays, colors, true);
    try exeptEqual(@as(usize, 2), anim.getFrameCount());
}

test "Animation.initPerFrameColor with mismatched colors length returns error" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const colors = &.{Color.initNamed(.red)};

    const result = Animation.initPerFrameColor(frames, delays, colors, true);
    try exeptEqual(AnimationError.InvalidLen, result);
}

test "Animation.getFrame with valid index" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);
    const frame = try anim.getFrame(1);
    try exeptEqual(Mask.default, frame);
}

test "Animation.getFrame with out of bounds index returns error" {
    const frames = &.{Mask.default};
    const delays = &.{0.1};
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);
    const result = anim.getFrame(5);
    try exeptEqual(AnimationError.IndexOutOfBounds, result);
}

test "Animation.getCurrentFrame" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);
    const frame = try anim.getCurrentFrame();
    try exeptEqual(Mask.default, frame);
}

test "Animation.getDelay with valid index" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);
    const delay = try anim.getDelay(1);
    try exeptEqual(@as(f32, 0.2), delay);
}

test "Animation.getDelay with out of bounds index returns error" {
    const frames = &.{Mask.default};
    const delays = &.{0.1};
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);
    const result = anim.getDelay(5);
    try exeptEqual(AnimationError.IndexOutOfBounds, result);
}

test "Animation.getColor returns solid color" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const color = Color.initNamed(.green);

    var anim = try Animation.init(frames, delays, color, true);
    const c = try anim.getColor(null);
    try exeptEqual(Color.initNamed(.green), c);
}

test "Animation.getColor with specific index" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const colors = &.{ Color.initNamed(.red), Color.initNamed(.blue) };

    var anim = try Animation.initPerFrameColor(frames, delays, colors, true);
    const c = try anim.getColor(1);
    try exeptEqual(Color.initNamed(.blue), c);
}

test "Animation.update advances frame" {
    const frames = &.{ Mask.default, Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2, 0.3 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, false);
    try exeptEqual(@as(usize, 0), anim.getCurrentFrameIndex());

    anim.update();
    try exeptEqual(@as(usize, 1), anim.getCurrentFrameIndex());

    anim.update();
    try exeptEqual(@as(usize, 2), anim.getCurrentFrameIndex());
}

test "Animation.update with loop wraps around" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);

    anim.update();
    try exeptEqual(@as(usize, 1), anim.getCurrentFrameIndex());

    anim.update();
    try exeptEqual(@as(usize, 0), anim.getCurrentFrameIndex());
}

test "Animation.update without loop sets finished" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, false);

    anim.update();
    try exeptEqual(false, anim.isFinished());

    anim.update();
    try exeptEqual(true, anim.isFinished());
}

test "Animation.next" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, false);

    try anim.next();
    try exeptEqual(@as(usize, 1), anim.getCurrentFrameIndex());
}

test "Animation.reset" {
    const frames = &.{ Mask.default, Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2, 0.3 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, false);
    anim.update();
    anim.update();

    anim.reset();
    try exeptEqual(@as(usize, 0), anim.getCurrentFrameIndex());
    try exeptEqual(false, anim.isFinished());
}

test "Animation.seek" {
    const frames = &.{ Mask.default, Mask.default, Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2, 0.3, 0.4 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);

    try anim.seek(2);
    try exeptEqual(@as(usize, 2), anim.getCurrentFrameIndex());
}

test "Animation.seek with out of bounds index returns error" {
    const frames = &.{Mask.default};
    const delays = &.{0.1};
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);
    const result = anim.seek(5);
    try exeptEqual(AnimationError.IndexOutOfBounds, result);
}

test "Animation.skip with loop" {
    const frames = &.{ Mask.default, Mask.default, Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2, 0.3, 0.4 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);

    try anim.skip(2);
    try exeptEqual(@as(usize, 2), anim.getCurrentFrameIndex());

    try anim.skip(3);
    try exeptEqual(@as(usize, 1), anim.getCurrentFrameIndex());
}

test "Animation.skip without loop stops at end" {
    const frames = &.{ Mask.default, Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2, 0.3 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, false);

    try anim.skip(5);
    try exeptEqual(@as(usize, 2), anim.getCurrentFrameIndex());
    try exeptEqual(true, anim.isFinished());
}

test "Animation.getTotalDuration" {
    const frames = &.{ Mask.default, Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2, 0.3 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);
    const duration = anim.getTotalDuration();
    try exeptEqual(@as(f32, 0.6), duration);
}

test "Animation.setLoop" {
    const frames = &.{Mask.default};
    const delays = &.{0.1};
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, false);
    try exeptEqual(false, anim.isLoop());

    anim.setLoop(true);
    try exeptEqual(true, anim.isLoop());
}

test "Animation.setColor" {
    const frames = &.{Mask.default};
    const delays = &.{0.1};
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);
    try exeptEqual(Color.initNamed(.red), try anim.getColor(null));

    anim.setColor(Color.initNamed(.blue));
    try exeptEqual(Color.initNamed(.blue), try anim.getColor(null));
}

test "Animation.setPerFrameColor" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);
    const newColors = &.{ Color.initNamed(.green), Color.initNamed(.yellow) };

    try anim.setPerFrameColor(newColors);
    try exeptEqual(Color.initNamed(.green), try anim.getColor(0));
    try exeptEqual(Color.initNamed(.yellow), try anim.getColor(1));
}

test "Animation.setPerFrameColor with mismatched length returns error" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);
    const newColors = &.{Color.initNamed(.green)};

    const result = anim.setPerFrameColor(newColors);
    try exeptEqual(AnimationError.InvalidLen, result);
}

test "Animation.getCurrentDelay" {
    const frames = &.{ Mask.default, Mask.default };
    const delays = &.{ 0.1, 0.2 };
    const color = Color.initNamed(.red);

    var anim = try Animation.init(frames, delays, color, true);
    const delay = try anim.getCurrentDelay();
    try exeptEqual(@as(f32, 0.1), delay);

    anim.update();
    const delay2 = try anim.getCurrentDelay();
    try exeptEqual(@as(f32, 0.2), delay2);
}

