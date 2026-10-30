#!/usr/bin/env python3
"""Offline JSON-RPC peer; deliberately interleave malformed data and events."""
import json
import os
from pathlib import Path
import sys
import time
import subprocess

fixture = json.loads(Path(os.environ["YAFP_CODEX_TEST_FIXTURE"]).read_text())
if fixture.get("helper"):
    subprocess.Popen([sys.executable, "-c", "import signal,time; signal.signal(signal.SIGTERM, signal.SIG_IGN); time.sleep(2)"])
    time.sleep(.1)
for line in sys.stdin:
    request = json.loads(line)
    with Path(os.environ["YAFP_CODEX_TEST_LOG"]).open("a") as log:
        log.write(json.dumps(request) + "\n")
    method = request["method"]
    if method == "initialized":
        continue
    if method == "initialize":
        result = {}
    elif method == "account/read":
        result = {"account": fixture.get("account", {"type": "chatgpt", "email": "PRIVATE"})}
    elif method == "account/rateLimits/read":
        if fixture.get("delay"):
            time.sleep(fixture["delay"])
        result = fixture.get("result", {})
    else:
        raise RuntimeError("Unexpected method")
    print("malformed line", flush=True)
    print(json.dumps({"method": "account/updated", "params": {}}), flush=True)
    response = {"id": request["id"], "result": result}
    if fixture.get("error") == method:
        response = {"id": request["id"], "error": {"message": "PRIVATE"}}
    print(json.dumps(response), flush=True)
