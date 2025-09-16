import os
import sys
import time
import requests
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

# Lấy Slack token từ biến môi trường
BOT_TOKEN = os.getenv("SLACK_BOT_TOKEN")
if not BOT_TOKEN:
    print("Error: SLACK_BOT_TOKEN is not set. Please set the environment variable and try again.")
    sys.exit(1)

# Kiểm tra tham số đầu vào
if len(sys.argv) < 3:
    print("Error: Missing arguments. Usage: send_slack_file_dm.py <file_path> <commit_message> [user_ids]")
    sys.exit(1)

file_path = sys.argv[1]
commit_message = sys.argv[2]
user_ids = sys.argv[3].split(",") if len(sys.argv) > 3 else []  # Nhận danh sách user_ids từ tham số

# Thêm tag người dùng vào commit_message nếu có user_ids
if user_ids:
    tagged_users = " ".join([f"<@{user_id.strip()}>" for user_id in user_ids if user_id.strip()])
    commit_message = f"\n{commit_message}\n{tagged_users}"

print("Commit message received:", commit_message)

# Định nghĩa API URLs
GET_UPLOAD_URL_API = "https://slack.com/api/files.getUploadURLExternal"
COMPLETE_UPLOAD_API = "https://slack.com/api/files.completeUploadExternal"

# Hàm lấy URL upload và file ID
def get_upload_url(filename, length):
    headers = {"Authorization": f"Bearer {BOT_TOKEN}"}
    data = {
        "filename": filename,
        "length": length
    }
    response = requests.post(GET_UPLOAD_URL_API, headers=headers, data=data, timeout=300)
    response_data = response.json()

    if not response_data.get("ok"):
        raise Exception(f"Error getting upload URL: {response_data.get('error')}")
    
    print("Upload URL retrieved successfully.")
    return response_data["upload_url"], response_data["file_id"]

# Hàm upload file lên URL
def upload_file_to_url(upload_url, file_path):
    with open(file_path, 'rb') as f:
        response = requests.post(upload_url, files={"file": f}, timeout=300)
    
    if response.status_code != 200:
        raise Exception(f"Error uploading file: {response.text}")
    
    print("File uploaded successfully.")

# Hàm hoàn tất quá trình upload
def complete_upload(file_id, title, channel_id, initial_comment):
    headers = {"Authorization": f"Bearer {BOT_TOKEN}", "Content-Type": "application/json"}
    payload = {
        "files": [
            {"id": file_id, "title": title}
        ],
        "channel_id": channel_id,
        "initial_comment": initial_comment
    }
    response = requests.post(COMPLETE_UPLOAD_API, headers=headers, json=payload, timeout=300)
    response_data = response.json()

    if not response_data.get("ok"):
        raise Exception(f"Error completing upload: {response_data.get('error')}")
    
    print("Upload process completed successfully.")
    return response_data

# Hàm chính để upload file tới DM của người dùng
def upload_file_to_user(user_id, file_path, commit_message):
    max_retries = 3  # Số lần thử lại tối đa
    retry_delay = 3  # Thời gian chờ giữa các lần thử (giây)
    timeout_duration = 300  # Thời gian timeout cho mỗi request (giây)

    for attempt in range(max_retries):
        try:
            print(f"Attempt {attempt + 1} of {max_retries}")
            
            # Mở kênh DM với người dùng
            client = WebClient(token=BOT_TOKEN)
            dm_response = client.conversations_open(users=user_id)
            dm_channel_id = dm_response['channel']['id']
            
            # Lấy thông tin file
            file_name = os.path.basename(file_path)
            file_size = os.path.getsize(file_path)
            
            # Bước 1: Lấy URL upload và file ID
            print("Step 1: Getting upload URL and file ID...")
            upload_url, file_id = get_upload_url(file_name, file_size)
            
            # Bước 2: Upload file lên URL
            print("Step 2: Uploading file to the upload URL...")
            upload_file_to_url(upload_url, file_path)
            
            # Bước 3: Hoàn tất upload và gửi file vào DM
            print("Step 3: Completing the upload process...")
            complete_upload(file_id, file_name, dm_channel_id, commit_message)
            
            break  # Thoát vòng lặp nếu thành công
        except SlackApiError as e:
            print(f"Slack API error (attempt {attempt + 1}): {e.response['error']}")
        except Exception as e:
            print(f"Unexpected error (attempt {attempt + 1}): {e}")
        
        # Đợi trước khi thử lại nếu chưa phải lần cuối
        if attempt < max_retries - 1:
            print(f"Retrying in {retry_delay} seconds...")
            time.sleep(retry_delay)
    else:
        print("Failed to upload file after multiple attempts.")

# Chạy script
if __name__ == "__main__":
    if not user_ids:
        print("Error: No user IDs provided. Please specify at least one user ID.")
        sys.exit(1)

    for user_id in user_ids:
        upload_file_to_user(user_id.strip(), file_path, commit_message)