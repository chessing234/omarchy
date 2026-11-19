#!/bin/bash

set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

python3 - "$ROOT" <<'PY'
import http.server
import os
from pathlib import Path
import sys
import threading
import types
from unittest.mock import patch

engine = types.ModuleType("local_engine")
path = Path(sys.argv[1]) / "bin/omarchy-agent-local-state"
exec(compile(path.read_text(), str(path), "exec"), engine.__dict__)
seen = []

class Local(http.server.BaseHTTPRequestHandler):
  def do_GET(self):
    seen.append(self.path)
    self.send_response(200)
    self.end_headers()
    self.wfile.write(b'{}')

  def do_POST(self):
    self.rfile.read(int(self.headers["Content-Length"]))
    self.do_GET()

  def log_message(self, *args):
    pass

with http.server.ThreadingHTTPServer(("127.0.0.1", 0), Local) as server:
  threading.Thread(target=server.serve_forever, daemon=True).start()
  engine.PORT = server.server_port
  proxy = "http://127.0.0.1:1"
  with patch.dict(os.environ, {"http_proxy": proxy, "HTTP_PROXY": proxy, "all_proxy": proxy, "ALL_PROXY": proxy, "no_proxy": "", "NO_PROXY": ""}):
    assert engine.server_answers(), "a proxy hides the real local server"
    engine.warm_up({"id": "test-model"})
  server.shutdown()
assert seen == ["/v1/models", "/v1/chat/completions", "/v1/chat/completions"], seen
print("ok - local health and warm-up requests bypass environment proxies")
PY
