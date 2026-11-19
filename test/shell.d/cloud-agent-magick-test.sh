#!/bin/bash

set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"
require_command convert
require_command identify
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
wrapper="$ROOT/.cursor/magick"
bash "$wrapper" -size 3x2 xc:red "$work/a picture.png"
[[ $(bash "$wrapper" identify -format '%wx%h' "$work/a picture.png") == "3x2" ]] || fail "the ImageMagick 6 bridge dispatches identify"
bash "$wrapper" convert "$work/a picture.png" -resize 1x1! "$work/small.png"
[[ $(identify -format '%wx%h' "$work/small.png") == "1x1" ]] || fail "the bridge dispatches convert"
printf 'not an image\n' >"$work/bad.png"
if bash "$wrapper" identify "$work/bad.png" >/dev/null 2>&1; then
  fail "the bridge preserves identify failures"
fi
pass "the ImageMagick 6 bridge handles conversion, identify and failures"
