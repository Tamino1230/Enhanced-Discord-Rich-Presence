#!/bin/bash
set -e

echo "============================================="
echo " Installing Enhanced RPC Bridge Native Host  "
echo "============================================="

BIN_DIR="$HOME/.local/bin"
BINARY_NAME="com.enhanced.rpc.bridge"

mkdir -p "$BIN_DIR"

PAYLOAD_LINE=$(awk '/^__PAYLOAD_BELOW__/ {print NR + 1; exit 0;}' "$0")
tail -n +"$PAYLOAD_LINE" "$0" > "$BIN_DIR/$BINARY_NAME"
chmod +x "$BIN_DIR/$BINARY_NAME"


CHROMIUM_PATHS=(
    "$HOME/.config/google-chrome/NativeMessagingHosts"
)

GECKO_PATHS=(
    "$HOME/.mozilla/native-messaging-hosts"
)


ESCAPED_BIN_PATH=$(echo "$BIN_DIR/$BINARY_NAME" | sed 's/\//\\\//g')


for PATH_DIR in "${CHROMIUM_PATHS[@]}"; do
    mkdir -p "$PATH_DIR"
    cat <<EOF > "$PATH_DIR/com.enhanced.rpc.bridge.json"
__CHROME_MANIFEST_TEMPLATE__
EOF
    sed -i "s|%placeholder%|$BIN_DIR/$BINARY_NAME|g" "$PATH_DIR/com.enhanced.rpc.bridge.json"
done

for PATH_DIR in "${GECKO_PATHS[@]}"; do
    mkdir -p "$PATH_DIR"
    cat <<EOF > "$PATH_DIR/com.enhanced.rpc.bridge.json"
__FIREFOX_MANIFEST_TEMPLATE__
EOF
    sed -i "s|%placeholder%|$BIN_DIR/$BINARY_NAME|g" "$PATH_DIR/com.enhanced.rpc.bridge.json"
done

echo "Installation successfully completed in user space!"
echo "Binary location: $BIN_DIR/$BINARY_NAME"
exit 0

__PAYLOAD_BELOW__