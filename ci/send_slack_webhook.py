import os
import sys
import json
import requests

# Slack Webhook URL
webhook_url = "https://hooks.slack.com/services/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"

# Đọc template từ file JSON
with open(os.path.join(os.path.dirname(__file__), "message_templates.json"), "r") as file:
    message_templates = json.load(file)

def send_message(message_type, data):
    template = message_templates.get(message_type, "")
    if not template:
        print(f"Không tìm thấy template cho loại tin nhắn: {message_type}")
        return

    # Format message từ template và dữ liệu
    formatted_message = template.format(**data)
    payload = {"text": formatted_message}

    # Gửi yêu cầu POST qua webhook
    response = requests.post(webhook_url, json=payload)
    if response.status_code == 200:
        print("Tin nhắn đã được gửi thành công!")
    else:
        print(f"Lỗi khi gửi tin nhắn: {response.text}")

def parse_arguments(args):
    parsed_args = {}
    for arg in args:
        if '=' in arg:
            key, value = arg.split("=", 1)  # Chỉ tách lần đầu tiên dấu '='
            parsed_args[key] = value
        else:
            print(f"Invalid argument format: {arg}")
    return parsed_args

if __name__ == "__main__":
    message_type = sys.argv[1]
    data = parse_arguments(sys.argv[2:])
    send_message(message_type, data)
