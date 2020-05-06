/*
* tga.c -- tga texture loader
* last modification: aug. 14, 2007
*
* Copyright (c) 2005-2007 David HENRY
*
* Permission is hereby granted, free of charge, to any person
* obtaining a copy of this software and associated documentation
* files (the "Software"), to deal in the Software without
* restriction, including without limitation the rights to use,
* copy, modify, merge, publish, distribute, sublicense, and/or
* sell copies of the Software, and to permit persons to whom the
* Software is furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
* NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
* ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
* CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
* WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*
* gcc -Wall -ansi -lGL -lGLU -lglut tga.c -o tga
*/

// SL: 2020-03-08 modified to return lower level info to caller

#include <stdio.h>
#include <stdlib.h>

#include <LibSL/System/System.h>

#include "tga.h"

#pragma pack(push, 1)
/* TGA header */
struct tga_header_t
{
  uchar id_lenght;          /* size of image id */
  uchar colormap_type;      /* 1 is has a colormap */
  uchar image_type;         /* compression type */

  short	cm_first_entry;       /* colormap origin */
  short	cm_length;            /* colormap length */
  uchar cm_size;            /* colormap size */

  short	x_origin;             /* bottom left x coord origin */
  short	y_origin;             /* bottom left y coord origin */

  short	width;                /* picture width (in pixels) */
  short	height;               /* picture height (in pixels) */

  uchar pixel_depth;        /* bits per pixel: 8, 16, 24 or 32 */
  uchar image_descriptor;   /* 24 bits = 0x00; 32 bits = 0x80 */
};
#pragma pack(pop)

/* Texture id for the demo */
uint texId = 0;


static void
GetTextureInfo (const struct tga_header_t *header,t_image_nfo *texinfo)
{
  texinfo->width = header->width;
  texinfo->height = header->height;

  switch (header->image_type)
  {
  case 3:  /* Grayscale 8 bits */
  case 11: /* Grayscale 8 bits (RLE) */
    {
      if (header->pixel_depth == 8)
      {
        texinfo->depth = 8;
      }
      else /* 16 bits */
      {
        texinfo->depth = 16;
      }

      break;
    }

  case 1:  /* 8 bits color index */
  case 2:  /* BGR 16-24-32 bits */
  case 9:  /* 8 bits color index (RLE) */
  case 10: /* BGR 16-24-32 bits (RLE) */
    {
      texinfo->depth = header->pixel_depth;
      /* 16 bits images will be converted to 24 bits */
      if (texinfo->depth == 16)
      {
        texinfo->depth = 24;
      }
      break;
    }
  }
}

static void
ReadTGA8bits (FILE *fp, t_image_nfo *texinfo)
{
  unsigned int i;
  uchar index;

  for (i = 0; i < texinfo->width * texinfo->height; ++i)
  {
    /* Read index color byte */
    index = (uchar)fgetc (fp);
    texinfo->pixels[i] = index;
  }
}

static void
ReadTGA16bits (FILE *fp, t_image_nfo *texinfo)
{
  unsigned int i;
  unsigned short color;

  for (i = 0; i < texinfo->width * texinfo->height; ++i)
  {
    /* Read color word */
    color = fgetc (fp) + (fgetc (fp) << 8);

    /* Convert BGR to RGB */
    texinfo->pixels[(i * 3) + 0] = (uchar)(((color & 0x7C00) >> 10) << 3);
    texinfo->pixels[(i * 3) + 1] = (uchar)(((color & 0x03E0) >>  5) << 3);
    texinfo->pixels[(i * 3) + 2] = (uchar)(((color & 0x001F) >>  0) << 3);
  }
}

static void
ReadTGA24bits (FILE *fp, t_image_nfo *texinfo)
{
  unsigned int i;

  for (i = 0; i < texinfo->width * texinfo->height; ++i)
  {
    /* Read and convert BGR to RGB */
    texinfo->pixels[(i * 3) + 2] = (uchar)fgetc (fp);
    texinfo->pixels[(i * 3) + 1] = (uchar)fgetc (fp);
    texinfo->pixels[(i * 3) + 0] = (uchar)fgetc (fp);
  }
}

static void
ReadTGA32bits (FILE *fp, t_image_nfo *texinfo)
{
  unsigned int i;

  for (i = 0; i < texinfo->width * texinfo->height; ++i)
  {
    /* Read and convert BGRA to RGBA */
    texinfo->pixels[(i * 4) + 2] = (uchar)fgetc (fp);
    texinfo->pixels[(i * 4) + 1] = (uchar)fgetc (fp);
    texinfo->pixels[(i * 4) + 0] = (uchar)fgetc (fp);
    texinfo->pixels[(i * 4) + 3] = (uchar)fgetc (fp);
  }
}

static void
ReadTGAgray8bits (FILE *fp, t_image_nfo *texinfo)
{
  unsigned int i;

  for (i = 0; i < texinfo->width * texinfo->height; ++i)
  {
    /* Read grayscale color byte */
    texinfo->pixels[i] = (uchar)fgetc (fp);
  }
}

static void
ReadTGAgray16bits (FILE *fp, t_image_nfo *texinfo)
{
  unsigned int i;

  for (i = 0; i < texinfo->width * texinfo->height; ++i)
  {
    /* Read grayscale color + alpha channel bytes */
    texinfo->pixels[(i * 2) + 0] = (uchar)fgetc (fp);
    texinfo->pixels[(i * 2) + 1] = (uchar)fgetc (fp);
  }
}

static void
ReadTGA8bitsRLE (FILE *fp, t_image_nfo *texinfo)
{
  int i, size;
  uchar index;
  uchar packet_header;
  uchar *ptr = texinfo->pixels;

  while (ptr < texinfo->pixels + (texinfo->width * texinfo->height))
  {
    /* Read first byte */
    packet_header = (uchar)fgetc (fp);
    size = 1 + (packet_header & 0x7f);

    if (packet_header & 0x80)
    {
      /* Run-length packet */
      index = (uchar)fgetc (fp);
      for (i = 0; i < size; ++i, ptr ++)
      {
        *ptr = index;
      }
    }
    else
    {
      /* Non run-length packet */
      for (i = 0; i < size; ++i, ptr ++)
      {
        index = (uchar)fgetc (fp);
        *ptr = index;
      }
    }
  }
}

static void
ReadTGA16bitsRLE (FILE *fp, t_image_nfo *texinfo)
{
  int i, size;
  unsigned short color;
  uchar packet_header;
  uchar *ptr = texinfo->pixels;

  while (ptr < texinfo->pixels + (texinfo->width * texinfo->height) * 3)
  {
    /* Read first byte */
    packet_header = fgetc (fp);
    size = 1 + (packet_header & 0x7f);

    if (packet_header & 0x80)
    {
      /* Run-length packet */
      color = fgetc (fp) + (fgetc (fp) << 8);

      for (i = 0; i < size; ++i, ptr += 3)
      {
        ptr[0] = (uchar)(((color & 0x7C00) >> 10) << 3);
        ptr[1] = (uchar)(((color & 0x03E0) >>  5) << 3);
        ptr[2] = (uchar)(((color & 0x001F) >>  0) << 3);
      }
    }
    else
    {
      /* Non run-length packet */
      for (i = 0; i < size; ++i, ptr += 3)
      {
        color = fgetc (fp) + (fgetc (fp) << 8);

        ptr[0] = (uchar)(((color & 0x7C00) >> 10) << 3);
        ptr[1] = (uchar)(((color & 0x03E0) >>  5) << 3);
        ptr[2] = (uchar)(((color & 0x001F) >>  0) << 3);
      }
    }
  }
}

static void
ReadTGA24bitsRLE (FILE *fp, t_image_nfo *texinfo)
{
  int i, size;
  uchar rgb[3];
  uchar packet_header;
  uchar *ptr = texinfo->pixels;

  while (ptr < texinfo->pixels + (texinfo->width * texinfo->height) * 3)
  {
    /* Read first byte */
    packet_header = (uchar)fgetc (fp);
    size = 1 + (packet_header & 0x7f);

    if (packet_header & 0x80)
    {
      /* Run-length packet */
      fread (rgb, sizeof (uchar), 3, fp);

      for (i = 0; i < size; ++i, ptr += 3)
      {
        ptr[0] = rgb[2];
        ptr[1] = rgb[1];
        ptr[2] = rgb[0];
      }
    }
    else
    {
      /* Non run-length packet */
      for (i = 0; i < size; ++i, ptr += 3)
      {
        ptr[2] = (uchar)fgetc (fp);
        ptr[1] = (uchar)fgetc (fp);
        ptr[0] = (uchar)fgetc (fp);
      }
    }
  }
}

static void
ReadTGA32bitsRLE (FILE *fp, t_image_nfo *texinfo)
{
  int i, size;
  uchar rgba[4];
  uchar packet_header;
  uchar *ptr = texinfo->pixels;

  while (ptr < texinfo->pixels + (texinfo->width * texinfo->height) * 4)
  {
    /* Read first byte */
    packet_header = (uchar)fgetc (fp);
    size = 1 + (packet_header & 0x7f);

    if (packet_header & 0x80)
    {
      /* Run-length packet */
      fread (rgba, sizeof (uchar), 4, fp);

      for (i = 0; i < size; ++i, ptr += 4)
      {
        ptr[0] = rgba[2];
        ptr[1] = rgba[1];
        ptr[2] = rgba[0];
        ptr[3] = rgba[3];
      }
    }
    else
    {
      /* Non run-length packet */
      for (i = 0; i < size; ++i, ptr += 4)
      {
        ptr[2] = (uchar)fgetc (fp);
        ptr[1] = (uchar)fgetc (fp);
        ptr[0] = (uchar)fgetc (fp);
        ptr[3] = (uchar)fgetc (fp);
      }
    }
  }
}

static void
ReadTGAgray8bitsRLE (FILE *fp, t_image_nfo *texinfo)
{
  int i, size;
  uchar color;
  uchar packet_header;
  uchar *ptr = texinfo->pixels;

  while (ptr < texinfo->pixels + (texinfo->width * texinfo->height))
  {
    /* Read first byte */
    packet_header = (uchar)fgetc (fp);
    size = 1 + (packet_header & 0x7f);

    if (packet_header & 0x80)
    {
      /* Run-length packet */
      color = (uchar)fgetc (fp);

      for (i = 0; i < size; ++i, ptr++)
        *ptr = color;
    }
    else
    {
      /* Non run-length packet */
      for (i = 0; i < size; ++i, ptr++)
        *ptr = (uchar)fgetc (fp);
    }
  }
}

static void
ReadTGAgray16bitsRLE (FILE *fp, t_image_nfo *texinfo)
{
  int i, size;
  uchar color, alpha;
  uchar packet_header;
  uchar *ptr = texinfo->pixels;

  while (ptr < texinfo->pixels + (texinfo->width * texinfo->height) * 2)
  {
    /* Read first byte */
    packet_header = (uchar)fgetc (fp);
    size = 1 + (packet_header & 0x7f);

    if (packet_header & 0x80)
    {
      /* Run-length packet */
      color = (uchar)fgetc (fp);
      alpha = (uchar)fgetc (fp);

      for (i = 0; i < size; ++i, ptr += 2)
      {
        ptr[0] = color;
        ptr[1] = alpha;
      }
    }
    else
    {
      /* Non run-length packet */
      for (i = 0; i < size; ++i, ptr += 2)
      {
        ptr[0] = (uchar)fgetc (fp);
        ptr[1] = (uchar)fgetc (fp);
      }
    }
  }
}

t_image_nfo *ReadTGAFile(const char *filename)
{
  FILE *fp;
  t_image_nfo *texinfo;
  struct tga_header_t header;
	fopen_s(&fp, filename, "rb");
  if (!fp) {
    fprintf (stderr, "error: couldn't open \"%s\"!\n", filename);
    return NULL;
  }

  /* Read header */
  fread (&header, sizeof (struct tga_header_t), 1, fp);

  texinfo = new t_image_nfo;
  GetTextureInfo (&header, texinfo);
  fseek (fp, header.id_lenght, SEEK_CUR);

  /* Memory allocation */
  texinfo->pixels = new uchar[texinfo->width * texinfo->height * (texinfo->depth/8)];
  if (!texinfo->pixels)
  {
    free (texinfo);
    return NULL;
  }

  /* Read color map */
  texinfo->colormap = NULL;
  if (header.colormap_type)
  {
    /* NOTE: color map is stored in BGR format */
    texinfo->colormap = new uchar[ header.cm_length * (header.cm_size >> 3) ];
    fread (texinfo->colormap, sizeof (uchar), header.cm_length * (header.cm_size >> 3), fp);
  }

  /* Read image data */
  switch (header.image_type)
  {
  case 0:
    /* No data */
    break;

  case 1:
    /* Uncompressed 8 bits color index */
    ReadTGA8bits (fp, texinfo);
    break;

  case 2:
    /* Uncompressed 16-24-32 bits */
    switch (header.pixel_depth)
    {
    case 16:
      ReadTGA16bits (fp, texinfo);
      break;

    case 24:
      ReadTGA24bits (fp, texinfo);
      break;

    case 32:
      ReadTGA32bits (fp, texinfo);
      break;
    }

    break;

  case 3:
    /* Uncompressed 8 or 16 bits grayscale */
    if (header.pixel_depth == 8)
      ReadTGAgray8bits (fp, texinfo);
    else /* 16 */
      ReadTGAgray16bits (fp, texinfo);
    break;

  case 9:
    /* RLE compressed 8 bits color index */
    ReadTGA8bitsRLE (fp, texinfo);
    break;

  case 10:
    /* RLE compressed 16-24-32 bits */
    switch (header.pixel_depth)
    {
    case 16:
      ReadTGA16bitsRLE (fp, texinfo);
      break;
    case 24:
      ReadTGA24bitsRLE (fp, texinfo);
      break;
    case 32:
      ReadTGA32bitsRLE (fp, texinfo);
      break;
    }

    break;

  case 11:
    /* RLE compressed 8 or 16 bits grayscale */
    if (header.pixel_depth == 8)
      ReadTGAgray8bitsRLE (fp, texinfo);
    else /* 16 */
      ReadTGAgray16bitsRLE (fp, texinfo);
    break;

  default:
    /* Image type is not correct */
    fprintf (stderr, "error: unknown TGA image type %i!\n", header.image_type);
    delete[] (texinfo->pixels);
    if (texinfo->colormap) delete[](texinfo->colormap);
    delete   (texinfo);
    texinfo = NULL;
    break;
  }

  fclose (fp);
  return texinfo;
}
