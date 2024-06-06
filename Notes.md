# Splat.js

looked simple at first, load data in WebGL data and draw with a shader

It's still quite complex:
1. uses a custom data format that i find confusing
2. the shading is weird and complicated, with a lot of weird numerical optimizations
3. javascript is hard to read for me

# GSV
This is fully OpenGL and Python which is more familiar and seems better structured

The CUDA componetn can be fully skipped

`util.py` only handles OpenGL funcrions simplifications

Also parses .ply files to a more structured format which is a lot better

.ply data is usually binary but we can convert it with the pytho libary i think

most of the work is passing data from the ply file to the shader in a standard form, then rendering

i don't see that much extra wokr being done elsewhere apart from the sorting

THe shader is a bit complex

# Gauss splat
https://github.com/limacv/GaussianSplattingViewer/tree/main
https://github.com/OutofAi/2D-Gaussian-Splatting/blob/main/2D_Gaussian_Splatting.ipynb
https://python-plyfile.readthedocs.io/en/latest/usage.html