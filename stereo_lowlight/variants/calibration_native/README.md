# Full native calibration capture (static board only)

This separate diagnostic profile captures one complete 400x480 eye per LCD
raster. Luminance is reduced to 6 bits and packed three pixels per 18-bit RAM
word (64000 words). Pixel positions retain native resolution. Memory fits in
32 BRAM36 blocks, leaving room for DDR/FIFOs and a 48-bit x4096 ILA.

Control bit14 arms/holds; bit0 selects the eye. A complete ordered raster is
required before valid is asserted. The selected eye is latched at frame start.
ILA sample bits47:45=110, bit44=complete, bits43:40=epoch, bit39=eye,
bits38:34=0, bits33:18=word address, bits17:0=three 6-bit pixels in raster order
(first pixel in bits5:0). Address/data are registered together.

`tools/calibration_native_hw.tcl` captures left, right, and left again. Each RAM
is read twice, requiring identical data and complete address coverage. The
checkerboard must stay physically fixed throughout: the eyes are captured at
different times and sensor exposures are not synchronized. The final left
image checks for endpoint movement, but cannot prove the board did not move
and return between exposures. The decoder reports this limitation explicitly.

This profile is for calibration, not dynamic ranging validation. Native corner
coordinates require no rescaling or crop offset. Grayscale quantization and
camera noise still limit corner precision. Do not infer distance accuracy from
successful checkerboard detection alone. A multi-pose stereo calibration and
independent measured-distance tests are still required.

Build scripts are derived using `tools/prepare_calibration_native.py` after
`tools/prepare_calibration_build.py`; hardware helper is derived using
`tools/prepare_calibration_native_hw.py`. Build with the separate
`tools/build_calibration_native.tcl`. Timing must pass before a bitstream is
written. Program/capture using `tools/calibration_native_hw.tcl` with Vivado
options preceding `-tclargs program POSE`. Decode the printed directory with
`tools/decode_calibration_native.py`.

The existing `rtl` and `build/video_fusion` are untouched. Restore with
`checkpoints/video_fusion_20261028/restore.ps1 -Version video`. No Flash writes.
RTL tests cover both native eyes, all384000 pixels, packing across row
boundaries, incomplete rejection, frozen data, rearm and reset. The software
test independently renders a checker with a known 12-pixel stereo offset,
checks corner recovery and rejects an injected corrupt repeat read.
