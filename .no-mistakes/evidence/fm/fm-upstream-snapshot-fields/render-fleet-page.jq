# Renders four fleet-page sections from the home summary using ONLY the
# structured fields this change added: ask{...}, title_plain, since_epoch,
# produces, open_url, project, restart{...}, counts.holds, omitted. No reason,
# name, title, or body prose is read.
def esc: tostring | gsub("&";"&amp;") | gsub("<";"&lt;") | gsub(">";"&gt;");
def link($u; $t): if $u == null then ($t|esc) else "<a href=\"\($u|esc)\">\($t|esc)</a>" end;
def since: if . == null then "" else (. | todate | .[0:10]) end;
def restart_label:
  if .kind == "after_work" then "after work: " + ((.blocker_ids // []) | join(", "))
  elif .kind == "date" then "on " + .until
  elif .kind == "captain_word" then "captain's word"
  elif .kind == "event" then "event" + (if .text then ": " + .text else "" end)
  elif .kind == "proposals" then "proposals"
  else "restart condition not recorded" + (if .text then " (" + .text + ")" else "" end) end;
(.decisions_open | map(select(.ask != null))) as $asks
| ([.omitted[] | select(.surface == "holds") | .count] | add // 0) as $holds_cut
| "<!doctype html><html><head><meta charset=utf-8><title>Fleet page - \(.home | esc)</title>
<style>
body{font:15px/1.45 system-ui,sans-serif;margin:0;padding:24px;background:#f6f7f9;color:#1b1f24;max-width:960px}
h1{font-size:20px;margin:0 0 4px}.sub{color:#5b6470;margin:0 0 20px;font-size:13px}
section{background:#fff;border:1px solid #d9dee5;border-radius:8px;padding:14px 18px;margin-bottom:16px}
h2{font-size:15px;margin:0 0 10px;display:flex;justify-content:space-between}
h2 .count{color:#5b6470;font-weight:normal;font-size:13px}
ul{margin:0;padding-left:18px}li{margin:4px 0}
.q{font-weight:600}.opt{display:inline-block;border:1px solid #c9d1da;border-radius:14px;padding:1px 10px;margin:4px 6px 0 0;font-size:13px}
.opt.rec{background:#1f6feb;color:#fff;border-color:#1f6feb}
.meta{color:#5b6470;font-size:13px}.tag{background:#eef1f5;border-radius:4px;padding:0 6px;font-size:12px;margin-left:6px}
.restart{color:#8a4b00;font-size:13px}.empty{color:#8b949e;font-style:italic}
</style></head><body>
<h1>Fleet page: \(.home | esc)</h1>
<p class=sub>Rendered from <code>\(.schema)</code> structured fields only (ask, title_plain, since_epoch, produces, open_url, project, restart). Generated \(.generated).</p>

<section><h2>Real asks <span class=count>\($asks | length) of \(.counts.decisions_open) open decisions carry a question (counts.asks = \(.counts.asks))</span></h2>
\(if ($asks|length) == 0 then "<p class=empty>No question is waiting for the captain.</p>" else
  "<ul>" + ($asks | map("<li><div class=q>\(.ask.question|esc)</div>"
    + (.ask.options | map("<span class=\"opt\(if .recommended then " rec" else "" end)\">\(.label|esc)</span>") | join(""))
    + (if .ask.free_text_allowed then "<span class=opt>free text</span>" else "" end)
    + "<div class=meta>\(.id|esc)" + (if .ask.link then " · " + link(.ask.link; "open link") else "" end) + "</div></li>") | join("")) + "</ul>" end)
</section>

<section><h2>Working <span class=count>\(.active_children|length)</span></h2><ul>
\(.active_children | map("<li>" + link(.open_url; .title_plain) + "<span class=tag>\(.kind)</span><span class=tag>→ \(.produces // "?")</span>"
  + "<div class=meta>since \(.since_epoch | since) · \(.doing|esc)</div></li>") | join(""))
</ul></section>

<section><h2>Landed <span class=count>\(.landed|length)</span></h2><ul>
\(.landed | map("<li>" + link(.open_url; .title_plain) + "<span class=tag>\(.project // "-")</span>"
  + (if .open_url == null then "<span class=meta> (no link recorded)</span>" else "" end) + "</li>") | join(""))
</ul></section>

<section><h2>Parked <span class=count>showing \(.holds|length) of \(.counts.holds)\(if $holds_cut > 0 then " (" + ($holds_cut|tostring) + " not listed)" else "" end)</span></h2><ul>
\(.holds | map("<li>\(.title_plain|esc)<span class=tag>\(.project // "-")</span><div class=restart>restarts: \(.restart | restart_label | esc)</div></li>") | join(""))
</ul></section>
</body></html>"
