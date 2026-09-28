"""Serve the preserved baseline with the existing gzip-aware handler, loopback only."""
import argparse
import importlib.util
from pathlib import Path

root = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('existing_web_server', root / 'tools/serve_web.py')
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)
parser = argparse.ArgumentParser()
parser.add_argument('--port', type=int, default=4186)
args = parser.parse_args()
server.ROOT = root / 'evidence/visual-upgrade-20260923/baseline-web/out'
assert (server.ROOT / 'index.pck').is_file(), 'Preserved baseline is missing'
print(f'Baseline only: http://127.0.0.1:{args.port} -> {server.ROOT}', flush=True)
server.ThreadingHTTPServer(('127.0.0.1', args.port), server.Handler).serve_forever()
