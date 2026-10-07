#!/usr/bin/env bash
# Demo: relaunch a task with an armed PR poll (trace context on/off) and show the
# task record tail plus the poll's verdict. Reuses the hermetic harness helpers
# from tests/fm-control-relaunch.test.sh (everything before its test invocations).
cd "$1"
eval "$(sed -n "1,2492p" tests/fm-control-relaunch.test.sh | sed "s#^\. \"\$(dirname \"\${BASH_SOURCE\[0\]}\")/lib.sh\"#. tests/lib.sh#")"
demo() { # <id> <trace on|off>
  local id=$1 trace=$2 dir head=0123456789abcdef0123456789abcdef01234567 poll="$ROOT/bin/fm-pr-poll.sh" out rc
  dir=$(new_case demo-$trace "$id"); add_ship_task "$dir" "$id" claude
  if [ "$trace" = on ]; then
    printf '%s\n' "$$" > "$dir/home/state/.lock"
    printf '%s on\n' "$$" > "$dir/home/state/.trace-context-effective"
  fi
  printf 'pr=https://github.com/example/repo/pull/76\npr_head=%s\n' "$head" >> "$dir/home/state/$id.meta"
  fm_pr_poll_prepare "$dir/home/state" "$id" github https://github.com/example/repo/pull/76 github.com example/repo 76 "$poll" >/dev/null
  fm_pr_poll_publish_prepared
  echo "=== trace context: $trace ==="
  echo "--- $id.meta tail BEFORE relaunch ---"; tail -n 4 "$dir/home/state/$id.meta"
  fm_pr_poll_artifacts_valid "$dir/home/state" "$id" "$poll" && echo "poll verdict: AUTHENTICATES" || echo "poll verdict: REFUSED"
  out=$(run_control "$dir" "$id" relaunch --note "continue with the PR open"); rc=$?
  echo "\$ fm-control.sh $id relaunch --note 'continue with the PR open'  -> exit $rc"
  echo "--- $id.meta tail AFTER relaunch ---"; tail -n 4 "$dir/home/state/$id.meta"
  fm_pr_metadata_identity_parse "$dir/home/state/$id.meta" && echo "fm_pr_metadata_identity_parse: OK ($FM_PR_META_URL)" || echo "fm_pr_metadata_identity_parse: REJECTED"
  fm_pr_poll_artifacts_valid "$dir/home/state" "$id" "$poll" && echo "poll verdict: AUTHENTICATES" || echo "poll verdict: REFUSED (watcher would refuse the merge poll)"
  echo
}
demo rd1 off
demo rd2 on
