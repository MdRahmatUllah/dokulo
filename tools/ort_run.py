"""Dev-only ONNX runner for doc_vision's OCR tests (DK-0398); never shipped.

    python -I tools/ort_run.py <models dir>

The app runs the models through flutter_onnxruntime, which needs a device.
On the development machine, the Dart tests run the real models through this:
one JSON request per stdin line, {"model": "det", "shape": [...], "in": path,
"out": path}, with the input as raw little-endian float32 at "in". It writes
the first output the same way to "out" and answers {"shape": [...]} on stdout.
Needs `pip install onnxruntime numpy`.
"""

import json
import sys
from pathlib import Path

import numpy as np
import onnxruntime as ort

FILES = {"det": "det.onnx", "cls": "cls.onnx", "rec": "rec_latin.onnx"}


def main() -> int:
    models = Path(sys.argv[1])
    sessions = {}
    for line in sys.stdin:
        request = json.loads(line)
        name = request["model"]
        if name not in sessions:
            sessions[name] = ort.InferenceSession(str(models / FILES[name]), providers=["CPUExecutionProvider"])
        session = sessions[name]
        x = np.fromfile(request["in"], dtype="<f4").reshape(request["shape"])
        output = session.run(None, {session.get_inputs()[0].name: x})[0].astype("<f4")
        output.tofile(request["out"])
        print(json.dumps({"shape": list(output.shape)}), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
