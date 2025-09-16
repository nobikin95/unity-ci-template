#!/bin/bash
set -e

RESOURCE_NAME="$1"
if [ -z "$RESOURCE_NAME" ]; then
  echo "❌ ERROR: Missing resource name argument"
  exit 1
fi

REDIS_URL="${REDIS_URL:-redis://localhost:6379/0}"
TIMEOUT_SECONDS="${WAIT_FOR_RESOURCE_TIMEOUT_SECONDS:-1800}"
POLL_INTERVAL_SECONDS="${WAIT_FOR_RESOURCE_POLL_INTERVAL_SECONDS:-5}"
LOCK_TTL_SECONDS="${LOCK_TTL_SECONDS:-600}"  # TTL default is 10 mins

START_TIME=$(date +%s)
SCRIPT_ID=$(uuidgen)
echo "🔄 Waiting for resource: $RESOURCE_NAME (ID: $SCRIPT_ID)"

while true; do
  CURRENT_TIME=$(date +%s)
  ELAPSED=$((CURRENT_TIME - START_TIME))

  if [ "$ELAPSED" -ge "$TIMEOUT_SECONDS" ]; then
    echo "⏰ Timeout after $ELAPSED seconds waiting for resource $RESOURCE_NAME"
    exit 1
  fi

  CURRENT_LOCK=$(redis-cli -u "$REDIS_URL" get "ci-lock:$RESOURCE_NAME")

  if [ -z "$CURRENT_LOCK" ]; then
    # Set keys wit TTL (in seconds)
    redis-cli -u "$REDIS_URL" set "ci-lock:$RESOURCE_NAME" "$SCRIPT_ID" EX "$LOCK_TTL_SECONDS"
    echo "✅ Acquired lock for  $RESOURCE_NAME (ID: $SCRIPT_ID) with TTL $LOCK_TTL_SECONDS seconds"
    echo "$SCRIPT_ID" > /tmp/ci-lock-id
    break
  else
    echo "⏳ Resource $RESOURCE_NAME is locked by $CURRENT_LOCK. Waiting..."
    sleep "$POLL_INTERVAL_SECONDS"
  fi
done