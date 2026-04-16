const MaskModule = @import("Mask.zig");
const Mask = MaskModule.Mask;
const MaskError = MaskModule.MaskError;

const AnimationModule = @import("Animation.zig");
const Animation = AnimationModule.Animation;
const AnimationError = AnimationModule.AnimationError;

const ColorModule = @import("Color.zig");
const Color = ColorModule.Color;
const ColorError = ColorModule.ColorError;

const Types = @import("Types.zig");
const Point2 = Types.Point2;
const Point3 = Types.Point3;

pub const EntityError = error{
    InvalidPosition,
    InvalidVelocity,
    AnimationError,
    NullCallback,
};

pub const Entity = struct {
    pivot: Point2,
    position: Point3,
    velocity: Point2,
    dead: bool,
    visible: bool,
    animation: ?Animation,
    preDraw: ?*const fn (*Entity) void,
    postDraw: ?*const fn (*Entity) void,
    userData: ?*anyopaque,

    pub fn init(
        pivot: Point2,
        position: Point3,
        velocity: Point2,
        animation: ?Animation,
        preDraw: ?*const fn (*Entity) void,
        postDraw: ?*const fn (*Entity) void,
    ) Entity {
        return Entity{
            .pivot = pivot,
            .position = position,
            .velocity = velocity,
            .dead = false,
            .visible = true,
            .animation = animation,
            .preDraw = preDraw,
            .postDraw = postDraw,
            .userData = null,
        };
    }

    pub fn initWithAnimation(
        pivot: Point2,
        position: Point3,
        velocity: Point2,
        animation: Animation,
    ) Entity {
        return Entity{
            .pivot = pivot,
            .position = position,
            .velocity = velocity,
            .dead = false,
            .visible = true,
            .animation = animation,
            .preDraw = null,
            .postDraw = null,
            .userData = null,
        };
    }

    pub fn initStatic(pivot: Point2, position: Point3) Entity {
        return Entity{
            .pivot = pivot,
            .position = position,
            .velocity = Point2{ .x = 0, .y = 0 },
            .dead = false,
            .visible = true,
            .animation = null,
            .preDraw = null,
            .postDraw = null,
            .userData = null,
        };
    }

    pub fn getPivot(self: *const Entity) Point2 {
        return self.pivot;
    }

    pub fn setPivot(self: *Entity, pivot: Point2) void {
        self.pivot = pivot;
    }

    pub fn getPosition(self: *const Entity) Point3 {
        return self.position;
    }

    pub fn setPosition(self: *Entity, position: Point3) void {
        self.position = position;
    }

    pub fn getX(self: *const Entity) i32 {
        return self.position.x;
    }

    pub fn getY(self: *const Entity) i32 {
        return self.position.y;
    }

    pub fn getZ(self: *const Entity) i32 {
        return self.position.z;
    }

    pub fn setX(self: *Entity, x: i32) void {
        self.position.x = x;
    }

    pub fn setY(self: *Entity, y: i32) void {
        self.position.y = y;
    }

    pub fn setZ(self: *Entity, z: i32) void {
        self.position.z = z;
    }

    pub fn getVelocity(self: *const Entity) Point2 {
        return self.velocity;
    }

    pub fn setVelocity(self: *Entity, velocity: Point2) void {
        self.velocity = velocity;
    }

    pub fn getVelocityX(self: *const Entity) i32 {
        return self.velocity.x;
    }

    pub fn getVelocityY(self: *const Entity) i32 {
        return self.velocity.y;
    }

    pub fn setVelocityX(self: *Entity, vx: i32) void {
        self.velocity.x = vx;
    }

    pub fn setVelocityY(self: *Entity, vy: i32) void {
        self.velocity.y = vy;
    }

    pub fn update(self: *Entity) void {
        self.position.x += self.velocity.x;
        self.position.y += self.velocity.y;

        if (self.animation) |*anim| {
            anim.update();
        }
    }

    pub fn updateWithDelta(self: *Entity, dt: f32) void {
        self.position.x += @as(i32, @intFromFloat(@floor(@as(f32, @floatFromInt(self.velocity.x)) * dt)));
        self.position.y += @as(i32, @intFromFloat(@floor(@as(f32, @floatFromInt(self.velocity.y)) * dt)));

        if (self.animation) |*anim| {
            anim.update();
        }
    }

    pub fn move(self: *Entity, dx: i32, dy: i32) void {
        self.position.x += dx;
        self.position.y += dy;
    }

    pub fn moveByVelocity(self: *Entity) void {
        self.move(self.velocity.x, self.velocity.y);
    }

    pub fn isDead(self: *const Entity) bool {
        return self.dead;
    }

    pub fn kill(self: *Entity) void {
        self.dead = true;
    }

    pub fn revive(self: *Entity) void {
        self.dead = false;
    }

    pub fn isVisible(self: *const Entity) bool {
        return self.visible;
    }

    pub fn setVisible(self: *Entity, visible: bool) void {
        self.visible = visible;
    }

    pub fn show(self: *Entity) void {
        self.visible = true;
    }

    pub fn hide(self: *Entity) void {
        self.visible = false;
    }

    pub fn getAnimation(self: *const Entity) ?Animation {
        return self.animation;
    }

    pub fn setAnimation(self: *Entity, animation: Animation) void {
        self.animation = animation;
    }

    pub fn hasAnimation(self: *const Entity) bool {
        return self.animation != null;
    }

    pub fn getCurrentFrame(self: *const Entity) ?Mask {
        if (self.animation) |*anim| {
            return anim.getCurrentFrame() catch null;
        }
        return null;
    }

    pub fn getCurrentColor(self: *const Entity) ?Color {
        if (self.animation) |*anim| {
            return anim.getCurrentColor() catch null;
        }
        return null;
    }

    pub fn draw(self: *Entity) void {
        if (!self.visible or self.dead) return;

        if (self.preDraw) |callback| {
            callback(self);
        }

        if (self.animation) |_| {
            _ = self.getCurrentFrame();
            _ = self.getCurrentColor();
        }

        if (self.postDraw) |callback| {
            callback(self);
        }
    }

    pub fn setPreDraw(self: *Entity, callback: *const fn (*Entity) void) void {
        self.preDraw = callback;
    }

    pub fn setPostDraw(self: *Entity, callback: *const fn (*Entity) void) void {
        self.postDraw = callback;
    }

    pub fn setUserData(self: *Entity, data: ?*anyopaque) void {
        self.userData = data;
    }

    pub fn getUserData(self: *const Entity) ?*anyopaque {
        return self.userData;
    }

    pub fn distanceTo(self: *const Entity, other: *const Entity) f32 {
        const dx = @as(f32, @floatFromInt(self.position.x - other.position.x));
        const dy = @as(f32, @floatFromInt(self.position.y - other.position.y));
        const dz = @as(f32, @floatFromInt(self.position.z - other.position.z));
        return @sqrt(dx * dx + dy * dy + dz * dz);
    }

    pub fn distanceTo2D(self: *const Entity, other: *const Entity) f32 {
        const dx = @as(f32, @floatFromInt(self.position.x - other.position.x));
        const dy = @as(f32, @floatFromInt(self.position.y - other.position.y));
        return @sqrt(dx * dx + dy * dy);
    }

    pub fn isCollidingWith(self: *const Entity, other: *const Entity) bool {
        const dx = @abs(self.position.x - other.position.x);
        const dy = @abs(self.position.y - other.position.y);
        return dx < 1 and dy < 1;
    }

    pub fn reset(self: *Entity) void {
        self.dead = false;
        self.visible = true;
        if (self.animation) |*anim| {
            anim.reset();
        }
    }
};

const std = @import("std");
const t = std.testing;
const exeptEqual = t.expectEqual;

test "Entity.init creates entity with default values" {
    const pivot = Point2{ .x = 0, .y = 0 };
    const position = Point3{ .x = 10, .y = 20, .z = 0 };
    const velocity = Point2{ .x = 1, .y = 2 };

    const entity = Entity.init(pivot, position, velocity, null, null, null);

    try exeptEqual(@as(i32, 0), entity.pivot.x);
    try exeptEqual(@as(i32, 0), entity.pivot.y);
    try exeptEqual(@as(i32, 10), entity.position.x);
    try exeptEqual(@as(i32, 20), entity.position.y);
    try exeptEqual(@as(i32, 0), entity.position.z);
    try exeptEqual(@as(i32, 1), entity.velocity.x);
    try exeptEqual(@as(i32, 2), entity.velocity.y);
    try exeptEqual(false, entity.dead);
    try exeptEqual(true, entity.visible);
    try exeptEqual(@as(?Animation, null), entity.animation);
}

test "Entity.initWithAnimation" {
    const pivot = Point2{ .x = 0, .y = 0 };
    const position = Point3{ .x = 0, .y = 0, .z = 0 };

    const entity = Entity.initStatic(pivot, position);

    try exeptEqual(@as(?Animation, null), entity.animation);
}

test "Entity.initStatic creates entity with zero velocity" {
    const pivot = Point2{ .x = 5, .y = 5 };
    const position = Point3{ .x = 100, .y = 200, .z = 5 };

    const entity = Entity.initStatic(pivot, position);

    try exeptEqual(@as(i32, 0), entity.velocity.x);
    try exeptEqual(@as(i32, 0), entity.velocity.y);
}

test "Entity.getPivot and setPivot" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    try exeptEqual(@as(i32, 0), entity.getPivot().x);

    entity.setPivot(Point2{ .x = 10, .y = 20 });
    try exeptEqual(@as(i32, 10), entity.pivot.x);
    try exeptEqual(@as(i32, 20), entity.pivot.y);
}

test "Entity.getPosition and setPosition" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    try exeptEqual(@as(i32, 0), entity.getPosition().x);

    entity.setPosition(Point3{ .x = 50, .y = 60, .z = 70 });
    try exeptEqual(@as(i32, 50), entity.position.x);
    try exeptEqual(@as(i32, 60), entity.position.y);
    try exeptEqual(@as(i32, 70), entity.position.z);
}

test "Entity.getX, getY, getZ" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 1, .y = 2, .z = 3 });

    try exeptEqual(@as(i32, 1), entity.getX());
    try exeptEqual(@as(i32, 2), entity.getY());
    try exeptEqual(@as(i32, 3), entity.getZ());
}

test "Entity.setX, setY, setZ" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    entity.setX(10);
    entity.setY(20);
    entity.setZ(30);

    try exeptEqual(@as(i32, 10), entity.position.x);
    try exeptEqual(@as(i32, 20), entity.position.y);
    try exeptEqual(@as(i32, 30), entity.position.z);
}

test "Entity.getVelocity and setVelocity" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    entity.setVelocity(Point2{ .x = 5, .y = 10 });

    try exeptEqual(@as(i32, 5), entity.velocity.x);
    try exeptEqual(@as(i32, 10), entity.velocity.y);
}

test "Entity.getVelocityX and getVelocityY" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    entity.setVelocity(Point2{ .x = 3, .y = 7 });

    try exeptEqual(@as(i32, 3), entity.getVelocityX());
    try exeptEqual(@as(i32, 7), entity.getVelocityY());
}

test "Entity.setVelocityX and setVelocityY" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    entity.setVelocityX(100);
    entity.setVelocityY(200);

    try exeptEqual(@as(i32, 100), entity.velocity.x);
    try exeptEqual(@as(i32, 200), entity.velocity.y);
}

test "Entity.update applies velocity" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    entity.setVelocity(Point2{ .x = 5, .y = -3 });

    entity.update();

    try exeptEqual(@as(i32, 5), entity.position.x);
    try exeptEqual(@as(i32, -3), entity.position.y);
}

test "Entity.updateWithDelta applies scaled velocity" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    entity.setVelocity(Point2{ .x = 10, .y = 20 });

    entity.updateWithDelta(0.5);

    try exeptEqual(@as(i32, 5), entity.position.x);
    try exeptEqual(@as(i32, 10), entity.position.y);
}

test "Entity.move" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 10, .y = 10, .z = 0 });

    entity.move(5, -3);

    try exeptEqual(@as(i32, 15), entity.position.x);
    try exeptEqual(@as(i32, 7), entity.position.y);
}

test "Entity.moveByVelocity" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    entity.setVelocity(Point2{ .x = 7, .y = 11 });

    entity.moveByVelocity();

    try exeptEqual(@as(i32, 7), entity.position.x);
    try exeptEqual(@as(i32, 11), entity.position.y);
}

test "Entity.isDead, kill, revive" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    try exeptEqual(false, entity.isDead());

    entity.kill();
    try exeptEqual(true, entity.isDead());

    entity.revive();
    try exeptEqual(false, entity.isDead());
}

test "Entity.isVisible, setVisible, show, hide" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    try exeptEqual(true, entity.isVisible());

    entity.hide();
    try exeptEqual(false, entity.isVisible());

    entity.show();
    try exeptEqual(true, entity.isVisible());

    entity.setVisible(false);
    try exeptEqual(false, entity.isVisible());
}

test "Entity.setAnimation and hasAnimation" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    try exeptEqual(false, entity.hasAnimation());

    _ = entity.hasAnimation();
}

test "Entity.getCurrentFrame" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    const frame = entity.getCurrentFrame();
    try exeptEqual(@as(?Mask, null), frame);
}

test "Entity.draw with visible entity" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    entity.visible = true;
    entity.dead = false;

    entity.draw();
}

test "Entity.draw with hidden entity" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    entity.visible = false;

    entity.draw();
}

test "Entity.draw with dead entity" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    entity.dead = true;

    entity.draw();
}

test "Entity.setPreDraw and setPostDraw" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    const noop = struct {
        fn empty(_: *Entity) void {}
    }.empty;

    entity.setPreDraw(noop);
    entity.setPostDraw(noop);
}

test "Entity.setUserData and getUserData" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    try exeptEqual(@as(?*anyopaque, null), entity.getUserData());

    var data: u32 = 42;
    entity.setUserData(&data);
    try exeptEqual(@as(?*anyopaque, &data), entity.getUserData());
}

test "Entity.distanceTo" {
    var entity1 = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    var entity2 = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 3, .y = 4, .z = 0 });

    const dist = entity1.distanceTo(&entity2);
    try exeptEqual(@as(f32, 5.0), dist);
}

test "Entity.distanceTo2D" {
    var entity1 = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    var entity2 = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 3, .y = 4, .z = 100 });

    const dist = entity1.distanceTo2D(&entity2);
    try exeptEqual(@as(f32, 5.0), dist);
}

test "Entity.isCollidingWith" {
    var entity1 = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    var entity2 = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });

    try exeptEqual(true, entity1.isCollidingWith(&entity2));
}

test "Entity.isCollidingWith no collision" {
    var entity1 = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    var entity2 = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 5, .y = 5, .z = 0 });

    try exeptEqual(false, entity1.isCollidingWith(&entity2));
}

test "Entity.reset" {
    var entity = Entity.initStatic(Point2{ .x = 0, .y = 0 }, Point3{ .x = 0, .y = 0, .z = 0 });
    entity.kill();
    entity.hide();

    entity.reset();

    try exeptEqual(false, entity.dead);
    try exeptEqual(true, entity.visible);
}