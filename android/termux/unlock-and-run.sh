#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
umask 077
ROOT="${NAZA_ROOT:-$HOME/.local/share/naza-zig}"
KEY_ALIAS="${NAZA_KEYSTORE_ALIAS:-naza-zig-unlock}"
BIN="$ROOT/bin/naza-zig"
[ -x "$BIN" ] || { echo 'Naza is not installed' >&2; exit 1; }
command -v termux-fingerprint >/dev/null || { echo 'Termux:API fingerprint unavailable' >&2; exit 1; }
command -v termux-keystore >/dev/null || { echo 'Termux:API keystore unavailable' >&2; exit 1; }
printf 'Authenticate to unlock Naza...\n'
result="$(termux-fingerprint -d 'Unlock Naza')"
printf '%s\n' "$result" | grep -q 'AUTH_RESULT: AUTH_RESULT_SUCCESS' || { echo 'Authentication failed' >&2; exit 1; }
nonce="$(od -An -N32 -tx1 /dev/urandom | tr -d ' \n')"
printf '%s' "$nonce" | termux-keystore sign "$KEY_ALIAS" RSA >/dev/null || { echo 'Keystore challenge failed' >&2; exit 1; }
exec "$BIN" "$@"
