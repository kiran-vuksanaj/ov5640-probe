#include <Wire.h>

// I2C Camera Controller for OV5640
// author: Kiran Vuksanaj

// On power cycle or soft reset, writes a sequence of registers via I2C pins to the OV5640
// to initialize and configure DVP camera output.

// Register sequences are inspired by the output of CircuitPython Modules `adafruit_ov5640`
// and `espcamera`, two complete solutions for controlling the OV5640.

// Code/wiring structure inspired by Joe Steinmeyer's code for similarly controlling the OV7670.

// Wire the SCL and SDA pins of your microcontroller to the SCL and SDA pins of the OV5640 breakout.
// Mode HD outputs 720p60fps output
// Mode QVGA outputs 240p120fps output

const byte ADDR = 0x3C; // i2c_address of camera default, line 1005

enum Mode {HD,QVGA,EXP} MODE = EXP; // change this line to switch the camera mode written
int led = 13;


typedef struct reg_data {
  uint16_t reg;
  uint8_t data;
};

reg_data *settings;
int total_settings;

void program() {
  for(int i = 0; i <total_settings; i += 1) {
    byte_read(ADDR,settings[i].reg);
    byte_write(ADDR,settings[i].reg,settings[i].data);
    byte_read(ADDR,settings[i].reg);
    Serial.print("\n");
  }
  Serial.println("OV5640 setup done");
  byte_read(ADDR,0x3816);
  byte_read(ADDR,0x3817);
  byte_read(ADDR,0x3818);
  byte_read(ADDR,0x3819);
}  


void byte_read(uint8_t address, uint16_t reg) {
  // put your main code here, to run repeatedly:
  byte error;

  byte reg_hi = (byte)(reg>>8); // chip id high byte
  byte reg_lo = (byte)reg;
//  Serial.printf("reg hi: %x, reg lo: %x\n",reg_hi,reg_lo);
  Wire.beginTransmission(address);
  Wire.write(reg_hi); 
  Wire.write(reg_lo);
  error = Wire.endTransmission();
//  Serial.printf("error after attempted communication at address %x:%d\n",address,error);

  int bytes_count;
  bytes_count = Wire.requestFrom(address,1,true);
  uint8_t byte_read;
  byte_read = Wire.read();
  Serial.printf("byte read from reg %x: %x\n",reg,byte_read);
}

void byte_write(uint8_t address, uint16_t reg, uint8_t val) {
  byte error;
  int bytes_written = 0;
  byte reg_hi = (byte)(reg>>8); // chip id high byte
  byte reg_lo = (byte)reg;

  Wire.beginTransmission(address);
  bytes_written += Wire.write(reg_hi);
  bytes_written += Wire.write(reg_lo);
  bytes_written += Wire.write(val);
  error = Wire.endTransmission();
  Serial.printf("byte write reg %x val %x resulted in error=%d & bytes_written=%d\n",reg,val,error,bytes_written);
}
