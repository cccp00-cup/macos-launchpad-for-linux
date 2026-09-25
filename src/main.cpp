/*
 * Launchpad — macOS 15 经典启动台复刻 (KDE Plasma / Wayland / X11)
 * 全屏毛玻璃、系统主题图标、拖拽排序、横向翻页、Left Alt 呼出
 */
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickImageProvider>
#include <QQuickWindow>
#include <QAbstractListModel>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSettings>
#include <QStandardPaths>
#include <QIcon>
#include <QImage>
#include <QPainter>
#include <QDateTime>
#include <QCryptographicHash>
#include <QLocalServer>
#include <QLocalSocket>
#include <QTimer>
#include <QProcess>
#include <QUrl>
#include <QDebug>
#include <QRegularExpression>
#include <QtConcurrent>
#include "appmodel.h"
#include <QDBusInterface>
#include <KGlobalAccel>
#include <QAction>
#include <algorithm>

/* ------------------------------------------------------------------ */
/*  壁纸：读取 Plasma 壁纸配置 → 高斯模糊 → 缓存                        */
/* ------------------------------------------------------------------ */
class Wallpaper : public QObject {
    Q_OBJECT
public:
    explicit Wallpaper(QObject *parent = nullptr) : QObject(parent) {}

    // 立即返回缓存结果；若需重新计算则后台异步进行，完成后发 ready
    Q_INVOKABLE QString url() {
        if (m_state == Ready) return "image://wallpaper/v" + m_cacheVersion;
        if (m_state == Idle) prepareAsync();
        return QString();
    }

    QImage image() const {
        if (m_cachePath.isEmpty()) return QImage();
        return QImage(m_cachePath);
    }

    void prepareAsync() {
        if (m_state == Busy) return;
        m_state = Busy;
        // 解析路径很快，可同步做；解码+模糊放后台线程
        (void)QtConcurrent::run([this] {
            const QString src = resolveWallpaperFile();
            QString result;
            if (!src.isEmpty()) result = buildBlur(src);
            QMetaObject::invokeMethod(this, [this, result] {
                m_state = result.isEmpty() ? Idle : Ready;
                if (!result.isEmpty()) {
                    m_cachePath = result;
                    m_cacheVersion = QString::number(m_cacheVersion.toInt() + 1);
                }
                emit ready();
            }, Qt::QueuedConnection);
        });
    }

signals:
    void ready();

private:
    enum State { Idle, Busy, Ready };

    QString buildBlur(const QString &srcPath) {
        // AVIF/HEIC 的 Qt 解码器不可靠，交给 ffmpeg 转成 PNG
        QString loadPath = srcPath;
        const QString suffix = QFileInfo(srcPath).suffix().toLower();
        if (suffix == "avif" || suffix == "heic" || suffix == "heif" || suffix == "jxl") {
            const QString cacheDir =
                QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/launchpad";
            QDir().mkpath(cacheDir);
            QString hash = QCryptographicHash::hash(
                srcPath.toUtf8(), QCryptographicHash::Md5).toHex().left(16);
            const QString png = cacheDir + "/src-" + hash + ".png";
            if (!QFile::exists(png) ||
                QFileInfo(png).lastModified() < QFileInfo(srcPath).lastModified()) {
                QProcess ff;
                ff.start("ffmpeg", {"-y", "-loglevel", "quiet", "-i", srcPath, "-frames:v", "1", png});
                if (!ff.waitForFinished(15000) || !QFile::exists(png)) return QString();
            }
            loadPath = png;
        }

        QImage img(loadPath);
        if (img.isNull()) return QString();
        // 缩小到 800 宽再模糊（毛玻璃效果，内存友好），再放大到 1600
        QImage small = img.scaledToWidth(800, Qt::SmoothTransformation);
        img = QImage(); // 释放原图
        boxBlur(small, 13); boxBlur(small, 10); boxBlur(small, 7);
        small = small.scaledToWidth(1600, Qt::SmoothTransformation);
        // 轻微压暗，让白色文字更清晰
        QPainter p(&small);
        p.fillRect(small.rect(), QColor(0, 0, 0, 42));
        p.end();

        const QString cacheDir =
            QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/launchpad";
        QDir().mkpath(cacheDir);
        QString key = QCryptographicHash::hash(
            (srcPath + QString::number(QFileInfo(srcPath).lastModified().toSecsSinceEpoch()))
                .toUtf8(), QCryptographicHash::Md5).toHex();
        const QString out = cacheDir + "/blur-" + key + ".png";
        small.save(out, "PNG");
        return out;
    }
    // 三次方框模糊近似高斯；滑动窗口边界严格按 clamp 处理
    static void boxBlur(QImage &img, int radius) {
        if (img.format() != QImage::Format_ARGB32 && img.format() != QImage::Format_RGB32)
            img = img.convertToFormat(QImage::Format_ARGB32);
        const int w = img.width(), h = img.height(), r = radius;
        if (w < 2 || h < 2 || r < 1) return;

        // 横向 pass: img -> tmp
        QImage tmp(img.size(), img.format());
        for (int y = 0; y < h; ++y) {
            const QRgb *src = reinterpret_cast<const QRgb*>(img.scanLine(y));
            QRgb *dst = reinterpret_cast<QRgb*>(tmp.scanLine(y));
            const int cnt0 = qMin(r, w - 1) + 1; // 初始窗口 [0, min(r,w-1)]
            long sr = 0, sg = 0, sb = 0, sa = 0;
            for (int i = 0; i < cnt0; ++i) {
                sr += qRed(src[i]); sg += qGreen(src[i]);
                sb += qBlue(src[i]); sa += qAlpha(src[i]);
            }
            int cnt = cnt0;
            for (int x = 0; x < w; ++x) {
                dst[x] = qRgba(sr / cnt, sg / cnt, sb / cnt, sa / cnt);
                const int outL = x - r;      // 窗口 x 的左端（未 clamp）
                const int inR = x + 1 + r;   // 窗口 x+1 的右端（未 clamp）
                if (outL >= 0) {
                    sr -= qRed(src[outL]); sg -= qGreen(src[outL]);
                    sb -= qBlue(src[outL]); sa -= qAlpha(src[outL]);
                    --cnt;
                }
                if (inR <= w - 1) {
                    sr += qRed(src[inR]); sg += qGreen(src[inR]);
                    sb += qBlue(src[inR]); sa += qAlpha(src[inR]);
                    ++cnt;
                }
            }
        }

        // 纵向 pass: tmp -> img
        for (int x = 0; x < w; ++x) {
            const int cnt0 = qMin(r, h - 1) + 1;
            long sr = 0, sg = 0, sb = 0, sa = 0;
            for (int i = 0; i < cnt0; ++i) {
                const QRgb px = reinterpret_cast<const QRgb*>(tmp.scanLine(i))[x];
                sr += qRed(px); sg += qGreen(px); sb += qBlue(px); sa += qAlpha(px);
            }
            int cnt = cnt0;
            for (int y = 0; y < h; ++y) {
                QRgb *px = reinterpret_cast<QRgb*>(img.scanLine(y));
                px[x] = qRgba(sr / cnt, sg / cnt, sb / cnt, sa / cnt);
                const int outT = y - r;
                const int inB = y + 1 + r;
                if (outT >= 0) {
                    const QRgb p = reinterpret_cast<const QRgb*>(tmp.scanLine(outT))[x];
                    sr -= qRed(p); sg -= qGreen(p); sb -= qBlue(p); sa -= qAlpha(p);
                    --cnt;
                }
                if (inB <= h - 1) {
                    const QRgb p = reinterpret_cast<const QRgb*>(tmp.scanLine(inB))[x];
                    sr += qRed(p); sg += qGreen(p); sb += qBlue(p); sa += qAlpha(p);
                    ++cnt;
                }
            }
        }
    }

    // 从 plasma-org.kde.plasma.desktop-appletsrc 解析壁纸路径
    static QString resolveWallpaperFile() {
        const QString fromCfg = fromAppletsrc();
        if (!fromCfg.isEmpty()) return fromCfg;
        const QString fromProc = fromPlasmashellFds();
        if (!fromProc.isEmpty()) return fromProc;
        return fromUsersWallpapers();
    }

    // 策略 1：解析 Plasma 配置文件
    static QString fromAppletsrc() {
        const QString cfg = QDir::homePath() + "/.config/plasma-org.kde.plasma.desktop-appletsrc";
        QFile f(cfg);
        if (!f.open(QIODevice::ReadOnly)) return QString();
        const QString home = QDir::homePath();
        QRegularExpression re(R"(^(Image|SlidePaths|File)=\s*(.+)$)");
        QStringList candidates;
        while (!f.atEnd()) {
            const QString line = QString::fromUtf8(f.readLine()).trimmed();
            const auto m = re.match(line);
            if (!m.hasMatch()) continue;
            QString val = m.captured(2).trimmed();
            if (val.startsWith("file://")) val = QUrl(val).toLocalFile();
            if (val.startsWith("~")) val = home + val.mid(1);
            candidates << val;
        }
        for (int i = candidates.size() - 1; i >= 0; --i) {
            const QString v = candidates.at(i);
            QFileInfo fi(v);
            if (isImageFile(v)) return v;
            if (fi.isDir()) { // 壁纸包目录
                const QString found = findImageInDir(fi.absoluteFilePath());
                if (!found.isEmpty()) return found;
            }
        }
        return QString();
    }

    // 策略 2：扫描 plasmashell 打开的文件描述符（配置未落盘时依然有效）
    static QString fromPlasmashellFds() {
        QDir proc("/proc");
        const auto pids = proc.entryList(QStringList(), QDir::Dirs | QDir::NoDotAndDotDot,
                                         QDir::Name);
        for (const QString &pid : pids) {
            bool ok = false;
            pid.toInt(&ok);
            if (!ok) continue;
            QFile cmd("/proc/" + pid + "/cmdline");
            if (!cmd.open(QIODevice::ReadOnly)) continue;
            const QByteArray cmdline = cmd.readAll();
            cmd.close();
            if (!cmdline.contains("plasmashell")) continue;
            QDir fdDir("/proc/" + pid + "/fd");
            const auto fds = fdDir.entryList(QStringList(), QDir::Files | QDir::NoDotAndDotDot);
            for (const QString &fd : fds) {
                const QString target = QFile::symLinkTarget("/proc/" + pid + "/fd/" + fd);
                if (isImageFile(target) && QFileInfo::exists(target))
                    return target;
            }
        }
        return QString();
    }

    // 策略 3：plasmarc 中用户最近使用的壁纸
    static QString fromUsersWallpapers() {
        QFile f(QDir::homePath() + "/.config/plasmarc");
        if (!f.open(QIODevice::ReadOnly)) return QString();
        QRegularExpression re(R"(^usersWallpapers=(.+)$)", QRegularExpression::MultilineOption);
        const QString content = QString::fromUtf8(f.readAll());
        const auto m = re.match(content);
        if (!m.hasMatch()) return QString();
        const QStringList cands = m.captured(1).split(',', Qt::SkipEmptyParts);
        for (const QString &raw : cands) {
            QString v = raw.trimmed();
            if (v.endsWith('/')) v.chop(1);
            QFileInfo fi(v);
            if (fi.isFile() && isImageFile(v)) return v;
            if (fi.isDir()) {
                const QString found = findImageInDir(fi.absoluteFilePath());
                if (!found.isEmpty()) return found;
            }
        }
        return QString();
    }

    static bool isImageFile(const QString &p) {
        static const QStringList exts = {"png", "jpg",  "jpeg", "webp",
                                         "bmp", "avif", "heic", "heif", "jxl"};
        QFileInfo fi(p);
        return fi.isFile() && exts.contains(fi.suffix().toLower());
    }

    static QString findImageInDir(const QString &dirPath) {
        static const QStringList exts = {"png", "jpg", "jpeg", "webp", "bmp"};
        // 常见壁纸包结构：contents/images/*.jpg | contents/screenshot.png | *.jpg
        for (const QString &sub : {"/contents/images", "/contents", "/previews", ""}) {
            QDir d(dirPath + sub);
            if (!d.exists()) continue;
            const auto entries = d.entryInfoList(QDir::Files, QDir::Size);
            for (const QFileInfo &e : entries) {
                if (exts.contains(e.suffix().toLower())) return e.absoluteFilePath();
            }
        }
        return QString();
    }

    QString m_cachePath, m_cacheVersion = "0";
    State m_state = Idle;
};

/* ------------------------------------------------------------------ */
/*  图标 Provider：跟随当前系统图标主题                                 */
/* ------------------------------------------------------------------ */
class IconProvider : public QQuickImageProvider {
public:
    IconProvider() : QQuickImageProvider(QQuickImageProvider::Pixmap) {}

    QPixmap requestPixmap(const QString &id, QSize *size, const QSize &requested) override {
        const int px = requested.isValid() ? qBound(32, requested.width(), 256) : 128;
        const QString key = id + "|" + QString::number(px);
        QPixmap pm;
        if (m_cache.contains(key)) {
            pm = m_cache.value(key);
        } else {
            QIcon icon;
            if (id.startsWith('/'))
                icon = QIcon(id);
            else
                icon = QIcon::fromTheme(id, QIcon::fromTheme("application-x-executable"));
            pm = icon.pixmap(px, px);
            if (pm.isNull())
                pm = QIcon::fromTheme("application-x-executable").pixmap(px, px);
            if (m_cache.size() > 400) m_cache.clear();
            m_cache.insert(key, pm);
        }
        if (size) *size = pm.size();
        return pm;
    }

private:
    QHash<QString, QPixmap> m_cache;
};

/* ------------------------------------------------------------------ */
/*  应用列表模型：扫描 .desktop、排序持久化、过滤、启动                  */
/* ------------------------------------------------------------------ */
/* ------------------------------------------------------------------ */
/*  壁纸 Provider                                                      */
/* ------------------------------------------------------------------ */
class WallpaperProvider : public QQuickImageProvider {
public:
    WallpaperProvider(Wallpaper *w) : QQuickImageProvider(QQuickImageProvider::Image), m_w(w) {}
    QImage requestImage(const QString &, QSize *size, const QSize &) override {
        QImage img = m_w->image();
        if (size) *size = img.size();
        return img;
    }

private:
    Wallpaper *m_w;
};

/* ------------------------------------------------------------------ */
/*  单实例 + 命令行                                                     */
/* ------------------------------------------------------------------ */
static QQuickWindow *g_window = nullptr;

static void showAndRaise() {
    if (!g_window) return;
    g_window->showFullScreen();
    g_window->raise();
    g_window->requestActivate();
}

static void toggleWindow() {
    if (!g_window) return;
    if (g_window->isVisible()) g_window->hide();
    else showAndRaise();
}

int main(int argc, char *argv[]) {
    QGuiApplication app(argc, argv);
    app.setApplicationName("Launchpad");
    app.setOrganizationName("qw-launchpad");
    app.setDesktopFileName("launchpad");
    app.setQuitOnLastWindowClosed(false); // 点空白关闭后仍驻留后台

    bool toggle = app.arguments().contains("--toggle");
    bool background = app.arguments().contains("--background");

    // 单实例：若已在运行，把命令发给已有实例后退出；
    // --background 的重复启动（如 autostart 双重触发）则静默退出
    const QString sock = "qw-launchpad-instance";
    QLocalSocket probe;
    probe.connectToServer(sock);
    if (probe.waitForConnected(200)) {
        if (!background) {
            probe.write(toggle ? "toggle\n" : "show\n");
            probe.flush();
            probe.waitForBytesWritten(200);
        }
        return 0;
    }
    QLocalServer::removeServer(sock);
    QLocalServer server;
    server.listen(sock);
    QObject::connect(&server, &QLocalServer::newConnection, &server, [&server]() {
        QLocalSocket *c = server.nextPendingConnection();
        if (!c) return;
        QObject::connect(c, &QLocalSocket::readyRead, c, [c]() {
            const QString cmd = QString::fromUtf8(c->readAll());
            if (cmd.contains("toggle"))
                toggleWindow();
            else
                showAndRaise();
            c->disconnectFromServer();
        });
    });

    Wallpaper wallpaper;
    auto *engine = new QQmlApplicationEngine;
    engine->addImageProvider("wallpaper", new WallpaperProvider(&wallpaper));
    engine->addImageProvider("appicon", new IconProvider());

    AppModel model;
    engine->rootContext()->setContextProperty("AppListModel", &model);
    engine->rootContext()->setContextProperty("WallpaperBackend", &wallpaper);

    QObject::connect(engine, &QQmlApplicationEngine::objectCreated, &app,
        [toggle, background](QObject *obj) {
            if (!obj) return;
            g_window = qobject_cast<QQuickWindow *>(obj);
            if (!g_window) return;
            if (toggle || !background) showAndRaise();
            QTimer::singleShot(80, [w = g_window]() {
                if (w && w->isVisible()) w->showFullScreen();
            });
        }, Qt::QueuedConnection);

    engine->loadFromModule("Launchpad", "Main");
    if (engine->rootObjects().isEmpty()) return -1;

    // Left Alt 全局快捷键（经 kglobalaccel，Wayland 唯一正规途径）
    QAction toggleAct;
    toggleAct.setObjectName("toggle");
    toggleAct.setText("Show Launchpad");
    toggleAct.setProperty("componentName", "launchpad");
    toggleAct.setProperty("shortcutName", "toggle");
    toggleAct.setProperty("displayName", "Show Launchpad");
    // 先清掉 kglobalaccel 中残留的旧实例注册（owner 掉线后仍占位，
    // 否则新实例注册会自我冲突，快捷键被清空）
    {
        QDBusInterface kga("org.kde.kglobalaccel", "/kglobalaccel",
                           "org.kde.KGlobalAccel");
        kga.call("unregister", "launchpad", "toggle");
    }
    const bool bound = KGlobalAccel::setGlobalShortcut(
        &toggleAct, { QKeySequence(Qt::ALT) });
    qWarning() << "[launchpad] setGlobalShortcut returned:" << bound;
    QObject::connect(&toggleAct, &QAction::triggered, []() { toggleWindow(); });

    return app.exec();
}

#include "main.moc"
