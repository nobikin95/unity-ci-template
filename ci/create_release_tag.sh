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

    # Kiểm tra tag có tồn tại không
    echo "Checking if tag $TAG_NAME exists..."
    CHECK_RESPONSE=$(curl --silent --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "$API_URL/$TAG_NAME?with_stats=false" --write-out "HTTP_STATUS:%{http_code}")
    CHECK_HTTP_STATUS=$(echo "$CHECK_RESPONSE" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)
    CHECK_BODY=$(echo "$CHECK_RESPONSE" | sed 's/HTTP_STATUS:[0-9]\+//')

    if [[ "$CHECK_HTTP_STATUS" == "200" ]]; then
        echo "Tag $TAG_NAME exists. Attempting to delete it."
        DELETE_RESPONSE=$(curl --silent --request DELETE --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" "$API_URL/$TAG_NAME" --write-out "HTTP_STATUS:%{http_code}")
        DELETE_HTTP_STATUS=$(echo "$DELETE_RESPONSE" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)

        if [[ "$DELETE_HTTP_STATUS" == "204" ]]; then
            echo "Successfully deleted tag $TAG_NAME."
        else
            echo "Failed to delete tag $TAG_NAME. HTTP Status: $DELETE_HTTP_STATUS"
            exit 1
        fi
    elif [[ "$CHECK_HTTP_STATUS" == "404" ]]; then
        echo "Tag $TAG_NAME does not exist. Proceeding to create it."
    else
        echo "Error checking tag $TAG_NAME. HTTP Status: $CHECK_HTTP_STATUS, Response: $CHECK_BODY"
        exit 1
    fi

    # Tạo tag mới
    PAYLOAD="{\"tag_name\":\"$TAG_NAME\",\"ref\":\"$CI_COMMIT_SHA\",\"message\":\"Tag created for release\"}"
    echo "Creating new tag: $TAG_NAME"
    CREATE_RESPONSE=$(curl --silent --request POST --header "PRIVATE-TOKEN: $GITLAB_API_TOKEN" \
      --header "Content-Type: application/json" \
      --data "$PAYLOAD" "$API_URL" --write-out "HTTP_STATUS:%{http_code}")
    CREATE_HTTP_STATUS=$(echo "$CREATE_RESPONSE" | grep -o "HTTP_STATUS:[0-9]\+" | cut -d':' -f2)
    CREATE_BODY=$(echo "$CREATE_RESPONSE" | sed 's/HTTP_STATUS:[0-9]\+//')

    if [[ "$CREATE_HTTP_STATUS" == "201" ]]; then
        echo "Tag $TAG_NAME created successfully (HTTP 201: Created)."
    else
        echo "Failed to create tag $TAG_NAME. HTTP Status: $CREATE_HTTP_STATUS, Response: $CREATE_BODY"
        exit 1
    fi
else
    echo "Not a push to release branch. Skipping tag creation."
fi