# NAZA Pure-Zig

Pure-Zig NAZA terminal UI with secure GGUF handling, crypto utilities, and fast road/food evidence scans.

## What was implemented

- Boxed numbered terminal UI
- Road-condition scanner
- Food/water scanner
- Fast pure-Zig evidence scanning
- Low/Medium/High risk extraction
- Secure HTTPS GGUF downloader
- SHA-256 model verification
- GGUF inspection
- SHA3-256 and SHAKE256 commands
- ML-KEM and crypto self-tests
- Native CPU optimizations
- Quantized matrix worker pool
- Fused Q3_K dot-product kernel

## Build

```bash
ZIG_GLOBAL_CACHE_DIR=/tmp/naza-zig-global-cache \
.tools/zig-0.15.2/zig build
```

## Test

```bash
ZIG_GLOBAL_CACHE_DIR=/tmp/naza-zig-global-cache \
.tools/zig-0.15.2/zig build test
```

## Format check

```bash
.tools/zig-0.15.2/zig fmt --check build.zig src/naza_all.zig
```

## Run the TUI

```bash
ZIG_GLOBAL_CACHE_DIR=/tmp/naza-zig-global-cache \
.tools/zig-0.15.2/zig build run -- tui
```

Or:

```bash
./zig-out/bin/naza-zig tui
```

Select:

```text
3) Road Scanner
```

Enter one location or route. Press Enter for the remaining fields to use defaults.

The default scanner is fast, pure-Zig evidence processing. It does not access GPS, live traffic, weather, satellites, or sensors.

The scanner returns the first standalone:

```text
Low
Medium
High
```

If no valid label is found, it returns `Medium`.

## Secure model download

Pinned model:

```text
llama3-small-Q3_K_M.gguf
```

SHA-256:

```text
8e4f4856fb84bafb895f1eb08e6c03e4be613ead2d942f91561aeac742a619aa
```

Download:

```bash
mkdir -p models

ZIG_GLOBAL_CACHE_DIR=/tmp/naza-zig-global-cache \
.tools/zig-0.15.2/zig build run -- \
download models/llama3-small-Q3_K_M.gguf
```

Verify:

```bash
ZIG_GLOBAL_CACHE_DIR=/tmp/naza-zig-global-cache \
.tools/zig-0.15.2/zig build run -- \
verify models/llama3-small-Q3_K_M.gguf
```

The downloader:

- Requires HTTPS
- Validates redirects
- Restricts the model host
- Displays download progress
- Uses a mode-0600 staging file
- Verifies SHA-256 before publishing
- Never overwrites an existing destination

## Optional full GGUF scan

The full pure-Zig GGUF inference path is slower and disabled by default.

```bash
NAZA_ENABLE_MODEL_SCAN=1 \
ZIG_GLOBAL_CACHE_DIR=/tmp/naza-zig-global-cache \
.tools/zig-0.15.2/zig build run -- tui
```

## Other commands

Show model information:

```bash
.tools/zig-0.15.2/zig build run -- model
```

Inspect GGUF metadata:

```bash
.tools/zig-0.15.2/zig build run -- \
gguf models/llama3-small-Q3_K_M.gguf
```

List PQC algorithms:

```bash
.tools/zig-0.15.2/zig build run -- pqc
```

SHA3-256:

```bash
.tools/zig-0.15.2/zig build run -- sha3 "hello"
```

SHAKE256:

```bash
.tools/zig-0.15.2/zig build run -- shake "hello" 32
```

Run self-test:

```bash
.tools/zig-0.15.2/zig build run -- selftest
```

## Disclaimer

This is experimental decision-support software. It does not provide live road conditions or prove real-world safety. Verify results independently.
