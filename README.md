# Gaussain Splatting rendering in VR using LOVR

Gaussian platting is a novel volume rendering technique, which was introduced in the 90s but recently received major attention due to recent papers that discuss methods to efficently produce and render them, allowing for real time use cases.

I wanted to understand the technique in depth, so I decided to see if i could port it to VR though my favourite Engine, LOVR.
As references i used the [Original paper](https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/3d_gaussian_splatting_low.pdf) and a [CUDA/OpenGL implementation of the renderer fro GitHub](https://github.com/limacv/GaussianSplattingViewer). The original paper discusses only a CUDA pipeline, so I needeed an OpenGL implementatin to more easily move it to LOVR.
