/// Primitive types
pub const Point2 = struct {
    x: i32 = 0,
    y: i32 = 0,

    pub fn isPositive(self: *const Point2) bool {
        return self.*.x > 0 and self.*.y > 0;
    }

    pub const matrix = struct {
        pub fn validSize(self: *const Point2) bool {
            return self.*.x >= 1 and self.*.y >= 1;
        }
    };
};

pub const Point3 = struct {
    x: i32 = 0,
    y: i32 = 0,
    z: i32 = 0,
};
