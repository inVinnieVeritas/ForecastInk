"""Test official xh 0.16.1 plus production logging, using only localhost.

Usage: python tests/test-error-logging-real.py --xh /path/to/xh --bash /path/to/bash
No downloaded tools are installed on the Kindle. The xh executable is supplied
explicitly; its --version must identify 0.16.1. Host and Kindle binaries may
have different build targets, so this does not claim ARM execution on-device.
"""
import argparse
import hashlib
import http.server
import os
from pathlib import Path
import shlex
import socket
import subprocess
import tempfile
import threading

parser = argparse.ArgumentParser()
parser.add_argument("--xh", required=True)
parser.add_argument("--bash", default="bash")
args = parser.parse_args()
xh = Path(args.xh).resolve()
repo = Path(__file__).resolve().parent.parent
version = subprocess.check_output([str(xh), "--version"]).decode().splitlines()[0]
assert version == "xh 0.16.1", version
print(version, "SHA-256", hashlib.sha256(xh.read_bytes()).hexdigest(), flush=True)


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        status = int(self.path.strip("/"))
        body = b'{"ok":true}' if status == 200 else b'{"reason":"body must not enter diagnostics"}'
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Retry-After", "60")
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *_):
        pass


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
thread = threading.Thread(target=server.serve_forever, daemon=True)
thread.start()
try:
    with tempfile.TemporaryDirectory(prefix="forecastink-real-xh-") as directory:
        captures = Path(directory)
        for status in (200, 503, 429):
            payload = captures / f"body-{status}.json"
            result = subprocess.run(
                [str(xh), "-d", "--quiet", "--print=h", "--pretty=none", "-o", str(payload), "get", f"http://127.0.0.1:{server.server_port}/{status}"],
                stdin=subprocess.DEVNULL, capture_output=True, timeout=10,
            )
            assert result.returncode == {200: 0, 503: 5, 429: 4}[status]
            assert not result.stdout and f" {status} ".encode() in result.stderr
            assert b"body must not enter diagnostics" not in result.stderr
            assert payload.exists() == (status == 200)
            (captures / f"real-xh-{status}.capture").write_bytes(result.stdout + result.stderr)
            print(f"PASS: HTTP {status}, rc={result.returncode}, headers on stderr despite --quiet", flush=True)
        with socket.socket() as sock:
            sock.bind(("127.0.0.1", 0))
            refused_port = sock.getsockname()[1]
        result = subprocess.run(
            [str(xh), "-d", "--quiet", "--print=h", "--pretty=none", "-o", str(captures / "refused.json"), "get", f"http://127.0.0.1:{refused_port}/"],
            stdin=subprocess.DEVNULL, capture_output=True, timeout=10,
        )
        assert result.returncode == 1 and b"xh: error:" in result.stderr
        (captures / "real-xh-refused.capture").write_bytes(result.stdout + result.stderr)
        print("PASS: real transport failure, rc=1, error text on stderr despite --quiet", flush=True)
        for shell in ("sh", "bash"):
            env = os.environ.copy()
            env["XH_REAL_CAPTURE_DIR"] = captures.as_posix()
            command = f"cd {shlex.quote(repo.as_posix())} && {shell} tests/test-error-logging.sh"
            subprocess.run([args.bash, "-lc", command], env=env, check=True)
finally:
    server.shutdown()
    server.server_close()
    thread.join(timeout=5)
print("PASS: real xh 0.16.1 and production logging integration under sh and bash", flush=True)
