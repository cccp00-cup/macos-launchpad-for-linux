#!/usr/bin/env bash
# 构建 launchpad .deb 安装包（软件商店/Discover 可安装）
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

VERSION="26.9.25"
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
Categories=Utility;
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
    <release version="26.9.25" date="2026-09-25">
      <description>
        <p>新增文件夹：把图标拖到另一个图标上即可合并，支持 3x3 可翻页的网格面板、
        内联重命名、成员拖出与重排，搜索也能命中文件夹内的应用。</p>
        <p>拖拽改版：长按进入编辑态，图标实时让位、跨页拖动不中断。</p>
        <p>文件夹面板改用重度高斯模糊加压暗的毛玻璃背景。</p>
      </description>
    </release>
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

## 操作
- 呼出 / 隐藏：左 Alt 全局快捷键（可在「系统设置 → 快捷键 → Launchpad」里改）
- 翻页：滚轮 / 触控板横滑 / 底部圆点
- 点击图标：启动应用
- 长按图标约 0.2 秒：进入编辑态（图标轻微抖动），此时拖动可排序，自动保存
- 把图标拖到另一个图标上停约 0.8 秒：合并成文件夹
- 点击文件夹：屏幕中央展开 3×3 面板，超过 9 个可滚轮翻页
- 面板内点击文件夹名可重命名
- 面板内长按拖动成员：调整顺序；拖到面板外：移出文件夹
- 成员被全部移出后，文件夹自动消失
- 输入文字：实时搜索（文件夹内的应用也能搜到），回车启动第一个结果
- Esc：退出编辑态 / 清空搜索 / 关闭窗口

## 文件
- 布局与排序：~/.config/launchpad/settings.conf
- 壁纸模糊缓存：~/.cache/qw-launchpad/Launchpad（可安全删除）
EOF
gzip -9n "$PKGROOT/usr/share/doc/launchpad/README.md" 2>/dev/null || true
if [ -f "$PKGROOT/usr/share/doc/launchpad/README.md.gz" ]; then
    mv "$PKGROOT/usr/share/doc/launchpad/README.md.gz" "$PKGROOT/usr/share/doc/launchpad/README.gz"
fi

# ---------- Debian changelog（软件商店/Discover 会读它显示更新记录）----------
cat > "$PKGROOT/usr/share/doc/launchpad/changelog.Debian" <<EOF
launchpad (${VERSION}-1) unstable; urgency=medium

  * 新增文件夹：把图标拖到另一个图标上即可合并；支持 3x3 可翻页的网格面板、
    内联重命名、成员拖出与重排，搜索也能命中文件夹内的应用。
  * 拖拽改版：长按图标进入编辑态，其余图标实时让位、跨页拖动不中断。
  * 文件夹面板改用重度高斯模糊加压暗的毛玻璃背景。
  * 补齐运行时依赖：qml6-module-qtquick-effects、qml6-module-qtqml、
    qml6-module-qtqml-models。
  * 菜单类别由 Utility;System;Core; 收敛为 Utility;（原来会在菜单中重复出现）。

 -- qw-launchpad <launchpad@localhost>  Fri, 25 Sep 2026 12:00:00 +0800

launchpad (1.0.0-1) unstable; urgency=medium

  * 首个版本。

 -- qw-launchpad <launchpad@localhost>  Sat, 12 Sep 2026 12:00:00 +0800
EOF
gzip -9n "$PKGROOT/usr/share/doc/launchpad/changelog.Debian"

# ---------- control ----------
INSTALLED_SIZE=$(du -sk --exclude=DEBIAN "$PKGROOT" | cut -f1)
cat > "$PKGROOT/DEBIAN/control" <<EOF
Package: launchpad
Version: ${VERSION}-1
Section: utils
Priority: optional
Architecture: ${ARCH}
Installed-Size: ${INSTALLED_SIZE}
Depends: libqt6core6t64 | libqt6core6, libqt6dbus6, libqt6network6, libqt6gui6, libqt6qml6, libqt6quick6, libqt6qmlworkerscript6, libkf6globalaccel6, qml6-module-qtquick, qml6-module-qtquick-window, qml6-module-qtquick-effects, qml6-module-qtqml, qml6-module-qtqml-models
Recommends: ffmpeg
Homepage: https://qwenwork.cn
Maintainer: qw-launchpad <launchpad@localhost>
Description: macOS-style full-screen application launcher
 Full-screen app launcher inspired by the classic macOS Launchpad.
 Shows applications over a blurred view of the current wallpaper,
 with drag-and-drop arrangement, folders, horizontal paging, live search,
 and a global hotkey via KGlobalAccel.
 .
 Requires Qt 6.5+ and KF6 (Plasma 6 era desktops). On Debian/Ubuntu
 install with: sudo apt install ./launchpad_26.9.25-1_amd64.deb
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
