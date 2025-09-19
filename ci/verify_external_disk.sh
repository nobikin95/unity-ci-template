#!/bin/bash

# Script to verify external disk availability for iOS build backup
# This script checks if the external disk is mounted and accessible

set -e

echo "🔍 Verifying external disk for iOS build backup..."

# Define external disk path (adjust as needed)
EXTERNAL_DISK_PATH="${EXTERNAL_DISK_PATH:-/Volumes/ExternalDisk}"
BACKUP_BASE_PATH="${BACKUP_BASE_PATH:-$EXTERNAL_DISK_PATH/iOS_Builds}"

# Check if external disk path is mounted
if [ ! -d "$EXTERNAL_DISK_PATH" ]; then
    echo "⚠️ External disk not found at: $EXTERNAL_DISK_PATH"
    echo "ℹ️ Backup will be skipped or use alternative location"
    exit 0
fi

# Check if the disk is writable
if [ ! -w "$EXTERNAL_DISK_PATH" ]; then
    echo "⚠️ External disk is not writable: $EXTERNAL_DISK_PATH"
    echo "ℹ️ Backup will be skipped"
    exit 0
fi

# Check available space (at least 1GB)
AVAILABLE_SPACE=$(df "$EXTERNAL_DISK_PATH" | awk 'NR==2 {print $4}')
MIN_SPACE_KB=$((1024 * 1024))  # 1GB in KB

if [ "$AVAILABLE_SPACE" -lt "$MIN_SPACE_KB" ]; then
    echo "⚠️ Insufficient space on external disk: $(($AVAILABLE_SPACE / 1024))MB available"
    echo "ℹ️ Minimum required: 1GB"
    exit 0
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_BASE_PATH"

echo "✅ External disk verification passed"
echo "📍 Disk path: $EXTERNAL_DISK_PATH"
echo "💾 Available space: $(($AVAILABLE_SPACE / 1024))MB"
echo "📁 Backup path: $BACKUP_BASE_PATH"

exit 0
