"""Local manual download tests. Run with python3, then visit 127.0.0.1:8768.

Small: 76-byte text. Slow: 1 MiB over about 30 seconds. Unknown: no length
header. Interrupted: fails once, then succeeds when the browser retries.
Changing speed: 16 MiB, with a four-second stall and faster final section.
All files use a Cove-download-test prefix. No external service is contacted.
"""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from threading import Lock
from urllib.parse import urlparse
import time

PAGE = b'''<!doctype html><title>Download test</title>
<style>body{font:20px system-ui;padding:50px}a{display:block;margin:22px}</style>
<h1>Download test</h1>
<a href="/small">Small text file</a><a href="/slow">Slow file</a>
<a href="/varying">Changing speed and stall</a>
<a href="/unknown">Unknown size</a><a href="/fail">Interrupted file</a>'''
CHUNK = b'Cove download test.\n'.ljust(8192, b' ')
SMALL = b'Cove download test.\nThis is a safe text file for the download flow check.\n'.ljust(76, b' ')


class Handler(BaseHTTPRequestHandler):
    attempts = 0
    lock = Lock()

    def do_GET(self):
        path = urlparse(self.path).path
        if path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(PAGE)
            return
        if path not in ('/small', '/slow', '/unknown', '/fail', '/varying'):
            self.send_error(404)
            return
        with self.lock:
            if path == '/fail':
                Handler.attempts += 1
            fail = path == '/fail' and Handler.attempts == 1
        size = len(SMALL) if path == '/small' else (16 if path == '/varying' else 1) * 1024 * 1024
        self.send_response(200)
        self.send_header('Content-Type', 'application/octet-stream')
        self.send_header('Content-Disposition', f'attachment; filename="Cove-download-test-{path[1:]}.txt"')
        if path != '/unknown':
            self.send_header('Content-Length', str(size))
        self.end_headers()
        try:
            if path == '/small':
                self.wfile.write(SMALL)
                return
            for n in range(size // len(CHUNK)):
                self.wfile.write(CHUNK)
                self.wfile.flush()
                if path == '/varying':
                    if n == 255:
                        time.sleep(4)
                    time.sleep(0.0625 if n < 256 else 0.0078125)
                else:
                    time.sleep(0.23)
                if fail and n == 8:
                    self.connection.shutdown(2)
                    return
        except (BrokenPipeError, ConnectionResetError):
            pass  # A cancelled browser download closes its connection.


if __name__ == '__main__':
    with ThreadingHTTPServer(('127.0.0.1', 8768), Handler) as server:
        print('Download test: http://127.0.0.1:8768/', flush=True)
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            pass
