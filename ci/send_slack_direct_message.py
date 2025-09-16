import os
import sys
import json
import requests

# Slack token for authentication
slack_token = os.getenv('SLACK_BOT_TOKEN')
if not slack_token:
    print("SLACK_BOT_TOKEN environment variable not set")
    sys.exit(1)

# Load message templates from a JSON file
template_file = os.path.join(os.path.dirname(__file__), "message_templates.json")
with open(template_file, "r") as file:
    message_templates = json.load(file)

def send_direct_message(user_id, message):
    """Send a direct message to a Slack user."""
    url = "https://slack.com/api/chat.postMessage"
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {slack_token}"
    }
    payload = {
        "channel": user_id,
        "text": message
    }

    response = requests.post(url, json=payload, headers=headers)
    if response.status_code == 200 and response.json().get("ok"):
        print(f"Message sent successfully to user {user_id}!")
    else:
        print(f"Error sending message to user {user_id}: {response.status_code}, {response.text}")

def filter_log(file_path):
    """Extract relevant log entries based on keywords."""
    keywords = [
        "error CS",               
        "Script Compilation Error",
        "> Reported",
        "Execution failed for task",
    ]
    extracted_lines = []

    try:
        with open(file_path, "r") as log_file:
            for line in log_file:
                if any(keyword in line for keyword in keywords):
                    extracted_lines.append(line.strip())

    except FileNotFoundError:
        print(f"Log file '{file_path}' not found.")
        return None

    return "\n\n".join(extracted_lines) if extracted_lines else None

def send_message(message_type, data):
    """Send a Slack message with filtered log content if available."""
    template = message_templates.get(message_type, "")
    if not template:
        print(f"Template for message type '{message_type}' not found.")
        return

    notify_users = data.get("notify_user")
    if not notify_users:
        print("No notify_user specified. Message not sent.")
        return

    user_ids = notify_users.split(',')
    for user_id in user_ids:
        user_id = user_id.strip()
        formatted_message = template.format(**data)

        log_file = data.get("log_file")
        if log_file and os.path.exists(log_file):
            filtered_log = filter_log(log_file)
            if filtered_log:
                formatted_message += f"\n\nFiltered Log:\n```\n{filtered_log}\n```"
            else:
                formatted_message += "\n\nNo relevant log entries found. Go to GitLab → Build → Jobs to download full log."

        # Thêm Change Log vào tin nhắn
        changelog = data.get("CHANGELOG")
        if changelog:
            formatted_message += f"\n\n*Change Log:*\n```\n{changelog}\n```"

        # Add shortened job link
        job_url = os.getenv('CI_JOB_URL', 'Job URL not available')
        formatted_message += f"\n\n[GitLab Build]({job_url})"

        send_direct_message(user_id, formatted_message)

def parse_arguments(args):
    """Parse command-line arguments into a dictionary."""
    parsed_args = {}
    for arg in args:
        if '=' in arg:
            key, value = arg.split("=", 1)
            parsed_args[key] = value
        else:
            print(f"Invalid argument format: {arg}")
    return parsed_args

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 send_slack_direct_message.py <message_type> [key=value ...]")
        sys.exit(1)

    message_type = sys.argv[1]
    data = parse_arguments(sys.argv[2:])
    send_message(message_type, data)
