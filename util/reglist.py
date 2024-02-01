import adafruit_ov5640
from manta import Manta

cam = adafruit_ov5640.OV5640(size=adafruit_ov5640.OV5640_SIZE_HD)

cam.colorspace = adafruit_ov5640.OV5640_COLOR_RGB

cam.flip_y = False
cam.flip_x = False

cam.test_pattern = True

# cam._write_addr_reg(0x3816,320,40)
byte_list = [ ((regval[0]<<8) + regval[1]) for regval in cam._writes ]

while (len(byte_list) < 256):
    byte_list.append(0)

### ROM Mode
# print("\n".join([format(regval,'06x') for regval in byte_list]))

#### Manta Mode
m = Manta('regseq.yaml')
addrs_a = list(range(0,len(byte_list)*2,2))
addrs_b = list(range(1,len(byte_list)*2,2))

m.register_sequence.write(addrs_a, [ val&0xFFFF for val in byte_list ])
m.register_sequence.write(addrs_b, [ val>>16 for val in byte_list ])
print("done")

manta_list = m.register_sequence.read( list(range(0,len(byte_list)*2)) )
print("\n".join([format(regval,'06x') for regval in manta_list]))


m.register_sequence.write(0,0xFFFF)
m.register_sequence.write(511,0xEE)
foo = m.register_sequence.read(0)
bar = m.register_sequence.read(511)
print(foo,bar)

### Arduino Mode
# print("reg_data settings_exp[] = {")
# print(",\n".join( ["{{{}, {}}}".format(hex(regval[0]),hex(regval[1])) for regval in cam._writes]))
# print("};")
# print("int length_exp = sizeof(settings_exp) / sizeof(reg_data);")

