import hashlib, json, pathlib, requests, zipfile, sys, time

ROOT = pathlib.Path(__file__).resolve().parent
receipts = {}
for name, repo, tag in [('godot', 'godotengine/godot', '4.7.2-stable'), ('emsdk', 'emscripten-core/emsdk', '4.0.20')]:
    ref = requests.get(f'https://api.github.com/repos/{repo}/git/ref/tags/{tag}', timeout=60)
    ref.raise_for_status()
    data = ref.json()
    sha = data['object']['sha']
    url = f'https://codeload.github.com/{repo}/zip/{sha}'
    archive = ROOT / (name + '-official.zip')
    print(f'Downloading {name} {sha}', flush=True)
    with requests.get(url, stream=True, timeout=120) as response:
        response.raise_for_status()
        with archive.open('wb') as out:
            for chunk in response.iter_content(1024*1024):
                out.write(chunk)
    receipts[name] = dict(repo=repo, tag=tag, commit=sha, url=url, archive_sha256=hashlib.sha256(archive.read_bytes()).hexdigest(), bytes=archive.stat().st_size)
    print(f'Extracting {name} {archive.stat().st_size} bytes', flush=True)
    with zipfile.ZipFile(archive) as z:
        prefix = z.namelist()[0].split('/')[0] + '/'
        for member in z.infolist():
            rel = member.filename[len(prefix):]
            if not rel or member.is_dir():
                continue
            target = ROOT / name / rel
            # Python supports Windows extended paths without a machine setting.
            target_string = '\\\\?\\' + str(target) if sys.platform == 'win32' else str(target)
            parent_string = '\\\\?\\' + str(target.parent) if sys.platform == 'win32' else str(target.parent)
            pathlib.Path(parent_string).mkdir(parents=True, exist_ok=True)
            with z.open(member) as src, open(target_string, 'wb') as dst:
                dst.write(src.read())
    print(f'{name} ready', flush=True)
(ROOT / 'source-provenance.json').write_text(json.dumps(receipts, indent=2), encoding='utf-8')
