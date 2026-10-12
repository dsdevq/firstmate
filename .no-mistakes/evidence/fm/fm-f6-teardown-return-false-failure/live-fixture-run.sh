#!/usr/bin/env bash
# usage: run.sh <mode>
mode=$1; D=/tmp/f6lab/case-${TAG:-fix}-$mode
ROOT=${ROOT_OVERRIDE:-/home/denys/.no-mistakes/worktrees/24c36faa9cd1/01M4R0T0HHGRS1E4HPNMPP7BVY}
rm -rf "$D"; /tmp/f6lab/setup.sh "$mode" "$D" || exit 99
cp "$D/meta" "$D/state/task-x1.meta"
WT=$(cat "$D/wt.path")
echo "--- pool BEFORE teardown"; (cd "$D/project" && TREEHOUSE_ROOT="$D/pool" treehouse status --json 2>/dev/null) | jq -c '.[]|{path,status,lease_id}'
echo "--- teardown (mode=$mode)"
env -u NO_MISTAKES_GATE FM_GATE_REFUSE_BYPASS=1 FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$D/state" FM_DATA_OVERRIDE="$D/data" FM_CONFIG_OVERRIDE="$D/config" \
  TREEHOUSE_ROOT="$D/pool" PATH="$D/fakebin:$PATH" "$ROOT/bin/fm-teardown.sh" task-x1 > "$D/stdout" 2> "$D/stderr"
rc=$?
echo "exit=$rc"; echo "--- stderr"; cat "$D/stderr"; echo "--- stdout"; cat "$D/stdout"
echo "--- shim.log"; cat "$D/shim.log"
echo "--- meta present?"; ls "$D/state/task-x1.meta" 2>&1
echo "--- pool AFTER teardown"; (cd "$D/project" && TREEHOUSE_ROOT="$D/pool" treehouse status --json 2>/dev/null) | jq -c '.[]|{path,status,lease_id}'
echo "--- wt status"; git -C "$WT" status --porcelain --untracked-files=all 2>&1 | head
