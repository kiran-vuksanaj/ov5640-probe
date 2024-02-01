import adafruit_ov5640
from manta import Manta

cam = adafruit_ov5640.OV5640(size=adafruit_ov5640.OV5640_SIZE_HD)

cam.colorspace = adafruit_ov5640.OV5640_COLOR_RGB

cam.flip_y = False
cam.flip_x = False

cam.test_pattern = False

# cam._write_addr_reg(0x3816,320,40)
byte_list = [ ((regval[0]<<8) + regval[1]) for regval in cam._writes ]

while (len(byte_list) < 256):
    byte_list.append(0)

### ROM Mode
print("\n".join([format(regval,'06x') for regval in byte_list]))

#### Manta Mode
# m = Manta('regseq.yaml')
# addrs = list(range(0,len(byte_list)))
# m.register_sequence.write(addrs,byte_list)

### Arduino Mode
# print("reg_data settings_exp[] = {")
# print(",\n".join( ["{{{}, {}}}".format(hex(regval[0]),hex(regval[1])) for regval in cam._writes]))
# print("};")
# print("int length_exp = sizeof(settings_exp) / sizeof(reg_data);")

