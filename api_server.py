import os, subprocess, threading, time, json, shutil, zipfile, io
from datetime import datetime
from flask import Flask, request, send_file, jsonify, Response

app = Flask(__name__)
PROJECT_DIR = os.path.join(os.getcwd(), os.environ.get('PROJECT_DIR', 'flutter_app'))
USERNAME = os.environ['RDP_USERNAME']
PASSWORD = os.environ['RDP_PASSWORD']
START_TIME = time.time()
SESSION_MINUTES = int(os.environ.get('SESSION_MINUTES', 120))

build_lock = threading.Lock()
build_state = {
    "status": "idle",
    "process": None,
    "log_lines": [],
    "apk_path": None,
    "error": None,
    "start_time": None
}

cmd_lock = threading.Lock()
running_commands = {}

def check_auth():
    auth = request.authorization
    return auth and auth.username == USERNAME and auth.password == PASSWORD

@app.before_request
def require_auth():
    if not check_auth():
        return Response('Unauthorized', 401,
            {'WWW-Authenticate': 'Basic realm="Flutter API"'})

@app.route('/')
@app.route('/docs')
def docs():
    return '''<!doctype html>
<html lang="en">
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Flutter API Docs</title>
<style>
    * { box-sizing: border-box; }
    body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; max-width: 1000px; margin: auto; padding: 20px; background: #0d1117; color: #c9d1d9; }
    h1 { color: #58a6ff; font-size: 2em; margin-top: 0; }
    h2 { color: #3fb950; border-bottom: 2px solid #30363d; padding-bottom: 8px; margin-top: 30px; }
    code { background: #161b22; padding: 3px 8px; border-radius: 4px; color: #f0883e; font-size: 0.9em; }
    pre { background: #161b22; padding: 15px; border-radius: 8px; overflow-x: auto; color: #e6edf3; border: 1px solid #30363d; }
    .method { color: #ff7b72; font-weight: bold; display: inline-block; min-width: 60px; }
    .endpoint { color: #7ee787; font-weight: bold; }
    .section { background: #161b22; border: 1px solid #30363d; border-radius: 10px; padding: 20px; margin: 20px 0; }
    .warning { background: #2d1b1b; border: 1px solid #ff4444; color: #ff8888; padding: 10px; border-radius: 6px; margin: 10px 0; }
    table { width: 100%; border-collapse: collapse; margin: 15px 0; }
    th, td { text-align: left; padding: 10px; border-bottom: 1px solid #30363d; }
    th { color: #58a6ff; }
</style></head>
<body>
<h1>📘 Flutter Build API</h1>
<p>Authentication: <strong>HTTP Basic Auth</strong></p>

<div class="section">
    <h2>📡 وضعیت سرور</h2>
    <p><span class="method">GET</span> <span class="endpoint">/api/status</span></p>
    <pre>curl -u user:pass http://host/api/status</pre>
</div>

<div class="section">
    <h2>📁 مدیریت فایل‌ها</h2>
    <table>
        <tr><th>متد</th><th>آدرس</th><th>توضیح</th></tr>
        <tr><td><span class="method">GET</span></td><td><span class="endpoint">/api/files</span></td><td>فهرست کل پروژه</td></tr>
        <tr><td><span class="method">GET</span></td><td><span class="endpoint">/api/files/&lt;path&gt;</span></td><td>دریافت محتوا</td></tr>
        <tr><td><span class="method">PUT</span></td><td><span class="endpoint">/api/files/&lt;path&gt;</span></td><td>بازنویسی فایل</td></tr>
        <tr><td><span class="method">DELETE</span></td><td><span class="endpoint">/api/files/&lt;path&gt;</span></td><td>حذف فایل/پوشه</td></tr>
        <tr><td><span class="method">POST</span></td><td><span class="endpoint">/api/files/&lt;path&gt;?action=mkdir</span></td><td>ایجاد پوشه</td></tr>
        <tr><td><span class="method">POST</span></td><td><span class="endpoint">/api/files/upload</span></td><td>آپلود (multipart, field: file, query: dest)</td></tr>
        <tr><td><span class="method">GET</span></td><td><span class="endpoint">/api/project/export</span></td><td>دانلود ZIP</td></tr>
        <tr><td><span class="method">GET</span></td><td><span class="endpoint">/api/project/info</span></td><td>اطلاعات پروژه</td></tr>
    </table>
</div>

<div class="section">
    <h2>⚡ اجرای دستور (هر چیزی)</h2>
    <div class="warning">⚠️ دسترسی کامل به shell. هر دستوری قابل اجراست.</div>
    <table>
        <tr><th>متد</th><th>آدرس</th><th>توضیح</th></tr>
        <tr><td><span class="method">POST</span></td><td><span class="endpoint">/api/exec</span></td><td>اجرای همزمان</td></tr>
        <tr><td><span class="method">POST</span></td><td><span class="endpoint">/api/exec-async</span></td><td>اجرای غیرهمزمان</td></tr>
        <tr><td><span class="method">GET</span></td><td><span class="endpoint">/api/exec-async/&lt;job_id&gt;</span></td><td>وضعیت job</td></tr>
    </table>
    <pre>curl -X POST -u user:pass -H "Content-Type: application/json" -d '{"command":"ls -la"}' http://host/api/exec</pre>
</div>

<div class="section">
    <h2>🛠️ بیلد</h2>
    <table>
        <tr><th>متد</th><th>آدرس</th><th>توضیح</th></tr>
        <tr><td><span class="method">POST</span></td><td><span class="endpoint">/api/build</span></td><td>شروع بیلد</td></tr>
        <tr><td><span class="method">GET</span></td><td><span class="endpoint">/api/build</span></td><td>وضعیت + تمام لاگ</td></tr>
        <tr><td><span class="method">GET</span></td><td><span class="endpoint">/api/download</span></td><td>دانلود APK</td></tr>
    </table>
</div>
</body></html>'''

@app.route('/api/status')
def status():
    elapsed = int(time.time() - START_TIME)
    remaining = max(0, SESSION_MINUTES * 60 - elapsed)
    return jsonify({
        "uptime_seconds": elapsed,
        "remaining_seconds": remaining,
        "remaining_minutes": remaining // 60,
        "session_minutes": SESSION_MINUTES,
        "project_exists": os.path.isdir(PROJECT_DIR)
    })

def safe_path(rel):
    full = os.path.normpath(os.path.join(PROJECT_DIR, rel))
    if not full.startswith(PROJECT_DIR):
        return None
    return full

@app.route('/api/files', defaults={'filepath': ''})
@app.route('/api/files/<path:filepath>', methods=['GET', 'PUT', 'DELETE', 'POST'])
def handle_files(filepath):
    full = safe_path(filepath)
    if full is None:
        return jsonify({"error": "مسیر غیرمجاز"}), 403

    if request.method == 'GET':
        if not os.path.exists(full):
            return jsonify({"error": "یافت نشد"}), 404
        if os.path.isdir(full):
            items = []
            for name in sorted(os.listdir(full)):
                p = os.path.join(full, name)
                rel_path = os.path.relpath(p, PROJECT_DIR).replace('\\', '/')
                st = os.stat(p)
                items.append({
                    "name": name,
                    "type": "dir" if os.path.isdir(p) else "file",
                    "path": rel_path,
                    "size": st.st_size,
                    "modified": st.st_mtime
                })
            return jsonify(items)
        else:
            with open(full, 'r', errors='ignore') as f:
                content = f.read()
            return jsonify({
                "path": filepath,
                "content": content,
                "size": os.path.getsize(full),
                "modified": os.path.getmtime(full)
            })

    elif request.method == 'PUT':
        os.makedirs(os.path.dirname(full), exist_ok=True)
        content = request.get_data(as_text=True)
        with open(full, 'w') as f:
            f.write(content)
        return jsonify({"status": "ok", "path": filepath, "size": len(content)})

    elif request.method == 'DELETE':
        if not os.path.exists(full):
            return jsonify({"error": "یافت نشد"}), 404
        if os.path.isdir(full):
            shutil.rmtree(full)
        else:
            os.remove(full)
        return jsonify({"status": "deleted"})

    elif request.method == 'POST':
        action = request.args.get('action', '')
        if action == 'mkdir':
            os.makedirs(full, exist_ok=True)
            return jsonify({"status": "directory created"})
        return jsonify({"error": "action نامعتبر"}), 400

@app.route('/api/files/upload', methods=['POST'])
def upload_file():
    if 'file' not in request.files:
        return jsonify({"error": "فایلی ارسال نشده"}), 400
    file = request.files['file']
    dest = request.args.get('dest', file.filename)
    if not dest:
        return jsonify({"error": "مسیر مقصد مشخص نشده"}), 400
    full = safe_path(dest)
    if full is None:
        return jsonify({"error": "مسیر غیرمجاز"}), 403
    os.makedirs(os.path.dirname(full), exist_ok=True)
    file.save(full)
    return jsonify({"status": "uploaded", "path": dest, "size": os.path.getsize(full)})

@app.route('/api/project/export')
def export_project():
    memory_file = io.BytesIO()
    with zipfile.ZipFile(memory_file, 'w', zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk(PROJECT_DIR):
            dirs[:] = [d for d in dirs if d not in ['.dart_tool', 'build', '.gradle', 'android/.gradle']]
            for file in files:
                full_path = os.path.join(root, file)
                arcname = os.path.relpath(full_path, PROJECT_DIR)
                zf.write(full_path, arcname)
    memory_file.seek(0)
    return send_file(memory_file, mimetype='application/zip',
                     as_attachment=True, download_name='flutter_project.zip')

@app.route('/api/project/info')
def project_info():
    pubspec = os.path.join(PROJECT_DIR, 'pubspec.yaml')
    info = {"project_dir": PROJECT_DIR}
    if os.path.exists(pubspec):
        with open(pubspec, 'r') as f:
            content = f.read()
        for line in content.split('\n'):
            line = line.strip()
            if line.startswith('name:'):
                info['name'] = line.split(':')[1].strip()
            elif line.startswith('version:'):
                info['version'] = line.split(':')[1].strip()
            elif line.startswith('description:'):
                info['description'] = line.split(':', 1)[1].strip()
    file_count = sum(len(files) for _, _, files in os.walk(PROJECT_DIR))
    info['total_files'] = file_count
    return jsonify(info)

@app.route('/api/exec', methods=['POST'])
def exec_command():
    data = request.get_json(silent=True)
    if not data or 'command' not in data:
        return jsonify({"error": "فیلد command لازم است"}), 400
    cmd = data['command']
    timeout = data.get('timeout', 300)
    working_dir = data.get('working_dir')
    if not working_dir or not os.path.isdir(working_dir):
        working_dir = PROJECT_DIR

    try:
        result = subprocess.run(
            cmd, shell=True, cwd=working_dir,
            capture_output=True, text=True, timeout=timeout
        )
        return jsonify({
            "stdout": result.stdout,
            "stderr": result.stderr,
            "exit_code": result.returncode
        })
    except subprocess.TimeoutExpired:
        return jsonify({"error": f"زمان اجرا ({timeout}s) پایان یافت"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/exec-async', methods=['POST'])
def exec_async():
    data = request.get_json(silent=True)
    if not data or 'command' not in data:
        return jsonify({"error": "فیلد command لازم است"}), 400
    cmd = data['command']
    timeout = data.get('timeout', 300)
    working_dir = data.get('working_dir')
    if not working_dir or not os.path.isdir(working_dir):
        working_dir = PROJECT_DIR

    job_id = datetime.now().strftime('%Y%m%d%H%M%S%f')
    with cmd_lock:
        running_commands[job_id] = {
            "command": cmd,
            "status": "running",
            "stdout": [],
            "stderr": [],
            "exit_code": None
        }
    t = threading.Thread(target=_run_async_cmd, args=(job_id, cmd, timeout, working_dir))
    t.daemon = True
    t.start()
    return jsonify({"job_id": job_id, "status": "running"})

def _run_async_cmd(job_id, cmd, timeout, working_dir):
    try:
        process = subprocess.Popen(
            cmd, shell=True, cwd=working_dir,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        for line in process.stdout:
            with cmd_lock:
                if job_id in running_commands:
                    running_commands[job_id]['stdout'].append(line)
        for line in process.stderr:
            with cmd_lock:
                if job_id in running_commands:
                    running_commands[job_id]['stderr'].append(line)
        process.wait()
        with cmd_lock:
            if job_id in running_commands:
                running_commands[job_id]['status'] = 'done'
                running_commands[job_id]['exit_code'] = process.returncode
    except Exception as e:
        with cmd_lock:
            if job_id in running_commands:
                running_commands[job_id]['status'] = 'error'
                running_commands[job_id]['error'] = str(e)

@app.route('/api/exec-async/<job_id>')
def exec_async_status(job_id):
    with cmd_lock:
        if job_id not in running_commands:
            return jsonify({"error": "job_id نامعتبر"}), 404
        job = running_commands[job_id]
        resp = {
            "job_id": job_id,
            "command": job['command'],
            "status": job['status'],
            "stdout": ''.join(job['stdout']),
            "stderr": ''.join(job['stderr']),
            "exit_code": job['exit_code']
        }
        if job['status'] in ('done', 'error'):
            del running_commands[job_id]
        return jsonify(resp)

@app.route('/api/build', methods=['POST'])
def start_build():
    global build_state
    with build_lock:
        if build_state['status'] == 'running':
            return jsonify({"error": "یک بیلد در حال انجام است"}), 409
        build_state['status'] = 'running'
        build_state['log_lines'] = []
        build_state['apk_path'] = None
        build_state['error'] = None
        build_state['start_time'] = time.time()
        build_state['process'] = None
    t = threading.Thread(target=run_build)
    t.daemon = True
    t.start()
    return jsonify({"status": "running", "message": "بیلد شروع شد"})

def run_build():
    global build_state
    try:
        process = subprocess.Popen(
            ['flutter', 'build', 'apk', '--target-platform', 'android-arm64'],
            cwd=PROJECT_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1
        )
        with build_lock:
            build_state['process'] = process
        for line in iter(process.stdout.readline, ''):
            with build_lock:
                build_state['log_lines'].append(line)
        process.wait()
        success = process.returncode == 0
        if success:
            apk_src = os.path.join(PROJECT_DIR, 'build/app/outputs/flutter-apk/app-release.apk')
            if os.path.exists(apk_src):
                dest = os.path.join('static', 'latest.apk')
                os.makedirs('static', exist_ok=True)
                shutil.copy2(apk_src, dest)
                with build_lock:
                    build_state['status'] = 'success'
                    build_state['apk_path'] = dest
            else:
                with build_lock:
                    build_state['status'] = 'failed'
                    build_state['error'] = 'APK یافت نشد'
        else:
            with build_lock:
                build_state['status'] = 'failed'
                build_state['error'] = 'بیلد ناموفق'
    except Exception as e:
        with build_lock:
            build_state['status'] = 'failed'
            build_state['error'] = str(e)

@app.route('/api/build', methods=['GET'])
def build_status():
    with build_lock:
        apk_available = build_state['apk_path'] is not None and os.path.exists(build_state['apk_path'])
        return jsonify({
            "status": build_state['status'],
            "log": build_state['log_lines'],
            "apk_available": apk_available,
            "error": build_state['error'],
            "start_time": build_state.get('start_time')
        })

@app.route('/api/download')
def download_apk():
    with build_lock:
        if build_state['apk_path'] and os.path.exists(build_state['apk_path']):
            return send_file(build_state['apk_path'], as_attachment=True, download_name='app-arm64.apk')
    return jsonify({"error": "APK آماده نیست"}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, threaded=True)
