# Getting started with Silice using YoWASP (all platforms)

## Install

Silice is available as a [YoWASP](https://yowasp.org/) package. This is a great
way to use Silice under any platform that supports python, as YoWASP runs
WebAssembly compiled tools from python. Yes, this means no pain with compiling
from tools or dealing with incompatible binaries!

To install Silice with YoWASP, simply run [get_started_yowasp.sh](get_started_yowasp.sh), assuming you already have a working installation
of `python` and `pip`. This will install all required YoWASP package.

Then, head to a project, such as `projects/blinky` and run:

```make yowasp-<BOARD>```

where BOARD is the name of a [supported board](frameworks/board). For instance:

```make yowasp-icebreaker```.



## Sending the bitstream to your board



