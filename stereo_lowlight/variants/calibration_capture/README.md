# Temporary static checkerboard acquisition

This profile bypasses fusion **only while running the diagnostic bitstream**.
Production RTL and `build/video_fusion` are unchanged. Restore with
`checkpoints/video_fusion_20261028/restore.ps1 -Version video` after capture.
Use JTAG RAM programming only; no configuration Flash commands are included.

The snapshot is one complete LCD raster. The two cameras expose independently;
these are not synchronized stereo sensor frames. Keep the printed board and
cameras stationary. This path is suitable for static calibration, not proof of
dynamic tracking accuracy.

Each camera's native coordinates are 400x480. Memory holds 400x240 grayscale:

- Full-field mode samples x=0,2,...,398 and y=0,2,...,478 in each eye.
- Native crop mode stores 200x240 pixels in each eye. Current hardware helper
  uses x=100..299,y=120..359. Crop origins can also be x=0/200,y=0/240.
- Every output row contains 200 left pixels then 200 right pixels.

VIO control: bit14 arm/hold; bit0 full-field mode; bits3:2 crop x/100 and
bits5:4 crop y/120 (both clamped at 2). Configuration is latched at capture
start. Release bit14 to rearm. A truncated or out-of-order raster is rejected.
The 96000 bytes stay frozen until release.

ILA32 sample: bits31:30=11, bit29=complete, bits28:25=epoch, bits24:8=address,
bits7:0=luminance. Address and RAM data are registered together in the read
clock domain. Completion/epoch are synchronized; epoch is stable before done.
The helper reads every byte twice and the decoder requires exact agreement.
Epoch alone is not a permanent capture ID (4-bit wrap); timestamp folders and
image hashes identify saved captures.

Build: run `tools/prepare_calibration_build.py`, then Vivado batch with
`tools/build_calibration_capture.tcl`. A bitstream is emitted only when both
setup and hold slack are nonnegative. Generated scripts live separately from
the production build. The hardware helper accepts `program POSE` (program and
capture) or `capture POSE` (already loaded diagnostic only). Pass all Vivado
options before `-tclargs`. Decode the emitted frame directory with
`tools/decode_calibration_capture.py`.

Verification: `sim/tb_calibration_capture.v` checks all96000 pixels of four
frames, three crop positions, partial rejection, freeze, rearm and abort/reset.
`tools/test_calibration_decode.py` checks checker detection and native coordinate
recovery and injects corrupt/missing reads to verify rejection. Synthetic test
frames live under `decoder_selftest`, separate from `frames` hardware captures.
