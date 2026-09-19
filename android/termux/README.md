# Hardened Android / Termux install

Install Termux and the matching Termux:API companion from the same trusted
distribution, then run:

```sh
pkg install -y git
git clone https://github.com/ornab74/naza-zig.git
cd naza-zig/android/termux
bash install.sh
```

The installer uses the signed Termux `zig` package and fails closed unless Termux:API can create and inspect a
2048-bit RSA Android Keystore key with user authentication and secure-hardware
enforcement. It pins the source checkout to the requested ref, builds a
`ReleaseSafe` `aarch64-linux-android` binary, stores it under a mode-0700
directory, and launches only after a biometric prompt plus a Keystore-backed
nonce signature.

Do not bypass the biometric gate or set `NAZA_ZIG_SHA256` from an untrusted
source. The launcher does not claim that a device is secure if Android reports
software-only key enforcement.
