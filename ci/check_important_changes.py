import json
import requests
import sys
import os
import fnmatch
import subprocess

def load_important_files(file_path):
    if not os.path.exists(file_path):
        print(f"Error: File {file_path} not found.")
        sys.exit(1)
    with open(file_path, "r") as f:
        return json.load(f)

def get_changed_files(api_url, token):
    headers = {"PRIVATE-TOKEN": token}
    try:
        response = requests.get(api_url, headers=headers)
        response.raise_for_status()
        changes = response.json().get("changes", [])
        
        # Debug: In tất cả các file thay đổi
        print("\n[DEBUG] Full list of changed files:")
        for change in changes:
            print(f"  - {change['new_path']}")
        
        return [change["new_path"] for change in changes]
    except requests.exceptions.RequestException as e:
        print(f"Error connecting to API: {e}")
        print(f"API URL: {api_url}")
        sys.exit(1)

def match_files(changed_files, important_files):
    matched_files = []
    for pattern in important_files:
        for changed_file in changed_files:
            if fnmatch.fnmatch(changed_file, pattern):  # Match using fnmatch
                matched_files.append(changed_file)
    return matched_files

def notify_via_slack(message_type, project_name, notify_user, matched_files):
    changed_files_str = ''.join(f'- {file}\n' for file in matched_files)
    try:
        args = [
            "python3", "./ci/send_slack_direct_message.py", 
            message_type, 
            f"project_name={project_name}", 
            f"changed_files={changed_files_str}",
            f"notify_user={notify_user}"
        ]
        subprocess.run(args, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error sending Slack message: {e}")

def main():
    if len(sys.argv) < 4:
        print("Usage: python3 check_important_changes.py <api_url> <gitlab_token> <project_name> <notify_user>")
        sys.exit(1)

    api_url = sys.argv[1]
    gitlab_token = sys.argv[2]
    project_name = sys.argv[3]
    notify_user = sys.argv[4]  # Danh sách người nhận thông báo

    important_files = load_important_files("./ci/important_files.json")
    changed_files = get_changed_files(api_url, gitlab_token)
    
    # Debug: Liệt kê các file quan trọng bị thay đổi
    print("\n[DEBUG] Checking important file patterns:")
    matched_files = match_files(changed_files, important_files)
    for file in matched_files:
        print(f"  - Matched: {file}")
    
    if matched_files:
        notify_via_slack("warning_message", project_name, notify_user, matched_files)
    else:
        print("No critical file changes detected.")

if __name__ == "__main__":
    main()
