# MMUKO-OS Examples

This directory contains the two runnable protocol examples used by the root
`Makefile`.

## Trident Boot

Path: `examples/trident-boot`

`trident-boot` is a static HTML/Canvas NSIGII visualizer. It models the MMUKO-OS
trident login/boot surface where identity, device, and time align toward the
95.4% aura-seal coherence threshold.

From the repository root:

```bash
make examples-trident
```

Then open:

```text
examples/trident-boot/index.html
```

No build step is required because the visualizer is plain browser HTML,
JavaScript, and CSS.

## LT File Format

Path: `examples/lt-fileformat`

`lt-fileformat` is the Go LTF/NSIGII codec example. It treats an input video or
RGB24 stream as a Linkable Then Format/File artifact:

```text
TRANSMIT -> RECEIVE -> VERIFY -> .nsigii
```

From the repository root:

```bash
make examples-lt-fileformat
```

The built codec is written to:

```text
build/nsigii-codec
```

On Windows the executable suffix is `.exe`.

Example usage from inside `examples/lt-fileformat`:

```bash
go run main.go -input your_video.mp4 -output your_video.nsigii
```

The codec uses FFmpeg/FFprobe for common video inputs and writes the `.nsigii`
container after trident verification.

## OBIELF Handoff

The examples are not native OBIELF binaries yet. The current integration path is
to build or generate an artifact first, then package it through the local OBIELF
crate:

```bash
make obielf-preview
```

That packages the MMUKO boot image as an `obielf64` executable artifact. Future
linkable examples should use `obielf package --kind object`, `--kind
static-library`, or `--kind dynamic-library` once the OBIELF linker and loader
contracts are formalized.
