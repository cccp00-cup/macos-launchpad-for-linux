#!/usr/bin/env bash
# Launchpad 安装脚本：安装到 ~/.local，注册开机自启与 Left Alt 快捷键
set -euo pipefail

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
AUTOSTART_DIR="$HOME/.config/autostart"
ICONS_DIR="$HOME/.local/share/icons/hicolor/scalable/apps"

echo "==> 安装可执行文件"
mkdir -p "$BIN_DIR" "$APP_DIR" "$AUTOSTART_DIR" "$ICONS_DIR"
install -m 755 "$SRC_DIR/build/launchpad" "$BIN_DIR/launchpad"

echo "==> 安装图标与 .desktop"
install -m 644 "$SRC_DIR/assets/launchpad.svg" "$ICONS_DIR/launchpad.svg"

cat > "$APP_DIR/launchpad.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Launchpad
Name[zh_CN]=启动台
GenericName=Application Launcher
Comment=macOS style full-screen app launcher
Exec=launchpad --background
Icon=launchpad
Terminal=false
Categories=Utility;System;
X-KDE-StartupNotify=false
StartupWMClass=launchpad
EOF

echo "==> 注册开机自启（登录即启动，延迟 12 秒避开桌面启动高峰）"
cat > "$AUTOSTART_DIR/launchpad.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Launchpad
Exec=/bin/sh -c 'sleep 12; exec $BIN_DIR/launchpad --background'
Icon=launchpad
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

echo "==> 更新图标缓存"
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    gtk-update-icon-cache -qtf "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
fi

echo "==> 启动 Launchpad（后台常驻）"
if pgrep -x launchpad >/dev/null; then
    echo "    已有实例在运行，先停止旧实例"
    pkill -x launchpad || true
    sleep 0.5
fi
nohup setsid "$BIN_DIR/launchpad" --background >/dev/null 2>&1 &
disown 2>/dev/null || true
sleep 2

if pgrep -x launchpad >/dev/null; then
    echo "安装完成！"
    echo "  • 按 Left Alt（左 Alt 键）呼出/隐藏启动台"
    echo "  • 已设置开机自动启动（后台常驻）"
    echo "  • 快捷键可在 系统设置 → 快捷键 → Launchpad 中修改"
else
    echo "警告：启动失败，请手动运行: $BIN_DIR/launchpad --background"
    exit 1
fi
