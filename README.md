# OV5640 Live Video Display to HDMI on FPGA

This repository contains a Xilinx FPGA design to connect an OV5640 and display

Designed for and tested on the [RealDigital Urbana Board](https://www.realdigital.org/hardware/urbana), using the [Spartan-7 S50](https://www.xilinx.com/products/silicon-devices/fpga/spartan-7.html). 

## Configuration
1. Build Camera Setting Sequence
The `util/reglist.py` file generates a sequence of I2C commands to turn on and configure the camera sensor; it needs to be generated before building the script, and formats it to be initialized in BRAM memory.
```python3 util/reglist.py rom > data/rom.mem```

2. Build FPGA Design
The `build.tcl` script can be used to run synthesis and routing through Vivado without using the GUI.
```vivado -mode batch -source build.tcl```
This script generates a bitstream suited for the board, which can then be loaded to the board.
```openFPGAloader -b arty_s7_50 obj/final.bit```

## Wiring Layout

The `xdc/top_level.xdc` file is intended for the Urbana Board, configuring standard i/o devices (LEDs, switches, etc) as well as the PMOD connectors and the HDMI port.
* PMODA is connected to data pins D2-D9 of the OV5640 breakout board, which
* PMODB is connected to the other relevant signals:
  * PMODB[0] <-- Pixel Clock (PC)
  * PMODB[1] <-- Horizontal Sync (HS)
  * PMODB[2] <-- Vertical Sync (VS)
  * PMODB[3] --> External Clock (XC)
  * PMODB[5] <-> I2C clock (SCL)
  * PMODB[6] <-> I2C data (SDA)

If using the OV7670 adapter PCB from 6.205, most of these connections are already handled. Instead of connecting a Seeeduino microcontroller, use two jumper cables: one from jb[5] to the position for the Seeed's D5 (SCL) pin, and the other from jb[6] to the position for the Seeed's D4 (SDA) pin.

(coming soon: a dedicated PCB to map two PMOD connectors to the proper camera breakout pins)


## Usage
### User-Defined Switches
On the Urbana board, switches 0-2 are in use:
sw[1:0] :: seven-segment display
* 2'b00 displays the hcount (right) and vcount (left) outputs between sync signals from the camera, in hex
* 2'b01 displays the number of cycles of PCLK each second, in thousands
* 2'b10 displays the number of cycles of PCLK in each frame
* 2'b11 displays the number of cycles of PCLK in each row (left) and the number of frames in each second (right)

sw[2] :: mode for camera register writes
* 1'b0 references the ROM initialized during synthesis
* 1'b1 references the BRAM that can communicate over UART through Manta

### User-Defined Buttons
* btn[0] : system reset
* btn[1] : write registers to the camera

### Real-time Board
TODO: explain how to use the manta core

## IP/Core Usage

* Xilinx Memory Interface Generator (MIG)
* AXI4-Stream FIFO IP
* Adafruit OV5640 library, modified for better functionality on FPGA
* Manta, by Fischer Moseley, to communicate by 

## Reference Documentation
* [RealDigital Urbana Board Manual]()
* [Spartan 7 S-50 FPGA]()
* [Adafruit OV5640 Breakout Board]()
* [Adafruit OV5640 MicroPython Library]()
* [OV5640 Register Datasheet]()

## Future Goals

I'll be working to eliminate usage of Xilinx IP to make this design work cross-platform for any FPGA, only relying on the presence of a memory chip, PMOD connectors, and 