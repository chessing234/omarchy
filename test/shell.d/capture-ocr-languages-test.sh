#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT
export HOME="$test_tmp/home" XDG_CONFIG_HOME="$test_tmp/config" OMARCHY_PATH="$ROOT"
export OMARCHY_TESSDATA="$test_tmp/tessdata"
mkdir -p "$test_tmp/bin" "$OMARCHY_TESSDATA" "$HOME"
export PATH="$test_tmp/bin:$ROOT/bin:$PATH"

export GUM_OPTIONS="$test_tmp/gum-options"

cat >"$test_tmp/bin/gum" <<'SH'
#!/bin/bash
cat > "$GUM_OPTIONS"
printf '%s\n' "$GUM_CHOICE"
SH
cat >"$test_tmp/bin/pacman" <<'SH'
#!/bin/bash
[[ $1 == "-Slq" ]] && printf '%s\n' ${PACMAN_PACKAGES:-}
SH
cat >"$test_tmp/bin/omarchy-pkg-add" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$PKG_ADDED"
exit "${PKG_ADD_EXIT:-0}"
SH
chmod +x "$test_tmp/bin/"*
export PKG_ADDED="$test_tmp/pkg-added"

[[ $(omarchy-capture-ocr-languages) == "eng" ]] || fail "capture text defaults to English"
pass "capture text defaults to English"

omarchy-capture-ocr-languages eng+chi_sim >/dev/null
[[ $(omarchy-capture-ocr-languages) == "eng+chi_sim" ]] || fail "a saved language list is what capture text will use"
pass "a saved language list is what capture text will use"

if omarchy-capture-ocr-languages 'eng;rm' >/dev/null 2>&1; then
  fail "a language list cannot carry a shell command"
fi
[[ $(omarchy-capture-ocr-languages) == "eng+chi_sim" ]] || fail "a rejected language list leaves the saved one in place"
pass "a language list cannot carry a shell command"

printf 'not langs\n' >"$XDG_CONFIG_HOME/omarchy/ocr-languages"
[[ $(omarchy-capture-ocr-languages) == "eng" ]] || fail "a broken language file falls back to English"
pass "a broken language file falls back to English"

for name in eng swe osd; do
  printf 'x\n' >"$OMARCHY_TESSDATA/$name.traineddata"
done
GUM_CHOICE=$'swe\neng' omarchy-capture-ocr-languages choose >/dev/null
[[ $(cat "$GUM_OPTIONS") == $'eng\nswe' ]] || fail "the picker offers installed languages without osd"
[[ $(omarchy-capture-ocr-languages) == "swe+eng" ]] || fail "the picker saves the languages it was given and skips osd"
pass "the picker saves the languages it was given and skips osd"
[[ ! -e $PKG_ADDED ]] || fail "choosing installed languages installs nothing"
pass "choosing installed languages installs nothing"

export PACMAN_PACKAGES="tesseract tesseract-data-eng tesseract-data-jpn tesseract-data-osd tesseract-data-chi_sim"
GUM_CHOICE=$'jpn\neng' omarchy-capture-ocr-languages choose >/dev/null
[[ $(cat "$GUM_OPTIONS") == $'eng\nswe\nchi_sim\njpn' ]] || fail "the picker also offers languages it can install, once each and after the installed ones"
pass "the picker also offers languages it can install, once each and after the installed ones"
[[ $(cat "$PKG_ADDED") == "tesseract-data-jpn" ]] || fail "the picker installs only the chosen languages that are missing"
[[ $(omarchy-capture-ocr-languages) == "jpn+eng" ]] || fail "an installed language is saved in the order it was chosen"
pass "the picker installs the missing language it was given and saves it"

if PKG_ADD_EXIT=1 GUM_CHOICE="chi_sim" omarchy-capture-ocr-languages choose >/dev/null 2>&1; then
  fail "a failed install is reported"
fi
[[ $(omarchy-capture-ocr-languages) == "jpn+eng" ]] || fail "a failed install leaves the saved languages in place"
pass "a failed install leaves the saved languages in place"
