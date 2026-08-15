import asyncio
import os
import re
import logging
from urllib.parse import urlparse

from telegram import Update
from telegram.ext import Application, MessageHandler, filters, ContextTypes
from curl_cffi import requests
from bs4 import BeautifulSoup
from bs4 import FeatureNotFound

# ---------- تنظیمات ----------
TOKEN = os.getenv('TOKEN')
if not TOKEN:
    raise ValueError("TOKEN environment variable not set")

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ---------- کد bypass (دقیقاً مشابه کد داده شده) ----------
IMPERSONATION_PROFILES = ("chrome110", "chrome107", "safari15_5")

def _browser_headers(hostname, referer):
    return {
        'authority': hostname,
        'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'accept-language': 'en-US,en;q=0.9',
        'cache-control': 'max-age=0',
        'pragma': 'no-cache',
        'referer': referer,
        'sec-ch-ua': '"Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"',
        'sec-ch-ua-mobile': '?0',
        'sec-ch-ua-platform': '"macOS"',
        'sec-fetch-dest': 'document',
        'sec-fetch-mode': 'navigate',
        'sec-fetch-site': 'same-origin',
        'sec-fetch-user': '?1',
        'upgrade-insecure-requests': '1',
        'user-agent': (
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/122.0.0.0 Safari/537.36'
        ),
    }

def _is_cloudflare_challenge(response):
    body_lower = (response.text or "").lower()
    return (
        response.status_code in {403, 429, 503}
        and (
            "just a moment" in body_lower
            or "cf-chl" in body_lower
            or "/cdn-cgi/challenge-platform" in body_lower
        )
    )

def RecaptchaV3():
    import requests
    ANCHOR_URL = 'https://www.google.com/recaptcha/api2/anchor?ar=1&k=6Lcr1ncUAAAAAH3cghg6cOTPGARa8adOf-y9zv2x&co=aHR0cHM6Ly9vdW8ucHJlc3M6NDQz&hl=en&v=pCoGBhjs9s8EhFOHJFe8cqis&size=invisible&cb=ahgyd1gkfkhe'
    url_base = 'https://www.google.com/recaptcha/'
    post_data = "v={}&reason=q&c={}&k={}&co={}"
    client = requests.Session()
    client.headers.update({
        'content-type': 'application/x-www-form-urlencoded'
    })
    matches = re.findall(r'(api2|enterprise)/anchor\?(.*)', ANCHOR_URL)[0]
    url_base += matches[0]+'/'
    params = matches[1]
    res = client.get(url_base+'anchor', params=params)
    token = re.findall(r'"recaptcha-token" value="(.*?)"', res.text)[0]
    params = dict(pair.split('=') for pair in params.split('&'))
    post_data = post_data.format(params["v"], token, params["k"], params["co"])
    res = client.post(url_base+'reload', params=f'k={params["k"]}', data=post_data)
    answer = re.findall(r'"rresp","(.*?)"', res.text)[0]    
    return answer

client = requests.Session()

async def ouo_bypass(url):
    tempurl = url.replace("ouo.press", "ouo.io")
    p = urlparse(tempurl)
    id = tempurl.split('/')[-1]

    home_url = f"{p.scheme}://{p.hostname}/"
    res = None
    selected_profile = None

    for profile in IMPERSONATION_PROFILES:
        client.headers.update(_browser_headers(p.hostname, referer=home_url))
        try:
            client.get(home_url, impersonate=profile, timeout=30)
            candidate = client.get(tempurl, impersonate=profile, timeout=30)
        except Exception:
            continue

        if _is_cloudflare_challenge(candidate):
            res = candidate
            continue

        selected_profile = profile
        res = candidate
        break

    if selected_profile is None and res is not None and _is_cloudflare_challenge(res):
        raise ValueError(
            "Blocked by Cloudflare challenge (HTTP 403). Try again later, use a different network/IP, or run from a browser-like environment."
        )
    if selected_profile is None or res is None:
        raise ValueError("Failed to open ouo page with available browser profiles.")

    next_url = f"{p.scheme}://{p.hostname}/go/{id}"

    for _ in range(2):
        if res.headers.get('Location'):
            break

        try:
            bs4 = BeautifulSoup(res.content, 'lxml')
        except FeatureNotFound:
            bs4 = BeautifulSoup(res.content, 'html.parser')
        form = bs4.find("form")
        if form is None:
            raise ValueError(
                "Could not find bypass form on the page. The link may be invalid, expired, or temporarily blocked."
            )

        inputs = form.find_all("input", {"name": re.compile(r"token$")})
        if not inputs:
            raise ValueError(
                "Could not find required bypass tokens on the page. The link flow may have changed."
            )

        data = {input.get('name'): input.get('value') for input in inputs}
        data['x-token'] = RecaptchaV3()

        h = {'content-type': 'application/x-www-form-urlencoded'}
        res = client.post(next_url, data=data, headers=h, 
            allow_redirects=False, impersonate=selected_profile, timeout=30)
        next_url = f"{p.scheme}://{p.hostname}/xreallcygo/{id}"

    bypassed_link = res.headers.get('Location')
    if not bypassed_link:
        raise ValueError(
            "Bypass did not produce a redirect URL. The link may be protected or currently unavailable."
        )

    return {
        'original_link': url,
        'bypassed_link': bypassed_link
    }

# ---------- هندلر پیام‌های تلگرام (async) ----------
async def handle_message(update: Update, context: ContextTypes.DEFAULT_TYPE):
    try:
        message = update.message
        if not message or not message.text:
            await message.reply_text("❌ لطفاً یک متن ارسال کنید.")
            return

        text = message.text
        ouo_pattern = r'(https?://(?:ouo\.io|ouo\.press)/[^\s]+)'
        matches = re.findall(ouo_pattern, text)
        if not matches:
            await message.reply_text("ℹ️ لینک ouo معتبری در پیام یافت نشد.")
            return

        target_url = matches[0]
        await message.reply_text(f"⏳ در حال پردازش لینک:\n{target_url}")

        # اجرای async bypass
        result = await ouo_bypass(target_url)
        bypassed = result.get('bypassed_link')

        if bypassed:
            await message.reply_text(f"✅ لینک نهایی:\n{bypassed}")
        else:
            await message.reply_text("⚠️ امکان bypass کردن لینک وجود نداشت (هدر Location دریافت نشد).")

    except Exception as e:
        error_msg = f"❌ خطا:\n{str(e)}"
        logger.exception("Error in handler")
        await update.message.reply_text(error_msg)

# ---------- راه‌اندازی ربات ----------
def main():
    app = Application.builder().token(TOKEN).build()
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    logger.info("Starting bot...")
    app.run_polling()

if __name__ == '__main__':
    main()