# SRAM

## Features
* FSM and blocking pipeline AXI4 write and read implementation
* FIXED and INCR burst type support
* Aligned address access only
* Narrow transfer support
* 4~32KB singal-port RAM
* Static synchronous design
* Full synthesizable

FULL vision of datatsheet can be found in [datasheet.md](./doc/datasheet.md).

## Build and Test
```bash
make comp    # compile code with vcs
make run     # compile and run test with vcs
make wave    # open fsdb format waveform with verdi
```