 Font Optimizer
-==============-

Developed by Philip Taylor (excors@gmail.com)

The main purpose of this project is to provide a way to convert TTF files into
smaller files that contain only a subset of the original's glyphs, focusing on
high-quality conversion (preserving special typographic features like kerning
and ligatures).

The project mainly consists of:

    Font/Subsetter.pm   - library to generate subsets of TTF files
    Font/EOTWrapper.pm  - library to convert TTF to EOT
    subset.pl           - example script using the libraries
    ext/                - external libraries (particularly Font::TTF, since a
                          specific not-yet-released version is needed)

The libraries are used in the web service at http://fonts.philip.html5.org/

The code doesn't really have any documentation or proper APIs, and it hasn't
been tested on a wide range of fonts, but when it works it should be fairly
reliable and stable.