from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import argparse

ROOT = Path(__file__).resolve().parents[1] / 'out'
ENCODING_HEADERS = True
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)
    def guess_type(self, path):
        return 'application/wasm' if path.endswith('.wasm') else ('application/octet-stream' if path.endswith('.pck') else super().guess_type(path))
    def end_headers(self):
        if ENCODING_HEADERS and self.path.split('?')[0].endswith('.wasm'):
            candidate=Path(self.translate_path(self.path))
            if candidate.is_file():
                with candidate.open('rb') as f:
                    if f.read(2)==b'\x1f\x8b': self.send_header('Content-Encoding','gzip')
        self.send_header('Cache-Control','no-cache')
        super().end_headers()
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=4174);parser.add_argument('--no-encoding',action='store_true');parser.add_argument('--directory',type=Path,default=ROOT)
    args=parser.parse_args()
    ROOT = args.directory.resolve()
    if not (ROOT / 'index.html').is_file(): parser.error('The selected Web candidate has no index.html')
    ENCODING_HEADERS = not args.no_encoding
    http = ThreadingHTTPServer(('127.0.0.1',args.port),Handler)
    print(f'Serving {ROOT} at http://127.0.0.1:{http.server_port}',flush=True)
    http.serve_forever()
