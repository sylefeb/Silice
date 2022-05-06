This folder is meant to contain source data to produce the terrain data file (loaded into spiflash). A possibility is to use images from the Comanche game, [available here](https://github.com/s-macke/VoxelSpace), and to downsample them.

Each map is made of two files (replace N in the filenames by the map id, e.g. from 1 to 6):
- `colorN.tga`: A 128x128 256 color palette image, where only the 16 first colors are used. I typically obtain this with an image editor, reducing the number of colors down to 16.
- `heightN.tga`: A 128x128 8bits grayscale height map.

Then, edit the [spiflash script](../make_spiflash.si) to adjust the variable `num_terrains` to the number of maps. The table `terrain_sky_id` contains the palette index of the sky for each map. Finally edit [the firmware](../firmware.c) and adjust `NUM_MAPS` to the number of maps.

Launch [`build.sh`](../build.sh) in the parent directory to rebuild the spiflash image, design, and to upload to the FPGA board.

**Note:** *A pre-build image with terrain data is available in the parent directory. The build script will use it if available. Erase the file (terrains.img) to rebuild it from images in this directory.*
