const std = @import("std");

const numbers_amount = 100000;
const parallel_partitions = 12;
const random_seed = 2025;

const max_hist_size: f32 = 50;

const tags_amount = 5;

pub fn classify(val: f32) usize {
    std.debug.assert(val <= tags_amount);
    std.debug.assert(val >= 0);
    return @intFromFloat(@floor(val));
}

pub fn hist(tags: []usize, time: i64) void {
    std.debug.assert(tags.len == tags_amount);

    const max_tag_value = max_blk: {
        var max_tag_local = tags[0];
        for (0..tags.len) |idx| {
            if (tags[idx] > max_tag_local) max_tag_local = tags[idx];
        }

        break :max_blk max_tag_local;
    };

    for (0..tags.len) |tag_idx| {
        std.debug.print("[{} - {}) ", .{
            tag_idx,
            tag_idx + 1,
        });

        const current_tag_f: f64 = @floatFromInt(tags[tag_idx]);
        const max_tag_f: f64 = @floatFromInt(max_tag_value);

        const width: f64 = ((current_tag_f / max_tag_f) * max_hist_size);
        const width_u: usize = @intFromFloat(@round(width));

        for (0..width_u + 1) |_| {
            std.debug.print("#", .{});
        }

        std.debug.print("\n", .{});
    }

    std.debug.print("took {}ms to run\n", .{ time });
}

pub fn nonThreaded(array: []f32) void {
    const time_start = std.time.milliTimestamp();

    var tags: [tags_amount]usize = @splat(0);
    for (array) |elem_f| tags[classify(elem_f)] += 1;

    return hist(tags[0..],
                std.time.milliTimestamp() - time_start);
}

const Tag = struct {
    value: usize = 0,
    lock: std.Thread.Mutex = .{},

    pub fn inc(self: *Tag) void {
        self.lock.lock();
        self.value += 1;
        self.lock.unlock();
    }

    pub fn sum(self: *Tag, value: usize) void {
        self.lock.lock();
        self.value += value;
        self.lock.unlock();
    }
};

pub fn histParallel(tags: []Tag, time: i64) void {
    std.debug.assert(tags.len == tags_amount);

    const max_tag_value = max_blk: {
        var max_tag_local = tags[0].value;
        for (0..tags.len) |idx| {
            if (tags[idx].value > max_tag_local) max_tag_local = tags[idx].value;
        }

        break :max_blk max_tag_local;
    };

    for (0..tags.len) |tag_idx| {
        std.debug.print("[{} - {}) ", .{
            tag_idx,
            tag_idx + 1,
        });

        const current_tag_f: f64 = @floatFromInt(tags[tag_idx].value);
        const max_tag_f: f64 = @floatFromInt(max_tag_value);

        const width: f64 = ((current_tag_f / max_tag_f) * max_hist_size);
        const width_u: usize = @intFromFloat(@round(width));

        for (0..width_u + 1) |_| {
            std.debug.print("#", .{});
        }

        std.debug.print("\n", .{});
    }

    std.debug.print("took {}ms to run\n", .{ time });
}

pub fn threadProcessUnit(array: []f32, tags: []Tag) void {
    for (array) |elem_f| tags[classify(elem_f)].inc();
}

pub fn threadProcessUnitOptimized(array: []f32, tags: []Tag) void {
    var local_tags: [tags_amount]usize = @splat(0);
    for (array) |elem_f| local_tags[classify(elem_f)] += 1;

    for (0..local_tags.len) |idx| {
        tags[idx].sum(local_tags[idx]);
    }
}


pub fn threaded(array: []f32) void {
    var tags: [tags_amount]Tag = @splat(.{});

    var new_arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const allocator = new_arena.allocator();

    defer new_arena.deinit();

    var thread_pool: std.Thread.Pool = undefined;
    thread_pool.init(std.Thread.Pool.Options{
        .allocator = allocator,
    }) catch unreachable;

    var wg: std.Thread.WaitGroup = .{};

    const time_start = std.time.milliTimestamp();

    for (0..parallel_partitions) |part_idx| {
        const offset = part_idx * (numbers_amount / parallel_partitions);
        var upper = offset + numbers_amount / parallel_partitions;
        if (numbers_amount - upper < parallel_partitions) {
            upper += numbers_amount - upper;
        }

        thread_pool.spawnWg(&wg, threadProcessUnit, .{
            array[offset..upper],
            tags[0..],
        });
    }

    thread_pool.waitAndWork(&wg);
    return histParallel(tags[0..],
                        std.time.milliTimestamp() - time_start);
}

pub fn threadedOptimized(array: []f32) void {
    var tags: [tags_amount]Tag = @splat(.{});

    var new_arena: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const allocator = new_arena.allocator();

    defer new_arena.deinit();

    var thread_pool: std.Thread.Pool = undefined;
    thread_pool.init(std.Thread.Pool.Options{
        .allocator = allocator,
    }) catch unreachable;

    var wg: std.Thread.WaitGroup = .{};

    const time_start = std.time.milliTimestamp();

    for (0..parallel_partitions) |part_idx| {
        const offset = part_idx * (numbers_amount / parallel_partitions);
        var upper = offset + numbers_amount / parallel_partitions;
        if (numbers_amount - upper < parallel_partitions) {
            upper += numbers_amount - upper;
        }

        thread_pool.spawnWg(&wg, threadProcessUnitOptimized, .{
            array[offset..upper],
            tags[0..],
        });
    }

    thread_pool.waitAndWork(&wg);
    return histParallel(tags[0..],
                        std.time.milliTimestamp() - time_start);
}

pub fn main() void {
    var rand_source: std.Random.DefaultPrng = .init(random_seed);
    const random_device = rand_source.random();

    var full_array: [numbers_amount]f32 = undefined;
    for (&full_array) |*elem| elem.* = random_device.float(f32) * 5;

    nonThreaded(full_array[0..]);
    threaded(full_array[0..]);
    threadedOptimized(full_array[0..]);
}

