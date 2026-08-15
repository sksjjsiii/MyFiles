import re
import logging
import telebot
import os
from curl_cffi import requests
from bs4 import BeautifulSoup
from urllib.parse import urlparse

# ---------- تنظیمات ----------
TOKEN = os.getenv('TOKEN')
if not TOKEN:
    raise ValueError("TOKEN environment variable not set")

bot = telebot.TeleBot(TOKEN)
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# ---------- توابع bypass (دقیقاً مشابه کد داده شده) ----------
def RecaptchaV3():
    ANCHOR_URL = 'https://www.google.com/recaptcha/api2/anchor?ar=1&k=6Lcr1ncUAAAAAH3cghg6cOTPGARa8adOf-y9zv2x&co=aHR0cHM6Ly9vdW8ucHJlc3M6NDQz&hl=en&v=pCoGBhjs9s8EhFOHJFe8cqis&size=invisible&cb=ahgyd1gkfkhe'
    url_base = 'https://www.google.com/recaptcha/'
    post_data = "v={}&reason=q&c={}&k={}&co={}"
    client = requests.Session()
    client.headers.update({
        'content-type': 'application/x-www-form-urlencoded'
    })
    matches = re.findall('([api2|enterprise]+)\/anchor\?(.*)', ANCHOR_URL)[0]
    url_base += matches[0]+'/'
    params = matches[1]
    res = client.get(url_base+'anchor', params=params)
    token = re.findall(r'"recaptcha-token" value="(.*?)"', res.text)[0]
    params = dict(pair.split('=') for pair in params.split('&'))
    post_data = post_data.format(params["v"], token, params["k"], params["co"])
    res = client.post(url_base+'reload', params=f'k={params["k"]}', data=post_data)
    answer = re.findall(r'"rresp","(.*?)"', res.text)[0]    
    return answer

def ouo_bypass(url):
    tempurl = url.replace("ouo.press", "ouo.io")
    p = urlparse(tempurl)
    id = tempurl.split('/')[-1]
    
    client = requests.Session()
    client.headers.update({
        'authority': 'ouo.io',
        'accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'accept-language': 'en-GB,en-US;q=0.9,en;q=0.8',
        'cache-control': 'max-age=0',
        'referer': 'http://www.google.com/ig/adde?moduleurl=',
        'upgrade-insecure-requests': '1',
    })

    res = client.get(tempurl, impersonate="chrome110")
    next_url = f"{p.scheme}://{p.hostname}/go/{id}"

    for _ in range(2):
        if res.headers.get('Location'):
            break

        bs4 = BeautifulSoup(res.content, 'lxml')
        inputs = bs4.form.findAll("input", {"name": re.compile(r"token$")})
        data = { input.get('name'): input.get('value') for input in inputs }
        data['x-token'] = RecaptchaV3()
        
        h = {
            'content-type': 'application/x-www-form-urlencoded'
        }
        
        res = client.post(next_url, data=data, headers=h, 
            allow_redirects=False, impersonate="chrome110")
        next_url = f"{p.scheme}://{p.hostname}/xreallcygo/{id}"

    return {
        'original_link': url,
        'bypassed_link': res.headers.get('Location')
    }

# ---------- هندلر پیام‌های تلگرام ----------
@bot.message_handler(func=lambda message: True)
def handle_message(message):
    try:
        text = message.text
        if not text:
            bot.reply_to(message, "❌ لطفاً یک متن ارسال کنید.")
            return

        # استخراج لینک ouo از متن
        # الگوی ساده برای لینک‌های ouo.io یا ouo.press
        ouo_pattern = r'(https?://(?:ouo\.io|ouo\.press)/[^\s]+)'
        matches = re.findall(ouo_pattern, text)
        if not matches:
            bot.reply_to(message, "ℹ️ لینک ouo معتبری در پیام یافت نشد.")
            return

        # فقط اولین لینک را پردازش می‌کنیم
        target_url = matches[0]
        bot.reply_to(message, f"⏳ در حال پردازش لینک:\n{target_url}")

        # اجرای bypass
        result = ouo_bypass(target_url)
        bypassed = result.get('bypassed_link')

        if bypassed:
            bot.reply_to(message, f"✅ لینک نهایی:\n{bypassed}")
        else:
            bot.reply_to(message, "⚠️ امکان bypass کردن لینک وجود نداشت (هدر Location دریافت نشد).")

    except Exception as e:
        # ارسال تمام جزئیات خطا به کاربر
        error_msg = f"❌ خطا:\n{str(e)}"
        logger.exception("Error in handler")
        bot.reply_to(message, error_msg)

# ---------- اجرای ربات ----------
if __name__ == '__main__':
    logger.info("Starting bot...")
    bot.infinity_polling()