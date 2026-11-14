"""Render Cove's actual download card and progress text into a local preview.

python3 prototypes/download-card/build.py /path/to/files.json /path/to/output
JSON: [{"name": "Example.dmg", "bytes": 258000000}]
Keep personal filenames and generated previews outside Git.
"""
import html
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
metadata, output = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
output.mkdir(parents=True, exist_ok=True)
samples = json.loads(metadata.read_text())
source = (ROOT / 'Cove/Sources/Library/DownloadFeedback.swift').read_text()
factory = output / 'DownloadFlightCard.swift'
factory.write_text('import AppKit\nimport QuartzCore\n' + source[source.index('@MainActor\nenum DownloadFlightCard'):])
subprocess.run(['swiftc', '-parse-as-library', str(factory),
    str(ROOT / 'Cove/Sources/Library/DownloadProgressText.swift'),
    str(ROOT / 'prototypes/download-card/render.swift'), '-o', str(output / 'render')], check=True)
subprocess.run([str(output / 'render'), str(metadata), str(output / 'cards')], check=True)
rows = '\n'.join(f'''<article><img data-card="{i}" src="cards/{i}-16-dark.png" alt="Download card for {html.escape(s['name'], quote=True)}">
<p>{html.escape(s['name'])}</p><small>{s['bytes'] / 1e6:.1f} MB</small></article>''' for i, s in enumerate(samples))
page = '''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Cove — Download card study</title>
<style>
:root{color-scheme:dark;--bg:#111315;--fg:#eceef1;--muted:#a4a9b0;--panel:#1b1e22;--line:#343940}
body.light{color-scheme:light;--bg:#f2f3f5;--fg:#16191d;--muted:#656b74;--panel:#fff;--line:#d6d9de}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:15px system-ui;line-height:1.5}
main{max-width:1080px;margin:48px auto;padding:0 28px}h1{font-size:32px;letter-spacing:-.7px;margin:0 0 8px}
.intro,small{color:var(--muted)}nav{display:flex;flex-wrap:wrap;gap:18px;padding:20px 0 30px;position:sticky;top:0;background:var(--bg);z-index:1}
label{display:flex;align-items:center;gap:8px}select{font:inherit;padding:7px 10px;border:1px solid var(--line);border-radius:8px;background:var(--panel)}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(min(100%,470px),1fr));gap:16px}
article{padding:24px;background:var(--panel);border:1px solid var(--line);border-radius:16px;overflow:auto}
article img{display:block;width:220px;height:36px}body.zoom article img{width:440px;height:72px}
article p{margin:18px 0 0;overflow-wrap:anywhere;font-size:13px}h2{font-size:21px;margin-top:44px}
.sheet{max-width:100%;width:504px;border-radius:14px}.progress{width:317px}
</style>
<main><h1>The download card, paused</h1>
<p class="intro">COUNT recent file downloads. Images excluded. These are still simulations from Cove’s actual card renderer; no files are downloaded again.</p>
<nav><label>Corners <select id="radius"><option value="16">16 pt · Current</option><option value="12">12 pt · Tighter</option><option value="10">10 pt · Tighter still</option></select></label>
<label>Appearance <select id="appearance"><option value="dark">Dark</option><option value="light">Light</option></select></label>
<label>Size <select id="zoom"><option value="1">Actual · 220 × 36 pt</option><option value="2">2× close-up</option></select></label></nav>
<div class="grid">ROWS</div>
<h2>Compare the corners</h2><img class="sheet" src="cards/corners.png" alt="16, 12 and 10 point corners compared">
<h2>Progress combinations</h2><p class="intro">Native SwiftUI output. Fixed-width digits, one decimal, shared units, and compact time estimates.</p>
<img class="sheet progress" src="cards/progress.png" alt="Download progress at size and duration boundaries">
</main><script>
const radius=document.querySelector('#radius'),appearance=document.querySelector('#appearance'),zoom=document.querySelector('#zoom');
function update(){document.body.classList.toggle('light',appearance.value==='light');document.body.classList.toggle('zoom',zoom.value==='2');document.querySelectorAll('[data-card]').forEach(img=>{img.src=`cards/${img.dataset.card}-${radius.value}-${appearance.value}.png`})}
[radius,appearance,zoom].forEach(input=>input.addEventListener('change',update));
</script>'''.replace('ROWS', rows).replace('COUNT', str(len(samples)))
(output / 'index.html').write_text(page)
print(output / 'index.html')
