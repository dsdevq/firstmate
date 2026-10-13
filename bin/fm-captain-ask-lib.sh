# shellcheck shell=bash
# Shared structured-ask rule for captain-held decisions.
# Usage: . bin/fm-captain-ask-lib.sh; splice "$FM_CAPTAIN_ASK_JQ_DEFS" ahead of
# a jq program, then call `captain_ask_problems` or `captain_ask_normalize`.
#
# ONE OWNER for what a stored captain ask may contain. bin/fm-captain-hold.sh
# validates and normalizes an ask before it stores one, bin/fm-fleet-snapshot.sh
# re-validates every stored ask before it publishes it as decisions_open[].ask,
# and bin/fm-home-summary-refresh.sh refuses a summary whose ask breaks the rule.
# All three answer the one question "may the dashboard render this ask", so the
# rule lives here and none of them restates it.
#
# The shape is the dashboard's FleetAsk:
#   {question, options?: [{id?, label, recommended?}], free_text_allowed?, link?}
# The field limits and the forbidden captain-facing text mirror the decision
# contract that lifekit-stack's notify-relay enforces: a question of at most
# 200 characters, at most 6 options with labels of at most 120 characters, at
# most one recommended option, option ids that are unique slugs, and no task or
# issue id, branch name, hash, status prefix, or status stamp in the question
# or any label. Unknown fields are rejected rather than passed through.
#
# `captain_ask_problems` returns an array of plain-English problems, empty for a
# valid ask. `captain_ask_normalize` takes a valid ask and returns the stored
# form: trimmed text, every option given an explicit id (its 1-based position
# when absent), label, and recommended flag, the recommended option first, and
# explicit free_text_allowed and link values.

# shellcheck disable=SC2034 # consumed by the scripts that source this library
FM_CAPTAIN_ASK_JQ_DEFS='
def captain_ask_trim: sub("^\\s+"; "") | sub("\\s+$"; "");
def captain_ask_forbidden_text:
  test("\\b[A-Za-z]+-\\d+\\b")
  or test("\\b(?:fm|fix|feat|chore|docs|refactor)/[\\w.-]+"; "i")
  or test("\\b[0-9a-f]{7,}\\b"; "i")
  or test("^\\s*(?:status|state|working|blocked|done|failed|paused|needs[- ]decision)\\s*[:\\-\\]]"; "i")
  or test("\\[at=\\d+\\]"; "i");
def captain_ask_text_problems($name; $max):
  if type != "string" then ["\($name) must be text"]
  else captain_ask_trim as $t
    | if ($t | length) == 0 then ["\($name) must not be empty"]
      elif ($t | length) > $max then ["\($name) must be at most \($max) characters"]
      elif ($t | captain_ask_forbidden_text) then
        ["\($name) must not carry a task or issue id, branch name, hash, or status prefix"]
      else [] end
  end;
def captain_ask_option_problems($n):
  if type != "object" then ["option \($n) must be an object"]
  else
    [keys[] | select(IN("id", "label", "recommended") | not) | "option \($n) has unknown field \(.)"]
    + (if has("label") then (.label | captain_ask_text_problems("option \($n) label"; 120))
       else ["option \($n) needs a label"] end)
    + (if has("id") and ((.id | type) != "string"
          or (.id | test("^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$") | not))
       then ["option \($n) id must be a slug of at most 64 characters"] else [] end)
    + (if has("recommended") and ((.recommended | type) != "boolean")
       then ["option \($n) recommended must be true or false"] else [] end)
  end;
def captain_ask_options_problems:
  if type != "array" then ["options must be a list"]
  elif length > 6 then ["at most 6 options are allowed"]
  else
    ([to_entries[] | .key as $i | .value | captain_ask_option_problems($i + 1)] | add // [])
    + (if ([.[] | select(type == "object" and .recommended == true)] | length) > 1
       then ["at most one option may be recommended"] else [] end)
    + ([to_entries[] | select(.value | type == "object")
        | (.value.id // (.key + 1 | tostring))]
       | if length != (unique | length) then ["option ids must be unique"] else [] end)
  end;
def captain_ask_problems:
  if type != "object" then ["the ask must be a JSON object"]
  else
    [keys[] | select(IN("question", "options", "free_text_allowed", "link") | not) | "unknown ask field \(.)"]
    + (if has("question") then (.question | captain_ask_text_problems("question"; 200))
       else ["question is required"] end)
    + (if has("options") then (.options | captain_ask_options_problems) else [] end)
    + (if has("free_text_allowed") and ((.free_text_allowed | type) != "boolean")
       then ["free_text_allowed must be true or false"] else [] end)
    + (if (.link // null) == null then []
       elif (.link | type) == "string" and (.link | length) <= 2048
         and (.link | test("^https?://[^\\s]+$")) then []
       else ["link must be an http or https URL"] end)
  end;
def captain_ask_valid: captain_ask_problems | length == 0;
def captain_ask_normalize:
  { question: (.question | captain_ask_trim),
    options: ([(.options // []) | to_entries[]
               | { id: (.value.id // (.key + 1 | tostring)),
                   label: (.value.label | captain_ask_trim),
                   recommended: (.value.recommended == true) }]
              | map(select(.recommended)) + map(select(.recommended | not))),
    free_text_allowed: (.free_text_allowed == true),
    link: (.link // null) };
'
