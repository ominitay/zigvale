# Zigvale

Zigvale is a Zig implementation of the stivale2 boot protocol to be used both in kernels and bootloaders. The specification, along with C header files, may be found [here](https://github.com/stivale/stivale).

## Add to your project

Zigvale is available on [aquila](https://aquila.red/1/Ominitay/zigvale), [zpm](https://zig.pm/#/package/zigvale), and [astrolabe](https://astrolabe.pm/#/package/Ominitay/zigvale/0.1.0).

### Gyro

`gyro add ominitay/zigvale`

### Zigmod
###### Aquila
`zigmod aq add 1/Ominitay/zigvale`

###### ZPM
`zigmod zpm add zigvale`

### ZKG

`zkg add zigvale`

### Git
###### Submodule
`git submodule add https://github.com/ominitay/zigvale zigvale`

###### Clone
`git clone https://github.com/ominitay/zigvale`

## Example

Presently, to work around [zig#9512](https://github.com/ziglang/zig/issues/9512), we have to define our stack as a sentinel-terminated array, since Zig does not allow us to do maths on link-time known pointers. 

```zig
const zigvale = @import("zigvale").v2;

export var stack_bytes: [16 * 1024:0]u8 align(16) linksection(".bss") = undefined;
const stack_bytes_slice = stack_bytes[0..];


export const header linksection(".stivale2hdr") = zigvale.Header{
    .stack = &stack_bytes[stack_bytes.len],
    .flags = .{
        .higher_half = 1,
        .pmr = 1,
    },
    .tags = null,
};

comptime {
    const entry = zigvale.entryPoint(kmain);
    @export(entry, .{ .name = "_start", .linkage = .Strong });
}

pub fn kmain(_: *zigvale.Struct.Parsed) noreturn {
    while (true) {}
}
```

## Documentation

To generate documentation, run `zig build docs`

Zig's documentation generator is experimental and incomplete. When documentation generation has improved somewhat, I will host the documentation. In the meantime, you may both read the comments made manually, and read the documentation in the [stivale repository](https://github.com/stivale/stivale).
