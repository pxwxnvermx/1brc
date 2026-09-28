const std = @import("std");
const Io = std.Io;

const Stats = struct {
    min: f64 = 0,
    max: f64 = 0,
    sum: f64 = 0,
    count: u32 = 0,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();

    var map: std.array_hash_map.String(Stats) = .empty;
    defer map.deinit(allocator);

    const input_file = try Io.Dir.cwd().openFile(io, "./measurements.txt", .{});
    defer input_file.close(io);
    var file_read_buf: [6 * 1024]u8 = undefined;
    var file_reader = input_file.reader(io, &file_read_buf);
    var file_reader_interface = &file_reader.interface;

    while (try file_reader_interface.takeDelimiter('\n')) |line| {
        const station_name, const temperature = std.mem.cutScalar(u8, line, ';') orelse break;
        const temperature_float = try std.fmt.parseFloat(f64, temperature);

        const res = try map.getOrPut(allocator, station_name);
        const val = res.value_ptr;
        if (res.found_existing) {
            val.count += 1;
            val.sum += temperature_float;
            val.max = @max(val.max, temperature_float);
            val.min = @min(val.min, temperature_float);
        } else {
            res.key_ptr.* = try allocator.dupe(u8, station_name);
            val.* = .{ .count = 1, .min = temperature_float, .max = temperature_float, .sum = temperature_float };
        }
    }

    const SortContext = struct {
        keys: [][]const u8,

        pub fn lessThan(self: @This(), a: usize, b: usize) bool {
            return std.mem.lessThan(u8, self.keys[a], self.keys[b]);
        }
    };

    map.sort(SortContext{ .keys = map.keys() });

    var out_file = try Io.Dir.cwd().createFile(io, "measurements_final.txt", .{});
    defer out_file.close(io);
    var out_file_buf: [6 * 1024]u8 = undefined;
    var out_file_writer = out_file.writer(io, &out_file_buf);
    var writer = &out_file_writer.interface;

    try writer.writeByte('{');

    var map_iter = map.iterator();

    while (map_iter.next()) |entry| {
        const station_name = entry.key_ptr.*;
        const stats = entry.value_ptr.*;
        const mean = stats.sum / @as(f64, @floatFromInt(stats.count));

        try writer.print("{s}={d}/{d}/{d}, ", .{ station_name, stats.min, mean, stats.max });
    }
    try writer.writeByte('}');
    try writer.flush();
}
