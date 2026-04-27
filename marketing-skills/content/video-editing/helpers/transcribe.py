"""Transcribe a video — ElevenLabs Scribe (default) or local mlx-whisper.

Backends:
  scribe (default when ELEVENLABS_API_KEY is present)
    Hosted ElevenLabs Scribe v1. Verbatim, word-level timestamps, speaker
    diarization, audio-event tags ((laughs), (applause)). Costs credits.

  mlx (local, Apple Silicon)
    mlx-whisper running on the local Neural Engine / GPU. Free, offline.
    Trade-offs: NO diarization (everything tagged speaker_0), NO audio-event
    tags, and Whisper-family models lightly normalize fillers ("um", "uh")
    even with biasing prompts. Filler-detection cuts will be less precise.

  auto (default)
    Use scribe if ELEVENLABS_API_KEY is set; otherwise fall back to mlx if
    `mlx-whisper` is importable; otherwise error out.

Output JSON shape is identical across backends so the rest of the pipeline
(pack_transcripts.py, render.py master-SRT builder) is backend-agnostic.

Cached: if the output file already exists, the upload/run is skipped.

Usage:
    python helpers/transcribe.py <video_path>                    # auto
    python helpers/transcribe.py <video_path> --backend mlx
    python helpers/transcribe.py <video_path> --backend scribe
    python helpers/transcribe.py <video_path> --language en
    python helpers/transcribe.py <video_path> --num-speakers 2   # scribe only
    python helpers/transcribe.py <video_path> --mlx-model mlx-community/whisper-large-v3-turbo
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import requests


SCRIBE_URL = "https://api.elevenlabs.io/v1/speech-to-text"
DEFAULT_MLX_MODEL = "mlx-community/whisper-large-v3-mlx"
# Bias mlx-whisper toward keeping fillers verbatim. Whisper still normalizes
# some, but this helps. Don't expect Scribe-quality filler tagging.
MLX_VERBATIM_PROMPT = (
    "Um, uh, like, you know, well, so, hmm, ah, okay, right, actually, basically."
)


# ── Backend selection ─────────────────────────────────────────────────────────


def load_api_key() -> str | None:
    """Return the ElevenLabs API key if found, else None.

    Searches: <skill_root>/.env, ./.env, ELEVENLABS_API_KEY env var.
    """
    for candidate in [Path(__file__).resolve().parent.parent / ".env", Path(".env")]:
        if candidate.exists():
            for line in candidate.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                k, v = line.split("=", 1)
                if k.strip() == "ELEVENLABS_API_KEY":
                    val = v.strip().strip('"').strip("'")
                    if val:
                        return val
    v = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    return v or None


def _mlx_available() -> bool:
    try:
        import mlx_whisper  # noqa: F401
        return True
    except ImportError:
        return False


def resolve_backend(requested: str, has_key: bool) -> str:
    """Map 'auto' → 'scribe' or 'mlx' based on what's available."""
    if requested != "auto":
        return requested
    if has_key:
        return "scribe"
    if _mlx_available():
        return "mlx"
    sys.exit(
        "no transcription backend available. Either:\n"
        "  - set ELEVENLABS_API_KEY (in .env or environment) for Scribe, or\n"
        "  - install mlx-whisper for local transcription:\n"
        "      uv add --optional local mlx-whisper   (or)   pip install mlx-whisper"
    )


# ── Audio extraction ─────────────────────────────────────────────────────────


def extract_audio(video_path: Path, dest: Path) -> None:
    cmd = [
        "ffmpeg", "-y", "-i", str(video_path),
        "-vn", "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le",
        str(dest),
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


# ── Backend: ElevenLabs Scribe ───────────────────────────────────────────────


def call_scribe(
    audio_path: Path,
    api_key: str,
    language: str | None = None,
    num_speakers: int | None = None,
) -> dict:
    data: dict[str, str] = {
        "model_id": "scribe_v1",
        "diarize": "true",
        "tag_audio_events": "true",
        "timestamps_granularity": "word",
    }
    if language:
        data["language_code"] = language
    if num_speakers:
        data["num_speakers"] = str(num_speakers)

    with open(audio_path, "rb") as f:
        resp = requests.post(
            SCRIBE_URL,
            headers={"xi-api-key": api_key},
            files={"file": (audio_path.name, f, "audio/wav")},
            data=data,
            timeout=1800,
        )

    if resp.status_code != 200:
        raise RuntimeError(f"Scribe returned {resp.status_code}: {resp.text[:500]}")

    return resp.json()


# ── Backend: local mlx-whisper ───────────────────────────────────────────────


def call_mlx(
    audio_path: Path,
    language: str | None = None,
    model: str = DEFAULT_MLX_MODEL,
) -> dict:
    """Run mlx-whisper locally and return a Scribe-shaped dict."""
    import mlx_whisper

    raw = mlx_whisper.transcribe(
        str(audio_path),
        path_or_hf_repo=model,
        word_timestamps=True,
        language=language,
        condition_on_previous_text=False,
        initial_prompt=MLX_VERBATIM_PROMPT,
        verbose=False,
    )
    return _mlx_to_scribe_shape(raw)


def _mlx_to_scribe_shape(mlx: dict, *, min_gap_for_spacing: float = 0.02) -> dict:
    """Convert mlx-whisper's segment/word output into the Scribe word-list shape
    that pack_transcripts.py and render.py expect.

    Scribe shape:
        {"words": [{"type": "word"|"spacing"|"audio_event",
                    "text": str, "start": float, "end": float,
                    "speaker_id": str | None}, ...]}
    """
    words: list[dict] = []
    prev_end: float | None = None

    for seg in mlx.get("segments", []) or []:
        for w in seg.get("words", []) or []:
            text = (w.get("word") or "").strip()
            start = w.get("start")
            end = w.get("end")
            if not text or start is None or end is None:
                continue
            # Insert a spacing entry to mark the gap (pack_transcripts.py uses
            # these to break phrases on long silences). Skip negligible gaps.
            if prev_end is not None and start - prev_end > min_gap_for_spacing:
                words.append({
                    "type": "spacing",
                    "text": " ",
                    "start": float(prev_end),
                    "end": float(start),
                })
            words.append({
                "type": "word",
                "text": text,
                "start": float(start),
                "end": float(end),
                # mlx-whisper has no diarization; tag everything as a single
                # speaker so phrase grouping doesn't fragment on every word.
                "speaker_id": "speaker_0",
            })
            prev_end = float(end)

    return {
        "language_code": mlx.get("language"),
        "language_probability": 1.0,
        "text": (mlx.get("text") or "").strip(),
        "words": words,
        # Backend marker so downstream callers can detect reduced-fidelity
        # transcripts if they care to. Scribe payloads omit this field.
        "_backend": "mlx-whisper",
    }


# ── Public entry point ───────────────────────────────────────────────────────


def transcribe_one(
    video: Path,
    edit_dir: Path,
    api_key: str | None,
    *,
    backend: str = "auto",
    language: str | None = None,
    num_speakers: int | None = None,
    mlx_model: str = DEFAULT_MLX_MODEL,
    verbose: bool = True,
) -> Path:
    """Transcribe a single video. Returns path to transcript JSON.

    Cached: returns existing path immediately if the transcript already exists.
    """
    transcripts_dir = edit_dir / "transcripts"
    transcripts_dir.mkdir(parents=True, exist_ok=True)
    out_path = transcripts_dir / f"{video.stem}.json"

    if out_path.exists():
        if verbose:
            print(f"cached: {out_path.name}")
        return out_path

    chosen = resolve_backend(backend, bool(api_key))

    if verbose:
        print(f"  extracting audio from {video.name}", flush=True)

    t0 = time.time()
    with tempfile.TemporaryDirectory() as tmp:
        audio = Path(tmp) / f"{video.stem}.wav"
        extract_audio(video, audio)
        size_mb = audio.stat().st_size / (1024 * 1024)

        if chosen == "scribe":
            if not api_key:
                sys.exit("backend=scribe but no ELEVENLABS_API_KEY available")
            if verbose:
                print(f"  [scribe] uploading {video.stem}.wav ({size_mb:.1f} MB)", flush=True)
            payload = call_scribe(audio, api_key, language, num_speakers)
        elif chosen == "mlx":
            if num_speakers is not None and verbose:
                print("  [mlx] --num-speakers ignored (no diarization)", flush=True)
            if verbose:
                print(f"  [mlx] transcribing {video.stem}.wav ({size_mb:.1f} MB) with {mlx_model}", flush=True)
            payload = call_mlx(audio, language, mlx_model)
        else:
            sys.exit(f"unknown backend: {chosen}")

    out_path.write_text(json.dumps(payload, indent=2))
    dt = time.time() - t0

    if verbose:
        kb = out_path.stat().st_size / 1024
        print(f"  saved: {out_path.name} ({kb:.1f} KB) in {dt:.1f}s")
        if isinstance(payload, dict) and "words" in payload:
            print(f"    words: {len(payload['words'])}  backend: {chosen}")

    return out_path


def main() -> None:
    ap = argparse.ArgumentParser(description="Transcribe a video (Scribe or mlx-whisper)")
    ap.add_argument("video", type=Path, help="Path to video file")
    ap.add_argument(
        "--edit-dir",
        type=Path,
        default=None,
        help="Edit output directory (default: <video_parent>/edit)",
    )
    ap.add_argument(
        "--backend",
        choices=["auto", "scribe", "mlx"],
        default="auto",
        help="Transcription backend. 'auto' picks scribe if a key is set, else mlx.",
    )
    ap.add_argument(
        "--language",
        type=str,
        default=None,
        help="Optional ISO language code (e.g., 'en'). Omit to auto-detect.",
    )
    ap.add_argument(
        "--num-speakers",
        type=int,
        default=None,
        help="Optional number of speakers (Scribe only; ignored for mlx).",
    )
    ap.add_argument(
        "--mlx-model",
        type=str,
        default=DEFAULT_MLX_MODEL,
        help=f"HF repo or local path for the mlx-whisper model (default: {DEFAULT_MLX_MODEL}).",
    )
    args = ap.parse_args()

    video = args.video.resolve()
    if not video.exists():
        sys.exit(f"video not found: {video}")

    edit_dir = (args.edit_dir or (video.parent / "edit")).resolve()
    api_key = load_api_key()

    transcribe_one(
        video=video,
        edit_dir=edit_dir,
        api_key=api_key,
        backend=args.backend,
        language=args.language,
        num_speakers=args.num_speakers,
        mlx_model=args.mlx_model,
    )


if __name__ == "__main__":
    main()
