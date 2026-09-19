# NAZA Pure-Zig Monolith — Realized Implementation Pass

This checkpoint is a single-source-file Zig implementation targetting Zig 0.15.2. It does not use `@cImport`, libc, C sources, Python, llama.cpp, liboqs, OpenSSL, or system-library crypto linkage.

The application source is `src/naza_all.zig`.

## What changed in this pass

The ML-KEM-512/768/1024 research implementation is callable but remains unverified against official vectors. The ML-DSA arithmetic and packing code is retained for repair work, but its public facade now fails closed because audit testing proved that its signer output is not accepted by its verifier.

The implementation catalog now uses explicit states:

- `catalog_only`: named for discovery, but no callable implementation exists.
- `partial`: meaningful algorithm components exist, but the complete standardized primitive is not implemented.
- `implemented_unverified`: a complete callable API path exists, but official vectors have not been run in this environment.
- `implemented`: implementation is complete and locally validated.
- `verified_vectors`: official vector validation has passed.

ML-KEM is `implemented_unverified`; it passes local round-trip and tamper-rejection tests but has not passed official FIPS 203 vectors. ML-DSA, HQC, FN-DSA, and SLH-DSA are `partial`. ML-DSA-44/65/87 are deliberately non-callable until sign/verify interoperability and official vectors pass. Other catalog entries remain `catalog_only`; SIKE and Rainbow remain marked deprecated/broken.

## Pinned GGUF

The source retains the exact pinned model:

- Repository: `https://huggingface.co/tensorblock/llama3-small-GGUF/resolve/main/`
- File: `llama3-small-Q3_K_M.gguf`
- SHA-256: `8e4f4856fb84bafb895f1eb08e6c03e4be613ead2d942f91561aeac742a619aa`

## Build

This workspace contains a locally installed Zig 0.15.2 under `.tools/`, excluded from Git. Its archive was downloaded from `ziglang.org`, checked for path traversal, and verified against the official SHA-256 `02aa270f183da276e5b5920b1dac44a63f1a49e55050ebde3aecc9eb82f93239` before extraction.

```text
.tools/zig-0.15.2/zig build
.tools/zig-0.15.2/zig build test
.tools/zig-0.15.2/zig build run -- selftest
```

## Secure model download

The downloader accepts only HTTPS URLs on the pinned Hugging Face host allowlist, manually validates every redirect, refuses userinfo and non-443 ports, disables content encoding, enforces an 8 GiB streaming limit, writes a mode-0600 exclusive staging file, verifies the pinned SHA-256 in constant time, and publishes without overwriting an existing destination.

```text
.tools/zig-0.15.2/zig build run -- download models/llama3-small-Q3_K_M.gguf
```

The parent directory must already exist. Existing destinations are never overwritten.

## Terminal UI

Run `zig build run` from a real terminal to open the boxed, numbered NAZA TUI. The same interface can be selected explicitly with `zig build run -- tui`. It includes Model Manager, chat-prompt preview, road and food/water evidence prompts, GGUF inspection, the PQC catalog, hash tools, and self-test. The UI does not claim to have sensors or a loaded model when those runtime inputs are unavailable.

The suite includes SHA-3/SHAKE known-answer tests, RFC HMAC/HKDF vectors, authenticated-encryption tamper rejection, ML-KEM round-trip and implicit-rejection checks, downloader policy checks, and integer-overflow checks. These tests are not substitutes for official ML-KEM vectors or independent cryptographic review.

The repository also includes a GitHub Actions workflow that runs formatting checks, the build, the full test suite, and the runtime self-test with Zig 0.15.2.
