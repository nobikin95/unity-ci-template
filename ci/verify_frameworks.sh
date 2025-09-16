#!/bin/bash

set -e  # Dừng script nếu có lỗi nghiêm trọng

# Debug: Hiển thị shell version
echo "⚡ Running on shell: $SHELL"
echo "⚡ Running on Bash version: $BASH_VERSION"

# Tìm file .xcodeproj trong thư mục Build/iOS/
PROJECT_PATH=$(find Build/iOS/ -maxdepth 1 -name "*.xcodeproj" | head -n 1)
if [ -z "$PROJECT_PATH" ]; then
  echo "❌ No .xcodeproj file found in Build/iOS/"
  exit 1
fi

PBXPROJ_PATH="$PROJECT_PATH/project.pbxproj"
if [ ! -f "$PBXPROJ_PATH" ]; then
  echo "❌ No project.pbxproj file found in $PROJECT_PATH"
  exit 1
fi

echo "🔍 Found Xcode project: $PROJECT_PATH"
echo "🔍 Using pbxproj file: $PBXPROJ_PATH"

# Tạo backup trước khi sửa đổi
echo "📋 Creating backup of project.pbxproj..."
cp "$PBXPROJ_PATH" "$PBXPROJ_PATH.backup"

# Validate file gốc trước khi bắt đầu
echo "🔍 Validating original project.pbxproj..."
if ! plutil -lint "$PBXPROJ_PATH" >/dev/null 2>&1; then
  echo "❌ Original project.pbxproj is invalid. Cannot proceed."
  exit 1
fi
echo "✅ Original project.pbxproj is valid."

echo "🔍 Verifying required frameworks in Xcode project..."

wrong_embed_settings=()

# Hàm validate và rollback
validate_and_rollback() {
  local framework="$1"
  if ! plutil -lint "$PBXPROJ_PATH" >/dev/null 2>&1; then
    echo "❌ Project file became invalid after updating $framework. Restoring backup...";
    cp "$PBXPROJ_PATH.backup" "$PBXPROJ_PATH";
    return 1;
  fi
  return 0;
}

update_embed_setting() {
  local framework="$1"
  local expected_embed="$2"
  local embed_status="Do Not Embed"

  echo "🔍 Checking $framework ... (Expected: $expected_embed)"

  if grep -A1 "$framework" "$PBXPROJ_PATH" | grep -q "ATTRIBUTES = (CodeSignOnCopy"; then
    embed_status="Embed & Sign"
  elif grep -A1 "$framework" "$PBXPROJ_PATH" | grep -q "ATTRIBUTES = (RemoveHeadersOnCopy"; then
    embed_status="Embed"
  fi

  echo "   🔹 Embed setting detected: $embed_status"

  if [ "$embed_status" != "$expected_embed" ]; then
    echo "❌ $framework has incorrect Embed setting! Expected: $expected_embed, Found: $embed_status"
    wrong_embed_settings+=("$framework")

    # Cập nhật giá trị Embed setting với error handling
    echo "🔧 Fixing Embed setting for $framework..."
    case "$expected_embed" in
      "Do Not Embed")
        # Sử dụng sed với backup và validation
        sed -i.backup "/$framework/,/ATTRIBUTES = (/d" "$PBXPROJ_PATH" || {
          echo "❌ Failed to update embed setting for $framework";
          cp "$PBXPROJ_PATH.backup" "$PBXPROJ_PATH";
          return 1;
        }
        ;;
      "Embed & Sign")
        sed -i.backup "/$framework/s/ATTRIBUTES = (RemoveHeadersOnCopy);/ATTRIBUTES = (CodeSignOnCopy);/" "$PBXPROJ_PATH" || {
          echo "❌ Failed to update embed setting for $framework";
          cp "$PBXPROJ_PATH.backup" "$PBXPROJ_PATH";
          return 1;
        }
        ;;
    esac
    
    # Validate sau khi sửa đổi
    if ! validate_and_rollback "$framework"; then
      return 1;
    fi
    
    echo "✅ Fixed Embed setting for $framework"
  else
    echo "✅ $framework has correct Embed setting: $embed_status"
  fi
}

framework_list=(
  "AdServices.framework" "Do Not Embed"
  "AdSupport.framework" "Do Not Embed"
  "AppLovinQualityService.xcframework" "Embed & Sign"
  "AppLovinSDK.xcframework" "Embed & Sign"
  "AppTrackingTransparency.framework" "Do Not Embed"
  "InMobiSDK.xcframework" "Embed & Sign"
  "OMSDK_Appodeal.xcframework" "Embed & Sign"
  "Pods_Unity_iPhone.framework" "Do Not Embed"
  "StoreKit.framework" "Do Not Embed"
  "UnityFramework.framework" "Embed & Sign"
)

# Process frameworks với error handling
missing_frameworks=()
for ((i=0; i<${#framework_list[@]}; i+=2)); do
  framework_name="${framework_list[i]}"
  expected_embed="${framework_list[i+1]}"

  if grep -q "$framework_name" "$PBXPROJ_PATH"; then
    echo "✅ $framework_name found."
    if ! update_embed_setting "$framework_name" "$expected_embed"; then
      echo "❌ Failed to update $framework_name. Stopping verification."
      exit 1;
    fi
  else
    echo "❌ $framework_name is missing!"
    missing_frameworks+=("$framework_name")
  fi
done

# Kiểm tra nếu có framework missing
if [ ${#missing_frameworks[@]} -ne 0 ]; then
  echo ""
  echo "❌ Missing frameworks detected: ${missing_frameworks[@]}"
  echo "🔄 Need to rebuild Unity project to include missing frameworks"
  echo "📋 Missing frameworks:"
  for framework in "${missing_frameworks[@]}"; do
    echo "   - $framework"
  done
  echo ""
  exit 1
fi

# Kiểm tra Always Embed Swift Standard Libraries cho UnityFramework
echo "🔍 Checking Swift Standard Libraries setting..."
swift_setting=$(xcodebuild -project "$PROJECT_PATH" -target UnityFramework -configuration Release -showBuildSettings 2>/dev/null | grep "ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES" | awk '{print $3}' || echo "YES")
echo "🔹 Swift setting value: $swift_setting"

if [ "$swift_setting" != "NO" ]; then
  echo "❌ UnityFramework's Always Embed Swift Standard Libraries is not set to NO!"
  echo "🔧 Fixing Swift Standard Libraries setting..."
  
  # Backup trước khi sửa đổi Swift setting
  cp "$PBXPROJ_PATH" "$PBXPROJ_PATH.swift_backup"
  
  sed -i.swift_backup "s/ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES;/ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = NO;/" "$PBXPROJ_PATH" || {
    echo "❌ Failed to update Swift setting. Restoring backup...";
    cp "$PBXPROJ_PATH.swift_backup" "$PBXPROJ_PATH";
    exit 1;
  }
  
  # Validate sau khi sửa đổi Swift setting
  if ! validate_and_rollback "Swift setting"; then
    exit 1;
  fi
  
  echo "✅ Fixed Swift Standard Libraries setting"
  rm -f "$PBXPROJ_PATH.swift_backup"
else
  echo "✅ UnityFramework's Always Embed Swift Standard Libraries is correctly set to NO."
fi

# Final validation
echo ""
echo "🔍 Final validation of project.pbxproj..."
if ! plutil -lint "$PBXPROJ_PATH" >/dev/null 2>&1; then
  echo "❌ Final validation failed. Restoring original backup...";
  cp "$PBXPROJ_PATH.backup" "$PBXPROJ_PATH";
  exit 1;
fi
echo "✅ Final validation passed."

# Cleanup backup files
rm -f "$PBXPROJ_PATH.backup"

# Nếu có framework bị sửa, hiển thị thông báo và tiếp tục build
if [ ${#wrong_embed_settings[@]} -ne 0 ]; then
  echo ""
  echo "⚠️ Fixed wrong embed settings for: ${wrong_embed_settings[@]}"
  echo "🚀 Continuing with the build process..."
  echo ""
else
  echo ""
  echo "✅ All frameworks are correctly configured!"
  echo ""
fi
