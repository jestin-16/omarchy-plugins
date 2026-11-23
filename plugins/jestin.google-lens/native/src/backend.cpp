#include "backend.h"

#include <QBuffer>
#include <QClipboard>
#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDesktopServices>
#include <QDir>
#include <QFileInfo>
#include <QGuiApplication>
#include <QImageReader>
#include <QMimeData>
#include <QPainter>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTcpSocket>
#include <QTimer>
#include <QUuid>
#include <QtConcurrent>
#include <cmath>

static QString rootPath(const QString &overridePath) {
    return overridePath.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation) : overridePath;
}

Backend::Backend(bool preview, const QString &root, QObject *parent)
    : QObject(parent), m_root(rootPath(root)), m_preview(preview),
      m_settings(m_root + "/preferences.ini", QSettings::IniFormat) {
    m_status = tr("Capture a region, paste an image, or drop a file.");
    QImageReader::setAllocationLimit(192);
    connect(&m_decoder, &QFutureWatcher<QImage>::finished, this, [this] {
        m_busy = false;
        const auto decoded = m_decoder.result();
        if (decoded.isNull()) {
            m_afterDecode = {};
            fail(tr("This image could not be opened. Use a PNG, JPEG, or WebP under 20 MB and 40 megapixels."));
            return;
        }
        setImage(decoded);
        auto next = std::move(m_afterDecode);
        m_afterDecode = {};
        if (next) next();
    });
    connect(&m_encoder, &QFutureWatcher<QByteArray>::finished, this, [this] {
        m_busy = false;
        const auto png = m_encoder.result();
        if (png.isEmpty() || png.size() > 20 * 1024 * 1024) {
            fail(tr("The upload is too large. Crop the image or turn off original quality."));
            return;
        }
        serveUpload(png);
    });
    connect(&m_server, &QTcpServer::newConnection, this, [this] {
        while (auto socket = m_server.nextPendingConnection()) {
            connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
            QTimer::singleShot(5000, socket, &QTcpSocket::abort);
            connect(socket, &QTcpSocket::readyRead, this, [this, socket] {
                QByteArray request = socket->property("request").toByteArray() + socket->readAll();
                if (request.size() > 16384) { socket->abort(); return; }
                if (!request.contains("\r\n\r\n")) { socket->setProperty("request", request); return; }
                if (socket->property("answered").toBool()) return;
                socket->setProperty("answered", true);
                const auto first = request.left(request.indexOf("\r\n")).split(' ');
                QByteArray body, type = "text/plain", status = "404 Not Found";
                if (first.size() == 3 && first[0] == "GET" && first[1] == m_route.toUtf8()) {
                    body = uploadHtml(m_route + "/image.png"); type = "text/html; charset=utf-8"; status = "200 OK";
                } else if (first.size() == 3 && first[0] == "GET" && first[1] == (m_route + "/image.png").toUtf8()) {
                    body = m_uploadPng; type = "image/png"; status = "200 OK";
                }
                socket->write("HTTP/1.1 " + status + "\r\nContent-Type: " + type +
                              "\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\nContent-Length: " +
                              QByteArray::number(body.size()) + "\r\n\r\n" + body);
                socket->disconnectFromHost();
            });
        }
    });
}

Backend::~Backend() {
    m_decoder.waitForFinished();
    m_encoder.waitForFinished();
    for (auto process : findChildren<QProcess *>()) {
        if (process->state() != QProcess::NotRunning) { process->kill(); process->waitForFinished(1000); }
    }
}

QString Backend::dimensions() const {
    return hasImage() ? tr("%1 × %2").arg(QLocale().toString(m_image.width()), QLocale().toString(m_image.height())) : QString();
}
bool Backend::lowMemory() const { return m_settings.value("lowMemory", true).toBool(); }
bool Backend::originalQuality() const { return m_settings.value("originalQuality", false).toBool(); }
void Backend::setLowMemory(bool enabled) { if (!m_preview) m_settings.setValue("lowMemory", enabled); emit preferencesChanged(); }
void Backend::setOriginalQuality(bool enabled) { if (!m_preview) m_settings.setValue("originalQuality", enabled); emit preferencesChanged(); }
QString Backend::profilePath() const { return m_root + "/web-profile"; }
QString Backend::cachePath() const { return m_root + "/web-cache"; }

void Backend::fail(const QString &message) { m_busy = false; m_error = message; emit changed(); }
void Backend::pageStatus(const QString &status, bool failed) { m_status = status; m_error = failed ? status : QString(); emit changed(); }

void Backend::setImage(const QImage &image) {
    if (image.isNull() || qint64(image.width()) * image.height() > 40000000) {
        fail(tr("The image is empty or too large.")); return;
    }
    m_image = image;
    m_undo = {};
    m_text.clear();
    m_error.clear();
    m_status = tr("Image ready. Search with Lens or extract text locally.");
    refreshImage();
}

void Backend::refreshImage() {
    QByteArray preview;
    QBuffer buffer(&preview);
    buffer.open(QIODevice::WriteOnly);
    m_image.scaled(960, 640, Qt::KeepAspectRatio, Qt::SmoothTransformation).save(&buffer, "PNG");
    m_previewSource = "data:image/png;base64," + QString::fromLatin1(preview.toBase64());
    emit changed();
}

void Backend::run(const QString &program, const QStringList &args, int timeout,
                  std::function<void(int, const QByteArray &, const QByteArray &)> done) {
    auto process = new QProcess(this);
    auto timer = new QTimer(process);
    timer->setSingleShot(true);
    connect(timer, &QTimer::timeout, process, [process] { process->setProperty("timedOut", true); process->kill(); });
    connect(process, &QProcess::errorOccurred, this, [this, process, done](QProcess::ProcessError error) {
        if (error == QProcess::FailedToStart) {
            done(-1, {}, process->errorString().toUtf8());
            process->deleteLater();
        }
    });
    connect(process, &QProcess::finished, this, [process, timer, done](int code, QProcess::ExitStatus status) {
        timer->stop();
        const bool failed = status != QProcess::NormalExit || process->property("timedOut").toBool();
        done(failed ? -1 : code, process->readAllStandardOutput().left(1024 * 1024), process->readAllStandardError().left(4096));
        process->deleteLater();
    });
    process->start(program, args);
    timer->start(timeout);
}

void Backend::capture(bool textOnly) {
    if (m_busy || m_preview) return;
    m_busy = true; m_error.clear(); m_status = tr("Select a region. Escape cancels."); emit changed(); emit captureHiding();
    QTimer::singleShot(220, this, [this, textOnly] {
        run("omarchy-capture-region", {"smart"}, 180000, [this, textOnly](int code, const QByteArray &output, const QByteArray &error) {
            const QString selection = QString::fromUtf8(output).trimmed();
            if (code != 0 || selection.isEmpty()) {
                m_busy = false;
                if (!error.isEmpty() || code < 0) fail(tr("Screen selection failed. Check the Omarchy capture tools."));
                else { m_status = tr("Capture cancelled."); emit changed(); }
                emit captureFinished(); return;
            }
            static const QRegularExpression geometry("^-?\\d+,-?\\d+ \\d+x\\d+$");
            if (!geometry.match(selection).hasMatch()) { fail(tr("The region picker returned an invalid selection.")); emit captureFinished(); return; }
            const QString path = m_temporary.filePath("capture.png");
            run("grim", {"-t", "png", "-g", selection, path}, 15000, [this, path, textOnly](int code, const QByteArray &, const QByteArray &) {
                m_busy = false; emit captureFinished();
                if (code != 0) { fail(tr("Could not capture the selected region.")); return; }
                m_afterDecode = [this, textOnly] {
                    QGuiApplication::clipboard()->setImage(m_image);
                    if (textOnly) extractText(); else search();
                };
                loadFile(QUrl::fromLocalFile(path));
            });
        });
    });
}

void Backend::loadFile(const QUrl &url) {
    if (m_busy) return;
    const QFileInfo file(url.toLocalFile());
    if (!url.isLocalFile() || !file.isFile() || file.size() > 20 * 1024 * 1024) {
        m_afterDecode = {}; fail(tr("Choose one local image under 20 MB.")); return;
    }
    m_busy = true; m_error.clear(); m_status = tr("Opening image…"); emit changed();
    const QString path = file.absoluteFilePath();
    m_decoder.setFuture(QtConcurrent::run([path] {
        QImageReader reader(path);
        reader.setAutoTransform(true);
        const QByteArray format = reader.format().toLower();
        if (format != "png" && format != "jpeg" && format != "jpg" && format != "webp") return QImage();
        const QSize size = reader.size();
        if (!size.isValid() || qint64(size.width()) * size.height() > 40000000) return QImage();
        return reader.read();
    }));
}

void Backend::pasteImage() {
    if (m_busy) return;
    const auto clipboard = QGuiApplication::clipboard();
    if (clipboard->mimeData()->hasImage()) setImage(clipboard->image());
    else if (clipboard->mimeData()->hasUrls() && clipboard->mimeData()->urls().size() == 1) loadFile(clipboard->mimeData()->urls().first());
    else fail(tr("The clipboard does not contain an image."));
}

void Backend::chooseFile() {
    if (m_busy || m_preview) return;
    auto bus = QDBusConnection::sessionBus();
    QDBusInterface portal("org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop", "org.freedesktop.portal.FileChooser", bus);
    if (!portal.isValid()) { fail(tr("The desktop file picker is unavailable. You can still drop an image into the window.")); return; }
    const QString token = "lensdesk_" + QUuid::createUuid().toString(QUuid::Id128);
    QString sender = bus.baseService().mid(1); sender.replace('.', '_');
    m_portalPath = "/org/freedesktop/portal/desktop/request/" + sender + "/" + token;
    bus.connect("org.freedesktop.portal.Desktop", m_portalPath, "org.freedesktop.portal.Request", "Response", this, SLOT(portalResponse(uint,QVariantMap)));
    m_busy = true; m_error.clear(); emit changed();
    QVariantMap options{{"handle_token", token}, {"multiple", false}, {"modal", true}};
    auto watcher = new QDBusPendingCallWatcher(portal.asyncCall("OpenFile", QString(), tr("Open image"), options), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher] {
        QDBusPendingReply<QDBusObjectPath> reply = *watcher;
        if (reply.isError()) {
            QDBusConnection::sessionBus().disconnect("org.freedesktop.portal.Desktop", m_portalPath, "org.freedesktop.portal.Request", "Response", this, SLOT(portalResponse(uint,QVariantMap)));
            m_portalPath.clear();
            fail(tr("Could not open the desktop file picker."));
        } else if (!m_portalPath.isEmpty() && reply.value().path() != m_portalPath) {
            auto bus = QDBusConnection::sessionBus();
            bus.disconnect("org.freedesktop.portal.Desktop", m_portalPath, "org.freedesktop.portal.Request", "Response", this, SLOT(portalResponse(uint,QVariantMap)));
            m_portalPath = reply.value().path();
            bus.connect("org.freedesktop.portal.Desktop", m_portalPath, "org.freedesktop.portal.Request", "Response", this, SLOT(portalResponse(uint,QVariantMap)));
        }
        watcher->deleteLater();
    });
}

void Backend::portalResponse(uint response, const QVariantMap &results) {
    QDBusConnection::sessionBus().disconnect("org.freedesktop.portal.Desktop", m_portalPath, "org.freedesktop.portal.Request", "Response", this, SLOT(portalResponse(uint,QVariantMap)));
    m_portalPath.clear();
    m_busy = false; emit changed();
    const QStringList urls = results.value("uris").toStringList();
    if (response == 0 && urls.size() == 1) loadFile(QUrl(urls.first()));
}

void Backend::search() {
    if (m_busy || !hasImage()) return;
    if (m_preview) { m_status = tr("Offline preview — no image was uploaded."); emit changed(); return; }
    m_busy = true; m_error.clear(); m_status = tr("Preparing visual search…"); emit changed();
    const auto image = m_image;
    const bool original = originalQuality();
    m_encoder.setFuture(QtConcurrent::run([image, original] {
        const QImage upload = !original && (image.width() > 2560 || image.height() > 2560)
            ? image.scaled(2560, 2560, Qt::KeepAspectRatio, Qt::SmoothTransformation) : image;
        QByteArray bytes; QBuffer buffer(&bytes); buffer.open(QIODevice::WriteOnly);
        if (!upload.save(&buffer, "PNG")) return QByteArray();
        return bytes;
    }));
}

QByteArray Backend::uploadHtml(const QString &imageRoute) {
    // The route is generated internally; no website text enters this document.
    if (!QRegularExpression("^/[0-9a-f]{32}/image\\.png$").match(imageRoute).hasMatch()) return {};
    return QByteArray(R"HTML(<!doctype html><meta charset="utf-8"><meta name="referrer" content="no-referrer">
<title>Google Lens</title><style>body{font:16px system-ui;background:#202124;color:#eee;padding:32px}</style>
<p id="status">Sending your image to Google Lens…</p>
<form id="upload" method="post" enctype="multipart/form-data" action="https://lens.google.com/v3/upload?ep=cntpubb&amp;re=df&amp;s=4">
<input id="image" type="file" name="encoded_image" hidden></form><script>
(async()=>{try{const response=await fetch(')HTML") + imageRoute.toUtf8() + QByteArray(R"HTML(',{cache:'no-store'});
if(!response.ok)throw Error('Image unavailable');const image=await response.blob();const files=new DataTransfer();
files.items.add(new File([image],'screenshot.png',{type:'image/png'}));document.getElementById('image').files=files.files;
const form=document.getElementById('upload');const action=new URL(form.action);action.searchParams.set('st',Date.now().toString());
action.searchParams.set('hl',navigator.language||'en');form.action=action.href;form.submit();
}catch(e){document.getElementById('status').textContent='Could not submit the image. Use Search again to retry.';}})();
</script>)HTML");
}

void Backend::serveUpload(const QByteArray &png) {
    m_server.close(); m_uploadPng = png;
    m_route = "/" + QUuid::createUuid().toString(QUuid::Id128);
    if (!m_server.listen(QHostAddress::LocalHost, 0)) { fail(tr("Could not start the local image handoff.")); return; }
    const QString route = m_route;
    QTimer::singleShot(45000, this, [this, route] {
        if (m_route == route) { m_server.close(); m_uploadPng.clear(); }
    });
    m_status = tr("Sending image to Google Lens…"); emit changed();
    emit navigateRequested(QUrl(QString("http://127.0.0.1:%1%2").arg(m_server.serverPort()).arg(m_route)));
}

void Backend::extractText() {
    if (m_busy || !hasImage()) return;
    if (QStandardPaths::findExecutable("tesseract").isEmpty()) { fail(tr("Install Tesseract to extract text locally.")); return; }
    const QString path = m_temporary.filePath("ocr.png");
    if (!m_image.save(path, "PNG")) { fail(tr("Could not prepare the image for text extraction.")); return; }
    m_busy = true; m_error.clear(); m_status = tr("Reading text locally…"); emit changed();
    run("tesseract", {path, "stdout", "-l", qEnvironmentVariable("OMARCHY_OCR_LANGS", "eng"), "--dpi", "300"}, 30000,
        [this, path](int code, const QByteArray &output, const QByteArray &) {
            QFile::remove(path); m_busy = false;
            if (code != 0) { fail(tr("Text extraction failed. Check the installed Tesseract languages.")); return; }
            m_text = QString::fromUtf8(output).trimmed();
            if (m_text.isEmpty()) { fail(tr("No readable text was found in this image.")); return; }
            m_status = tr("Text extracted locally. Nothing was uploaded."); emit changed(); emit textReady();
        });
}
void Backend::copyText() { if (!m_text.isEmpty()) QGuiApplication::clipboard()->setText(m_text); }

QRect Backend::cropRectangle(const QSize &image, double x, double y, double width, double height) {
    if (!std::isfinite(x) || !std::isfinite(y) || !std::isfinite(width) || !std::isfinite(height) ||
        x < 0 || y < 0 || width <= 0 || height <= 0 || x + width > 1.000001 || y + height > 1.000001) return {};
    return QRect(qRound(x * image.width()), qRound(y * image.height()), qRound(width * image.width()), qRound(height * image.height()))
        .intersected(QRect(QPoint(), image));
}
void Backend::crop(double x, double y, double width, double height) {
    if (m_busy || !hasImage()) return;
    const QRect selection = cropRectangle(m_image.size(), x, y, width, height);
    if (selection.width() < 2 || selection.height() < 2) { fail(tr("Select a larger crop inside the image.")); return; }
    m_undo = m_image; m_image = m_image.copy(selection); m_error.clear();
    m_status = tr("Crop ready. Search again to use it."); refreshImage();
}
void Backend::undoCrop() { if (!m_busy && canUndo()) { m_image = m_undo; m_undo = {}; m_error.clear(); refreshImage(); } }

bool Backend::canOpenExternally(const QUrl &url) {
    return (url.scheme() == "https" || url.scheme() == "http") && !url.host().isEmpty() &&
        url.host() != "127.0.0.1" && url.host() != "localhost" && url.host() != "::1";
}
void Backend::openInBrowser(const QUrl &url) {
    if (canOpenExternally(url)) QDesktopServices::openUrl(url);
    else fail(tr("Search results are not ready to open in your browser."));
}
QVariantMap Backend::geometry() const {
    return {{"x", m_settings.value("x", 100)}, {"y", m_settings.value("y", 80)},
            {"width", m_settings.value("width", 860)}, {"height", m_settings.value("height", 800)}};
}
void Backend::saveGeometry(int x, int y, int width, int height) {
    if (m_preview) return;
    m_settings.setValue("x", x); m_settings.setValue("y", y);
    m_settings.setValue("width", width); m_settings.setValue("height", height);
}
void Backend::seedPreview() {
    QImage image(1000, 560, QImage::Format_RGB32); image.fill(QColor("#ece9df"));
    QPainter painter(&image);
    painter.setPen(QColor("#23302e")); painter.setFont(QFont("sans-serif", 32, QFont::Bold));
    painter.drawText(QRect(65, 60, 850, 90), "A closer look.");
    painter.setFont(QFont("sans-serif", 22));
    painter.drawText(QRect(65, 170, 850, 260), Qt::TextWordWrap, "Capture something interesting. Search the image, crop a detail, or copy its words without leaving your desktop.");
    painter.setPen(Qt::NoPen); painter.setBrush(QColor("#7aa2f7")); painter.drawEllipse(QPoint(840, 440), 55, 55);
    painter.end(); setImage(image);
}
