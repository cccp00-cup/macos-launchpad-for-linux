#!/usr/bin/env bash
# 构建 launchpad .deb 安装包（软件商店/Discover 可安装）
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

VERSION="1.0.0"
ARCH="amd64"
PKGROOT="pkg"
DEB="launchpad_${VERSION}-1_${ARCH}.deb"

# 1. 编译
echo "==> 编译"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build build -j"$(nproc)" >/dev/null

# 2. 组装目录树
echo "==> 组装包结构"
rm -rf "$PKGROOT"
install -d "$PKGROOT/DEBIAN" \
    "$PKGROOT/usr/bin" \
    "$PKGROOT/usr/share/applications" \
    "$PKGROOT/usr/share/icons/hicolor/scalable/apps" \
    "$PKGROOT/usr/share/metainfo" \
    "$PKGROOT/usr/share/doc/launchpad" \
    "$PKGROOT/etc/xdg/autostart"

install -m 755 build/launchpad "$PKGROOT/usr/bin/launchpad"
install -m 644 assets/launchpad.svg "$PKGROOT/usr/share/icons/hicolor/scalable/apps/launchpad.svg"

# ---------- 菜单项 ----------
cat > "$PKGROOT/usr/share/applications/launchpad.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Launchpad
Name[zh_CN]=启动台
GenericName=Application Launcher
GenericName[zh_CN]=应用启动台
Comment=macOS style full-screen app launcher
Comment[zh_CN]=macOS 风格的全屏应用启动台
Exec=launchpad
Icon=launchpad
Terminal=false
Categories=Utility;System;Core;
Keywords=launchpad;launcher;apps;starter;
X-KDE-StartupNotify=false
StartupWMClass=launchpad
SingleMainWindow=true
EOF

# ---------- 开机自启 ----------
cat > "$PKGROOT/etc/xdg/autostart/launchpad-autostart.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=Launchpad
Name[zh_CN]=启动台
Exec=launchpad --background
Icon=launchpad
Terminal=false
OnlyShowIn=KDE;
X-KDE-autostart-phase=2
X-GNOME-Autostart-enabled=true
EOF

# ---------- AppStream 元数据（软件商店展示用） ----------
cat > "$PKGROOT/usr/share/metainfo/launchpad.metainfo.xml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>launchpad.desktop</id>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>MIT</project_license>
  <name>Launchpad</name>
  <name xml:lang="zh_CN">启动台</name>
  <summary>macOS style full-screen application launcher</summary>
  <summary xml:lang="zh_CN">macOS 风格的全屏应用启动台</summary>
  <description>
    <p>A full-screen app launcher inspired by the classic macOS Launchpad.</p>
    <p>Shows your applications over a blurred view of the current desktop
    wallpaper, with drag-and-drop icon arrangement, horizontal paging,
    live search and a global Left-Alt hotkey (via KGlobalAccel).</p>
    <p xml:lang="zh_CN">经典 macOS 启动台风格的全屏应用启动器：毛玻璃壁纸背景、
    图标拖拽排序、横向翻页、实时搜索，支持左 Alt 全局快捷键呼出。
    自动读取当前系统图标主题，开机自启、后台常驻。</p>
  </description>
  <launchable type="desktop-id">launchpad.desktop</launchable>
  <url type="homepage">https://qwenwork.cn</url>
  <provides>
    <binary>launchpad</binary>
  </provides>
  <categories>
    <category>Utility</category>
  </categories>
  <releases>
    <release version="1.0.0" date="2026-09-12">
      <description>
        <p>Initial release.</p>
      </description>
    </release>
  </releases>
  <content_rating type="oars-1.1"/>
</component>
EOF

# ---------- 文档 ----------
cat > "$PKGROOT/usr/share/doc/launchpad/copyright" <<'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: launchpad
Source: local

Files: *
Copyright: 2026 qw-launchpad
License: MIT
 Permission is hereby granted, free of charge, to any person obtaining a
 copy of this software and associated documentation files (the "Software"),
 to deal in the Software without restriction, including without limitation
 the rights to use, copy, modify, merge, publish, distribute, sublicense,
 and/or sell copies of the Software.
 .
 On Debian systems, the complete text of the MIT license can be found
 in /usr/share/common-licenses/MIT.
EOF
cat > "$PKGROOT/usr/share/doc/launchpad/README.md" <<'EOF'
# Launchpad 启动台

macOS 经典风格的全屏应用启动器（KDE Plasma）。

- 左 Alt：呼出 / 隐藏
- 滚轮或触控板横滑：翻页
- 点击图标：启动应用；按住拖拽：排序（自动保存）
- 输入文字：实时搜索，回车启动第一个结果
- Esc：清空搜索 / 关闭

配置与排序保存于 ~/.config/launchpad/。
壁纸模糊缓存位于 ~/.cache/qw-launchpad/（可安全删除）。
EOF
gzip -9n "$PKGROOT/usr/share/doc/launchpad/README.md" 2>/dev/null || true
if [ -f "$PKGROOT/usr/share/doc/launchpad/README.md.gz" ]; then
    mv "$PKGROOT/usr/share/doc/launchpad/README.md.gz" "$PKGROOT/usr/share/doc/launchpad/README.gz"
fi

# ---------- control ----------
INSTALLED_SIZE=$(du -sk --exclude=DEBIAN "$PKGROOT" | cut -f1)
cat > "$PKGROOT/DEBIAN/control" <<EOF
Package: launchpad
Version: ${VERSION}-1
Section: utils
Priority: optional
Architecture: ${ARCH}
Installed-Size: ${INSTALLED_SIZE}
Depends: libqt6core6t64, libqt6gui6, libqt6qml6, libqt6quick6, libqt6qmlworkerscript6, libkf6globalaccel6, qml6-module-qtquick, qml6-module-qtquick-window
Recommends: ffmpeg
Maintainer: qw-launchpad <launchpad@localhost>
Description: macOS-style full-screen application launcher
 Full-screen app launcher inspired by the classic macOS Launchpad.
 Shows applications over a blurred view of the current wallpaper,
 with drag-and-drop arrangement, horizontal paging, live search,
 and a global Left-Alt hotkey via KGlobalAccel.
EOF

cat > "$PKGROOT/DEBIAN/conffiles" <<'EOF'
/etc/xdg/autostart/launchpad-autostart.desktop
EOF

# ---------- 维护脚本 ----------
cat > "$PKGROOT/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e

# 刷新图标与菜单缓存
if [ -x /usr/bin/update-desktop-database ]; then
    update-desktop-database -q /usr/share/applications || true
fi
gtk-update-icon-cache -qtf /usr/share/icons/hicolor 2>/dev/null || true

# 升级时重启正在运行的实例（尽力而为；失败则下次登录由 autostart 拉起）
pids=$(pgrep -x launchpad 2>/dev/null || true)
if [ -n "$pids" ]; then
    for pid in $pids; do
        uid=$(stat -c %u "/proc/$pid" 2>/dev/null) || continue
        user=$(id -nu "$uid" 2>/dev/null) || continue
        kill "$pid" 2>/dev/null || true
        if command -v systemd-run >/dev/null 2>&1; then
            systemd-run --user -M "$user@.host" --collect \
                --setenv=QT_QPA_PLATFORM=wayland \
                --setenv=WAYLAND_DISPLAY=wayland-0 \
                /usr/bin/launchpad --background >/dev/null 2>&1 || true
        fi
    done
fi

exit 0
EOF

cat > "$PKGROOT/DEBIAN/prerm" <<'EOF'
#!/bin/sh
set -e
if [ "$1" = "remove" ] || [ "$1" = "upgrade" ]; then
    pkill -x launchpad 2>/dev/null || true
fi
exit 0
EOF

cat > "$PKGROOT/DEBIAN/postrm" <<'EOF'
#!/bin/sh
set -e
gtk-update-icon-cache -qtf /usr/share/icons/hicolor 2>/dev/null || true
exit 0
EOF

chmod 755 "$PKGROOT/DEBIAN/postinst" "$PKGROOT/DEBIAN/prerm" "$PKGROOT/DEBIAN/postrm"

# 规范权限：目录 755，普通文件 644，可执行 755
find "$PKGROOT" -type d -exec chmod 755 {} +
find "$PKGROOT" -type f -exec chmod 644 {} +
chmod 755 "$PKGROOT/usr/bin/launchpad"
chmod 755 "$PKGROOT/DEBIAN/postinst" "$PKGROOT/DEBIAN/prerm" "$PKGROOT/DEBIAN/postrm"

# 3. 打包
echo "==> dpkg-deb 构建"
fakeroot dpkg-deb --build --root-owner-group "$PKGROOT" "$DEB" 2>/dev/null \
    || dpkg-deb --build --root-owner-group "$PKGROOT" "$DEB"

echo "完成: $DEB ($(du -h "$DEB" | cut -f1))"
