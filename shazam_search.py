import asyncio
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from shazamio import Shazam

AUDIO_FILE = Path("hsj.mp3")
RESULT_FILE = Path("shazam-results.json")
SEGMENT_LENGTH = 12          # طول هر قطعه برای شناسایی (ثانیه)
START_STEP = 5               # گام برش از زمان‌های مختلف (ثانیه)

# روش‌های مختلف تغییر صدا
METHODS = [
    {
        "name": "tempo",
        "description": "تغییر سرعت با حفظ زیروبمی (atempo)",
        "factors": [0.5, 0.6, 0.7, 0.75, 0.8, 0.85, 0.9, 0.95, 1.0,
                    1.05, 1.1, 1.15, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0],
    },
    {
        "name": "rate",
        "description": "تغییر نرخ نمونه‌برداری (تغییر سرعت و زیروبمی)",
        "factors": [0.8, 0.9, 1.0, 1.1, 1.2],
    },
]

def get_duration(file_path):
    """دریافت مدت زمان فایل صوتی با ffprobe"""
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1",
        str(file_path)
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
    return float(result.stdout.strip())

def build_filter(method_name, factor):
    """ساخت فیلتر ffmpeg برای تغییر صدا"""
    if method_name == "tempo":
        if factor == 1.0:
            return "aresample=44100"
        return f"aresample=44100,atempo={factor}"
    elif method_name == "rate":
        if factor == 1.0:
            return "aresample=44100"
        return f"aresample=44100,asetrate=44100*{factor},aresample=44100"
    else:
        raise ValueError(f"Unknown method: {method_name}")

def create_audio_bytes(file_path, start, input_duration, method_name, factor):
    """
    برش از زمان start به مدت input_duration ثانیه از فایل اصلی،
    اعمال فیلتر تغییر صدا و خروجی mp3 به صورت bytes.
    """
    filter_str = build_filter(method_name, factor)
    cmd = [
        "ffmpeg", "-y",
        "-loglevel", "error",
        "-ss", str(start),          # جستجوی سریع قبل از ورودی
        "-i", str(file_path),
        "-t", str(input_duration),   # مدت زمان ورودی (قبل از فیلتر)
        "-af", filter_str,
        "-vn",
        "-ac", "2",
        "-ar", "44100",
        "-f", "mp3",
        "pipe:1"
    ]
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)
    if result.returncode != 0:
        raise RuntimeError(f"ffmpeg failed: {result.stderr.decode(errors='ignore')[:200]}")
    return result.stdout

async def recognize_with_retry(shazam, audio_bytes, retries=2):
    """شناسایی با چند بار تلاش در صورت خطای محدودیت نرخ"""
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

async def main():
    if not AUDIO_FILE.exists():
        print(f"Error: {AUDIO_FILE} not found")
        sys.exit(1)

    duration = get_duration(AUDIO_FILE)
    print(f"Audio duration: {duration:.2f} seconds")

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
                # مدت زمان ورودی مورد نیاز برای رسیدن به خروجی حدود SEGMENT_LENGTH ثانیه
                input_duration = min(SEGMENT_LENGTH * factor, duration - start)
                if input_duration < 2:   # کمتر از ۲ ثانیه فایده ندارد
                    continue
                variations.append({
                    "method": method["name"],
                    "factor": factor,
                    "start": start,
                    "input_duration": input_duration,
                })

    print(f"Total variations to try: {len(variations)}")

    shazam = Shazam()
    results = []
    found_matches = 0

    for idx, var in enumerate(variations, 1):
        print(f"[{idx}/{len(variations)}] Trying method={var['method']}, factor={var['factor']}, start={var['start']}s, input_duration={var['input_duration']}s")
        try:
            audio_bytes = create_audio_bytes(
                AUDIO_FILE,
                var["start"],
                var["input_duration"],
                var["method"],
                var["factor"]
            )
            if len(audio_bytes) == 0:
                print("  Empty audio, skipping")
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
                print(f"  ✅ MATCH: {title} - {subtitle}")
            else:
                error = resp.get("error")
                if error:
                    print(f"  ⚠️ Error: {error}")
                else:
                    print("  ❌ No match")

            result_entry = {**var, "matched": matched}
            if matched:
                result_entry["title"] = title
                result_entry["subtitle"] = subtitle
                result_entry["shazam_track"] = track
            if resp.get("error"):
                result_entry["error"] = resp["error"]
            results.append(result_entry)

        except Exception as e:
            print(f"  ❌ Exception: {e}")
            results.append({**var, "matched": False, "error": str(e)})

        # کمی تاخیر برای جلوگیری از محدودیت نرخ
        await asyncio.sleep(0.3)

        # ذخیره نتایج میانی بعد از هر ۲۰ تغییر
        if idx % 20 == 0:
            interim = {
                "generated_at": datetime.now(timezone.utc).isoformat(),
                "audio_file": str(AUDIO_FILE),
                "duration_seconds": duration,
                "total_variations": len(variations),
                "processed": idx,
                "found_matches": found_matches,
                "results": results,
            }
            RESULT_FILE.write_text(json.dumps(interim, ensure_ascii=False, indent=2), encoding="utf-8")

    final = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "audio_file": str(AUDIO_FILE),
        "duration_seconds": duration,
        "total_variations": len(variations),
        "found_matches": found_matches,
        "results": results,
    }
    RESULT_FILE.write_text(json.dumps(final, ensure_ascii=False, indent=2), encoding="utf-8")

    print("\n===== Summary =====")
    print(f"Total variations tried: {len(variations)}")
    print(f"Total matches found: {found_matches}")
    if found_matches:
        print("\nMatched tracks:")
        for r in results:
            if r.get("matched"):
                print(f"  - method={r['method']}, factor={r['factor']}, start={r['start']}s: {r.get('title')} - {r.get('subtitle')}")
    else:
        print("No matches found.")
    print(f"Results written to {RESULT_FILE}")

if __name__ == "__main__":
    asyncio.run(main())