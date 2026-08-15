import asyncio
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from datetime import datetime, timezone
from typing import Optional

from aiogram import Bot, Dispatcher, types, F, Router
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from aiogram.fsm.storage.memory import MemoryStorage
from aiogram.utils.keyboard import InlineKeyboardBuilder
from aiogram.exceptions import TelegramBadRequest

import yt_dlp
from shazam_search import search_all_variations

# ─── تنظیمات ──────────────────────────────────────────────
TOKEN = os.getenv("TOKEN")
ALLOWED_USERNAME = "a_exhausted"

bot = Bot(token=TOKEN)
dp = Dispatcher(storage=MemoryStorage())
router = Router()
dp.include_router(router)

# ─── State ها ─────────────────────────────────────────────
class ProcessState(StatesGroup):
    waiting_for_audio_identify = State()
    waiting_for_audio_versions = State()

# ─── دیکشنری‌های سراسری برای مدیریت تسک‌ها ────────────────
active_tasks: dict[int, asyncio.Task] = {}
cancel_events: dict[int, asyncio.Event] = {}
processing_messages: dict[int, int] = {}  # chat_id -> message_id

# ─── لیست نسخه‌های تولیدی ─────────────────────────────────
VERSION_SPECS = [
    ("Speed Up", "atempo=1.1"),
    ("Super Speed Up", "atempo=1.25"),
    ("Ultra Speed Up", "atempo=1.5"),
    ("Mega Speed Up", "atempo=2.0"),
    ("Slowed", "atempo=0.9"),
    ("Super Slowed", "atempo=0.8"),
    ("Ultra Slowed", "atempo=0.7"),
    ("Mega Slowed", "atempo=0.5"),
    ("Reverb", "aecho=0.8:0.9:1000:0.3"),
    ("Slowed + Reverb", "atempo=0.75,aecho=0.8:0.9:1000:0.3"),
    ("Super Slowed + Reverb", "atempo=0.7,aecho=0.8:0.9:1000:0.3"),
    ("Ultra Slowed + Reverb", "atempo=0.6,aecho=0.8:0.9:1000:0.3"),
    ("Mega Slowed + Reverb", "atempo=0.5,aecho=0.8:0.9:1000:0.3"),
    ("Nightcore", "atempo=1.25,asetrate=44100*1.25,aresample=44100"),
    ("Daycore", "atempo=0.85,asetrate=44100*0.85,aresample=44100"),
    ("Bass Boosted", "equalizer=f=80:t=h:width=200:g=8"),
    ("8D Audio", "apulsator=hz=0.1:amount=0.5"),
    ("Lo-fi", "lowpass=f=4000,atempo=0.9,aecho=0.8:0.7:800:0.2"),
    ("Deep Voice", "asetrate=44100*0.8,aresample=44100,atempo=0.8"),
    ("Chipmunk", "asetrate=44100*1.25,aresample=44100,atempo=1.25"),
    ("Reverse", "areverse"),
    ("Muffled", "lowpass=f=2000"),
    ("Crystal Clear", "highpass=f=200,equalizer=f=5000:t=q:width=1:g=3"),
    ("Radio", "highpass=f=300,lowpass=f=3000"),
    ("Vaporwave", "atempo=0.8,aecho=0.8:0.9:1000:0.4"),
]

# ─── توابع کمکی ───────────────────────────────────────────
def is_allowed(user) -> bool:
    return user.username == ALLOWED_USERNAME

async def download_file_from_tg(file_id: str, dest_dir: Path) -> Path:
    file = await bot.get_file(file_id)
    file_path = dest_dir / "input" + Path(file.file_path).suffix
    await bot.download_file(file.file_path, file_path)
    return file_path

def extract_audio(input_path: Path, output_dir: Path) -> Path:
    output_path = output_dir / "audio.mp3"
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-i", str(input_path),
        "-vn", "-ac", "2", "-ar", "44100", "-b:a", "192k",
        str(output_path)
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    return output_path

def get_audio_title(input_path: Path) -> str:
    """دریافت عنوان از متادیتا یا نام فایل"""
    cmd = [
        "ffprobe", "-v", "error",
        "-show_entries", "format_tags=title",
        "-of", "default=noprint_wrappers=1:nokey=1",
        str(input_path)
    ]
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    title = res.stdout.strip()
    if not title:
        title = input_path.stem
    return title

async def download_from_url(url: str, dest_dir: Path) -> Path:
    """دانلود صدا از لینک با yt-dlp"""
    ydl_opts = {
        'format': 'bestaudio/best',
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }],
        'outtmpl': str(dest_dir / '%(title)s.%(ext)s'),
        'quiet': True,
        'noplaylist': True,
    }
    def _sync_download():
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=True)
            filename = ydl.prepare_filename(info)
            # پس از postprocessor پسوند mp3 می‌شود
            mp3_path = Path(filename).with_suffix('.mp3')
            if mp3_path.exists():
                return str(mp3_path)
            # اگر فایل اصلی mp3 نبود، به دنبال هر mp3 در پوشه بگرد
            mp3_files = list(dest_dir.glob('*.mp3'))
            if mp3_files:
                return str(mp3_files[-1])
            raise FileNotFoundError("Downloaded audio not found")
    return Path(await asyncio.to_thread(_sync_download))

async def process_audio_input(message: types.Message, state: ProcessState, mode: str):
    """پردازش ورودی صوتی/لینک و شروع عملیات مناسب"""
    chat_id = message.chat.id
    user = message.from_user

    if not is_allowed(user):
        await message.answer("⛔️ شما مجاز به استفاده از این ربات نیستید.")
        return

    if chat_id in active_tasks and not active_tasks[chat_id].done():
        await message.answer("⚠️ یک عملیات در حال اجراست. ابتدا آن را لغو کنید یا منتظر بمانید.")
        return

    temp_dir = Path(tempfile.mkdtemp(prefix="musicbot_"))
    try:
        # مشخص کردن منبع فایل
        audio_path = None
        if message.text and (message.text.startswith("http://") or message.text.startswith("https://")):
            await message.answer("⬇️ در حال دانلود از لینک...")
            audio_path = await download_from_url(message.text.strip(), temp_dir)
        elif message.audio:
            await message.answer("📥 در حال دریافت فایل صوتی...")
            file_path = await download_file_from_tg(message.audio.file_id, temp_dir)
            audio_path = extract_audio(file_path, temp_dir)
        elif message.video:
            await message.answer("📥 در حال دریافت ویدئو و استخراج صدا...")
            file_path = await download_file_from_tg(message.video.file_id, temp_dir)
            audio_path = extract_audio(file_path, temp_dir)
        elif message.document:
            await message.answer("📥 در حال دریافت فایل...")
            file_path = await download_file_from_tg(message.document.file_id, temp_dir)
            audio_path = extract_audio(file_path, temp_dir)
        elif message.voice:
            await message.answer("📥 در حال دریافت پیام صوتی...")
            file_path = await download_file_from_tg(message.voice.file_id, temp_dir)
            audio_path = extract_audio(file_path, temp_dir)
        else:
            await message.answer("❌ لطفاً یک فایل صوتی/ویدئویی یا لینک معتبر بفرستید.")
            return

        # شروع عملیات
        cancel_event = asyncio.Event()
        cancel_events[chat_id] = cancel_event

        status_msg = await message.answer(
            f"🔄 عملیات شروع شد...\n"
            f"حالت: {mode}\n"
            f"فایل: {audio_path.name}"
        )
        processing_messages[chat_id] = status_msg.message_id

        if mode == "identify":
            task = asyncio.create_task(
                identify_task(chat_id, audio_path, temp_dir, cancel_event)
            )
        else:
            task = asyncio.create_task(
                versions_task(chat_id, audio_path, temp_dir, cancel_event)
            )
        active_tasks[chat_id] = task

    except Exception as e:
        await message.answer(f"❌ خطا در پردازش ورودی: {str(e)}")
        shutil.rmtree(temp_dir, ignore_errors=True)

# ─── تسک شناسایی ──────────────────────────────────────────
async def identify_task(chat_id: int, audio_path: Path, temp_dir: Path, cancel_event: asyncio.Event):
    try:
        async def progress_callback(done, total):
            # به‌روزرسانی پیام هر ۵ تغییر
            if done % 5 == 0 or done == total:
                try:
                    await bot.edit_message_text(
                        f"🔄 در حال شناسایی...\n"
                        f"پیشرفت: {done}/{total}\n"
                        f"لغو با دکمه زیر",
                        chat_id=chat_id,
                        message_id=processing_messages[chat_id],
                        reply_markup=InlineKeyboardBuilder().button(
                            text="❌ لغو", callback_data="cancel"
                        ).as_markup()
                    )
                except TelegramBadRequest:
                    pass

        result = await search_all_variations(
            audio_path,
            progress_callback=progress_callback,
            cancel_event=cancel_event,
        )

        found = result.get("found_matches", 0)
        results = result.get("results", [])
        if found:
            text = f"🎉 **نتایج شناسایی:**\n\n"
            for r in results:
                if r.get("matched"):
                    text += f"✅ `{r.get('title', '')}` - `{r.get('subtitle', '')}`\n"
                    text += f"   روش: {r['method']} | فاکتور: {r['factor']} | شروع: {r['start']}s\n"
            text += f"\nکل تطابق‌ها: {found}"
        else:
            text = "😢 هیچ موسیقی شناسایی نشد."

        await bot.edit_message_text(
            text,
            chat_id=chat_id,
            message_id=processing_messages[chat_id],
            parse_mode="Markdown"
        )
    except asyncio.CancelledError:
        await bot.edit_message_text("⏹ عملیات لغو شد.", chat_id=chat_id, message_id=processing_messages[chat_id])
    except Exception as e:
        await bot.edit_message_text(f"❌ خطا در شناسایی: {str(e)}", chat_id=chat_id, message_id=processing_messages[chat_id])
    finally:
        active_tasks.pop(chat_id, None)
        cancel_events.pop(chat_id, None)
        processing_messages.pop(chat_id, None)
        shutil.rmtree(temp_dir, ignore_errors=True)

# ─── تسک تولید نسخه‌ها ────────────────────────────────────
async def versions_task(chat_id: int, audio_path: Path, temp_dir: Path, cancel_event: asyncio.Event):
    try:
        original_title = get_audio_title(audio_path)
        version_dir = temp_dir / "versions"
        version_dir.mkdir(exist_ok=True)

        total_versions = len(VERSION_SPECS)
        for idx, (name, filter_str) in enumerate(VERSION_SPECS, 1):
            if cancel_event.is_set():
                await bot.edit_message_text(
                    f"⏹ تولید لغو شد. {idx-1} نسخه ساخته شد.",
                    chat_id=chat_id,
                    message_id=processing_messages[chat_id]
                )
                return

            # به‌روزرسانی پیشرفت
            if idx % 2 == 0 or idx == total_versions:
                await bot.edit_message_text(
                    f"🔄 در حال تولید نسخه‌ها...\n"
                    f"پیشرفت: {idx}/{total_versions}\n"
                    f"نسخه فعلی: {name}",
                    chat_id=chat_id,
                    message_id=processing_messages[chat_id],
                    reply_markup=InlineKeyboardBuilder().button(
                        text="❌ لغو", callback_data="cancel"
                    ).as_markup()
                )

            output_file = version_dir / f"{name}.mp3"
            title_tag = f"[{name}] {original_title}"
            cmd = [
                "ffmpeg", "-y", "-loglevel", "error",
                "-i", str(audio_path),
                "-af", filter_str,
                "-metadata", f"title={title_tag}",
                "-metadata", f"artist={original_title}",
                "-vn", "-ac", "2", "-ar", "44100", "-b:a", "192k",
                str(output_file)
            ]
            subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

        await bot.edit_message_text(
            "✅ همه نسخه‌ها ساخته شدند. در حال ارسال...",
            chat_id=chat_id,
            message_id=processing_messages[chat_id]
        )

        # ارسال فایل‌ها
        sent_count = 0
        for idx, (name, _) in enumerate(VERSION_SPECS, 1):
            if cancel_event.is_set():
                await bot.send_message(chat_id, f"⏹ ارسال متوقف شد. {sent_count} نسخه ارسال شد.")
                return
            file_path = version_dir / f"{name}.mp3"
            if file_path.exists():
                await bot.send_audio(
                    chat_id=chat_id,
                    audio=types.FSInputFile(file_path),
                    caption=f"🎵 {name}"
                )
                sent_count += 1
                await asyncio.sleep(0.5)

        await bot.send_message(chat_id, f"🎉 تمام {sent_count} نسخه ارسال شد.")
    except asyncio.CancelledError:
        await bot.edit_message_text("⏹ عملیات لغو شد.", chat_id=chat_id, message_id=processing_messages[chat_id])
    except Exception as e:
        await bot.edit_message_text(f"❌ خطا در تولید نسخه‌ها: {str(e)}", chat_id=chat_id, message_id=processing_messages[chat_id])
    finally:
        active_tasks.pop(chat_id, None)
        cancel_events.pop(chat_id, None)
        processing_messages.pop(chat_id, None)
        shutil.rmtree(temp_dir, ignore_errors=True)

# ─── هندلرهای ربات ────────────────────────────────────────
@router.message(commands=["start"])
async def cmd_start(message: types.Message):
    if not is_allowed(message.from_user):
        await message.answer("⛔️ دسترسی غیرمجاز.")
        return
    await message.answer(
        "🎵 به ربات پیشرفته موسیقی خوش آمدید!\n\n"
        "🔍 /identify — شناسایی موسیقی با روش‌های متعدد\n"
        "🎚 /versions — تولید نسخه‌های مختلف (Slowed, Speed Up, Reverb و...)\n"
        "❌ /cancel — لغو عملیات جاری\n\n"
        "می‌توانید فایل صوتی، ویدئو یا لینک بفرستید."
    )

@router.message(commands=["identify"])
async def cmd_identify(message: types.Message, state: FSMContext):
    if not is_allowed(message.from_user):
        await message.answer("⛔️ دسترسی غیرمجاز.")
        return
    await state.set_state(ProcessState.waiting_for_audio_identify)
    await message.answer("📤 لطفاً فایل صوتی/ویدئویی یا لینک موسیقی را بفرستید.")

@router.message(commands=["versions"])
async def cmd_versions(message: types.Message, state: FSMContext):
    if not is_allowed(message.from_user):
        await message.answer("⛔️ دسترسی غیرمجاز.")
        return
    await state.set_state(ProcessState.waiting_for_audio_versions)
    await message.answer("📤 لطفاً فایل صوتی/ویدئویی یا لینک موسیقی را بفرستید.")

@router.message(commands=["cancel"])
async def cmd_cancel(message: types.Message, state: FSMContext):
    if not is_allowed(message.from_user):
        await message.answer("⛔️ دسترسی غیرمجاز.")
        return
    await state.clear()
    chat_id = message.chat.id
    if chat_id in cancel_events:
        cancel_events[chat_id].set()
        await message.answer("🛑 درخواست لغو ثبت شد.")
    else:
        await message.answer("ℹ️ عملیات فعالی وجود ندارد.")

@router.callback_query(F.data == "cancel")
async def cancel_callback(callback: types.CallbackQuery):
    if not is_allowed(callback.from_user):
        await callback.answer("⛔️ غیرمجاز", show_alert=True)
        return
    chat_id = callback.message.chat.id
    if chat_id in cancel_events:
        cancel_events[chat_id].set()
        await callback.answer("در حال لغو...")
    else:
        await callback.answer("عملیاتی فعال نیست")

@router.message(F.text & (F.text.startswith("http://") | F.text.startswith("https://")))
async def handle_link(message: types.Message, state: FSMContext):
    current_state = await state.get_state()
    if current_state == ProcessState.waiting_for_audio_identify.state:
        await state.clear()
        await process_audio_input(message, state, "identify")
    elif current_state == ProcessState.waiting_for_audio_versions.state:
        await state.clear()
        await process_audio_input(message, state, "versions")
    else:
        # اگر حالت مشخص نیست، از کاربر بپرس چه کاری انجام دهیم
        builder = InlineKeyboardBuilder()
        builder.button(text="🔍 شناسایی", callback_data="choose_identify")
        builder.button(text="🎚 تولید نسخه", callback_data="choose_versions")
        await message.answer(
            "چه کاری می‌خواهید انجام دهید؟",
            reply_markup=builder.as_markup()
        )

@router.message(F.audio | F.video | F.document | F.voice)
async def handle_media(message: types.Message, state: FSMContext):
    current_state = await state.get_state()
    if current_state == ProcessState.waiting_for_audio_identify.state:
        await state.clear()
        await process_audio_input(message, state, "identify")
    elif current_state == ProcessState.waiting_for_audio_versions.state:
        await state.clear()
        await process_audio_input(message, state, "versions")
    else:
        # اگر حالت مشخص نیست، از کاربر بپرس
        builder = InlineKeyboardBuilder()
        builder.button(text="🔍 شناسایی", callback_data="choose_identify")
        builder.button(text="🎚 تولید نسخه", callback_data="choose_versions")
        await message.answer(
            "چه کاری می‌خواهید انجام دهید؟",
            reply_markup=builder.as_markup()
        )

@router.callback_query(F.data.startswith("choose_"))
async def choose_mode(callback: types.CallbackQuery, state: FSMContext):
    if not is_allowed(callback.from_user):
        await callback.answer("⛔️ غیرمجاز", show_alert=True)
        return
    mode = callback.data.split("_")[1]  # identify یا versions
    if mode == "identify":
        await state.set_state(ProcessState.waiting_for_audio_identify)
        await callback.message.edit_text("📤 لطفاً فایل صوتی/ویدئویی یا لینک موسیقی را بفرستید.")
    else:
        await state.set_state(ProcessState.waiting_for_audio_versions)
        await callback.message.edit_text("📤 لطفاً فایل صوتی/ویدئویی یا لینک موسیقی را بفرستید.")
    await callback.answer()

# ─── اجرای ربات ───────────────────────────────────────────
async def main():
    await dp.start_polling(bot)

if __name__ == "__main__":
    asyncio.run(main())