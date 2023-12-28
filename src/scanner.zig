const std = @import("std");
const sig = @import("signature.zig");

const Watcher = struct {
    address: usize,
    index: usize,
};

pub fn Scanner(comptime signature: []const u8) type {
    const size = comptime std.mem.count(u8, signature, " ") + 1;
    return struct {
        const Self = @This();

        /// The Signature to hold
        signature: sig.Signature(size),

        pub fn init() !Self {
            return Self{
                .signature = try sig.Signature(size).init(signature),
            };
        }

        /// Scans the given memory range for the byte sequence
        pub fn scan(self: Self, start_address: [*]u8, end_address: [*]u8) ?usize {
            const total = @intFromPtr(end_address) - @intFromPtr(start_address);
            var watcher: Watcher = .{ .address = 0x0, .index = 0 };
            var i: usize = 0;
            while (i < total) : (i += 1) {
                const current = self.signature.bytes[watcher.index];
                // Wildcard is fine, go next
                if (current.is_wildcard) {
                    // no need to track the watcher's address here
                    // a wildcard on the first position doesn't matter anyway
                    watcher.index += 1;
                    continue;
                }

                // No Wildcard here, so there must be a byte left...
                const cur_byte = current.byte.?;
                if (start_address[i] == cur_byte and watcher.index == (self.signature.bytes.len - 1)) {
                    return watcher.address;
                } else if (start_address[i] == cur_byte) {
                    if (watcher.address == 0x0) {
                        watcher.address = @intFromPtr(&start_address[i]);
                    }
                    watcher.index += 1;
                } else {
                    // maybe it's the first byte?
                    i = i -| 1;
                    watcher.index = 0;
                    watcher.address = 0x0;
                }
            }

            return null;
        }
    };
}

test "scanner construction" {
    _ = try Scanner("AA ?? BB").init();
    _ = try Scanner("AA ? BB").init();
    _ = try Scanner("AA CC BB").init();
}

test "scanner failing construction" {
    try std.testing.expectError(sig.SignatureError.SizeMismatch, Scanner("AA BB ").init());
    try std.testing.expectError(sig.SignatureError.InvalidSignatureByte, Scanner("AA x").init());
}
