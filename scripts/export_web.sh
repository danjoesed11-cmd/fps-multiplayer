#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

echo "==> Exporting web build..."
/Users/danielseder/Downloads/Godot.app/Contents/MacOS/Godot --headless --export-release "Web" docs/game/index.html

echo "==> Applying cache busting..."
python3 - << 'EOF'
import re, os, shutil, subprocess

ver = subprocess.check_output(['git', 'rev-parse', '--short', 'HEAD']).decode().strip()
pck_src = 'docs/game/index.pck'
pck_dst = f'docs/game/pck_{ver}.pck'
pck_size = os.path.getsize(pck_src)

shutil.copy(pck_src, pck_dst)
os.remove(pck_src)

for f in os.listdir('docs/game'):
    if f.startswith('pck_') and f.endswith('.pck') and f != f'pck_{ver}.pck':
        os.remove(f'docs/game/{f}')

with open('docs/game/index.html', 'r') as f:
    html = f.read()

html = re.sub(r'"index\.pck":\d+', f'"pck_{ver}.pck":{pck_size}', html)
html = html.replace("engine.startGame({", f"engine.startGame({{'mainPack':'pck_{ver}.pck',")
html = re.sub(r'src="index\.js(\?v=[^"]*)?', f'src="index.js?v={ver}', html)

no_cache = '<meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate"><meta http-equiv="Pragma" content="no-cache"><meta http-equiv="Expires" content="0">'
if 'Cache-Control' not in html:
    html = html.replace('<head>', '<head>\n\t\t' + no_cache, 1)

with open('docs/game/index.html', 'w') as f:
    f.write(html)

print(f"Done — pck_{ver}.pck ({pck_size} bytes)")
EOF

echo "==> Done. Remember to git add docs/game/ && git commit && git push"
