const Mask = @import("Mask.zig");

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

    _currentFrame: usize,
};
