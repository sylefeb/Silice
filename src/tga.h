#pragma once

typedef struct 
{
  uint   width;
  uint   height;
  uchar  depth;
  uchar *pixels;
  uchar *colormap;
  uint   colormap_size;
  uint   colormap_chans;
} t_image_nfo;

t_image_nfo *ReadTGAFile(const char *filename);
