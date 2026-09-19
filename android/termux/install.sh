#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
umask 077

APP_NAME="naza-zig"
KEY_ALIAS="${NAZA_KEYSTORE_ALIAS:-naza-zig-unlock}"
REPO_URL="${NAZA_REPO_URL:-https://github.com/ornab74/naza-zig.git}"
REF="${NAZA_REF:-main}"
ROOT="${NAZA_ROOT:-$HOME/.local/share/$APP_NAME}"
BIN="$ROOT/bin/$APP_NAME"

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
[[ "$KEY_ALIAS" =~ ^[A-Za-z0-9._-]{1,64}$ ]] || fail "invalid keystore alias"
[[ "$REPO_URL" =~ ^https://github\.com/[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] || fail "NAZA_REPO_URL must be an HTTPS GitHub repository URL"
[[ "$REF" =~ ^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$ && "$REF" != *..* && "$REF" != *//* ]] || fail "invalid NAZA_REF"

pkg update -y
pkg install -y git curl coreutils termux-api clang lld make zig
command -v termux-keystore >/dev/null || fail "Termux:API keystore unavailable"

printf '%s\n' 'Checking Android keystore...'
if ! termux-keystore list 2>/dev/null | grep -Fq "$KEY_ALIAS"; then
  termux-keystore generate "$KEY_ALIAS" -a RSA -s 2048 -u 10 || fail "keystore key generation failed"
fi
DETAIL="$(termux-keystore list -d 2>/dev/null)" || fail "cannot inspect keystore"
printf '%s\n' "$DETAIL" | grep -Eq '"alias"[[:space:]]*:[[:space:]]*"'"$KEY_ALIAS"'"' || fail "keystore alias not found"
printf '%s\n' "$DETAIL" | grep -Eq '"algorithm"[[:space:]]*:[[:space:]]*"RSA"' || fail "keystore key is not RSA"
printf '%s\n' "$DETAIL" | grep -Eq '"size"[[:space:]]*:[[:space:]]*2048' || fail "keystore key is not 2048-bit"
printf '%s\n' "$DETAIL" | grep -Eq '"required"[[:space:]]*:[[:space:]]*true' || fail "keystore key is not user-authenticated"
printf '%s\n' "$DETAIL" | grep -Eq '"enforced_by_secure_hardware"[[:space:]]*:[[:space:]]*true' || fail "keystore key is not hardware enforced"

mkdir -p "$ROOT/src" "$ROOT/bin" "$ROOT/data"
chmod 700 "$ROOT" "$ROOT/src" "$ROOT/bin" "$ROOT/data"
if [ -d "$ROOT/src/.git" ]; then
  [ "$(git -C "$ROOT/src" remote get-url origin)" = "$REPO_URL" ] || fail "existing checkout origin mismatch"
  git -C "$ROOT/src" fetch --depth=1 origin "$REF"
else
  git clone --depth=1 --branch "$REF" "$REPO_URL" "$ROOT/src"
fi
git -C "$ROOT/src" checkout --detach FETCH_HEAD

ZIG="${NAZA_ZIG:-$(command -v zig || true)}"
[ -n "$ZIG" ] && [ -x "$ZIG" ] || fail "Termux zig package is unavailable"

ZIG_GLOBAL_CACHE_DIR="$ROOT/zig-cache" "$ZIG" build -Dtarget=aarch64-linux-android -Doptimize=ReleaseSafe -Dnative-cpu=false \
  --prefix "$ROOT/stage"
install -m 700 "$ROOT/stage/bin/$APP_NAME" "$BIN"
rm -rf "$ROOT/stage"
install -m 700 "$(dirname "$0")/unlock-and-run.sh" "$ROOT/unlock-and-run.sh"

PROFILE="$HOME/.bashrc"
grep -qF "$ROOT/unlock-and-run.sh" "$PROFILE" 2>/dev/null || \
  printf '\n# Naza Zig hardened launcher\nalias naza=%q\n' "$ROOT/unlock-and-run.sh tui" >> "$PROFILE"
printf 'Installed %s. Reopen Termux, then run: naza\n' "$APP_NAME"
