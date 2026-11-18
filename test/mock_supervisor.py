"""Minimal Supervisor stand-in for test/e2e.sh: serves the app options and records POSTs."""
import json
import pathlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

DATA = pathlib.Path("/data")


class Handler(BaseHTTPRequestHandler):
    def reply(self, data):
        body = json.dumps({"result": "ok", "data": data}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.endswith("/self/options/config"):
            self.reply(json.loads((DATA / "options.json").read_text()))
        else:
            self.reply({})

    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        # /core/api/states/binary_sensor.x -> posted/core_api_states_binary_sensor.x
        name = self.path.strip("/").replace("/", "_")
        (DATA / "posted").mkdir(exist_ok=True)
        (DATA / "posted" / name).write_bytes(body)
        self.reply({})


ThreadingHTTPServer(("0.0.0.0", 80), Handler).serve_forever()
