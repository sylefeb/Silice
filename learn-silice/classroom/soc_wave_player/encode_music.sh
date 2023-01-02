#!/bin/bash
ffmpeg -i $1 -acodec pcm_u8 -f u8 -ac 1 -ar 8000 music.raw
