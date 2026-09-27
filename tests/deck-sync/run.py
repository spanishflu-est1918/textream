"""Run with python3 tests/deck-sync/run.py; requires macOS Command Line Tools."""
import http.server
import json
import pathlib
import subprocess
import tempfile
import threading
import time

root = pathlib.Path(__file__).resolve().parents[2]
class Handler(http.server.BaseHTTPRequestHandler):
    reload = False
    connections = 0
    connection_times = []

    def log_message(self, *args):
        pass

    def do_GET(self):
        if self.path == '/deck/slides.json':
            if Handler.connections:
                Handler.connection_times.append(time.monotonic())
            if Handler.connections and not Handler.reload:
                self.send_error(503)
                return
            deck = {'slides': [{'script': 'Intro'}, {'script': ''},
                {'type': 'timeline', 'segments': [{'event': 'a', 'text': 'Revised' if Handler.reload else 'Alpha'}]}],
                'timeline': {'events': [{'key': 'a'}, {'key': 'missing'}]}}
            self.send_response(200)
            self.end_headers()
            self.wfile.write(json.dumps(deck).encode())
            Handler.reload = False
        elif self.path == '/sync/stream':
            Handler.connections += 1
            self.send_response(200)
            self.send_header('Content-Type', 'text/event-stream')
            self.end_headers()
            for message in [{'type': 'goto', 'i': 0}, {'type': 'goto', 'i': 0},
                            {'type': 'goto', 'i': 1}, {'type': 'goto', 'i': 2, 'tlPos': 0},
                            {'type': 'goto', 'i': 2, 'tlPos': 1}, {'type': 'video'},
                            {'type': 'goto', 'i': 2, 'tlPos': 0}]:
                self.wfile.write(('data: ' + json.dumps(message) + '\n\n').encode())
                self.wfile.flush()
                time.sleep(.05)
            Handler.reload = True
            self.wfile.write(b': ping\n\ndata: broken\n\ndata: {"type":"reload"}\n\n')
            self.wfile.flush()
            time.sleep(.4)
        else:
            self.send_error(404)

with http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler) as server:
    threading.Thread(target=server.serve_forever, daemon=True).start()
    # Keep compiler products and caches inside this repository.
    with tempfile.TemporaryDirectory(prefix='.deck-check-', dir=root) as temp:
        exe = str(pathlib.Path(temp) / 'checks')
        subprocess.run(['xcrun', 'swiftc', '-parse-as-library', '-module-cache-path', temp,
            str(root / 'Textream/Textream/DeckSync.swift'), str(root / 'tests/deck-sync/Checks.swift'), '-o', exe], check=True)
        subprocess.run([exe, f'http://127.0.0.1:{server.server_port}'], check=True)
        times = Handler.connection_times
        assert len(times) >= 3, times
        assert times[2] - times[1] >= 1.8, times  # second retry backs off for 2s
    server.shutdown()
