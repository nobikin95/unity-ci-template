#!/bin/bash

set -e

echo "🔧 Checking Xcode workspace/project setup..."

# Kiểm tra xem có workspace không
if [ -d "Unity-iPhone.xcworkspace" ]; then
  echo "✅ Xcode workspace found: Unity-iPhone.xcworkspace"
  exit 0
fi

# Kiểm tra xem có project không
if [ -d "Unity-iPhone.xcodeproj" ]; then
  echo "⚠️ Only Xcode project found, creating workspace..."
  
  # Tạo workspace từ project
  xcodebuild -project Unity-iPhone.xcodeproj -scheme Unity-iPhone -configuration Release -showBuildSettings | head -n 5
  
  # Kiểm tra lại xem workspace đã được tạo chưa
  if [ -d "Unity-iPhone.xcworkspace" ]; then
    echo "✅ Xcode workspace created successfully: Unity-iPhone.xcworkspace"
    exit 0
  else
    echo "⚠️ Workspace creation may have failed, but project is available"
    echo "✅ Will use project directly for build"
    exit 0
  fi
fi

echo "❌ No Xcode project or workspace found!"
exit 1 