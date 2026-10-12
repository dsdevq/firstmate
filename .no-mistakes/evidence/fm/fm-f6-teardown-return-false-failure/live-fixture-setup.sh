#!/usr/bin/env bash
# usage: setup.sh <mode: released|inuse|dirty> <dir>
set -euo pipefail
mode=$1 D=$2
ROOT=/home/denys/.no-mistakes/worktrees/24c36faa9cd1/01M4R0T0HHGRS1E4HPNMPP7BVY
mkdir -p "$D"/{state,config,data,fakebin,pool}
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
git init -q --bare "$D/origin.git"; git -C "$D/origin.git" symbolic-ref HEAD refs/heads/main
git clone -q "$D/origin.git" "$D/project" 2>/dev/null
git -C "$D/project" commit -q --allow-empty -m baseline
git -C "$D/project" branch -M main
git -C "$D/project" push -q origin main
git -C "$D/project" remote set-head origin main
export TREEHOUSE_ROOT="$D/pool"
cd "$D/project"
WT=$(treehouse get --lease --json --no-fetch --lease-holder fm-lab 2>/dev/null | jq -r '.path // .worktree_path // empty')
[ -n "$WT" ] || { treehouse get --lease --json --no-fetch --lease-holder fm-lab; exit 1; }
echo "$WT" > "$D/wt.path"
git -C "$WT" checkout -q -b fm/task-x1
git -C "$WT" commit -q --allow-empty -m "shippable work"
git -C "$WT" push -q origin fm/task-x1
git -C "$D/project" fetch -q origin
REALTH=$(command -v treehouse)
cat > "$D/fakebin/treehouse" <<SH
#!/usr/bin/env bash
# Forwards to the REAL treehouse; only \`return\` is made to report failure.
if [ "\${1:-}" = return ]; then
  echo "TH-SHIM return mode=$mode args: \$*" >> "$D/shim.log"
  case "$mode" in
    released) $REALTH "\$@" >/dev/null 2>&1 || true ;;
    dirty)    $REALTH "\$@" >/dev/null 2>&1 || true; echo junk > "\${@: -1}/leftover.txt" ;;
    inuse)    : ;;
  esac
  echo "error: treehouse return failed" >&2
  exit 1
fi
exec $REALTH "\$@"
SH
chmod +x "$D/fakebin/treehouse"
for t in tmux gh-axi gh no-mistakes; do printf '#!/usr/bin/env bash\ncase "${1:-} ${2:-}" in "pr list") printf "count: 0 (showing first 0)\\npull_requests[]: []\\n";; "pr view") exit 1;; esac\nexit 0\n' > "$D/fakebin/$t"; chmod +x "$D/fakebin/$t"; done
cat > "$D/meta" <<M
window=firstmate:fm-task-x1
endpoint_task_id=task-x1
worktree=$WT
project=$D/project
kind=ship
mode=no-mistakes
spawn_gen=teardown-test-task-x1
M
touch "$D/state/.last-watcher-beat"
echo "wt=$WT"
