#!/bin/bash

echo "Checking for merge request merged into release branch..."

if [[ "$CI_PIPELINE_SOURCE" == "push" && "$CI_COMMIT_REF_NAME" == *release* ]]; then
    echo "Merge request successfully merged into release branch."

    if [[ -z "$1" ]]; then
        TAG_NAME="release/bundle_$AAB_VERSION"
    else
        TAG_NAME="$1"
    fi

    echo "Creating or updating tag: $TAG_NAME via GitLab API"

    # API Endpoint
    API_URL="https://gitlab.ikameglobal.com/api/v4/projects/$CI_PROJECT_ID/repository/tags"

    # Hàm để kiểm tra tag có tồn tại không
    check_tag_exists() {
        local tag_name="$1"
        local response=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "$API_URL/$tag_name" --write-out "HTTP_STATUS:%{http_code}")
        local http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)
        echo "$http_status"
    }

    # Hàm để xóa tag
    delete_tag() {
        local tag_name="$1"
        echo "Attempting to delete existing tag: $tag_name"
        local response=$(curl --silent --request DELETE --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "$API_URL/$tag_name" --write-out "HTTP_STATUS:%{http_code}")
        local http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)

        if [[ "$http_status" == "204" ]]; then
            echo "Successfully deleted tag $tag_name."
            # Chờ một chút để đảm bảo tag đã được xóa hoàn toàn
            sleep 2
            return 0
        elif [[ "$http_status" == "404" ]]; then
            echo "Tag $tag_name does not exist (404). Nothing to delete."
            return 0
        else
            echo "Failed to delete tag $tag_name. HTTP Status: $http_status"
            return 1
        fi
    }

    # Kiểm tra và xử lý tag tồn tại
    echo "Checking if tag $TAG_NAME exists..."
    TAG_CHECK_STATUS=$(check_tag_exists "$TAG_NAME")

    if [[ "$TAG_CHECK_STATUS" == "200" ]]; then
        echo "Tag $TAG_NAME already exists."
        if delete_tag "$TAG_NAME"; then
            echo "Tag deleted successfully. Proceeding to create new tag."
        else
            echo "Failed to delete existing tag. Exiting."
            exit 1
        fi
    elif [[ "$TAG_CHECK_STATUS" == "404" ]]; then
        echo "Tag $TAG_NAME does not exist. Proceeding to create it."
    else
        echo "Error checking tag $TAG_NAME. HTTP Status: $TAG_CHECK_STATUS"
        exit 1
    fi

    # Hàm để force delete và recreate tag với debug info
    force_recreate_tag() {
        local tag_name="$1"
        echo "Force recreating tag: $tag_name"

        # Thử xóa tag với debug info
        echo "Attempting to force delete tag..."
        local delete_response=$(curl --silent --request DELETE --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "$API_URL/$tag_name" --write-out "HTTP_STATUS:%{http_code}")
        local delete_status=$(echo "$delete_response" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)
        echo "Delete attempt result: HTTP $delete_status"

        # Chờ lâu hơn
        echo "Waiting 10 seconds for GitLab to process deletion..."
        sleep 10

        # Kiểm tra tag có còn tồn tại không
        local check_status=$(check_tag_exists "$tag_name")
        echo "Tag status after deletion attempt: $check_status"

        # Thử tạo tag với debug info
        local payload="{\"tag_name\":\"$tag_name\",\"ref\":\"$CI_COMMIT_SHA\",\"message\":\"Tag created for release\"}"
        echo "Attempting to create tag with payload: $payload"
        local response=$(curl --silent --request POST --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
          --header "Content-Type: application/json" \
          --data "$payload" "$API_URL" --write-out "HTTP_STATUS:%{http_code}")
        local http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)
        local body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]\+//')

        echo "Create response: HTTP $http_status, Body: $body"

        if [[ "$http_status" == "201" ]]; then
            echo "Tag $tag_name force recreated successfully."
            return 0
        else
            echo "Failed to force recreate tag $tag_name. HTTP Status: $http_status, Response: $body"

            # Nếu vẫn gặp lỗi "already exists", thử một cách khác
            if [[ "$http_status" == "400" && "$body" == *"already exists"* ]]; then
                echo "Tag still exists after force delete. Trying alternative approach..."

                # Thử tạo tag với tên tạm thời rồi đổi tên
                local temp_tag="${tag_name}_temp_$(date +%s)"
                echo "Creating temporary tag: $temp_tag"

                local temp_payload="{\"tag_name\":\"$temp_tag\",\"ref\":\"$CI_COMMIT_SHA\",\"message\":\"Temporary tag\"}"
                local temp_response=$(curl --silent --request POST --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
                  --header "Content-Type: application/json" \
                  --data "$temp_payload" "$API_URL" --write-out "HTTP_STATUS:%{http_code}")
                local temp_status=$(echo "$temp_response" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)

                if [[ "$temp_status" == "201" ]]; then
                    echo "Temporary tag created successfully. This confirms the issue is with the specific tag name."
                    # Xóa temp tag
                    curl --silent --request DELETE --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "$API_URL/$temp_tag" > /dev/null 2>&1
                    echo "This appears to be a GitLab API caching issue. The tag '$tag_name' is stuck in GitLab's cache."
                    echo "Manual intervention may be required to clear this tag from GitLab's system."
                    return 1
                else
                    echo "Failed to create temporary tag. There may be a broader API issue."
                    return 1
                fi
            fi

            return 1
        fi
    }

    # Hàm để tạo tag mới với retry logic
    create_tag() {
        local tag_name="$1"
        local max_attempts=3
        local attempt=1

        while [[ $attempt -le $max_attempts ]]; do
            echo "Creating new tag: $tag_name (attempt $attempt/$max_attempts)"

            local payload="{\"tag_name\":\"$tag_name\",\"ref\":\"$CI_COMMIT_SHA\",\"message\":\"Tag created for release\"}"
            local response=$(curl --silent --request POST --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
              --header "Content-Type: application/json" \
              --data "$payload" "$API_URL" --write-out "HTTP_STATUS:%{http_code}")
            local http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)
            local body=$(echo "$response" | sed 's/HTTP_STATUS:[0-9]\+//')

            if [[ "$http_status" == "201" ]]; then
                echo "Tag $tag_name created successfully (HTTP 201: Created)."
                return 0
            elif [[ "$http_status" == "400" && "$body" == *"already exists"* ]]; then
                echo "Tag $tag_name still exists. Checking current status and trying to delete..."

                # Kiểm tra lại trạng thái tag
                local check_status=$(check_tag_exists "$tag_name")
                if [[ "$check_status" == "200" ]]; then
                    echo "Tag confirmed to exist. Attempting to delete..."
                    if delete_tag "$tag_name"; then
                        echo "Tag deleted successfully. Attempting to create again..."
                        ((attempt++))
                        continue
                    else
                        echo "Failed to delete existing tag. Trying force recreate..."
                        if force_recreate_tag "$tag_name"; then
                            return 0
                        else
                            return 1
                        fi
                    fi
                else
                    echo "Tag check returned status $check_status. This might be a race condition."
                    if [[ $attempt -eq $max_attempts ]]; then
                        echo "Last attempt - trying force recreate..."
                        if force_recreate_tag "$tag_name"; then
                            return 0
                        else
                            return 1
                        fi
                    else
                        echo "Waiting 5 seconds and retrying creation..."
                        sleep 5
                        ((attempt++))
                        continue
                    fi
                fi
            else
                echo "Failed to create tag $tag_name. HTTP Status: $http_status, Response: $body"
                if [[ $attempt -lt $max_attempts ]]; then
                    echo "Retrying in 3 seconds..."
                    sleep 3
                    ((attempt++))
                else
                    return 1
                fi
            fi
        done

        echo "Failed to create tag after $max_attempts attempts."
        return 1
    }

    # Hàm để thử "flush" GitLab cache
    try_flush_cache() {
        local original_tag="$1"
        echo "Attempting to flush GitLab cache for tag: $original_tag"

        # Tạo một tag dummy để "wake up" GitLab API
        local dummy_tag="cache_flush_$(date +%s)"
        echo "Creating dummy tag: $dummy_tag"

        local dummy_payload="{\"tag_name\":\"$dummy_tag\",\"ref\":\"$CI_COMMIT_SHA\",\"message\":\"Cache flush dummy tag\"}"
        local dummy_response=$(curl --silent --request POST --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
          --header "Content-Type: application/json" \
          --data "$dummy_payload" "$API_URL" --write-out "HTTP_STATUS:%{http_code}")
        local dummy_status=$(echo "$dummy_response" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)

        if [[ "$dummy_status" == "201" ]]; then
            echo "Dummy tag created. Deleting it immediately..."
            curl --silent --request DELETE --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "$API_URL/$dummy_tag" > /dev/null 2>&1
            sleep 3

            echo "Cache flush attempt completed. Trying to create original tag again..."
            local payload="{\"tag_name\":\"$original_tag\",\"ref\":\"$CI_COMMIT_SHA\",\"message\":\"Tag created for release\"}"
            local response=$(curl --silent --request POST --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
              --header "Content-Type: application/json" \
              --data "$payload" "$API_URL" --write-out "HTTP_STATUS:%{http_code}")
            local http_status=$(echo "$response" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)

            if [[ "$http_status" == "201" ]]; then
                echo "Success! Tag $original_tag created after cache flush."
                return 0
            else
                echo "Cache flush didn't help. HTTP Status: $http_status"
                return 1
            fi
        else
            echo "Failed to create dummy tag. Cache flush not possible."
            return 1
        fi
    }

    # Tạo tag mới
    if create_tag "$TAG_NAME"; then
        echo "Tag creation process completed successfully."
    else
        echo "Tag creation process failed. Trying cache flush approach..."

        if try_flush_cache "$TAG_NAME"; then
            echo "Tag creation completed successfully after cache flush."
        else
            echo "Cache flush failed. Trying fallback approach..."

            # Fallback: tạo tag với timestamp
            TIMESTAMP=$(date +%Y%m%d_%H%M%S)
            FALLBACK_TAG_NAME="${TAG_NAME}_${TIMESTAMP}"
            echo "Attempting to create fallback tag: $FALLBACK_TAG_NAME"

            PAYLOAD="{\"tag_name\":\"$FALLBACK_TAG_NAME\",\"ref\":\"$CI_COMMIT_SHA\",\"message\":\"Fallback tag created for release (original: $TAG_NAME)\"}"
            RESPONSE=$(curl --silent --request POST --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
              --header "Content-Type: application/json" \
              --data "$PAYLOAD" "$API_URL" --write-out "HTTP_STATUS:%{http_code}")
            HTTP_STATUS=$(echo "$RESPONSE" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)

            if [[ "$HTTP_STATUS" == "201" ]]; then
                echo "Fallback tag $FALLBACK_TAG_NAME created successfully."
                echo "WARNING: Original tag name '$TAG_NAME' could not be created due to GitLab API issues."
                echo "Please manually delete the problematic tag '$TAG_NAME' from GitLab and rename '$FALLBACK_TAG_NAME' to '$TAG_NAME' if needed."
            else
                echo "Both original and fallback tag creation failed."
                exit 1
            fi
        fi
    fi
else
    echo "Not a push to release branch. Skipping tag creation."
fi