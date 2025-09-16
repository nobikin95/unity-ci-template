#!/usr/bin/env python3
import os
import sys
import subprocess
import time
import json
import re
import requests

DEBUG = True

def debug(msg):
    if DEBUG:
        print("[DEBUG]", msg)

def error_exit(msg):
    print("[ERROR]", msg, file=sys.stderr)
    sys.exit(1)

SLACK_CHANNEL_ID = os.getenv('SLACK_CHANNEL_ID')
if not SLACK_CHANNEL_ID:
    print("SLACK_CHANNEL_ID environment variable not set")
    sys.exit(1)

SLACK_BOT_TOKEN = os.getenv('SLACK_BOT_TOKEN')
if not SLACK_BOT_TOKEN:
    print("SLACK_BOT_TOKEN environment variable not set")
    sys.exit(1)

SEND_SLACK_SCRIPT = os.path.join(os.path.dirname(__file__), "send_slack_message.py")
MESSAGE_TEMPLATES_FILE = os.path.join(os.path.dirname(__file__), "message_templates.json")

def load_message_template(template_key, **kwargs):
    try:
        with open(MESSAGE_TEMPLATES_FILE, "r", encoding="utf-8") as f:
            templates = json.load(f)
        if template_key in templates:
            message = templates[template_key].format(**kwargs)
            return message
        else:
            print(f"[ERROR] Message template '{template_key}' not found.")
            return None
    except Exception as e:
        print(f"[ERROR] Failed to load message templates: {e}")
        return None

def send_slack_notification(template_key, **kwargs):
    message = load_message_template(template_key, **kwargs)
    if message:
        try:
            subprocess.run(
                ["python3", SEND_SLACK_SCRIPT, SLACK_CHANNEL_ID, message, SLACK_BOT_TOKEN],
                check=True
            )
        except subprocess.CalledProcessError as e:
            print(f"[ERROR] Failed to send Slack message: {e}")

def main():
    os.environ["QT_QPA_PLATFORM"] = "xcb"
    os.environ["QT_QPA_PLATFORM_PLUGIN_PATH"] = os.path.expanduser("~/android-sdk/emulator/lib64/qt/plugins/platforms")

    apk_path = ""
    app_package = ""
    for arg in sys.argv[1:]:
        if arg.startswith("apkPath="):
            apk_path = arg.split("=", 1)[1]
        elif arg.startswith("appPackage="):
            app_package = arg.split("=", 1)[1]

    if not apk_path or not app_package:
        print("Usage: {} apkPath=<APK_PATH> appPackage=<APP_PACKAGE>".format(sys.argv[0]))
        sys.exit(1)

    debug("APK_PATH: {}".format(apk_path))
    debug("APP_PACKAGE: {}".format(app_package))

    API_KEY = "56oxTixtuLMwFtYM5LOmQQb0o96erGRI3A78FLB7UUUi1CwxOJJFFUANixRoNNkm"
    url = f"https://prms.ikameglobal.com/api/v1/npi/projects/get-by-app-id?app_id={app_package}"
    debug(f"Fetching expected token from URL: {url}")

    try:
        response = requests.get(url, headers={"apikey": API_KEY})
        response.raise_for_status()
    except Exception as e:
        error_exit("API request failed: " + str(e))

    try:
        data = response.json()
    except Exception as e:
        error_exit("Failed to parse JSON from API response: " + str(e))

    expected_token = data.get("adjust_token")
    if not expected_token or expected_token == "null":
        error_exit("adjust_token is null or not present in response: " + json.dumps(data))
    debug(f"Retrieved expected token: {expected_token}")

    #send_slack_notification("verify_token_start", project_name=app_package, expected_token=expected_token)

    android_sdk_root = os.path.expanduser("~/android-sdk")
    android_emulator = os.path.join(android_sdk_root, "emulator", "emulator")
    android_platform_tools = os.path.join(android_sdk_root, "platform-tools")

    debug("ANDROID_SDK_ROOT: {}".format(android_sdk_root))
    debug("ANDROID_EMULATOR: {}".format(android_emulator))
    debug("ANDROID_PLATFORM_TOOLS: {}".format(android_platform_tools))

    avd_name = "test_emulator"
    app_activity = "com.unity3d.player.UnityPlayerActivity"

    print("[DEBUG] Checking AVD list...")
    try:
        result = subprocess.run([android_emulator, "-list-avds"],
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                text=True,
                                check=True)
        avd_list = result.stdout.strip()
    except subprocess.CalledProcessError as e:
        error_exit("Failed to retrieve AVD list. Ensure Android SDK is correctly installed.\n" + e.stderr)
    debug(avd_list)

    print(f"[DEBUG] Starting Android Emulator: {avd_name}")
    try:
        emulator_proc = subprocess.Popen([android_emulator,
                                          "-avd", avd_name,
                                          "-no-audio",
                                          "-gpu", "swiftshader_indirect",
                                          "-no-window",
                                          "-wipe-data",
                                          "-ports", "5554,5555"],
                                          stdout=subprocess.DEVNULL,  # Thay PIPE bằng DEVNULL
                                          stderr=subprocess.DEVNULL)  # Thay PIPE bằng DEVNULL
    except Exception as e:
        error_exit("Failed to start emulator: " + str(e))
    debug(f"Emulator PID: {emulator_proc.pid}")

    adb = os.path.join(android_platform_tools, "adb")
    time.sleep(2)

    print("[DEBUG] Waiting for emulator to be ready...")
    try:
        subprocess.run([adb, "wait-for-device"], check=True)
    except subprocess.CalledProcessError:
        error_exit("Emulator did not become ready.")

    print("[DEBUG] Waiting for system boot to complete...")
    boot_completed = ""
    while boot_completed.strip() != "1":
        try:
            result = subprocess.run([adb, "shell", "getprop", "sys.boot_completed"],
                                    stdout=subprocess.PIPE,
                                    stderr=subprocess.PIPE,
                                    text=True)
            boot_completed = result.stdout.strip()
        except Exception as e:
            debug("Error checking boot_completed: " + str(e))
        time.sleep(1)
    print("[DEBUG] System boot completed.")
    time.sleep(10)

    print("[DEBUG] Checking connected devices...")
    try:
        subprocess.run([adb, "devices"], check=True)
    except subprocess.CalledProcessError:
        error_exit("Failed to check connected devices.")

    print("[DEBUG] Clearing logcat...")
    try:
        subprocess.run([adb, "logcat", "-c"], check=True)
    except subprocess.CalledProcessError:
        print("[WARNING] Clearing logcat failed, continuing anyway...")

    print(f"[DEBUG] Installing APK: {apk_path}")
    try:
        subprocess.run([adb, "install", "-r", apk_path], check=True)
    except subprocess.CalledProcessError:
        print("[ERROR] APK installation failed.")
        emulator_proc.terminate()
        sys.exit(1)

    print("[DEBUG] Launching APK...")
    component = f"{app_package}/{app_activity}"
    try:
        subprocess.run([adb, "shell", "am", "start", "-n", component], check=True)
    except subprocess.CalledProcessError:
        print("[ERROR] Failed to launch the app.")
        emulator_proc.terminate()
        sys.exit(1)

    print("[DEBUG] Waiting for the app to initialize and log data...")
    time.sleep(60)

    print("[DEBUG] Collecting logs...")
    try:
        with open("log.txt", "w") as log_file:
            subprocess.run([adb, "logcat", "-d"], stdout=log_file, check=True)
    except subprocess.CalledProcessError:
        print("[ERROR] Failed to collect logs.")
        emulator_proc.terminate()
        sys.exit(1)

    print("[DEBUG] Verifying token...")
    logged_token = ""
    try:
        with open("log.txt", "r") as f:
            for line in f:
                if "app_token" in line:
                    if "{" in line and "}" in line:
                        match = re.search(r'(\{.*\})', line)
                        if match:
                            json_part = match.group(1)
                            try:
                                log_data = json.loads(json_part)
                                token = log_data.get("app_token")
                                if token and token != "null":
                                    logged_token = token
                                    break
                            except json.JSONDecodeError:
                                continue
                    else:
                        match = re.search(r'app_token\s+([A-Za-z0-9]+)', line)
                        if match:
                            logged_token = match.group(1)
                            break
    except Exception as e:
        error_exit("Failed to process log file: " + str(e))

    if logged_token == expected_token:
        send_slack_notification("verify_token_success", project_name=app_package, expected_token=expected_token)
        print(f"[DEBUG] Token Matched: {logged_token}")
    else:
        SLACK_USER_IDS = os.getenv('SLACK_USER_IDS')
        tagged_users = " ".join([f"<@{user_id.strip()}>" for user_id in SLACK_USER_IDS.split(",")])
        send_slack_notification("verify_token_fail", project_name=app_package, expected_token=expected_token, current_token=logged_token, tagged_users=tagged_users)
        print(f"[ERROR] Token Mismatch! Logged: {logged_token}, Expected: {expected_token}")

    print("[DEBUG] Cleaning up...")
    try:
        subprocess.run([adb, "emu", "kill"], check=True)
        print("[DEBUG] Sent adb emu kill command successfully.")
    except subprocess.CalledProcessError:
        print("[WARNING] Failed to kill emulator with adb emu kill")

    # Chờ emulator kết thúc với timeout 30 giây
    try:
        emulator_proc.wait(timeout=30)
        print("[DEBUG] Emulator process terminated normally.")
    except subprocess.TimeoutExpired:
        print("[WARNING] Emulator did not terminate within 30 seconds, attempting to terminate...")
        emulator_proc.terminate()
        try:
            emulator_proc.wait(timeout=10)  # Chờ thêm 10 giây sau terminate
            print("[DEBUG] Emulator terminated after terminate().")
        except subprocess.TimeoutExpired:
            print("[ERROR] Emulator still running, forcing kill...")
            emulator_proc.kill()
            time.sleep(2)  # Đợi một chút để hệ thống xử lý

    # Kiểm tra trạng thái cuối cùng
    if emulator_proc.poll() is None:
        print("[ERROR] Emulator process is still running after kill!")
        send_slack_notification("cleanup_failed", project_name=app_package)
        sys.exit(1)  # Thoát với mã lỗi để CI/CD nhận diện vấn đề
    else:
        print("[DEBUG] Emulator process has been fully terminated.")

    print("[DEBUG] Test completed successfully.")
    sys.exit(0)

if __name__ == "__main__":
    main()
