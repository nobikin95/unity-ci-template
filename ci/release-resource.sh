#!/bin/bash
set -e

RESOURCE_NAME="$1"
if [ -z "$RESOURCE_NAME" ]; then
  echo "❌ ERROR: Missing resource name argument"
  exit 1
fi

REDIS_URL="${REDIS_URL:-redis://localhost:6379/0}"
LOCK_KEY="ci-lock:$RESOURCE_NAME"
LOCK_ID=$(cat /tmp/ci-lock-id 2>/dev/null || true)

if [ -z "$LOCK_ID" ]; then
  echo "⚠️ No lock ID found. Skipping unlock."
  exit 0
fi

CURRENT_LOCK=$(redis-cli -u "$REDIS_URL" get "$LOCK_KEY")

if [ "$CURRENT_LOCK" == "$LOCK_ID" ]; then
  redis-cli -u "$REDIS_URL" del "$LOCK_KEY"
  echo "🔓 Released lock for $RESOURCE_NAME (ID: $LOCK_ID)"
else
  echo "⚠️ Lock ID mismatch. Not releasing lock."
fi

rm -f /tmp/ci-lock-id
