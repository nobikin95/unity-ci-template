#!/bin/bash

# Biến mặc định
TARGET_BRANCH="develop"

# Kiểm tra tham số đầu vào
if [[ "$1" =~ --target_branch=.* ]]; then
  TARGET_BRANCH="${1#--target_branch=}"
else
  echo "Usage: $0 --target_branch=<branch_name>"
  exit 1
fi

# Lấy thông tin merge request đã được merge gần nhất vào nhánh được chỉ định
MERGE_REQUEST_INFO=$(curl --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "https://gitlab.ikameglobal.com/api/v4/projects/$CI_PROJECT_ID/merge_requests?state=merged&target_branch=$TARGET_BRANCH&order_by=updated_at&sort=desc" | jq '.[0]')

# Kiểm tra nếu không tìm thấy merge request nào
if [ -z "$MERGE_REQUEST_INFO" ] || [ "$MERGE_REQUEST_INFO" == "null" ]; then
  echo "No recent merged merge request found for branch $TARGET_BRANCH."
  export CHANGELOG=""
  export CLEAR_CACHE="false"
else
  # Lấy mô tả từ merge request gần nhất
  export MR_DESCRIPTION=$(echo "$MERGE_REQUEST_INFO" | jq -r '.description')
  export MERGER_NAME=$(echo "$MERGE_REQUEST_INFO" | jq -r '.merged_by.name')
  export MERGER_USERNAME=$(echo "$MERGE_REQUEST_INFO" | jq -r '.merged_by.username')
  echo "Merge Request Description:"
  echo "$MR_DESCRIPTION"
  echo "Merged by: $MERGER_NAME (@$MERGER_USERNAME)"
  echo "__________________________________"

  # Kiểm tra nếu mô tả không tuân theo template hoặc không có mô tả
  if [[ -z "$MR_DESCRIPTION" || ! "$MR_DESCRIPTION" =~ "## Change Log" ]]; then
    echo "Merge request description is invalid or missing."
    export CHANGELOG=""
    export CLEAR_CACHE="false"
  else
    # Trích xuất Change Log
    export CHANGELOG=$(echo "$MR_DESCRIPTION" | sed -n '/## Change Log/,/## Commits/{/## Commits/q;p}')
    echo "Change Log:"
    echo "__________________________________"
    echo "$CHANGELOG"
    echo "$CHANGELOG" > changelog.tmp
    # Thêm thông tin người merge vào changelog
    echo -e "\nMerged by: $MERGER_NAME (@$MERGER_USERNAME)" >> changelog.tmp
    echo "$MERGER_NAME (@$MERGER_USERNAME)" > merger.tmp

    # Trích xuất giá trị Clear Cache
    export CLEAR_CACHE=$(echo "$MR_DESCRIPTION" | grep -oP '(?<=## Clear_cache=).*' | tr -d '[:space:]')
    echo "Clear Cache value: $CLEAR_CACHE"
  fi
fi

# Kiểm tra nếu Clear Cache được đặt thành true và xóa thư mục /Library
if [ "$CLEAR_CACHE" == "true" ]; then
  if [ -d "./Library" ]; then
    echo "Clearing ./Library directory..."
    if rm -rf "./Library/"*; then
      echo "Successfully cleared ./Library directory."
    else
      echo "Failed to clear ./Library directory. Please check permissions."
    fi
    echo "Contents of ./Library after clearing (if any):"
    ls "./Library"
  else
    echo "./Library directory not found or not accessible."
  fi
else
  echo "Clear Cache is not set to true, skipping cache clear."
fi

