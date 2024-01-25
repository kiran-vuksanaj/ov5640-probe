import adafruit_ov5640

cam = adafruit_ov5640.OV5640(size=adafruit_ov5640.OV5640_SIZE_HD)

cam.colorspace = adafruit_ov5640.OV5640_COLOR_RGB

cam.flip_y = False
cam.flip_x = False

cam.test_pattern = False

# cam._write_addr_reg(0x3816,320,40)

print("reg_data settings_exp[] = {")
print(",\n".join( ["{{{}, {}}}".format(hex(regval[0]),hex(regval[1])) for regval in cam._writes]))
print("};")
print("int length_exp = sizeof(settings_exp) / sizeof(reg_data);")


