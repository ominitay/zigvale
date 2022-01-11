const std = @import("std");
const expect = std.testing.expect;

/// Anchor for non-ELF kernels
pub const Anchor = packed struct {
    anchor: [15]u8 = "STIVALE2 ANCHOR",
    bits: u8,
    phys_load_addr: u64,
    phys_bss_start: u64,
    phys_bss_end: u64,
    phys_stivale2hdr: u64,
};

/// A tag containing a unique identifier, which must belong to a type which is a u64, non-exhaustive enum.
pub fn TagGeneric(comptime Id: type) type {
    if (@typeInfo(Id) != .Enum) @compileError("Tag identifier must be an enum");
    if (@typeInfo(Id).Enum.tag_type != u64) @compileError("Tag identifier enum tag type isn't u64");
    if (@typeInfo(Id).Enum.is_exhaustive) @compileError("Tag identifier must be a non-exhaustive enum");

    return packed struct {
        const Self = @This();

        /// The unique identifier of the tag
        identifier: Id,
        /// The next tag in the linked list
        next: ?*const Self = null,
    };
}

test "TagGeneric" {
    const Identifier = enum(u64) {
        hello = 0x0,
        world = 0x1,
        _,
    };
    const Tag = TagGeneric(Identifier);
    try expect(@bitSizeOf(Tag) == 128);
}

/// The Header contains information passed from the kernel to the bootloader.
/// The kernel must have a section `.stivale2hdr` either containing a header, or an anchor pointing to one.
pub const Header = packed struct {
    /// The address to be jumped to as the entry point of the kernel. If 0, the ELF entry point will be used.
    entry_point: ?fn (*const Struct) callconv(.C) noreturn = null,
    /// The stack address which will be in ESP/RSP when the kernel is loaded.
    /// The stack must be at least 256 bytes, and must have a 16 byte aligned address.
    stack: ?*u8,
    flags: Flags,
    /// Pointer to the first tag of the linked list of header tags.
    tags: ?*const Tag,

    pub const Flags = packed struct {
        /// Reserved and unused
        reserved: u1 = 0,
        /// If set, all pointers are to be offset to the higher half.
        higher_half: u1 = 0,
        /// If set, enables protected memory ranges.
        pmr: u1 = 0,
        /// If set, enables fully virtual kernel mapping for PMRs.
        fully_virtual_mapping: u1 = 0,
        /// Do NOT fail to boot if low memory area could not be allocated. THIS SHOULD ALWAYS BE SET AS THIS
        /// FUNCTIONALITY IS DEPRECATED.
        boot_if_lma_fail: u1 = 1,
        /// Undefined and must be set to 0.
        zeros: u59 = 0,
    };

    pub const Tag = TagGeneric(Identifier);

    /// Unique identifiers for each header tag
    pub const Identifier = enum(u64) {
        any_video = 0xc75c9fa92a44c4db,
        framebuffer = 0x3ecc1bc43d0f7971,
        framebuffer_mtrr = 0x4c7bb07731282e00,
        terminal = 0xa85d499b1823be72,
        smp = 0x1ab015085f3273df,
        five_level_paging = 0x932f477032007e8f,
        slide_hddm = 0xdc29269c2af53d1d,
        unmap_null = 0x92919432b16fe7e7,
        _,
    };

    /// This tag tells the bootloader that the kernel has no requirement for a framebuffer to be initialised.
    /// Using neither this tag nor `FramebufferTag` means "force CGA text mode", and the bootloader will
    /// refuse to boot the kernel if that cannot be fulfilled.
    pub const AnyVideoTag = packed struct {
        tag: Tag = .{ .identifier = .any_video },
        preference: Preference,

        pub const Preference = enum(u64) {
            linear = 0,
            no_linear = 1,
        };
    };

    /// This tag tells the bootloader framebuffer preferences. If used without `AnyVideo`, the bootloader
    /// will refuse to boot the kernel if a framebuffer cannot be initialised. Using neither means force CGA
    /// text mode, and the bootloader will refuse to boot the kernel if that cannot be fulfilled.
    pub const FramebufferTag = packed struct {
        tag: Tag = .{ .identifier = .framebuffer },
        width: u16 = 0,
        height: u16 = 0,
        bpp: u16 = 0,
        unused: u16 = 0,
    };

    /// **WARNING:** This tag is deprecated. Use is discouraged and may not be supported on newer bootloaders!
    /// This tag tells the bootloader to set up MTRR write-combining for the framebuffer.
    pub const FramebufferMtrrTag = packed struct {
        tag: Tag = .{ .identifier = .framebuffer_mtrr },
    };

    /// This tag tells the bootloader to set up a terminal for the kernel. The terminal may run in framebuffer
    /// or text mode.
    pub const TerminalTag = packed struct {
        tag: Tag = .{ .identifier = .terminal },
        flags: @This().Flags = .{},
        /// Address of the terminal callback function
        callback: ?fn (CallbackType, u64, u64, u64) callconv(.C) void = null,

        pub const Flags = packed struct {
            /// Set if a callback function is provided
            callback: u1 = 0,
            /// Undefined and must be set to 0.
            zeros: u63 = 0,
        };

        /// These are the possible types which the terminal callback function may have to deal with.
        pub const CallbackType = enum(u64) {
            dec = 10,
            bell = 20,
            private_id = 30,
            status_report = 40,
            pos_report = 50,
            kbd_leds = 60,
            mode = 70,
            linux = 80,
        };
    };

    /// This tag enables support for booting up application processors.
    pub const SmpTag = packed struct {
        tag: Tag = .{ .identifier = .smp },
        flags: @This().Flags = .{},

        pub const Flags = packed struct {
            /// Use xAPIC
            xapic: u1 = 0,
            /// Use x2APIC if possible
            x2apic: u1 = 0,
            /// Undefined and must be set to 0.
            zeros: u62 = 0,
        };
    };

    /// This tag enables support for 5-level paging, if available.
    pub const FiveLevelPagingTag = packed struct {
        tag: Tag = .{ .identifier = .five_level_paging },
    };

    /// This tag tells the bootloader to add a random slide to the base address of the higher half direct map (HHDM)
    pub const SlideHhdmTag = packed struct {
        tag: Tag = .{ .identifier = .slide_hhdm },
        flags: @This().Flags = .{},
        /// Desired alignment for base address of the HHDM. Must be non-0 and aligned to 2MiB.
        alignment: u64,

        pub const Flags = packed struct {
            /// Undefined and must be set to 0.
            zeros: u64 = 0,
        };
    };

    /// This tag tells the bootloader to unmap the first page of the virtual address space.
    pub const UnmapNullTag = packed struct {
        tag: Tag = .{ .identifier = .unmap_null },
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

test "Header Size" {
    try expect(@bitSizeOf(Header) == 256);
}

test "Header Tag Sizes" {
    try expect(@bitSizeOf(Header.AnyVideoTag) == 192);
    try expect(@bitSizeOf(Header.FramebufferTag) == 192);
    try expect(@bitSizeOf(Header.FramebufferMtrrTag) == 128);
    try expect(@bitSizeOf(Header.TerminalTag) == 256);
    try expect(@bitSizeOf(Header.SmpTag) == 192);
    try expect(@bitSizeOf(Header.FiveLevelPagingTag) == 128);
    try expect(@bitSizeOf(Header.SlideHhdmTag) == 256);
    try expect(@bitSizeOf(Header.UnmapNullTag) == 128);
}

/// The Struct contains information passed from the bootloader to the kernel.
/// A pointer to this is passed to the kernel as an argument to the entry point.
pub const Struct = packed struct {
    /// Null terminated ASCII string
    bootloader_brand: [64]u8,
    /// Null terminated ASCII string
    bootloader_version: [64]u8,
    /// Pointer to the first tag of the linked list of tags.
    tags: ?*const Tag = null,

    pub const Tag = TagGeneric(Identifier);

    /// Unique identifiers for each struct tag
    pub const Identifier = enum(u64) {
        pmrs = 0x5df266a64047b6bd,
        cmdline = 0xe5e76a1b4597a781,
        memmap = 0x2187f79e8612de07,
        framebuffer = 0x506461d2950408fa,
        framebuffer_mtrr = 0x6bc1a78ebe871172,
        textmode = 0x38d74c23e0dca893,
        edid = 0x968609d7af96b845,
        terminal = 0xc2b3f4c3233b0974,
        modules = 0x4b6fe466aade04ce,
        rsdp = 0x9e1786930a375e78,
        smbios = 0x274bd246c62bf7d1,
        epoch = 0x566a7bed888e1407,
        firmware = 0x359d837855e3858c,
        efi_system_table = 0x4bc5ec15845b558e,
        kernel_file = 0xe599d90c2975584a,
        kernel_file_v2 = 0x37c13018a02c6ea2,
        boot_volume = 0x9b4358364c19ee62,
        kernel_slide = 0xee80847d01506c57,
        smp = 0x34d1d96339647025,
        pxe_server_info = 0x29d1e96239247032,
        mmio32_uart = 0xb813f9b8dbc78797,
        dtb = 0xabb29bd49a2833fa,
        hhdm = 0xb0ed257db18cb58f,
        _,
    };

    /// This struct contains all detected tags, returned by `Struct.parse()`
    pub const Parsed = struct {
        bootloader_brand: []const u8,
        bootloader_version: []const u8,
        first: ?*const Tag = null,
        pmrs: ?*const PmrsTag = null,
        cmdline: ?*const CmdlineTag = null,
        memmap: ?*const MemmapTag = null,
        framebuffer: ?*const FramebufferTag = null,
        framebuffer_mtrr: ?*const FramebufferMtrrTag = null,
        textmode: ?*const TextModeTag = null,
        edid: ?*const EdidTag = null,
        terminal: ?*const TerminalTag = null,
        modules: ?*const ModulesTag = null,
        rsdp: ?*const RsdpTag = null,
        smbios: ?*const SmbiosTag = null,
        epoch: ?*const EpochTag = null,
        firmware: ?*const FirmwareTag = null,
        efi_system_table: ?*const EfiSystemTableTag = null,
        kernel_file: ?*const KernelFileTag = null,
        kernel_file_v2: ?*const KernelFileV2Tag = null,
        boot_volume: ?*const BootVolumeTag = null,
        kernel_slide: ?*const KernelSlideTag = null,
        smp: ?*const SmpTag = null,
        pxe_server_info: ?*const PxeServerInfoTag = null,
        mmio32_uart: ?*const Mmio32UartTag = null,
        dtb: ?*const DtbTag = null,
        hhdm: ?*const HhdmTag = null,
    };

    /// Returns `Struct.Parsed`, filled with all detected tags
    pub fn parse(self: *const Struct) Parsed {
        var parsed = Parsed{
            .bootloader_brand = std.mem.sliceTo(&self.bootloader_brand, 0),
            .bootloader_version = std.mem.sliceTo(&self.bootloader_version, 0),
            .first = self.tags,
        };

        var tag_opt = self.tags;
        while (tag_opt) |tag| : (tag_opt = tag.next) {
            switch (tag.identifier) {
                .pmrs => parsed.pmrs = @ptrCast(*const PmrsTag, tag),
                .cmdline => parsed.cmdline = @ptrCast(*const CmdlineTag, tag),
                .memmap => parsed.memmap = @ptrCast(*const MemmapTag, tag),
                .framebuffer => parsed.framebuffer = @ptrCast(*const FramebufferTag, tag),
                .framebuffer_mtrr => parsed.framebuffer_mtrr = @ptrCast(*const FramebufferMtrrTag, tag),
                .textmode => parsed.textmode = @ptrCast(*const TextModeTag, tag),
                .edid => parsed.edid = @ptrCast(*const EdidTag, tag),
                .terminal => parsed.terminal = @ptrCast(*const TerminalTag, tag),
                .modules => parsed.modules = @ptrCast(*const ModulesTag, tag),
                .rsdp => parsed.rsdp = @ptrCast(*const RsdpTag, tag),
                .smbios => parsed.smbios = @ptrCast(*const SmbiosTag, tag),
                .epoch => parsed.epoch = @ptrCast(*const EpochTag, tag),
                .firmware => parsed.firmware = @ptrCast(*const FirmwareTag, tag),
                .efi_system_table => parsed.efi_system_table = @ptrCast(*const EfiSystemTableTag, tag),
                .kernel_file => parsed.kernel_file = @ptrCast(*const KernelFileTag, tag),
                .kernel_file_v2 => parsed.kernel_file_v2 = @ptrCast(*const KernelFileV2Tag, tag),
                .boot_volume => parsed.boot_volume = @ptrCast(*const BootVolumeTag, tag),
                .kernel_slide => parsed.kernel_slide = @ptrCast(*const KernelSlideTag, tag),
                .smp => parsed.smp = @ptrCast(*const SmpTag, tag),
                .pxe_server_info => parsed.pxe_server_info = @ptrCast(*const PxeServerInfoTag, tag),
                .mmio32_uart => parsed.mmio32_uart = @ptrCast(*const Mmio32UartTag, tag),
                .dtb => parsed.dtb = @ptrCast(*const DtbTag, tag),
                .hhdm => parsed.hhdm = @ptrCast(*const HhdmTag, tag),
                _ => {}, // Ignore unknown tags
            }
        }

        return parsed;
    }

    /// This tag tells the kernel that the PMR flag in the header was recognised and that the kernel has been
    /// successfully mapped by its ELF segments. It also provides the array of ranges and their corresponding
    /// permissions.
    pub const PmrsTag = packed struct {
        tag: Tag = .{ .identifier = .pmrs },
        /// Number of entries in array
        entries: u64,

        /// Returns array of Pmr structs
        pub fn getPmrs(self: *const PmrsTag) []const Pmr {
            return @intToPtr([*]const Pmr, @ptrToInt(&self.entries) + 8)[0..self.entries];
        }
    };

    pub const Pmr = packed struct {
        base: u64,
        length: u64,
        permissions: Permissions,

        pub const Permissions = packed struct {
            executable: u1,
            writable: u1,
            readable: u1,
            unused: u61,
        };
    };

    /// This tag provides the kernel with the command line string.
    pub const CmdlineTag = packed struct {
        tag: Tag = .{ .identifier = .cmdline },
        /// Null-terminated array
        cmdline: [*:0]const u8,

        pub fn asSlice(self: *const CmdlineTag) []const u8 {
            return std.mem.sliceTo(self.cmdline, 0);
        }
    };

    /// This tag provides the kernel with the memory map.
    pub const MemmapTag = packed struct {
        tag: Tag = .{ .identifier = .memmap },
        /// Number of entries in array
        entries: u64,

        /// Returns array of `MemmapEntry` structs
        pub fn getMemmap(self: *const MemmapTag) []const MemmapEntry {
            return @intToPtr([*]const MemmapEntry, @ptrToInt(&self.entries) + 8)[0..self.entries];
        }
    };

    pub const MemmapEntry = packed struct {
        /// Physical address of the base of the memory section
        base: u64,
        /// Length of the memory section
        length: u64,
        type: Type,
        unused: u32,

        pub const Type = enum(u32) {
            usable = 1,
            reserved = 2,
            acpi_reclaimable = 3,
            acpi_nvs = 4,
            bad_memory = 5,
            bootloader_reclaimable = 0x1000,
            kernel_and_modules = 0x1001,
            framebuffer = 0x1002,
        };
    };

    /// This tag provides the kernel with details of the currently set-up framebuffer, if any
    pub const FramebufferTag = packed struct {
        tag: Tag = .{ .identifier = .framebuffer },
        /// The address of the framebuffer
        address: u64,
        /// Width and height of the framebuffer in pixels
        width: u16,
        height: u16,
        /// Pitch in bytes
        pitch: u16,
        /// Bits per pixel
        bpp: u16,
        memory_model: MemoryModel,
        red_mask_size: u8,
        red_mask_shift: u8,
        green_mask_size: u8,
        green_mask_shift: u8,
        blue_mask_size: u8,
        blue_mask_shift: u8,
        unused: u8,

        pub const MemoryModel = enum(u8) {
            rgb = 1,
            _,
        };
    };

    /// **WARNING:** This tag is deprecated. Use is discouraged and may not be supported on newer bootloaders!
    /// This tag signals to the kernel that MTRR write-combining for the framebuffer was enabled.
    pub const FramebufferMtrrTag = packed struct {
        tag: Tag = .{ .identifier = .framebuffer_mtrr },
    };

    /// This tag provides the kernel with details of the currently set up CGA text mode, if any.
    pub const TextModeTag = packed struct {
        tag: Tag = .{ .identifier = .textmode },
        /// The address of the text mode buffer
        address: u64,
        unused: u16,
        rows: u16,
        columns: u16,
        bytes_per_char: u16,
    };

    /// This tag provides the kernel with EDID information.
    pub const EdidTag = packed struct {
        tag: Tag = .{ .identifier = .edid },
        /// The number of bytes in the array
        edid_size: u64,

        /// Returns edid information
        pub fn getEdidInformation(self: *const EdidTag) []const u8 {
            return @intToPtr([*]u8, @ptrToInt(&self.edid_size) + 8)[0..self.edid_size];
        }
    };

    /// This tag provides the kernel with the entry point of the `stivale2_term_write()` function, if it was
    /// requested, and supported by the bootloader.
    pub const TerminalTag = packed struct {
        tag: Tag = .{ .identifier = .terminal },
        flags: Flags,
        cols: u16,
        rows: u16,
        /// Pointer to the entry point of the `stivale2_term_write()` function.
        term_write: fn (ptr: [*]const u8, length: u64) callconv(.C) void,
        /// If `Flags.max_length` is set, this field specifies the maximum allowed string length to be passed
        /// to `term_write()`. If this is 0, then there is limit.
        max_length: u64,

        pub const Flags = packed struct {
            /// If set, cols and rows are provided
            cols_and_rows: u1,
            /// If not set, assume a max_length of 1024
            max_length: u1,
            /// If the callback was requested and supported by the bootloader, this is set
            callback: u1,
            /// If set, context control is available
            context_control: u1,
            unused: u28,
        };

        pub const Writer = struct {
            context: TerminalTag,
            pub const Error = error{}; // No errors can be returned, but this is necessary anyway to be a valid writer...

            pub fn write(self: Writer, bytes: []const u8) !usize {
                self.context.write(bytes);
                return bytes.len;
            }

            pub fn writeAll(self: Writer, bytes: []const u8) !void {
                _ = try self.write(bytes);
            }

            pub fn print(self: Writer, comptime format: []const u8, args: anytype) !void {
                return std.fmt.format(self, format, args);
            }

            pub fn writeByte(self: Writer, byte: u8) !void {
                _ = try self.write(&[_]u8{byte});
            }

            pub fn writeByteNTimes(self: Writer, byte: u8, n: usize) !void {
                var bytes: [256]u8 = undefined;
                std.mem.set(u8, bytes[0..], byte);

                var remaining: usize = n;
                while (remaining > 0) {
                    const to_write = std.math.min(remaining, bytes.len);
                    try self.writeAll(bytes[0..to_write]);
                    remaining -= to_write;
                }
            }
        };

        pub fn writer(self: TerminalTag) Writer {
            return Writer{ .context = self };
        }

        pub fn write(self: TerminalTag, bytes: []const u8) void {
            self.term_write(bytes.ptr, bytes.len);
        }

        pub fn print(self: TerminalTag, comptime format: []const u8, args: anytype) void {
            self.writer().print(format, args) catch unreachable;
        }
    };

    /// This tag provides the kernel with a list of modules loaded alongside the kernel.
    pub const ModulesTag = packed struct {
        tag: Tag = .{ .identifier = .modules },
        /// Number of modules in the array
        module_count: u64,

        /// Returns array of `Module` structs
        pub fn getModules(self: *const ModulesTag) []const Module {
            return @intToPtr([*]const Module, @ptrToInt(&self.module_count) + 8)[0..self.module_count];
        }
    };

    pub const Module = packed struct {
        /// Address where the module is loaded
        begin: u64,
        /// End address of the module
        end: u64,
        /// ASCII null-terminated string passed to the module
        string: [128]u8,

        pub fn getString(self: *const Module) []const u8 {
            return std.mem.sliceTo(&self.string, 0);
        }
    };

    /// This tag provides the kernel with the location of the ACPI RSDP structure
    pub const RsdpTag = packed struct {
        tag: Tag = .{ .identifier = .rsdp },
        /// Address of the ACPI RSDP structure
        rsdp: u64,
    };

    /// This tag provides the kernel with the location of SMBIOS entry points in memory
    pub const SmbiosTag = packed struct {
        tag: Tag = .{ .identifier = .smbios },
        /// Flags are for future use and currently all unused
        flags: Flags,
        /// 32-bit SMBIOS entry point address, 0 if unavailable
        smbios_entry_32: u64,
        /// 64-bit SMBIOS entry point address, 0 if unavailable
        smbios_entry_64: u64,

        pub const Flags = packed struct {
            unused: u64,
        };
    };

    /// This tag provides the kernel with the current UNIX epoch
    pub const EpochTag = packed struct {
        tag: Tag = .{ .identifier = .epoch },
        /// UNIX epoch at boot, read from RTC
        epoch: u64,
    };

    /// This tag provides the kernel with info about the firmware
    pub const FirmwareTag = packed struct {
        tag: Tag = .{ .identifier = .firmware },
        flags: Flags,

        pub const Flags = packed struct {
            /// If set, BIOS, if unset, UEFI
            bios: u1,
            unused: u63,
        };
    };

    /// This tag provides the kernel with a pointer to the EFI system table if available
    pub const EfiSystemTableTag = packed struct {
        tag: Tag = .{ .identifier = .efi_system_table },
        /// Address of the EFI system table
        system_table: u64,
    };

    /// This tag provides the kernel with a pointer to a copy of the executable file of the kernel
    pub const KernelFileTag = packed struct {
        tag: Tag = .{ .identifier = .kernel_file },
        /// Address of the kernel file
        kernel_file: [*]const u8,
    };

    /// This tag provides the kernel with a pointer to a copy of the executable file of the kernel, along with
    /// the size of the file
    pub const KernelFileV2Tag = packed struct {
        tag: Tag = .{ .identifier = .kernel_file_v2 },
        /// Address of the kernel file
        kernel_file: [*]const u8,
        /// Size of the kernel file
        kernel_size: u64,

        /// Returns a slice over the kernel file
        pub fn asSlice(self: KernelFileV2Tag) []const u8 {
            return self.kernel_file[0..self.kernel_size];
        }
    };

    /// This tag provides the GUID and partition GUID of the volume from which the kernel was loaded, if available
    pub const BootVolumeTag = packed struct {
        tag: Tag = .{ .identifier = .boot_volume },
        flags: Flags,
        /// GUID -- valid when flags.guid_valid is set
        guid: Guid,
        /// Partition GUID -- valid when flags.part_guid_valid is set
        part_guid: Guid,

        pub const Flags = packed struct {
            /// Set if GUID is valid
            guid_valid: u1,
            /// Set if partition GUID is valid
            part_guid_valid: u1,
            unused: u62,
        };

        pub const Guid = packed struct {
            a: u32,
            b: u16,
            c: u16,
            d: [8]u8,
        };
    };

    /// This tag provides the kernel with the slide that the bootloader has applied to the kernel's address
    pub const KernelSlideTag = packed struct {
        tag: Tag = .{ .identifier = .kernel_slide },
        kernel_slide: u64,
    };

    /// This tag provides the kernel with info about a multiprocessor environment
    pub const SmpTag = packed struct {
        tag: Tag = .{ .identifier = .smp },
        flags: Flags,
        /// LAPIC ID of the BSP
        bsp_lapic_id: u32,
        unused: u32,
        /// Total number of logical CPUs (incl BSP)
        cpu_count: u64,

        /// Returns array of `SmpInfo` structs
        pub fn getSmpInfo(self: *const SmpTag) []const SmpInfo {
            return @intToPtr([*]const SmpInfo, @ptrToInt(&self.cpu_count) + 8)[0..self.cpu_count];
        }

        pub const Flags = packed struct {
            /// Set if x2APIC was requested, supported, and sucessfully enabled
            x2apic: u1,
            unused: u63,
        };
    };

    pub const SmpInfo = packed struct {
        /// ACPI processor UID as specified by MADT
        processor_id: u32,
        /// LAPIC ID as specified by MADT
        lapic_id: u32,
        /// The stack that will be loaded in ESP/RSP once the goto_address field is loaded. This **MUST** point
        /// to a valid stack of at least 256 bytes in size, and 16-byte aligned. `target_stack` is unused for
        /// the struct describing the BSP.
        target_stack: u64,
        /// This field is polled by the started APs until the kernel on another CPU performs a write to this field.
        /// When that happens, bootloader code will load up ESP/RSP with the stack value specified in
        /// `target_stack`. It will then proceed to load a pointer to this structure in either RDI for 64-bit, or
        /// onto the stack for 32-bit. Then, `goto_address` is called, and execution is handed off.
        goto_address: u64,
        /// This field is here for the kernel to use for whatever it wants. Writes here should be performed before
        /// writing to `goto_address`.
        extra_argument: u64,
    };

    /// This tag provides the kernel with the server ip that it was booted from, if the kernel has been booted
    /// via PXE
    pub const PxeServerInfoTag = packed struct {
        tag: Tag = .{ .identifier = .pxe_server_info },
        /// Server IP in network byte order
        server_ip: u32,
    };

    /// This tag provides the kernel with the address of a memory mapped UART port
    pub const Mmio32UartTag = packed struct {
        tag: Tag = .{ .identifier = .mmio32_uart },
        /// The address of the UART port
        addr: u64,
    };

    /// This tag describes a device tree blob
    pub const DtbTag = packed struct {
        tag: Tag = .{ .identifier = .dtb },
        /// The address of the DTB
        addr: u64,
        /// The size of the DTB
        size: u64,
    };

    /// This tag reports the start address of the higher half direct map (HHDM)
    pub const HhdmTag = packed struct {
        tag: Tag = .{ .identifier = .hhdm },
        /// Beginning of the HHDM (virtual address)
        addr: u64,
    };

    comptime {
        std.testing.refAllDecls(@This());
    }
};

test "Struct Size" {
    try expect(@bitSizeOf(Struct) == 64 * 8 * 2 + 64);
}

test "Struct Tag Sizes" {
    try expect(@bitSizeOf(Struct.PmrsTag) == 192);
    try expect(@bitSizeOf(Struct.CmdlineTag) == 192);
    try expect(@bitSizeOf(Struct.MemmapTag) == 192);
    try expect(@bitSizeOf(Struct.FramebufferTag) == 320);
    try expect(@bitSizeOf(Struct.FramebufferMtrrTag) == 128);
    try expect(@bitSizeOf(Struct.TextModeTag) == 256);
    try expect(@bitSizeOf(Struct.EdidTag) == 192);
    try expect(@bitSizeOf(Struct.TerminalTag) == 320);
    try expect(@bitSizeOf(Struct.ModulesTag) == 192);
    try expect(@bitSizeOf(Struct.RsdpTag) == 192);
    try expect(@bitSizeOf(Struct.SmbiosTag) == 320);
    try expect(@bitSizeOf(Struct.EpochTag) == 192);
    try expect(@bitSizeOf(Struct.FirmwareTag) == 192);
    try expect(@bitSizeOf(Struct.EfiSystemTableTag) == 192);
    try expect(@bitSizeOf(Struct.KernelFileTag) == 192);
    try expect(@bitSizeOf(Struct.KernelFileV2Tag) == 256);
    try expect(@bitSizeOf(Struct.BootVolumeTag) == 448);
    try expect(@bitSizeOf(Struct.KernelSlideTag) == 192);
    try expect(@bitSizeOf(Struct.SmpTag) == 320);
    try expect(@bitSizeOf(Struct.PxeServerInfoTag) == 160);
    try expect(@bitSizeOf(Struct.Mmio32UartTag) == 192);
    try expect(@bitSizeOf(Struct.DtbTag) == 256);
    try expect(@bitSizeOf(Struct.HhdmTag) == 192);
}

test "Struct Other Sizes" {
    try expect(@bitSizeOf(Struct.Pmr) == 192);
    try expect(@bitSizeOf(Struct.MemmapEntry) == 192);
    try expect(@bitSizeOf(Struct.Module) == 1152);
    try expect(@bitSizeOf(Struct.SmpInfo) == 256);
}

test "KernelFileV2Tag asSlice" {
    const string: []const u8 = "Hello world!";
    const kernel_file_v2_tag = Struct.KernelFileV2Tag{
        .kernel_file = string.ptr,
        .kernel_size = string.len,
    };

    try expect(std.mem.eql(u8, string, kernel_file_v2_tag.asSlice()));
}

// We use this only as a helper for our test
fn padString(comptime string: anytype, comptime len: usize) [len]u8 {
    comptime {
        if (string.len >= len) unreachable;
        const paddingLen = len - string.len;
        const padding = [1]u8{0} ** paddingLen;
        return string ++ padding;
    }
}

test "Parse Struct" {
    var info = Struct{
        .bootloader_brand = padString("Foo...".*, 64),
        .bootloader_version = padString("Bar!".*, 64),
    };

    var epochtag = Struct.EpochTag{ .epoch = 0x6969696969696969 };
    info.tags = &epochtag.tag;

    const parsed = info.parse();
    try expect(parsed.epoch.?.*.epoch == 0x6969696969696969);
    try expect(std.mem.eql(u8, parsed.bootloader_brand, "Foo..."));
    try expect(std.mem.eql(u8, parsed.bootloader_version, "Bar!"));
}

/// This function takes your kernel entry point as an argument. It parses the `Struct` for you, and provides `Struct.Parsed` as an argument to the
/// entry point. You may export it as `_start` using `@export`.
pub fn entryPoint(comptime entrypoint: fn (Struct.Parsed) noreturn) fn (*const Struct) callconv(.C) noreturn {
    return struct {
        pub fn entryPoint(info: *const Struct) callconv(.C) noreturn {
            const parsed = info.parse();
            entrypoint(parsed);
        }
    }.entryPoint;
}

test "entryPoint" {
    const kmain = struct {
        pub fn kmain(_: Struct.Parsed) noreturn {
            while (true) {}
        }
    }.kmain;

    _ = entryPoint(kmain);
}

comptime {
    std.testing.refAllDecls(@This());
}
