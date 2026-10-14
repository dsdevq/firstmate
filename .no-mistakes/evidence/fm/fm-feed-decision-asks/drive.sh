#!/usr/bin/env bash
# Live drive: real fm-captain-hold.sh + real fm-home-summary-refresh.sh + real tasks-axi in a disposable home.
set -u
ROOT=/home/denys/.no-mistakes/worktrees/24c36faa9cd1/01M4VVSDFAYXY7K7MTRRJ3F6X7
. "$ROOT/tests/lib.sh"
H=$(mktemp -d "${TMPDIR:-/tmp}/fm-ask-live.XXXXXX"); trap 'rm -rf "$H"' EXIT
mkdir -p "$H/data" "$H/state" "$H/config" "$H/projects"
fm_test_tasks_toml "$H/.tasks.toml"
printf '## In flight\n\n## Queued\n\n## Done\n' > "$H/data/backlog.md"
fb=$(fm_fakebin "$H"); fm_fake_exit0 "$fb" tmux treehouse no-mistakes gh gh-axi
E() { PATH="$H/fakebin:$PATH" FM_HOME="$H" FM_STATE_OVERRIDE="$H/state" FM_DATA_OVERRIDE="$H/data" FM_CONFIG_OVERRIDE="$H/config" FM_PROJECTS_OVERRIDE="$H/projects" "$@"; }
hold() { E "$ROOT/bin/fm-captain-hold.sh" "$@"; }
pub() { E "$ROOT/bin/fm-home-summary-refresh.sh" >/dev/null && jq -c '{decisions_open:[.decisions_open[]|{id,summary,reason,ask}],omitted}' "$H/state/home-summary.json"; }
echo "### 1 hold with ask (options incl. text the dropped filter used to refuse)"
cat > "$H/ask.json" <<J
{"question":" Which export format? ","options":[{"label":"CSV"},{"label":"Spreadsheet","id":"sheet"},{"label":"JSON","recommended":true},{"label":"Budget 2000000"},{"label":"Use GPT-4"}],"free_text_allowed":true,"link":"https://example.test/board"}
J
hold hold pick-format --title "Pick the export format" --reason "format pending" --repo sample --ask-file "$H/ask.json"; echo "rc=$?"
echo "### 2 hold without ask"
hold hold pick-name --title "Pick the release name" --reason "name pending" --repo sample; echo "rc=$?"
pub
echo "### 3 malformed asks refused, nothing stored"
for bad in '{"options":[{"label":"x"}]}' '{"question":"q","options":[{"label":"a","recommended":true},{"label":"b","recommended":true}]}' '{"question":"q","link":"javascript:alert(1)"}' '{"question":"q","options":[{"label":"1"},{"label":"2"},{"label":"3"},{"label":"4"},{"label":"5"},{"label":"6"},{"label":"7"}]}'; do
  echo "$bad" > "$H/bad.json"; hold hold bad-one --title Bad --reason r --repo sample --ask-file "$H/bad.json"; echo "rc=$?"; done
ls "$H/data/captain-asks"
echo "### 4 ask subcommand is gone"
hold ask pick-format --ask-file "$H/ask.json" 2>&1 | head -3; echo "rc=${PIPESTATUS[0]}"
echo "### 5 re-hold with new ask replaces; re-hold w/o keeps"
echo '{"question":"Which?","options":[{"label":"A"},{"label":"B","recommended":true}]}' > "$H/ask2.json"
hold hold pick-format --reason "format pending" --ask-file "$H/ask2.json"; pub | jq -c '.decisions_open[]|select(.id=="pick-format")|.ask'
hold hold pick-format --reason "format pending"; pub | jq -c '.decisions_open[]|select(.id=="pick-format")|.ask'
echo "### 6 tampered record withheld + disclosed"
jq '.ask.options[0].recommended="yes"' "$H/data/captain-asks/pick-format.json" > "$H/t.json" && mv "$H/t.json" "$H/data/captain-asks/pick-format.json"
pub
echo "### 7 answer removes ask"
echo "Use B." > "$H/dec.txt"
hold answer pick-format --decision-file "$H/dec.txt" --release; echo "rc=$?"
ls "$H/data/captain-asks"; pub
