#!/bin/bash

set -e

echo "🔧 Starting iOS build backup process..."

# Debug: Hiển thị thông tin hệ thống
echo "🔍 System information:"
echo "   - Current user: $(whoami)"
echo "   - Current directory: $(pwd)"
echo "   - CI_PROJECT_DIR: $CI_PROJECT_DIR"
echo "   - Available disk space:"
df -h | head -5
echo ""

# Debug: Kiểm tra quyền truy cập
echo "🔍 Checking permissions:"
echo "   - Can write to current directory: $(test -w . && echo "YES" || echo "NO")"
echo "   - Can write to CI_PROJECT_DIR: $(test -w "$CI_PROJECT_DIR" && echo "YES" || echo "NO")"
echo ""

# Kiểm tra build thành công
echo "🔍 Checking build artifacts..."
if [ ! -d "$CI_PROJECT_DIR/Build/iOS" ] || \
   ([ ! -d "$CI_PROJECT_DIR/Build/iOS/ExportedIPA_Release" ] && [ ! -d "$CI_PROJECT_DIR/Build/iOS/ExportedIPA_Dev" ]); then
  echo "❌ Không tìm thấy build iOS hoàn tất. Bỏ qua backup."
  echo "   - Build/iOS exists: $(test -d "$CI_PROJECT_DIR/Build/iOS" && echo "YES" || echo "NO")"
  echo "   - ExportedIPA_Release exists: $(test -d "$CI_PROJECT_DIR/Build/iOS/ExportedIPA_Release" && echo "YES" || echo "NO")"
  echo "   - ExportedIPA_Dev exists: $(test -d "$CI_PROJECT_DIR/Build/iOS/ExportedIPA_Dev" && echo "YES" || echo "NO")"
  exit 0
fi

# Backup
export BACKUP_DIR="/Volumes/external_disk/cicd/${PROJECT_NAME}"
export BUILD_DIR="$CI_PROJECT_DIR/Build/iOS"
export TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

if [ -d "$CI_PROJECT_DIR/Build/iOS/ExportedIPA_Release" ]; then
  export BUILD_TYPE="Release"
else
  export BUILD_TYPE="Development"
fi

# Store backup directly in the base directory (no timestamped subdirectory)
export BACKUP_PATH="$BACKUP_DIR"

echo "📋 Backup details:"
echo "   - Project: $PROJECT_NAME"
echo "   - Version: $IOS_VERSION"
echo "   - Build Type: $BUILD_TYPE"
echo "   - Timestamp: $TIMESTAMP"
echo "   - Backup Path: $BACKUP_PATH"
echo ""

# Debug: Kiểm tra thư mục backup
echo "🔍 Checking backup directory:"
echo "   - Backup directory: $BACKUP_DIR"
echo "   - Backup directory exists: $(test -d "$BACKUP_DIR" && echo "YES" || echo "NO")"
echo "   - Can write to backup directory: $(test -w "$BACKUP_DIR" 2>/dev/null && echo "YES" || echo "NO")"
echo "   - Can create backup directory: $(test -w "$(dirname "$BACKUP_DIR")" 2>/dev/null && echo "YES" || echo "NO")"
echo ""

# Thử tạo thư mục backup với fallback
echo "🔧 Creating backup directory..."
if ! mkdir -p "$BACKUP_DIR" 2>/dev/null; then
  echo "⚠️ Cannot create backup directory: $BACKUP_DIR"
  echo "🔧 Trying alternative backup location..."

  # Fallback: Sử dụng thư mục tạm
  export BACKUP_DIR="/tmp/cicd/${PROJECT_NAME}"
  export BACKUP_PATH="$BACKUP_DIR"

  echo "   - Alternative backup path: $BACKUP_PATH"

  if ! mkdir -p "$BACKUP_DIR" 2>/dev/null; then
    echo "❌ Cannot create alternative backup directory either"
    echo "🔍 Trying to create in current directory..."

    # Fallback cuối cùng: Sử dụng thư mục hiện tại
    export BACKUP_DIR="./backup/${PROJECT_NAME}"
    export BACKUP_PATH="$BACKUP_DIR"

    echo "   - Final backup path: $BACKUP_PATH"
    mkdir -p "$BACKUP_DIR"
  fi
fi

echo "✅ Backup directory created: $BACKUP_DIR"

# Remove existing backup if it exists
echo "🧹 Removing existing backup..."
if [ -d "$BACKUP_PATH/iOS" ]; then
  rm -rf "$BACKUP_PATH/iOS"
  echo "✅ Removed existing iOS backup"
fi
if [ -f "$BACKUP_PATH/metadata.json" ]; then
  rm -f "$BACKUP_PATH/metadata.json"
  echo "✅ Removed existing metadata"
fi

# Tạo backup
echo "🔧 Creating backup..."
BACKUP_SUCCESS=false
if cp -r "$BUILD_DIR" "$BACKUP_PATH/"; then
  echo "✅ Backup thành công: $BACKUP_PATH"
  du -sh "$BACKUP_PATH"
  BACKUP_SUCCESS=true
else
  echo "❌ Backup thất bại"
  echo "🔍 Debug information:"
  echo "   - Source exists: $(test -d "$BUILD_DIR" && echo "YES" || echo "NO")"
  echo "   - Source readable: $(test -r "$BUILD_DIR" && echo "YES" || echo "NO")"
  echo "   - Destination writable: $(test -w "$BACKUP_PATH" && echo "YES" || echo "NO")"
  echo "   - Available space:"
  df -h "$BACKUP_PATH"
  exit 1
fi

# Tạo metadata (chỉ khi backup thành công)
if [ "$BACKUP_SUCCESS" = true ]; then
  echo "🔧 Creating metadata..."
  cat > "$BACKUP_PATH/metadata.json" << EOF
{
  "project_name": "$PROJECT_NAME",
  "version": "$IOS_VERSION",
  "build_type": "$BUILD_TYPE",
  "backup_timestamp": "$TIMESTAMP",
  "git_commit": "$CI_COMMIT_SHA",
  "pipeline_id": "$CI_PIPELINE_ID",
  "backup_location": "$BACKUP_PATH"
}
EOF

  echo "✅ Metadata created: $BACKUP_PATH/metadata.json"
else
  echo "⚠️ Skipping metadata creation due to backup failure"
fi

# Xóa toàn bộ thư mục project sau khi backup thành công
if [ "$BACKUP_SUCCESS" = true ]; then
  echo "🧹 Cleaning up entire project directory after successful backup..."
  echo "📋 Project directory to be removed: $CI_PROJECT_DIR"

  # Kiểm tra xem có phải đang trong CI environment không
  if [[ "$CI_PROJECT_DIR" == "$CI_BUILDS_DIR"* ]] && [ -n "$CI_BUILDS_DIR" ]; then
    # Trong CI environment, xóa từ thư mục cha để tránh lỗi "cd"
    PARENT_DIR=$(dirname "$CI_PROJECT_DIR")
    BUILD_NAME=$(basename "$CI_PROJECT_DIR")

    echo "🔍 CI environment detected:"
    echo "   - Parent directory: $PARENT_DIR"
    echo "   - Build directory name: $BUILD_NAME"
    echo "   - Full path: $CI_PROJECT_DIR"

    # Chuyển đến thư mục cha trước khi xóa
    if cd "$PARENT_DIR" 2>/dev/null; then
      echo "🗑️ Removing project directory: $BUILD_NAME"
      if rm -rf "$BUILD_NAME" 2>/dev/null || sudo rm -rf "$BUILD_NAME" 2>/dev/null; then
        echo "✅ Successfully removed project directory: $BUILD_NAME"
      else
        echo "⚠️ Failed to remove project directory, but backup was successful"
      fi
    else
      echo "⚠️ Cannot change to parent directory, but backup was successful"
    fi
  else
    # Không trong CI environment hoặc đường dẫn không chuẩn
    echo "🗑️ Removing project directory: $CI_PROJECT_DIR"
    if rm -rf "$CI_PROJECT_DIR" 2>/dev/null || sudo rm -rf "$CI_PROJECT_DIR" 2>/dev/null; then
      echo "✅ Successfully removed project directory: $CI_PROJECT_DIR"
    else
      echo "⚠️ Failed to remove project directory, but backup was successful"
    fi
  fi
else
  echo "⚠️ Skipping project cleanup due to backup failure"
fi

echo "🎉 Backup and cleanup completed successfully!"
echo "📋 Final backup location: $BACKUP_PATH" 