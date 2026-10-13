"""Minimal mock of the GitHub/GitLab "create MR" endpoints for tests.

Usage: python3 -I tests/mock_api.py PORT_FILE LOG_FILE
Writes the bound port to PORT_FILE, then appends one JSON line per request
(method, path, auth headers, body) to LOG_FILE.
"""
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        with open(sys.argv[2], "a") as log:
            log.write(json.dumps({
                "path": self.path,
                "authorization": self.headers.get("Authorization"),
                "private_token": self.headers.get("PRIVATE-TOKEN"),
                "body": json.loads(body or b"{}"),
            }) + "\n")
        url = "http://mock/merge/1"
        resp = json.dumps({"html_url": url, "web_url": url}).encode()
        self.send_response(201)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(resp)))
        self.end_headers()
        self.wfile.write(resp)

    def log_message(self, *args):
        pass


server = HTTPServer(("127.0.0.1", 0), Handler)
with open(sys.argv[1], "w") as f:
    f.write(str(server.server_port))
server.serve_forever()
