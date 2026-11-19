#!/bin/bash

set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/omarchy/shell/plugins/agents/assets"
printf '<svg viewBox="0 0 16 16"><rect width="16" height="16"/></svg>\n' >"$work/omarchy/shell/plugins/agents/assets/local.svg"
cat >"$work/bin/omarchy-agent-local" <<'SH'
#!/bin/bash
printf '%s\n' '{"models":{"song":{"name":"","vendor":"","kind":"music"},"coder":{"name":"","vendor":"","kind":"text"}}}'
SH
chmod +x "$work/bin/omarchy-agent-local"
HOME="$work/home" OMARCHY_PATH="$work/omarchy" PATH="$work/bin:$PATH" bash "$ROOT/bin/omarchy-agent-local-launchers"
apps="$work/home/.local/share/applications"
grep -Fxq 'Exec=fantasi open --model song' "$apps/omarchy-agent-local-song.desktop" || fail "a blank display name changes the media launcher's kind"
grep -Fxq 'Name=song' "$apps/omarchy-agent-local-song.desktop" || fail "a blank display name falls back to its recipe"
grep -Fxq 'Name=coder' "$apps/omarchy-agent-local-coder.desktop" || fail "a blank coding model name falls back to its recipe"
pass "blank model names and vendors preserve recipe identity and media kind"
