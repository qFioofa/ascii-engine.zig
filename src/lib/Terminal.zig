const Types = @import("Types.zig");
const Point2 = Types.Point2;
const Point3 = Types.Point3;

const Terminal = struct {
    size: Point2,
    can_display_color: bool = false,

    pub fn init() Terminal {
        return Terminal();
    }
};
