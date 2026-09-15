#!/usr/bin/env python3
"""Public fixture only; never prints recognized content. No microphone claim."""
import json
import math
import pathlib
import struct
import subprocess
import sys
import time
import wave

worker, model, fixture = map(pathlib.Path, sys.argv[1:])
command = ['/usr/bin/sandbox-exec', '-p', '(version 1)(allow default)(deny network*)', str(worker.resolve()), str(model.resolve())]

def run(payload):
    return subprocess.run(command, input=payload, capture_output=True, timeout=30)

def pcm(samples):
    return struct.pack('<I', len(samples)) + struct.pack('<' + 'f' * len(samples), *samples)

for payload in [b'', struct.pack('<I', 400001), struct.pack('<I', 5), pcm([float('nan')]), pcm([2.0]), pcm([0.0]) + b'extra']:
    assert run(payload).returncode != 0, 'Malformed PCM accepted'
silent = run(pcm([0.0] * 16000))
assert silent.returncode == 0 and json.loads(silent.stdout) == [], 'Silence produced text'
with wave.open(str(fixture)) as audio:
    assert (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) == (1, 2, 16000)
    raw = audio.readframes(audio.getnframes())
samples = [n / 32768 for (n,) in struct.iter_unpack('<h', raw)]
start = time.monotonic()
result = run(pcm(samples))
elapsed = time.monotonic() - start
assert result.returncode == 0, 'Real local inference failed'
segments = json.loads(result.stdout)
assert segments and all(isinstance(s['text'], str) and math.isfinite(s['start']) and s['end'] >= s['start'] for s in segments)
assert any(s['text'].strip() for s in segments), 'Speech produced empty text'
print(json.dumps({'kind':'whisper-native-injected-audio', 'network':'denied-for-worker', 'segments':len(segments), 'elapsedSeconds':elapsed, 'status':'passed'}))
