# Coach voice clips

The reaction drill says a fixed list of lines (every move in
`ReactionCommands`, plus "Get ready!", "Rest" and "Time!"). Instead of a speech
model on the phone, those lines are rendered once with the free
[Kokoro](https://huggingface.co/hexgrad/Kokoro-82M) neural voice model
(Apache-2.0) and shipped as small MP3 clips in `assets/voices/<voice>/`. They
sound human, work offline, play instantly and are identical on every phone.

| App voice  | Kokoro voice |
| ---------- | ------------ |
| `us_male`   | `am_michael` |
| `uk_male`   | `bm_george`  |
| `us_female` | `af_heart`   |

`test/unit/training/coach_voice_test.dart` fails if a line the drill says has
no clip, or a clip is left over for a line it no longer says.

## When a move is added or changed

1. Add the line to `LINES` in `generate.py`.
2. Re-run the generator (below) and commit the new clips.

## Running the generator

Needs Python 3.12 and `ffmpeg`. Keep the environment and the model files
outside the repo.

```
uv venv --python 3.12 venv
uv pip install --python venv/Scripts/python.exe kokoro-onnx soundfile numpy
# kokoro-v1.0.int8.onnx and voices-v1.0.bin from
# https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.0
venv/Scripts/python.exe -I generate.py --model kokoro-v1.0.int8.onnx \
    --voices voices-v1.0.bin --out <repo>/fighter_edge/assets/voices
```

Clips are trimmed, levelled to the same loudness and encoded as 64 kbps mono
MP3 (about 900 KB for all three voices).
