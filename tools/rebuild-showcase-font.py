"""Rebuild the existing OFL UI subset from its verified retained original."""
from pathlib import Path
import argparse
import hashlib
import json
import sys

parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, required=True)
parser.add_argument('--fonttools-path', type=Path)
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
target = root / 'godot/assets/fonts/SignalSansTC.otf'
provenance = target.with_name('PROVENANCE.json')
record = json.loads(provenance.read_text(encoding='utf-8-sig'))
source_hash = hashlib.sha256(args.source.read_bytes()).hexdigest()
if source_hash != record['source_sha256']:
    raise SystemExit('Font original does not match retained provenance')
if args.fonttools_path:
    sys.path.insert(0, str(args.fonttools_path.resolve()))
import fontTools
from fontTools import subset
from fontTools.ttLib import TTFont

font = TTFont(args.source)
text = (root / 'godot/scripts/interface.gd').read_text(encoding='utf-8')
text += (root / 'godot/config/brand.json').read_text(encoding='utf-8')
chars = (set(text) | {chr(n) for n in range(32, 127)}) - {'\n', '\r', '\t'}
missing = sorted(ord(c) for c in chars if ord(c) not in font.getBestCmap())
if missing:
    raise SystemExit(f'Original font lacks requested codepoints: {missing}')
options = subset.Options()
options.name_IDs = ['*']
options.name_legacy = True
options.name_languages = ['*']
subsetter = subset.Subsetter(options)
subsetter.populate(text=''.join(sorted(chars)))
subsetter.subset(font)
for name in font['name'].names:
    if name.nameID in (1, 3, 4, 6, 16):
        name.string = ('SignalSansTC-Regular' if name.nameID in (3, 6) else 'Signal Sans TC').encode(name.getEncoding())
if 'CFF ' in font:
    cff = font['CFF '].cff
    cff.fontNames = ['SignalSansTC-Regular']
    cff.topDictIndex[0].FamilyName = 'Signal Sans TC'
    cff.topDictIndex[0].FullName = 'Signal Sans TC Regular'
backup = root / 'evidence/visual-upgrade-20260923/pm-ui-font-before'
backup.mkdir(parents=True, exist_ok=True)
for source in (target, provenance):
    copy = backup / source.name
    if not copy.exists(): copy.write_bytes(source.read_bytes())
temporary = target.with_name('SignalSansTC.pending.otf')
font.save(temporary)
check = TTFont(temporary)
if not all(ord(c) in check.getBestCmap() for c in chars):
    raise SystemExit('Generated font failed complete character coverage')
check.close()
temporary.replace(target)
record.update(subset_sha256=hashlib.sha256(target.read_bytes()).hexdigest(), subset_bytes=target.stat().st_size,
              covered_characters=len(chars), missing_characters=[], tool=f'fontTools {fontTools.__version__}; retained local dependency',
              rebuild='python tools/rebuild-showcase-font.py --source <verified retained original> --fonttools-path <local dependency>')
provenance.write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'covered_characters': len(chars), 'missing_characters': [], 'subset_bytes': target.stat().st_size, 'subset_sha256': record['subset_sha256']}))
