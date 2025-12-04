#!/bin/bash

# ==========================================
# VS Code <-> Cursor Sync Installer
# ==========================================

set -e # Exit immediately if a command exits with a non-zero status

# --- Variables ---
SYNC_DIR="$HOME/.editor_sync"
SCRIPT_PATH="$SYNC_DIR/sync_editors.sh"
PLIST_NAME="com.$USER.editorsync.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"

VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"

# --- Colors ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Starting VS Code <-> Cursor Sync Setup...${NC}"

# 1. Check Dependencies
echo -e "${YELLOW}🔍 Checking dependencies...${NC}"
if ! command -v brew &> /dev/null; then
    echo -e "${RED}Error: Homebrew is not installed.${NC}"
    exit 1
fi

if ! command -v fswatch &> /dev/null; then
    echo "Installing fswatch..."
    brew install fswatch
else
    echo "✅ fswatch is already installed."
fi

# 2. Sync Configuration (Symlinks)
echo -e "${YELLOW}🔗 Setting up Configuration Symlinks...${NC}"

# Backup Cursor Config
if [ -f "$CURSOR_USER_DIR/settings.json" ]; then
    cp "$CURSOR_USER_DIR/settings.json" "$CURSOR_USER_DIR/settings.json.bak"
    echo "   - Backed up Cursor settings.json"
fi
if [ -f "$CURSOR_USER_DIR/keybindings.json" ]; then
    cp "$CURSOR_USER_DIR/keybindings.json" "$CURSOR_USER_DIR/keybindings.json.bak"
    echo "   - Backed up Cursor keybindings.json"
fi

# Remove existing Cursor config files to make room for symlinks
rm -f "$CURSOR_USER_DIR/settings.json"
rm -f "$CURSOR_USER_DIR/keybindings.json"
rm -rf "$CURSOR_USER_DIR/snippets"

# Create Symlinks
ln -s "$VSCODE_USER_DIR/settings.json" "$CURSOR_USER_DIR/settings.json"
ln -s "$VSCODE_USER_DIR/keybindings.json" "$CURSOR_USER_DIR/keybindings.json"
ln -s "$VSCODE_USER_DIR/snippets" "$CURSOR_USER_DIR/snippets"

echo "✅ Configuration files linked."

# 3. Create the Sync Script
echo -e "${YELLOW}📝 Generating Sync Script...${NC}"
mkdir -p "$SYNC_DIR"

cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

# Add Homebrew paths to ensure code/cursor/fswatch are found
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

VSCODE_EXT_FILE="$HOME/.vscode_current.txt"
CURSOR_EXT_FILE="$HOME/.cursor_current.txt"
LAST_STATE_FILE="$HOME/.editor_sync_state.txt"

# Initialize state on first run
if [ ! -f "$LAST_STATE_FILE" ]; then
    code --list-extensions > "$VSCODE_EXT_FILE"
    cursor --list-extensions > "$CURSOR_EXT_FILE"
    sort "$VSCODE_EXT_FILE" "$CURSOR_EXT_FILE" | uniq > "$LAST_STATE_FILE"
fi

echo "$(date): 🔄 Sync Started"

# Get Current State
code --list-extensions | sort > "$VSCODE_EXT_FILE"
cursor --list-extensions | sort > "$CURSOR_EXT_FILE"

# Handle Deletions (Uninstalls)
comm -12 "$LAST_STATE_FILE" "$CURSOR_EXT_FILE" | comm -23 - "$VSCODE_EXT_FILE" | while read ext; do
    [ -n "$ext" ] && echo "🗑️ Removing $ext from Cursor" && cursor --uninstall-extension "$ext"
done

comm -12 "$LAST_STATE_FILE" "$VSCODE_EXT_FILE" | comm -23 - "$CURSOR_EXT_FILE" | while read ext; do
    [ -n "$ext" ] && echo "🗑️ Removing $ext from VS Code" && code --uninstall-extension "$ext"
done

# Handle Additions (Installs)
comm -13 "$LAST_STATE_FILE" "$VSCODE_EXT_FILE" | while read ext; do
    [ -n "$ext" ] && echo "📦 Installing $ext in Cursor" && cursor --install-extension "$ext"
done

comm -13 "$LAST_STATE_FILE" "$CURSOR_EXT_FILE" | while read ext; do
    [ -n "$ext" ] && echo "📦 Installing $ext in VS Code" && code --install-extension "$ext"
done

# Update State
code --list-extensions | sort > "$VSCODE_EXT_FILE"
cursor --list-extensions | sort > "$CURSOR_EXT_FILE"
sort "$VSCODE_EXT_FILE" "$CURSOR_EXT_FILE" | uniq > "$LAST_STATE_FILE"

echo "$(date): ✅ Sync Complete"
EOF

chmod +x "$SCRIPT_PATH"
echo "✅ Script created at $SCRIPT_PATH"

# 4. Create and Load Launch Agent
echo -e "${YELLOW}⚙️  Configuring Background Service (LaunchAgent)...${NC}"

# We use cat << EOF (without quotes) to allow variable expansion for $HOME and $USER
cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.$USER.editorsync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH"; /opt/homebrew/bin/fswatch -o -l 5 '$HOME/.vscode/extensions' '$HOME/.cursor/extensions' | xargs -n1 -I{} '$SCRIPT_PATH'</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/editorsync.out.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/editorsync.err.log</string>
</dict>
</plist>
EOF

# Reset Permissions and Load
chmod 644 "$PLIST_PATH"
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo -e "${GREEN}✅ Setup Complete!${NC}"
echo -e "   1. Settings and Keybindings are now symlinked."
echo -e "   2. Extension sync is running in the background."
echo -e "   3. To view logs, run: ${BLUE}tail -f /tmp/editorsync.out.log${NC}"
