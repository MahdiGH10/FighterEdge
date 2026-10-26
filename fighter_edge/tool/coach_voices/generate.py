"""Renders the coach's lines to short MP3 clips with the free Kokoro model.

The reaction drill only ever says a fixed list of lines (every move in
ReactionCommands, plus the drill announcements), so instead of running a
speech model on the phone the lines are rendered once here and shipped as
small clips: human-sounding, offline, instant, and the same on every phone.

Usage (see README.md for the one-time setup):

    python generate.py --model kokoro.onnx --voices voices.bin \
        --out ../../assets/voices

The line list must match what the app speaks. test/unit/training/
coach_voice_assets_test.dart fails if a spoken line has no clip.
"""

import argparse
import re
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

# folder in the app -> Kokoro voice
VOICES = {
    "us_male": "am_michael",
    "uk_male": "bm_george",
    "us_female": "af_heart",
}

# Exactly what the drill speaks: each move's `spoken` text, then the
# announcements. Keep in sync with reaction_drill.dart and the controller.
LINES = [
    # Grappling
    "Shoot", "Sprawl", "Front roll", "Back roll", "Down block", "Jump",
    "Cartwheel",
    # Strikes
    "Jab", "Hook", "Cross", "Back hook", "Uppercut", "Lead uppercut",
    "Low kick", "High kick", "Middle kick", "Left kick", "Right kick",
    "Side kick", "Teep",
    # Defense
    "Kick check", "Slip left", "Slip right",
    # Footwork
    "Step left", "Step right", "Step back", "Step in", "Pivot left",
    "Pivot right",
    # MMA level changes
    "Level change", "Level change front roll", "Level change back roll",
]
ANNOUNCEMENTS = ["Get ready!", "Rest", "Time!"]

SPEED = 1.1  # a coach barks; a narrator reads
TARGET_RMS_DB = -18.0
PEAK_LIMIT = 0.97
PAD_SECONDS = 0.03


def slug(line: str) -> str:
    """Same rule as CoachClipNames.slug in the app."""
    return re.sub(r"[^a-z0-9]+", "_", line.lower()).strip("_")


def trim(samples: np.ndarray, rate: int) -> np.ndarray:
    active = np.flatnonzero(np.abs(samples) > 0.01)
    if active.size == 0:
        return samples
    pad = int(PAD_SECONDS * rate)
    start = max(0, active[0] - pad)
    end = min(len(samples), active[-1] + pad)
    return samples[start:end]


def level(samples: np.ndarray) -> np.ndarray:
    rms = float(np.sqrt(np.mean(np.square(samples))))
    if rms == 0:
        return samples
    gain = 10 ** (TARGET_RMS_DB / 20) / rms
    peak = float(np.max(np.abs(samples))) * gain
    if peak > PEAK_LIMIT:
        gain *= PEAK_LIMIT / peak
    return samples * gain


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--voices", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    kokoro = Kokoro(args.model, args.voices)
    out = Path(args.out)
    # Moves are said with an exclamation mark, like the app's spoken line.
    texts = [f"{line}!" for line in LINES] + ANNOUNCEMENTS

    with tempfile.TemporaryDirectory() as tmp:
        for folder, voice in VOICES.items():
            target = out / folder
            target.mkdir(parents=True, exist_ok=True)
            for text in texts:
                samples, rate = kokoro.create(
                    text, voice=voice, speed=SPEED, lang="en-us"
                )
                samples = level(trim(np.asarray(samples), rate))
                wav = Path(tmp) / "clip.wav"
                sf.write(wav, samples, rate)
                mp3 = target / f"{slug(text)}.mp3"
                subprocess.run(
                    ["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav),
                     "-ac", "1", "-codec:a", "libmp3lame", "-b:a", "64k",
                     str(mp3)],
                    check=True,
                )
                print(f"{folder}/{mp3.name}  {len(samples) / rate:.2f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
