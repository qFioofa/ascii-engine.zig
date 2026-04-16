const MaskModule = @import("Mask.zig");
const Mask = MaskModule.Mask;

const AnimationModule = @import("Animation.zig");
const Animation = AnimationModule.Animation;

const ColorModule = @import("Color.zig");
const Color = ColorModule.Color;
const ColorMap = ColorModule.ColorMap;

const Types = @import("Types.zig");
const Point2 = Types.Point2;
const Point3 = Types.Point3;

const EntityError = error{
    InvalidePovit,
};

const Entity = struct {
    povit: Point2,
    position: Point3,
    velocity: Point2,
    isDead: bool,

    animation: Animation,
    preDraw: *const fn (*Entity) void,
    afterDraw: *const fn (*Entity) void,
};
