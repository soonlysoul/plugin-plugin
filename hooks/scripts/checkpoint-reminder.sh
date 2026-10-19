#!/usr/bin/env bash
# checkpoint-reminder — Stop hook.
# When <project>/.plugin-plugin/checkpoint.md is older than the last commit or than an
# uncommitted change outside .plugin-plugin/, asks Claude once to update it, through
# hookSpecificOutput.additionalContext. Inert without a checkpoint or when stop_hook_active is
# true. Never fails: every problem ends silently with exit 0 (onFailure has no effect on Stop).

command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0
IFS= read -r -d '' input || true
active=$(jq -r '.stop_hook_active // false' <<<"$input" 2>/dev/null) || exit 0
[[ $active == false ]] || exit 0
root=${CLAUDE_PROJECT_DIR:-$(jq -r '.cwd // "" | strings' <<<"$input" 2>/dev/null)}
checkpoint="$root/.plugin-plugin/checkpoint.md"
[[ -n $root && -f $checkpoint ]] || exit 0
git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null; }

reason=""
commit_time=$(git -C "$root" log -1 --format=%ct 2>/dev/null)
checkpoint_time=$(mtime "$checkpoint")
if [[ -n $commit_time && -n $checkpoint_time ]] && ((commit_time > checkpoint_time)); then
  reason="le dernier commit ($(git -C "$root" log -1 --format=%h)) est plus récent"
else
  while IFS= read -r -d '' entry; do
    status=${entry:0:2} path=${entry:3}
    # A rename or copy is followed by its original path.
    if [[ $status == R* || $status == C* ]]; then IFS= read -r -d '' _; fi
    [[ $path != .plugin-plugin/* ]] || continue
    # Files only: a directory's date moves when an entry inside it is renamed.
    if [[ -f $root/$path && $root/$path -nt $checkpoint ]]; then
      reason="un changement non commité est plus récent (par exemple $path)"
      break
    fi
  done < <(git -C "$root" --no-optional-locks status --porcelain -z --untracked-files=all 2>/dev/null)
fi
[[ -n $reason ]] || exit 0

message="plugin-plugin : .plugin-plugin/checkpoint.md est périmé : $reason. Mets-le à jour maintenant (pp.sh checkpoint … done N --command … --exit …) avec les étapes faites, puis arrête-toi sans commencer autre chose."
jq -nc --arg m "$message" '{hookSpecificOutput: {hookEventName: "Stop", additionalContext: $m}}'
exit 0
