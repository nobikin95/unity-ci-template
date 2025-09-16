import os
import sys
import requests
import time

# Slack token từ biến môi trường
BOT_TOKEN = os.getenv("SLACK_BOT_TOKEN")
if not BOT_TOKEN:
    print("Error: SLACK_BOT_TOKEN is not set. Please set the environment variable and try again.")
    sys.exit(1)

# Kiểm tra tham số đầu vào
if len(sys.argv) < 3:
    print("Error: Missing arguments. Usage: upload_slack.py <file_path> <commit_message> [user_ids]")
    sys.exit(1)

file_path = sys.argv[1]
commit_message = sys.argv[2]
user_ids = sys.argv[3].split(",") if len(sys.argv) > 3 else []  # Nhận user_ids từ dòng lệnh

# Thêm các tag người dùng vào commit_message nếu có user_ids
if user_ids:
    tagged_users = " ".join([f"<@{user_id.strip()}>" for user_id in user_ids if user_id.strip()])
    commit_message = f"\n{commit_message}\n{tagged_users}"

print("Commit message received:", commit_message)

# API URLs
GET_UPLOAD_URL_API = "https://slack.com/api/files.getUploadURLExternal"
COMPLETE_UPLOAD_API = "https://slack.com/api/files.completeUploadExternal"

def get_upload_url(filename, length):
    headers = {"Authorization": f"Bearer {BOT_TOKEN}"}
    data = {
        "filename": filename,
        "length": length
    }
    response = requests.post(GET_UPLOAD_URL_API, headers=headers, data=data)
    response_data = response.json()

    if not response_data.get("ok"):
        print("Error getting upload URL:", response_data.get("error"))
        sys.exit(1)

    print("Upload URL retrieved successfully.")
    return response_data["upload_url"], response_data["file_id"]

def upload_file_to_url(upload_url, file_path):
    with open(file_path, 'rb') as f:
        response = requests.post(upload_url, files={"file": f})

    if response.status_code == 200:
        print("File uploaded successfully.")
    else:
        print("Error uploading file:", response.text)
        sys.exit(1)

def complete_upload(file_id, title, channel_id=None, initial_comment=None):
    headers = {"Authorization": f"Bearer {BOT_TOKEN}", "Content-Type": "application/json"}
    payload = {
        "files": [
            {"id": file_id, "title": title}
        ]
    }
    # Thêm các tham số tùy chọn nếu có
    if channel_id:
        payload["channel_id"] = channel_id
    if initial_comment:
        payload["initial_comment"] = initial_comment

    response = requests.post(COMPLETE_UPLOAD_API, headers=headers, json=payload)
    response_data = response.json()

    if not response_data.get("ok"):
        print("Error completing upload:", response_data.get("error"))
        sys.exit(1)

    print("Upload process completed successfully.")
    return response_data

if __name__ == "__main__":
    # Lấy channel_id từ biến môi trường GitLab CI
    channel_id = os.getenv("SLACK_CHANNEL_ID")
    if not channel_id:
        print("Error: SLACK_CHANNEL_ID is not set. Please set the environment variable and try again.")
        sys.exit(1)

    file_name = os.path.basename(file_path)
    file_size = os.path.getsize(file_path)

    # Step 1: Lấy URL upload và file ID
    print("Step 1: Getting upload URL and file ID...")
    upload_url, file_id = get_upload_url(file_name, file_size)

    # Step 2: Upload file qua URL được cung cấp
    print("Step 2: Uploading file to the upload URL...")
    upload_file_to_url(upload_url, file_path)

    # Step 3: Hoàn tất upload
    print("Step 3: Completing the upload process...")
    complete_upload(file_id, file_name, channel_id, commit_message)
