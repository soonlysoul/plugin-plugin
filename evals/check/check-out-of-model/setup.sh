#!/usr/bin/env bash
# A plugin built outside the model: its hook in shell form, under hooks/ instead of hooks/scripts/,
# its tests at the root of tests/.
set -euo pipefail
dir=plugin-meteo
repo=https://github.com/soonlysoul/$dir
mkdir -p "$dir/.claude-plugin" "$dir/hooks" "$dir/tests"
printf '{"name": "%s", "version": "0.1.0", "description": "Météo.", "author": {"name": "Soon"}, "homepage": "%s", "repository": "%s", "license": "MIT"}\n' "$dir" "$repo" "$repo" >"$dir/.claude-plugin/plugin.json"
printf '{"name": "%s", "owner": {"name": "Soon"}, "plugins": [{"name": "%s", "source": "./"}]}\n' "$dir" "$dir" >"$dir/.claude-plugin/marketplace.json"
printf '{"hooks": {"PreToolUse": [{"matcher": "Bash", "hooks": [{"type": "command", "command": "bash \\"${CLAUDE_PLUGIN_ROOT}/hooks/garde.sh\\"", "timeout": 10}]}]}}\n' >"$dir/hooks/hooks.json"
printf '#!/usr/bin/env bash\nexit 0\n' >"$dir/hooks/garde.sh"
printf '#!/usr/bin/env bash\necho ok\n' >"$dir/tests/test_garde.sh"
printf '# plugin-meteo\n' >"$dir/README.md"
git -C "$dir" init -q -b main
