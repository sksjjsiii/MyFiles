import asyncio
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional, Callable, Awaitable

from shazamio import Shazam

# ─── تنظیمات ──────────────────────────────────────────────
SEGMENT_LENGTH = 12          # طول هر قطعه برای شناسایی (ثانیه)
START_STEP = 5               # گام برش از زمان‌های مختلف (ثانیه)
DEFAULT_RESULT_FILE = Path("shazam-results.json")

# ─── روش‌های تغییر صدا ────────────────────────────────────
METHODS = [
    {
        "name": "tempo",
        "description": "تغییر سرعت با حفظ زیروبمی",
        "factors": [0.5, 0.6, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 1.0,
                    1.05, 1.1, 1.15, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0],
    },
    {
        "name": "rate",
        "description": "تغییر نرخ نمونه‌برداری (سرعت + زیروبمی)",
        "factors": [0.8, 0.9, 1.0, 1.1, 1.2],
    },
    {
        "name": "volume",
        "description": "تغییر بلندی صدا",
        "factors": [0.3, 0.5, 0.7, 0.9, 1.0, 1.2, 1.5, 2.0],
    },
    {
        "name": "eq_bass",
        "description": "تقویت بیس",
        "factors": ["light", "medium", "heavy"],
    },
    {
        "name": "eq_mid",
        "description": "تقویت میانه",
        "factors": ["light", "medium", "heavy"],
    },
    {
        "name": "eq_treble",
        "description": "تقویت زیر",
        "factors": ["light", "medium", "heavy"],
    },
    {
        "name": "eq_vocal",
        "description": "تقویت وکال",
        "factors": ["light", "medium", "heavy"],
    },
    {
        "name": "noise_reduction",
        "description": "کاهش نویز",
        "factors": ["light", "medium", "heavy"],
    },
    {
        "name": "reverse",
        "description": "پخش معکوس",
        "factors": [1],
    },
]

# ─── توابع کمکی ────────────────────────────────────────────
def get_duration(file_path):
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        str(file_path)
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
    return float(result.stdout.strip())

def build_filter(method_name, factor):
    """ساخت فیلتر ffmpeg بر اساس روش و مقدار"""
    base = "aresample=44100"
    if method_name == "tempo":
        if float(factor) == 1.0:
            return base
        return f"aresample=44100,atempo={factor}"
    elif method_name == "rate":
        if float(factor) == 1.0:
            return base
        return f"aresample=44100,asetrate=44100*{factor},aresample=44100"
    elif method_name == "volume":
        if float(factor) == 1.0:
            return base
        return f"volume={factor},aresample=44100"
    elif method_name == "reverse":
        return f"areverse,{base}"
    elif method_name == "eq_bass":
        g = {"light": 3, "medium": 6, "heavy": 9}[factor]
        return f"equalizer=f=100:t=h:width=200:g={g},{base}"
    elif method_name == "eq_mid":
        g = {"light": 3, "medium": 6, "heavy": 9}[factor]
        return f"equalizer=f=1000:t=q:width=1:g={g},{base}"
    elif method_name == "eq_treble":
        g = {"light": 3, "medium": 6, "heavy": 9}[factor]
        return f"equalizer=f=8000:t=q:width=1:g={g},{base}"
    elif method_name == "eq_vocal":
        g = {"light": 3, "medium": 5, "heavy": 7}[factor]
        return f"equalizer=f=3000:t=q:width=2:g={g},{base}"
    elif method_name == "noise_reduction":
        nf = {"light": -25, "medium": -20, "heavy": -15}[factor]
        return f"afftdn=nf={nf},{base}"
    else:
        raise ValueError(f"Unknown method: {method_name}")

def create_audio_bytes(file_path, start, input_duration, method_name, factor):
    filter_str = build_filter(method_name, factor)
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-ss", str(start),
        "-i", str(file_path),
        "-t", str(input_duration),
        "-af", filter_str,
        "-vn", "-ac", "2", "-ar", "44100",
        "-f", "mp3", "pipe:1"
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg failed: {result.stderr.decode(errors='ignore')[:200]}")
    return result.stdout

async def recognize_with_retry(shazam, audio_bytes, retries=2):
    for attempt in range(retries):
        try:
            if hasattr(shazam, 'recognize_song'):
                result = await shazam.recognize_song(audio_bytes)
            else:
                result = await shazam.recognize(audio_bytes)
            return result
        except Exception as e:
            err = str(e).lower()
            if '429' in err or 'rate' in err or 'too many' in err:
                await asyncio.sleep(5)
            else:
                return {"error": str(e)}
    return {"error": "Max retries exceeded"}

# ─── تابع اصلی جستجو (قابل استفاده در ربات) ────────────────
async def search_all_variations(
    audio_file_path,
    progress_callback: Optional[Callable[[int, int], Awaitable[None]]] = None,
    cancel_event: Optional[asyncio.Event] = None,
    result_file: Optional[Path] = None,
) -> dict:
    """
    اجرای همه تغییرات و شناسایی موسیقی.

    Args:
        audio_file_path: مسیر فایل صوتی
        progress_callback: تابع async که (پردازش‌شده، کل) را می‌گیرد
        cancel_event: رویداد لغو
        result_file: اگر داده شود، نتایج در آن ذخیره می‌شود

    Returns:
        dict شامل results و found_matches
    """
    if not Path(audio_file_path).exists():
        raise FileNotFoundError(f"{audio_file_path} not found")

    duration = get_duration(audio_file_path)

    # تولید لیست تغییرات
    variations = []
    starts = []
    current = 0.0
    while current < duration:
        starts.append(round(current, 2))
        current += START_STEP
    if not starts:
        starts.append(0.0)

    for method in METHODS:
        for factor in method["factors"]:
            for start in starts:
                if method["name"] in ("reverse",):
                    input_duration = min(SEGMENT_LENGTH, duration - start)
                else:
                    input_duration = min(SEGMENT_LENGTH * (float(factor) if isinstance(factor, (int, float)) else 1.0), duration - start)
                if input_duration < 2:
                    continue
                variations.append({
                    "method": method["name"],
                    "factor": factor,
                    "start": start,
                    "input_duration": input_duration,
                })

    total = len(variations)
    shazam = Shazam()
    results = []
    found_matches = 0

    for idx, var in enumerate(variations, 1):
        if cancel_event and cancel_event.is_set():
            print("Cancellation requested")
            break

        if progress_callback:
            await progress_callback(idx, total)

        try:
            audio_bytes = create_audio_bytes(
                audio_file_path, var["start"], var["input_duration"],
                var["method"], var["factor"]
            )
            if len(audio_bytes) == 0:
                results.append({**var, "matched": False, "error": "Empty audio"})
                continue

            resp = await recognize_with_retry(shazam, audio_bytes)

            matches = resp.get("matches", [])
            track = resp.get("track", {})
            title = track.get("title")
            subtitle = track.get("subtitle")

            matched = bool(matches) or bool(title)
            if matched:
                found_matches += 1
                print(f"✅ MATCH: {title} - {subtitle}")

            result_entry = {**var, "matched": matched}
            if matched:
                result_entry["title"] = title
                result_entry["subtitle"] = subtitle
                result_entry["shazam_track"] = track
            if resp.get("error"):
                result_entry["error"] = resp["error"]
            results.append(result_entry)

        except Exception as e:
            print(f"❌ Exception: {e}")
            results.append({**var, "matched": False, "error": str(e)})

        await asyncio.sleep(0.3)

    final = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "audio_file": str(audio_file_path),
        "duration_seconds": duration,
        "total_variations": len(variations),
        "processed": len(results),
        "found_matches": found_matches,
        "results": results,
    }

    if result_file:
        result_file.write_text(json.dumps(final, ensure_ascii=False, indent=2), encoding="utf-8")

    return final

# ─── اجرای مستقل ──────────────────────────────────────────
async def main():
    audio_file = Path("hsj.mp3")
    if not audio_file.exists():
        print(f"Error: {audio_file} not found")
        sys.exit(1)

    final = await search_all_variations(audio_file, result_file=DEFAULT_RESULT_FILE)
    print(f"Total: {final['total_variations']}, Matches: {final['found_matches']}")
    for r in final["results"]:
        if r.get("matched"):
            print(f"  - {r['method']} {r['factor']} @ {r['start']}s: {r.get('title')}")

if __name__ == "__main__":
    asyncio.run(main())