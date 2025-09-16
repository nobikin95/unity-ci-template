#!/bin/bash

PROJECT_SETTINGS_FILE="ProjectSettings/ProjectSettings.asset"

# Kiểm tra nếu file không tồn tại
if [[ ! -f "$PROJECT_SETTINGS_FILE" ]]; then
    echo "❌ Error: File $PROJECT_SETTINGS_FILE not found!"
    exit 1
fi

# Phân tích các tham số dòng lệnh
for arg in "$@"; do
    case $arg in
        --add_define_symbol=*)
            ADD_DEFINE_SYMBOLS="${arg#*=}"
            ;;
        --remove_define_symbol=*)
            REMOVE_DEFINE_SYMBOLS="${arg#*=}"
            ;;
        *)
            echo "Usage: $0 [--add_define_symbol=<symbols>] [--remove_define_symbol=<symbols>]"
            exit 1
            ;;
    esac
done

# Kiểm tra biến ADD_DEFINE_SYMBOLS và REMOVE_DEFINE_SYMBOLS
if [[ -z "$ADD_DEFINE_SYMBOLS" ]]; then
    echo "⚠️ Warning: ADD_DEFINE_SYMBOLS is empty!"
else
    echo "✔️ ADD_DEFINE_SYMBOLS: $ADD_DEFINE_SYMBOLS"
fi

if [[ -z "$REMOVE_DEFINE_SYMBOLS" ]]; then
    echo "⚠️ Warning: REMOVE_DEFINE_SYMBOLS is empty!"
else
    echo "✔️ REMOVE_DEFINE_SYMBOLS: $REMOVE_DEFINE_SYMBOLS"
fi

# Chuyển đổi biến thành mảng
IFS=',' read -r -a ADD_SYMBOLS <<< "$ADD_DEFINE_SYMBOLS"
IFS=',' read -r -a REMOVE_SYMBOLS <<< "$REMOVE_DEFINE_SYMBOLS"

echo "==== Updating Scripting Define Symbols ===="
echo "ProjectSettings File: $PROJECT_SETTINGS_FILE"
echo "-------------------------------------------"

# Sao lưu file gốc trước khi chỉnh sửa
cp "$PROJECT_SETTINGS_FILE" "$PROJECT_SETTINGS_FILE.bak"

# Biến lưu nội dung mới của file
UPDATED_CONTENT=""
IN_SCRIPTING_DEFINE_SYMBOLS=0
CHANGES_MADE=0

# Đọc từng dòng của file gốc
while IFS= read -r line || [[ -n "$line" ]]; do
    # Bắt đầu phần scriptingDefineSymbols
    if echo "$line" | grep -qE '^[[:space:]]*scriptingDefineSymbols:'; then
        IN_SCRIPTING_DEFINE_SYMBOLS=1
        echo "[DEBUG] Found scriptingDefineSymbols section."
        UPDATED_CONTENT+="$line"$'\n'
        continue
    fi

    # Nếu đang trong scriptingDefineSymbols và gặp additionalCompilerArguments, kết thúc chỉnh sửa
    if [[ $IN_SCRIPTING_DEFINE_SYMBOLS -eq 1 && $(echo "$line" | grep -E '^[[:space:]]*additionalCompilerArguments:') ]]; then
        IN_SCRIPTING_DEFINE_SYMBOLS=0
        echo "[DEBUG] End of scriptingDefineSymbols section."
    fi

    # Nếu đang trong scriptingDefineSymbols và gặp một nền tảng
    if [[ $IN_SCRIPTING_DEFINE_SYMBOLS -eq 1 && $(echo "$line" | grep -E '^[[:space:]]{4}[A-Za-z0-9_]+:') ]]; then
        PLATFORM=$(echo "$line" | sed -E 's/^[[:space:]]{4}([^:]+):.*/\1/')
        SYMBOLS=$(echo "$line" | sed -E 's/.*: (.*)/\1/')

        # Nếu SYMBOLS là `{}` hoặc rỗng, giữ nguyên để tránh làm hỏng YAML
        if [[ "$SYMBOLS" == "{}" || -z "$SYMBOLS" ]]; then
            echo "[WARNING] $PLATFORM has no symbols defined, skipping..."
            UPDATED_CONTENT+="$line"$'\n'
            continue
        fi

        # Chuyển đổi thành mảng
        IFS=';' read -r -a SYMBOLS_ARRAY <<< "$SYMBOLS"

        # Thêm các symbols mới nếu chưa có
        for SYMBOL in "${ADD_SYMBOLS[@]}"; do
            if [[ -n "$SYMBOL" && ! " ${SYMBOLS_ARRAY[@]} " =~ " $SYMBOL " ]]; then
                SYMBOLS_ARRAY+=("$SYMBOL")
                echo "[DEBUG] Added: $SYMBOL to $PLATFORM"
                CHANGES_MADE=1
            fi
        done

        # Xóa các symbols cần loại bỏ
        for REMOVE_SYMBOL in "${REMOVE_SYMBOLS[@]}"; do
            if [[ -n "$REMOVE_SYMBOL" && " ${SYMBOLS_ARRAY[@]} " =~ " $REMOVE_SYMBOL " ]]; then
                SYMBOLS_ARRAY=("${SYMBOLS_ARRAY[@]/$REMOVE_SYMBOL}")
                echo "[DEBUG] Removed: $REMOVE_SYMBOL from $PLATFORM"
                CHANGES_MADE=1
            fi
        done

        # Ghép lại thành chuỗi mới với dấu ";"
        NEW_SYMBOLS=$(IFS=';'; echo "${SYMBOLS_ARRAY[*]}")

        echo "[DEBUG] Updated $PLATFORM Symbols: $NEW_SYMBOLS"
        echo "-------------------------------------------"

        # Cập nhật lại dòng cho nền tảng này
        line="    $PLATFORM: $NEW_SYMBOLS"
    fi

    UPDATED_CONTENT+="$line"$'\n'
done < "$PROJECT_SETTINGS_FILE.bak"

# Ghi nội dung đã chỉnh sửa vào file
echo "$UPDATED_CONTENT" > "$PROJECT_SETTINGS_FILE"

if [[ "$CHANGES_MADE" -eq 1 ]]; then
    echo "✅ Update completed. Check logs for debugging."
else
    echo "ℹ️ No changes were made to scriptingDefineSymbols."
fi

echo "🔄 Backup saved at: $PROJECT_SETTINGS_FILE.bak"
