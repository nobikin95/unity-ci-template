import requests
import sys
import json

def send_slack_message(channel_id, message, slack_bot_token, attachments=None):
    """
    Gửi tin nhắn đến Slack channel và trả về timestamp (ts).

    Args:
        channel_id (str): ID của kênh Slack hoặc user ID.
        message (str): Nội dung tin nhắn.
        slack_bot_token (str): Token xác thực bot Slack.
        attachments (list, optional): Danh sách attachment (nếu có).

    Returns:
        str: Giá trị timestamp (ts) của tin nhắn vừa gửi, hoặc None nếu thất bại.
    """
    url = "https://slack.com/api/chat.postMessage"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {slack_bot_token}"
    }
    data = {
        "channel": channel_id,
        "text": message
    }
    
    if attachments:
        data["attachments"] = attachments
    
    response = requests.post(url, headers=headers, json=data)
    
    try:
        response_data = response.json()
        if response.status_code == 200 and response_data.get("ok"):
            ts = response_data.get("ts")
            if ts:
                print(ts)  # ✅ Chỉ in ra giá trị ts để dễ lấy trong GitLab CI/CD
                return ts
            else:
                print("❌ Error: Missing 'ts' in response.")
                sys.exit(1)
        else:
            error_message = response_data.get('error', 'Unknown error')
            print(f"❌ Failed to send message. Error: {error_message}")
            sys.exit(1)
    except json.JSONDecodeError:
        print("❌ Error: Unable to parse Slack API response.")
        sys.exit(1)


if __name__ == "__main__":
    # Kiểm tra tham số đầu vào
    if len(sys.argv) < 4:
        print("❌ Error: Missing arguments. Usage: send_slack_message.py <channel_id> <message> <slack_bot_token> [attachment_text]")
        sys.exit(1)
    
    # Lấy tham số từ dòng lệnh
    channel_id = sys.argv[1]
    message = sys.argv[2]
    slack_bot_token = sys.argv[3]
    attachment_text = sys.argv[4] if len(sys.argv) > 4 else None

    attachments = [{"text": attachment_text, "color": "#36a64f"}] if attachment_text else None
    
    # Gửi tin nhắn và nhận timestamp
    send_slack_message(channel_id, message, slack_bot_token, attachments)
