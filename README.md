# 启动台 · macOS Launchpad for Linux

> macOS 经典风格的全屏应用启动台 —— 在壁纸的毛玻璃虚化之上铺开所有应用，
> 支持拖拽排序、文件夹、横向翻页与实时搜索，左 Alt 一键呼出。基于 Qt 6 + KF6，
> 面向 KDE Plasma 6。

<p align="center">
  <img alt="license" src="https://img.shields.io/badge/license-GPL--3.0-blue">
  <img alt="platform" src="https://img.shields.io/badge/platform-KDE%20Plasma%206-1d99f3">
  <img alt="qt" src="https://img.shields.io/badge/Qt-6.5%2B-41cd52">
</p>

<!-- 截图：把截图放到 docs/ 下并替换下面这行
![启动台](docs/screenshot.png)
-->

---

## ✨ 功能

- **全屏启动台**：呼出即覆盖整屏，背景是当前壁纸的毛玻璃虚化，自动跟随换壁纸。
- **全局快捷键**：左 `Alt` 呼出 / 隐藏（经 KF6 GlobalAccel，可在
  「系统设置 → 快捷键 → Launchpad」里改）。
- **拖拽排序**：长按图标约 0.2 秒进入编辑态（图标轻微抖动），此时拖动即可排序，
  其余图标实时让位，跨页拖动不中断，改动自动保存。
- **文件夹**：把图标拖到另一个图标上停约 0.8 秒即可合并；点击文件夹在屏幕中央展开
  **3×3 可翻页**的面板，支持内联重命名、成员拖出与重排；成员全部移出后文件夹自动消失。
- **横向翻页**：滚轮 / 触控板横滑 / 底部圆点，翻页更顺手。
- **实时搜索**：输入即在整屏筛选（**文件夹内的应用也能命中**），回车启动第一个结果。
- **后台常驻**：以 `--background` 常驻并注册开机自启，呼出无启动延迟。
- **跟随系统图标主题**。

## 🖥 系统要求

- KDE Plasma 6（依赖 KF6 GlobalAccel 做全局快捷键）
- Qt 6.5+

## 📦 安装

### 方式一：Debian / Ubuntu（推荐）

```bash
bash build-deb.sh
sudo apt install ./launchpad_26.9.25-1_amd64.deb
```

生成的 `.deb` 也可以直接双击、在**软件商店 / Discover** 里点安装（这是本地包，
没有 GPG 签名，出现「不受信任」提示属正常，确认继续即可；用 `apt` 安装能更可靠地
自动装齐依赖）。

### 方式二：源码安装（装到 `~/.local`，无需 root）

```bash
bash install.sh       # 安装并启动
./uninstall.sh        # 卸载（保留 ~/.config/launchpad 里的布局与文件夹）
```

### 其它发行版（Arch / Fedora / openSUSE 等）

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"
sudo install -Dm755 build/launchpad /usr/local/bin/launchpad
```

## ⌨️ 操作

| 操作 | 效果 |
| --- | --- |
| 左 `Alt` | 呼出 / 隐藏启动台 |
| 点击图标 | 启动应用 |
| 长按图标约 0.2 秒 | 进入编辑态（抖动），此后可拖动排序 |
| 把图标拖到另一个图标上停约 0.8 秒 | 合并成文件夹 |
| 点击文件夹 | 屏幕中央展开 3×3 面板（超过 9 个可滚轮翻页） |
| 面板内点击文件夹名 | 重命名 |
| 面板内长按拖动成员 | 调整顺序；拖到面板外则移出文件夹 |
| 滚轮 / 触控板横滑 / 底部圆点 | 横向翻页 |
| 输入文字 | 实时搜索（含文件夹内应用），回车启动第一个结果 |
| `Esc` | 退出编辑态 / 清空搜索 / 关闭窗口 |

## ⚙️ 配置与缓存

```
~/.config/launchpad/settings.conf          # 图标布局、排序与文件夹
~/.cache/qw-launchpad/Launchpad            # 壁纸模糊缓存（可安全删除）
```

卸载不会动这两处；要彻底清干净：`rm -rf ~/.config/launchpad ~/.cache/qw-launchpad`。

## 🧩 架构

```
launchpad/
├── src/main.cpp          主程序：窗口 / 壁纸毛玻璃 / 全局快捷键 / 后台常驻
├── src/appmodel.h        应用模型：扫描 .desktop、排序、文件夹、搜索
├── qml/Main.qml          启动台 UI（图标网格、文件夹面板、搜索框、翻页）
├── tests/tst_drag.cpp    拖拽与文件夹的回归测试
├── assets/launchpad.svg  图标
├── build-deb.sh          打 Debian 包
├── install.sh           源码安装到 ~/.local
├── uninstall.sh         移除 ~/.local 下的文件
└── INSTALL.txt          简明安装说明
```

## 🧪 测试

开发用的回归测试默认关闭，打开后经 `ctest` 运行（离屏执行）：

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=ON
cmake --build build -j"$(nproc)"
ctest --test-dir build --output-on-failure
```

## 🔧 依赖

Debian 包名（`build-deb.sh` 的 `Depends`）：

```
libqt6core6t64 | libqt6core6, libqt6dbus6, libqt6network6, libqt6gui6,
libqt6qml6, libqt6quick6, libqt6qmlworkerscript6, libkf6globalaccel6,
qml6-module-qtquick, qml6-module-qtquick-window, qml6-module-qtquick-effects,
qml6-module-qtqml, qml6-module-qtqml-models
```

`Recommends`：`ffmpeg`（读取 AVIF / HEIC 等格式的壁纸时用到）。

## 📄 许可

GPL-3.0，见 [LICENSE](LICENSE)。
