# HDMI and hardware Perlin noise

This project relies on [Silice HDMI implementation](../common/hdmi.ice). For a tutorial on the HDMI framework and HDMI controller [please refer to this example](../hdmi_test/).

**Note:** *This project targets the ULX3S ; adapting to other boards should not be difficult but requires reworking the clocks and possibly the HDMI controller.*

In this project we investigate how to implement the famous [Perlin noise](https://en.wikipedia.org/wiki/Perlin_noise) using Silice.

Perlin noise is an essential ingredient of procedural generation and has inspired many follow up works. Beyond the algorithm itself it introduces the *recipe* to efficiently generate visual complexity. 
I myself was greatly inspired by the seminal paper of Perlin but also by the book [Texturing and modeling a procedural approach](https://books.google.fr/books/about/Texturing_and_Modeling.html?id=fXp5UsEWNX8C&redir_esc=y), which gathered together top experts of the field presenting very practical approaches with example code. A must read, absolutely still relevant today. Years later, I found myself co-authoring a [state of the art on the topic](https://www-sop.inria.fr/reves/Basilic/2010/LLCDDELPZ10/LLCDDELPZ10STARPNF.pdf) with some of the main experts in the field ; I would never have believed this would happen when I was hacking procedural textures from the book back in 1997! For latest results in this field, you may want to check out our recent [procedural phasor noise](https://hal.inria.fr/hal-02118508) paper.

But enough background, let's dive into the details!

So what is Perlin noise? First, it is a *procedural* noise generator; and by this I do not simply mean that it is produced by a procedure (some computations), but I mean some very specific properties:
- It computes a value at a given texture coordinate (2D in our case) in constant time.
- It uses little memory, and the amount of memory it uses is independent of the size of the output.
- It is visually random, but its frequency content is controlled. Wait, what??? This intuitively means that the 'size' of the perceived features, e.g. the 'roughness' of the noise is controlled. Basically, while it is random in the *spatial* domain, it is structured in the *spectral* domain (think Fourier transform).

This notion of 'random grain size control', or rather *frequency band* is at the core of the methodology of procedural texturing introduced by Perlin. By combining several of these frequency-controlled noises together, and by feeding the result into non-linear functions (sine wave, absolute values, colormap) very interesting textures are created: marble, wood, even planets!

So how do you get a frequency-controlled *procedural* noise generator? *This*, is an excellent and very important question that [got a lot of researchers busy](https://www-sop.inria.fr/reves/Basilic/2010/LLCDDELPZ10/LLCDDELPZ10STARPNF.pdf) for a long time (and still does!). 

Perlin's seminal paper introduces a first and very effective method to do that: *gradient noise* (not to be confused with *value noise*). It is not without defects, but produces great results at a small level of complexity. The method is perfect to produce visually interesting results at low cost, and in particular when you have no memory to store a framebuffer. That is, it is perfect to generate visual complexity while [*racing the beam*](https://en.wikipedia.org/wiki/Racing_the_Beam): as the video signal is generated.

We are going to do exactly that, [shadertoy style](https://www.shadertoy.com/view/wt23zz).
As with the original implementation we will be using a lookup table to produce (pseudo-)randomness.

The principle behind Perlin noise is to rely on a (virtual) grid in space. For the sake of simplicity, assume each grid cell has a unit size. At each node of this grid, we have a unit random vector. Given a point in a cell, we compute one value for each cell corner. This value is the dot product between the point *local cell coordinates* and the unit vector at the corner. The local cell coordinates of a point are simply its coordinate within the cell (e.g. if cells have unit size, the fractional part of its coordinates).

So, we need unit vectors for the cell corners, and a way to produce a random assignment of these vectors to grid corners. For this, we will use a *permutation table*: in our case a table of 256 entries which is a random permutation of indices from 0 to 255.

The final noise value is obtained by bilinear interpolation of the noise values computed from the corners.

So that's sounds fairly easy; however we are targeting hardware here, and want to race the beam! What does that means in terms of hardware resources and clocking?


