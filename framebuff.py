from manta import Manta
import numpy as np
from PIL import Image

m = Manta('cam.yaml')

addrs = list(range(0,120*128))

buf = m.frame_buffer.read(addrs)
# print(buf)
# print(buf[20], (buf[20]>>11 & 0b11_111)<<3)
rgb = [ [(pix&0b11_111) << 3, (pix>>5&0b111_111) << 2, (pix>>11&0b11_111) << 3] for pix in buf]

np_rgb = np.array(rgb,dtype="uint8").reshape((128,120,3))
print(np_rgb)
np.moveaxis(np_rgb,0,-1)


with np.printoptions(threshold=np.inf):
    print(np_rgb)

Image.fromarray(np_rgb, "RGB").show()


