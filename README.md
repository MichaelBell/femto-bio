# FemtoRV based IO processor

This will be an implementation similar to the [Baochip BIO](https://www.bunniestudios.com/blog/2026/bio-the-bao-i-o-coprocessor/).

The idea is to make something small that is suitable for integration with a larger core on modest FPGAs or open source silicon processes (e.g. gf180mcu).

## Functionality

The BIO core is a small RISC-V core with a small dedicated RAM for instructions and local data.  Configuration registers and the instruction RAM are accessible through an APB interface.

Optionally, the core can also access the SoC's main address space via an APB interface.  This allows the BIO to be used for data processing unrelated to IO.

The default configuration will be 1kB instruction RAM, but this will be configurable.

Up to 32 GPIOs can be controlled.

The IO core is based on RV32E, using a heavily modified FemtoRV quark bicycle core, plus Zbkb extension (possibly not all of it?  possibly with a single bit reverse instruction?), with the following quirks:
- Registers x0-x15 are implemented as normal.  This allows a regular RV32E toolchain to be used to compile programs.
- Registers x16-x31 are implemented to match [Baochip 1x BIO](https://baochip.github.io/baochip-1x/ch02-00-bio-overview.html#design-of-the-bio).  1-4 FIFOs of depth 4 or 8 can be configured.
