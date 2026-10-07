#!/usr/bin/env bash
# End-to-end evidence: a captain hold recorded with --ask-file through the real
# hold command, plus working/landed/parked rows, read back by
# fm-fleet-snapshot.sh --secondmate-home-summary as the four fleet-page sections.
set -u
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../worktrees/143d8a14096c/01M4AKRE51GXJRMQG8BFYJ78M8" && pwd)
. "$ROOT/tests/lib.sh"
TMP_ROOT=$(fm_test_tmproot fm-evidence-page)
TASKS_AXI_BIN=$(command -v tasks-axi)
home=$TMP_ROOT/home
mkdir -p "$home/data" "$home/state" "$home/config" "$home/projects/ship-wt" "$home/projects/scout-wt" "$home/projects/paused-wt"
cp "$ROOT/.tasks.toml" "$home/.tasks.toml"
cat > "$home/data/backlog.md" <<'EOF'
## In flight

## Queued

## Done
EOF
fakebin=$(fm_fakebin "$home")
fm_fake_exit0 "$fakebin" tmux treehouse no-mistakes gh gh-axi
cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
case "${1:-}" in
  list-windows) sed -n 's/^window=[^:]*://p' "${FM_HOME:?}"/state/*.meta ;;
  display-message) case "$*" in *pane_current_command*) printf 'claude\n' ;; *) printf '%%1\n' ;; esac ;;
  capture-pane) printf 'work in progress\n' ;;
esac
exit 0
SH
chmod +x "$fakebin/tmux"
captain() { PATH="$fakebin:$PATH" REAL_TASKS_AXI="$TASKS_AXI_BIN" FM_HOME="$home" FM_STATE_OVERRIDE="$home/state" \
  FM_DATA_OVERRIDE="$home/data" FM_CONFIG_OVERRIDE="$home/config" "$ROOT/bin/fm-captain-hold.sh" "$@"; }
summary() { PATH="$fakebin:$PATH" FM_HOME="$home" FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
  FM_CONFIG_OVERRIDE="$home/config" FM_PROJECTS_OVERRIDE="$home/projects" FM_SNAPSHOT_NOW=2026-10-07T12:00:00Z \
  "$ROOT/bin/fm-fleet-snapshot.sh" "$@"; }
step() { printf '\n$ %s\n' "$*"; }

cat > "$home/ask.json" <<'EOF'
{"question":"Which export format ships first?","options":[{"id":"csv","label":"CSV","recommended":false},{"id":"json","label":"JSON","recommended":true}],"free_text_allowed":true,"link":"https://board.example/session/b1"}
EOF
step "cat ask.json"; cat "$home/ask.json"
step "fm-captain-hold.sh hold export-format --title 'Choose the export format' --repo alpha --reason 'captain picks the format' --ask-file ask.json"
captain hold export-format --title "Choose the export format" --repo alpha --reason "captain picks the format" --ask-file "$home/ask.json"; echo "exit=$?"
step "fm-captain-hold.sh hold route-call --title 'Which route should we take?' --repo alpha --reason 'Pick A or B - recommended A'   # live hold, NO ask file"
captain hold route-call --title "Which route should we take?" --repo alpha --reason "Pick A or B - recommended A"; echo "exit=$?"
step "fm-captain-hold.sh hold revisit-later --title 'Revisit the export later' --repo alpha --reason 'revisit later' --until 2026-12-01 --ask-file ask.json   # dated hold"
captain hold revisit-later --title "Revisit the export later" --repo alpha --reason "revisit later" --until 2026-12-01 --ask-file "$home/ask.json"; echo "exit=$?"
printf '%s\n' '{"question":"Re-check?","options":[{"id":"reconcile","label":"Re-check","recommended":false}],"free_text_allowed":false}' > "$home/bad.json"
step "fm-captain-hold.sh hold bad-ask --title 'Bad ask' --repo alpha --reason 'bad' --ask-file bad.json   # reserved option id 'reconcile'"
captain hold bad-ask --title "Bad ask" --repo alpha --reason "bad" --ask-file "$home/bad.json"; echo "exit=$?"

step "tasks-axi show export-format --full   # the stored structured line"
(cd "$home" && tasks-axi show export-format --full)

# Working, landed, and other parked rows beside the captain holds.
python3 - "$home/data/backlog.md" <<'PY'
import sys,re
p=sys.argv[1]; s=open(p).read()
s=s.replace("## In flight\n","## In flight\n- [ ] ship-a - feat(api): ship-a Export widget for the dashboard page https://github.com/o/alpha/issues/12 (repo: alpha) (kind: ship) (since 2026-10-01)\n- [ ] scout-b - SCOUT alpha: investigate the flaky upload path (repo: alpha) (kind: scout) (since 2026-10-02)\n- [ ] paused-d - fix: Wire the widget into the page blocked-by: ship-a (repo: alpha) (kind: ship) (since 2026-10-03)\n",1)
s=s.replace("## Queued\n","## Queued\n- [ ] vendor-hold - Vendor reply needed (repo: alpha) (kind: ship) (hold: vendor replies) (hold-kind: external)\n- [ ] after-hold - Follow-up after the widget blocked-by: ship-a (repo: alpha) (kind: ship)\n- [ ] parked-hold - Parked idea (repo: alpha) (kind: ship) (hold: later maybe) (hold-kind: parked)\n",1)
s=s.replace("## Done\n","## Done\n- [x] done-pr - chore(ci): done-pr Speed up the lint lane https://github.com/o/alpha/pull/7 (repo: alpha) (kind: ship) (merged 2026-10-05)\n- [x] done-scout - Scout the cache data/done-scout/report.md (repo: alpha) (kind: scout) (reported 2026-10-04)\n",1)
open(p,"w").write(s)
PY
fm_write_meta "$home/state/ship-a.meta" "window=firstmate:fm-ship-a" "worktree=$home/projects/ship-wt" "project=alpha" "harness=claude" "kind=ship" "mode=no-mistakes" "yolo=off" "spawn_gen=s1790000000.11.22"
gen=$("$ROOT/bin/fm-busy-event.sh" arm "$home/state" ship-a); "$ROOT/bin/fm-busy-event.sh" apply "$home/state" ship-a busy --gen "$gen" --source claude-hook --event user-prompt-submit
fm_write_meta "$home/state/scout-b.meta" "window=firstmate:fm-scout-b" "worktree=$home/projects/scout-wt" "project=alpha" "harness=claude" "kind=scout"
gen=$("$ROOT/bin/fm-busy-event.sh" arm "$home/state" scout-b); "$ROOT/bin/fm-busy-event.sh" apply "$home/state" scout-b busy --gen "$gen" --source claude-hook --event user-prompt-submit
fm_write_meta "$home/state/paused-d.meta" "window=firstmate:fm-paused-d" "worktree=$home/projects/paused-wt" "project=alpha" "harness=claude" "kind=ship" "mode=no-mistakes" "yolo=off"
gen=$("$ROOT/bin/fm-busy-event.sh" arm "$home/state" paused-d); "$ROOT/bin/fm-busy-event.sh" apply "$home/state" paused-d idle --gen "$gen" --source claude-hook --event stop
printf 'paused: waiting for ship-a to land\n' > "$home/state/paused-d.status"

step "cat data/backlog.md"; cat "$home/data/backlog.md"

out=$(summary --secondmate-home-summary) || { echo "summary failed"; exit 1; }
step "fm-fleet-snapshot.sh --secondmate-home-summary | jq '{schema, counts}'"
printf '%s' "$out" | jq '{schema, hold_classifier_schema, counts}'
step "... | jq '.decisions_open'   # REAL ASKS: ask present only where the captain's answer restarts the work"
printf '%s' "$out" | jq '.decisions_open | map({id, hold_bucket, reason, ask})'
step "... | jq '.active_children'   # WORKING"
printf '%s' "$out" | jq '.active_children | map({id, kind, name, title_plain, since_epoch, produces, open_url, doing})'
step "... | jq '.landed'   # LANDED"
printf '%s' "$out" | jq '.landed | map({id, project, title_plain, open_url, pr_url, report_path, completion})'
step "... | jq '.holds'   # PARKED, restart decided only from structured fields"
printf '%s' "$out" | jq '.holds | map({id, source, project, title_plain, restart, unresolved_blocker_ids})'
step "FM_SNAPSHOT_SECONDMATE_QUEUED=2 fm-fleet-snapshot.sh --secondmate-home-summary | jq '{holds:(.holds|length), total:.counts.holds, omitted}'   # capped list discloses its real total"
FM_SNAPSHOT_SECONDMATE_QUEUED=2 summary --secondmate-home-summary | jq '{holds_listed:(.holds|length), counts_holds:.counts.holds, omitted}'
step "fm-fleet-snapshot.sh --json | jq '{schema, asks:[.backlog.records[]|select(.ask!=null)|{id,hold_bucket,ask:.ask.question}]}'"
summary --json | jq '{schema, backlog_asks:[.backlog.records[]|select(.ask!=null)|{id,hold_bucket,question:.ask.question}]}'
