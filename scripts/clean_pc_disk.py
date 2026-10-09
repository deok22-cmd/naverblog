import os
import sys
import shutil
import time
import json
import datetime
import ctypes

if sys.platform == "win32":
    try:
        sys.stdout.reconfigure(encoding='utf-8')
        sys.stderr.reconfigure(encoding='utf-8')
    except Exception:
        pass

def get_c_drive_space():
    """Returns (used_gb, free_gb, total_gb) for C: drive."""
    try:
        free_bytes = ctypes.c_ulonglong(0)
        total_bytes = ctypes.c_ulonglong(0)
        total_free = ctypes.c_ulonglong(0)
        ctypes.windll.kernel32.GetDiskFreeSpaceExW(
            ctypes.c_wchar_p("C:\\"),
            ctypes.byref(free_bytes),
            ctypes.byref(total_bytes),
            ctypes.byref(total_free)
        )
        total_gb = total_bytes.value / (1024**3)
        free_gb = free_bytes.value / (1024**3)
        used_gb = total_gb - free_gb
        return round(used_gb, 2), round(free_gb, 2), round(total_gb, 2)
    except Exception:
        return 0.0, 0.0, 0.0

def run_cleanup():
    start_time = time.time()
    deleted_files = 0
    deleted_bytes = 0
    failed_items = 0
    errors = []
    log_lines = []

    def log(msg):
        print(msg)
        log_lines.append(f"[{datetime.datetime.now().strftime('%H:%M:%S')}] {msg}")

    used_before, free_before, total_gb = get_c_drive_space()
    log(f"=== PC 디스크 정리 서브에이전트 가동 @ {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ===")
    log(f"C: 드라이브 현재 용량: {used_before} GB 사용 중 / {free_before} GB 여유 (전체 {total_gb} GB)")

    locked_items = 0

    def remove_file(filepath):
        nonlocal deleted_files, deleted_bytes, failed_items, locked_items
        try:
            sz = os.path.getsize(filepath)
            os.remove(filepath)
            deleted_files += 1
            deleted_bytes += sz
        except PermissionError:
            locked_items += 1
        except OSError as e:
            if getattr(e, 'winerror', None) in (32, 5):  # Sharing violation / In-use
                locked_items += 1
            else:
                failed_items += 1
                errors.append(f"파일 삭제 실패: {os.path.basename(filepath)} ({e})")
        except Exception as e:
            failed_items += 1
            errors.append(f"파일 삭제 실패: {os.path.basename(filepath)} ({e})")

    def remove_dir(dirpath):
        nonlocal deleted_files, deleted_bytes, failed_items, locked_items
        try:
            for root, dirs, files in os.walk(dirpath):
                for f in files:
                    fp = os.path.join(root, f)
                    try:
                        deleted_bytes += os.path.getsize(fp)
                        deleted_files += 1
                    except Exception:
                        pass
            shutil.rmtree(dirpath, ignore_errors=True)
        except Exception as e:
            failed_items += 1
            errors.append(f"폴더 삭제 실패: {dirpath} ({e})")

    def clean_dir_contents(dirpath):
        if not os.path.exists(dirpath):
            return
        for item in os.listdir(dirpath):
            ipath = os.path.join(dirpath, item)
            if os.path.isdir(ipath):
                remove_dir(ipath)
            else:
                remove_file(ipath)

    # 1. Hugging Face AI 모델 캐시
    hf_cache = os.path.expanduser(r"~/.cache/huggingface")
    if os.path.exists(hf_cache):
        log(f"  [1/8] Hugging Face 캐시 정리: {hf_cache}")
        remove_dir(hf_cache)

    # 2. NPM 패키지 캐시
    npm_cache = os.path.expanduser(r"~\AppData\Local\npm-cache")
    if os.path.exists(npm_cache):
        log(f"  [2/8] NPM 패키지 캐시 정리: {npm_cache}")
        remove_dir(npm_cache)

    # 3. Antigravity IDE 구버전 claude-code 확장 프로그램
    ext_dir = os.path.expanduser(r"~/.antigravity-ide/extensions")
    if os.path.exists(ext_dir):
        log(f"  [3/8] IDE 확장 프로그램 구버전 정리: {ext_dir}")
        claude_exts = [d for d in os.listdir(ext_dir) if d.startswith("anthropic.claude-code-2.1.")]
        claude_exts.sort()
        if len(claude_exts) > 1:
            for old_ext in claude_exts[:-1]:
                old_path = os.path.join(ext_dir, old_ext)
                log(f"        삭제: {old_ext}")
                remove_dir(old_path)

    # 4. agy.exe 자동 업데이트 구버전 백업 파일
    agy_bin = os.path.expanduser(r"~\AppData\Local\agy\bin")
    if os.path.exists(agy_bin):
        log(f"  [4/8] agy.exe 구버전 백업 파일 정리: {agy_bin}")
        for f in os.listdir(agy_bin):
            if f.startswith("agy.exe.") and f.endswith(".old"):
                log(f"        삭제: {f}")
                remove_file(os.path.join(agy_bin, f))

    # 5. 앱 자동 업데이터 다운로드 잔여 설치 파일
    log("  [5/8] 앱 구버전 설치 잔여 패키지 및 확장 휴지통 정리")
    updater_targets = [
        os.path.expanduser(r"~\AppData\Local\vrew-updater"),
        os.path.expanduser(r"~\AppData\Local\evernote-client-updater\pending"),
        os.path.expanduser(r"~\AppData\Local\obsidian-updater"),
        os.path.expanduser(r"~\AppData\Local\Figma\packages"),
        os.path.expanduser(r"~\AppData\Local\antigravity-updater"),
        os.path.expanduser(r"~\AppData\Roaming\npm\node_modules\@anthropic-ai\.claude-code-gASGwoeE"),
        os.path.expanduser(r"~\AppData\Roaming\Antigravity IDE\CachedExtensionVSIXs\.trash")
    ]
    for ut in updater_targets:
        if os.path.exists(ut):
            log(f"        정리: {ut}")
            remove_dir(ut)

    # 6. Windows Update 다운로드 캐시
    wu_download = r"C:\Windows\SoftwareDistribution\Download"
    if os.path.exists(wu_download):
        log(f"  [6/8] 윈도우 업데이트 다운로드 캐시 정리: {wu_download}")
        clean_dir_contents(wu_download)

    # 7. 사용자 Temp 임시 폴더
    user_temp = os.path.expanduser(r"~\AppData\Local\Temp")
    if os.path.exists(user_temp):
        log(f"  [7/8] 사용자 Temp 폴더 정리: {user_temp}")
        clean_dir_contents(user_temp)

    # 8. C:\Temp 및 C:\tmp 폴더
    for tp in [r"C:\Temp", r"C:\tmp"]:
        if os.path.exists(tp):
            log(f"  [8/8] 루트 임시 폴더 정리: {tp}")
            clean_dir_contents(tp)

    duration = round(time.time() - start_time, 2)
    used_after, free_after, _ = get_c_drive_space()
    freed_mb = round(deleted_bytes / (1024 * 1024), 2)
    freed_gb = round(freed_mb / 1024, 2)

    status = "SUCCESS" if len(errors) == 0 else "ERROR"
    summary = f"{deleted_files:,}개 파일 삭제 완료 ({freed_mb:,.1f} MB 확보, C: 여유 {free_after} GB)"
    if locked_items > 0:
        summary += f" (사용 중 {locked_items}개 안전 건너뜀)"

    log("\n=== 정리 완료 요약 ===")
    log(f"결과 상태     : {status}")
    log(f"소요 시간     : {duration}초")
    log(f"삭제된 파일   : {deleted_files:,}개")
    log(f"확보된 용량   : {freed_mb:,.1f} MB ({freed_gb} GB)")
    log(f"정리 후 C:여유: {free_after} GB (전체 {total_gb} GB)")
    if locked_items > 0:
        log(f"사용 중 건너뜀: {locked_items}개")
    if errors:
        log(f"오류 수       : {len(errors)}개")

    # Save state to subagents log directory
    project_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    subagent_logs_dir = os.path.join(project_root, ".scripts", "logs", "subagents")
    os.makedirs(subagent_logs_dir, exist_ok=True)

    state_path = os.path.join(subagent_logs_dir, "disk-cleaner.json")
    state_data = {
        "id": "disk-cleaner",
        "name": "PC 디스크 & 캐시 자동 청소기",
        "last_run": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "status": status,
        "duration_sec": duration,
        "metrics": {
            "deleted_files": deleted_files,
            "freed_mb": freed_mb,
            "freed_gb": freed_gb,
            "c_drive_free_gb": free_after,
            "c_drive_total_gb": total_gb,
            "locked_items": locked_items,
            "failed_items": failed_items
        },
        "summary": summary,
        "errors": errors[:10],
        "log_tail": log_lines[-15:]
    }

    with open(state_path, "w", encoding="utf-8") as f:
        json.dump(state_data, f, ensure_ascii=False, indent=2)

    return state_data

if __name__ == "__main__":
    run_cleanup()
