# ⚡️ VS Code <-> Cursor Sync

This script creates a seamless, bidirectional synchronization between **VS Code** and **Cursor** on macOS. It allows you to use both editors interchangeably without manually copying settings or extensions.

## 🚀 What it does
1.  **Settings & Keybindings:** Creates **symlinks** from VS Code to Cursor.
    * *Result:* Change a setting or keybinding in one, and it updates instantly in the other.
2.  **Extensions:** Sets up a background service (LaunchAgent) using `fswatch`.
    * *Result:* Install or Uninstall an extension in one editor, and it automatically syncs to the other within 5 seconds.

## 📋 Prerequisites
* macOS
* VS Code and Cursor installed.
* **Homebrew** (required to install `fswatch`).

## 🛠️ Installation

1.  Download `install_editor_sync.sh`.
2.  Open your terminal and run:

```bash
chmod +x install_editor_sync.sh
./install_editor_sync.sh
```

**That's it.** The script will backup your existing Cursor settings, link the configuration files, and start the background sync service.

## 🔍 How to check logs
The background service logs to the `/tmp` directory. To watch the sync happen in real-time:

```bash
tail -f /tmp/editorsync.out.log /tmp/editorsync.err.log
```

## 🛑 Uninstallation
To remove the sync and background service:

```bash
# Unload the background task
launchctl unload ~/Library/LaunchAgents/com.$USER.editorsync.plist
rm ~/Library/LaunchAgents/com.$USER.editorsync.plist

# Remove the sync scripts
rm -rf ~/.editor_sync

# Note: Your Cursor settings are still symlinked to VS Code. 
# If you want to unlink them, delete the files in Cursor's User directory 
# and restore your backups (or create new files).
```
