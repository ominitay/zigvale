# Zigvale

Zigvale is a Zig implementation of the stivale2 boot protocol to be used both in kernels and bootloaders. The specification, along with C header files, may be found [here](https://github.com/stivale/stivale).

## Example

Visit [zigvale-barebones](https://github.com/ominitay/zigvale-barebones) for a bare-bones kernel demonstrating how to use Zigvale.

## Add to your project

Zigvale is available on [aquila](https://aquila.red/1/Ominitay/zigvale), [zpm](https://zig.pm/#/package/zigvale), and [astrolabe](https://astrolabe.pm/#/package/ominitay/zigvale/0.7.0).

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

## Documentation

To generate documentation, run `zig build docs`

Zig's documentation generator is experimental and incomplete. When documentation generation has improved somewhat, I will host the documentation. In the meantime, you may both read the comments made manually, and read the documentation in the [stivale repository](https://github.com/stivale/stivale).
