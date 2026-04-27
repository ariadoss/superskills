"""Batch-transcribe every video in a directory.

Walks <videos_dir> for common video extensions, runs the chosen transcription
backend on each, writes transcripts to <videos_dir>/edit/transcripts/<name>.json.

Backends (see transcribe.py for full description):
  scribe — ElevenLabs Scribe (network-bound; parallel workers help)
  mlx    — local mlx-whisper (GPU-bound; workers forced to 1)
  auto   — scribe if ELEVENLABS_API_KEY set, else mlx

Cached per-file: any source that already has a transcript is skipped.

Usage:
    python helpers/transcribe_batch.py <videos_dir>
    python helpers/transcribe_batch.py <videos_dir> --backend mlx
    python helpers/transcribe_batch.py <videos_dir> --workers 4
    python helpers/transcribe_batch.py <videos_dir> --num-speakers 2
    python helpers/transcribe_batch.py <videos_dir> --edit-dir /custom/edit
"""

from __future__ import annotations

import argparse
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from transcribe import DEFAULT_MLX_MODEL, load_api_key, resolve_backend, transcribe_one


VIDEO_EXTS = {".mp4", ".MP4", ".mov", ".MOV", ".mkv", ".MKV", ".avi", ".AVI", ".m4v"}


def find_videos(videos_dir: Path) -> list[Path]:
    videos = sorted(
        p for p in videos_dir.iterdir()
        if p.is_file() and p.suffix in VIDEO_EXTS
    )
    return videos


def main() -> None:
    ap = argparse.ArgumentParser(description="Parallel batch transcription of a videos directory")
    ap.add_argument("videos_dir", type=Path, help="Directory containing source videos")
    ap.add_argument(
        "--edit-dir",
        type=Path,
        default=None,
        help="Edit output directory (default: <videos_dir>/edit)",
    )
    ap.add_argument(
        "--backend",
        choices=["auto", "scribe", "mlx"],
        default="auto",
        help="Transcription backend. 'auto' picks scribe if a key is set, else mlx.",
    )
    ap.add_argument("--workers", type=int, default=4, help="Parallel workers (default: 4 for scribe, forced to 1 for mlx)")
    ap.add_argument(
        "--language",
        type=str,
        default=None,
        help="Optional ISO language code. Omit to auto-detect per file.",
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

    videos_dir = args.videos_dir.resolve()
    if not videos_dir.is_dir():
        sys.exit(f"not a directory: {videos_dir}")

    edit_dir = (args.edit_dir or (videos_dir / "edit")).resolve()
    (edit_dir / "transcripts").mkdir(parents=True, exist_ok=True)

    videos = find_videos(videos_dir)
    if not videos:
        sys.exit(f"no videos found in {videos_dir}")

    already_cached = [v for v in videos if (edit_dir / "transcripts" / f"{v.stem}.json").exists()]
    pending = [v for v in videos if v not in already_cached]

    print(f"found {len(videos)} videos ({len(already_cached)} cached, {len(pending)} to transcribe)")
    if not pending:
        print("nothing to do")
        return

    api_key = load_api_key()
    chosen = resolve_backend(args.backend, bool(api_key))

    # MLX runs on a single GPU/Neural Engine — parallel calls just queue and
    # risk OOM. Force workers=1 for local backends.
    workers = args.workers if chosen == "scribe" else 1

    print(f"backend: {chosen}  workers: {workers}")
    print(f"transcribing {len(pending)} files")
    t0 = time.time()

    errors: list[tuple[Path, str]] = []
    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {
            pool.submit(
                transcribe_one,
                video=v,
                edit_dir=edit_dir,
                api_key=api_key,
                backend=args.backend,
                language=args.language,
                num_speakers=args.num_speakers,
                mlx_model=args.mlx_model,
                verbose=False,
            ): v
            for v in pending
        }
        for fut in as_completed(futures):
            v = futures[fut]
            try:
                out = fut.result()
                print(f"  + {v.stem}  →  {out.name}")
            except Exception as e:
                errors.append((v, str(e)))
                print(f"  x {v.stem}  FAILED: {e}")

    dt = time.time() - t0
    print(f"\ndone in {dt:.1f}s")
    if errors:
        print(f"{len(errors)} failures:")
        for v, msg in errors:
            print(f"  {v.name}: {msg}")
        sys.exit(1)


if __name__ == "__main__":
    main()
