"""Sync fastclaw's next-export snapshot into the app as ONE zip asset.

Route A of the bundled-webui plan: zips fastclaw/web/out ->
assets/webui.zip, excluding the whiteboard bundle (excalidraw, ~14MB)
that wiki/workflows never load. One zip instead of 900+ loose assets —
Flutter's directory assets don't recurse, and a single deflated entry
keeps the APK delta small. Run after building fastclaw's web.

Usage: python tool/sync_webui.py
"""
import os
import sys
import zipfile

SRC = r'D:\backup\Desktop\fastclaw\web\out'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DST = os.path.join(ROOT, 'assets', 'webui.zip')

# Top-level export entries the local wiki/workflows shells never fetch.
EXCLUDE_TOP = {'excalidraw'}


def main():
    if not os.path.isdir(SRC):
        sys.exit(f'missing export at {SRC} — build fastclaw web first')
    os.makedirs(os.path.dirname(DST), exist_ok=True)
    total = 0
    count = 0
    with zipfile.ZipFile(DST, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for root, dirs, files in os.walk(SRC):
            dirs[:] = [d for d in dirs if d not in EXCLUDE_TOP]
            for f in files:
                full = os.path.join(root, f)
                rel = os.path.relpath(full, SRC).replace(os.sep, '/')
                z.write(full, rel)
                total += os.path.getsize(full)
                count += 1
    zipped = os.path.getsize(DST)
    print(f'zipped {count} files, {total / 1024 / 1024:.1f} MB raw -> {zipped / 1024 / 1024:.1f} MB -> {DST}')


if __name__ == '__main__':
    main()
