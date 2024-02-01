import adafruit_ov5640
from manta import Manta
import sys

# PART 1
# simulate writes to camera, according to adafruit library (with modifications by kiran)

cam = adafruit_ov5640.OV5640(size=adafruit_ov5640.OV5640_SIZE_HD)

cam.colorspace = adafruit_ov5640.OV5640_COLOR_RGB

cam.flip_y = False
cam.flip_x = False

cam.test_pattern = True

# cam._write_addr_reg(0x3816,320,40)
byte_list = [ ((regval[0]<<8) + regval[1]) for regval in cam._writes ]

while (len(byte_list) < 256):
    byte_list.append(0)



# PART 2    
# write the register sequence in the mode specified
modes = ["rom","manta","arduino"]
if ( len(sys.argv) < 2 or not sys.argv[1] in modes ):
    print("usage: python3 reglist.py ["+"|".join(modes)+"]")
else:
    mode = sys.argv[1]
    if mode == "rom":
        ### ROM Mode
        print("\n".join([format(regval,'06x') for regval in byte_list]))
    elif mode == "manta":
        #### Manta Mode
        m = Manta('regseq.yaml')
        addrs_a = list(range(0,len(byte_list)*2,2))
        addrs_b = list(range(1,len(byte_list)*2,2))

        m.register_sequence.write(addrs_a, [ val&0xFFFF for val in byte_list ])
        m.register_sequence.write(addrs_b, [ val>>16 for val in byte_list ])
        
        manta_list = m.register_sequence.read( list(range(0,len(byte_list)*2)) )
        print("manta contents")
        print([format(regval,'04x') for regval in manta_list])
    elif mode == "arduino":
        ### Arduino Mode
        print("reg_data settings_exp[] = {")
        print(",\n".join( ["{{{}, {}}}".format(hex(regval[0]),hex(regval[1])) for regval in cam._writes]))
        print("};")
        print("int length_exp = sizeof(settings_exp) / sizeof(reg_data);")

