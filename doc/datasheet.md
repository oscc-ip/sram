## Datasheet

### Overview
The `sram` IP is a fully parameterised soft IP to implement the sram controller. The IP features an AXI4 slave interface, fully compliant with the AMBA4 AXI Protocol Specification.

### Feature
* FSM and blocking pipeline AXI4 write and read implementation
* FIXED and INCR burst type support
* Aligned address access only
* Narrow transfer support
* 4~32KB singal-port RAM
* Static synchronous design
* Full synthesizable

### Interface
| port name | type        | description          |
|:--------- |:------------|:---------------------|
| axi4      | interface   | axi4 slave interface |

### Register

### Program Guide
The software operation of `sram` is simple. It supports memory mmap access.

### Resoureces
### References
### Revision History