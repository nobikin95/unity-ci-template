#!/usr/bin/env python3
import requests
import sys
import re

# Kiểm tra tham số đầu vào
if len(sys.argv) < 3:
    print("Usage: fetch_replace_ids_config.py <APP_PACKAGE> <PLATFORM>")
    sys.exit(1)

app_package = sys.argv[1]
platform = int(sys.argv[2])  # 0: Android, 1: iOS

# API Key thực tế
API_KEY = "56oxTixtuLMwFtYM5LOmQQb0o96erGRI3A78FLB7UUUi1CwxOJJFFUANixRoNNkm"

# URL API để lấy adjust_token và adjust_in_app_purchase_android
url = f"https://prms.ikameglobal.com/api/v1/npi/projects/get-by-app-id?app_id={app_package}"
print(f"Fetching adjust tokens from: {url}")

try:
    response = requests.get(url, headers={"apikey": API_KEY})
    response.raise_for_status()
    data = response.json()

    adjust_token = data.get("adjust_token", "")
    adjust_iap_id = data.get("adjust_in_app_purchase_android", "")

    if not adjust_token or adjust_token == "null":
        print("Error: adjust_token is null or missing")
        sys.exit(1)

    if not adjust_iap_id or adjust_iap_id == "null":
        print("Error: adjust_in_app_purchase_android is null or missing")
        sys.exit(1)

    print(f"Retrieved Adjust Token: {adjust_token}")
    print(f"Retrieved Adjust IAP ID: {adjust_iap_id}")

except Exception as e:
    print(f"Error: Failed to fetch data - {e}")
    sys.exit(1)

# Đường dẫn đến file IDsConfig.asset
config_path = "Assets/Resources/IDsConfig.asset"

# Đọc nội dung file gốc
try:
    with open(config_path, "r", encoding="utf-8") as file:
        content = file.readlines()
except Exception as e:
    print(f"Error: Failed to read IDsConfig.asset - {e}")
    sys.exit(1)

# Chỉnh sửa giá trị adjustAppToken và adjustIapID cho đúng platform
updated_content = []
in_target_platform = False

for line in content:
    if f"platform: {platform}" in line:
        in_target_platform = True
    elif "platform:" in line:  # Nếu gặp platform khác, reset trạng thái
        in_target_platform = False

    if in_target_platform:
        if "adjustAppToken:" in line:
            line = f"    adjustAppToken: {adjust_token}\n"
        elif "adjustIapID:" in line:
            line = f"    adjustIapID: {adjust_iap_id}\n"

    updated_content.append(line)

# Ghi đè lại file
try:
    with open(config_path, "w", encoding="utf-8") as file:
        file.writelines(updated_content)
    print(f"Updated adjustAppToken and adjustIapID for platform {platform}")
except Exception as e:
    print(f"Error: Failed to update IDsConfig.asset - {e}")
    sys.exit(1)
