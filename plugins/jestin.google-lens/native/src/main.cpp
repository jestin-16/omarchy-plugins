#include <QCommandLineParser>
#include <QDir>
#include <QFile>
#include <QGuiApplication>
#include <QIcon>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QLocalServer>
#include <QLocalSocket>
#include <QLockFile>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QTimer>
#include <QtWebEngineQuick>
#include <cstdio>

#include "backend.h"
#include "theme.h"
#include "translator.h"

int main(int argc, char *argv[]) {
    bool preview = false;
    bool headless = false;
    for (int i = 1; i < argc; ++i) {
        const QByteArray arg(argv[i]);
        if (arg == "--preview") preview = true;
        if (arg == "--check" || arg == "--help" || arg == "-h" || arg == "--version" || arg == "-v") headless = true;
    }
    if (headless) { qputenv("QT_QPA_PLATFORM", "offscreen"); qputenv("QT_QPA_PLATFORMTHEME", "generic"); }
    if (!preview && !headless) QtWebEngineQuick::initialize();
    QGuiApplication app(argc, argv);
    app.setApplicationName("lensdesk");
    app.setApplicationVersion("0.1.0");
    app.setDesktopFileName("lensdesk");
    app.setWindowIcon(QIcon(":/lensdesk.svg"));
    app.setQuitOnLastWindowClosed(false);
    QQuickStyle::setStyle("Material");

    QCommandLineParser parser;
    parser.setApplicationDescription("Native visual search panel (preview release)");
    parser.addHelpOption(); parser.addVersionOption();
    parser.addOption({"preview", "Render offline sample content without starting a browser."});
    parser.addOption({"screenshot", "Save the offline preview and exit.", "path"});
    parser.addOption({"language", "Language used for an offline preview.", "code"});
    parser.addOption({"capture", "Capture a region and search it."});
    parser.addOption({"text", "Capture a region and extract text locally."});
    parser.addOption({"check", "Check local dependencies without opening a window."});
    parser.addOption({"json", "Print dependency checks as JSON."});
    parser.addPositionalArgument("image", "Optional local image to open.", "[image]");
    parser.process(app);
    if (parser.isSet("check")) {
        QJsonObject tools;
        bool ready = true;
        for (const QString &name : {QString("omarchy-capture-region"), QString("grim")}) {
            const QString executable = QStandardPaths::findExecutable(name);
            tools.insert(name, executable);
            ready = ready && !executable.isEmpty();
        }
        tools.insert("tesseract_optional", QStandardPaths::findExecutable("tesseract"));
        const auto data = QJsonDocument(QJsonObject{{"ready", ready}, {"tools", tools}, {"live_google_verified", false}}).toJson();
        if (parser.isSet("json")) std::fwrite(data.constData(), 1, data.size(), stdout);
        else std::printf("Lensdesk dependencies: %s. Native Google compatibility requires a live test.\n", ready ? "available" : "missing");
        return ready ? 0 : 1;
    }
    if (parser.isSet("json")) parser.showHelp(1);
    if (parser.isSet("screenshot") && !preview) parser.showHelp(1);
    if (parser.positionalArguments().size() > 1) parser.showHelp(1);

    const QString action = parser.isSet("text") ? "text" : parser.isSet("capture") ? "capture" : "show";
    const QString file = parser.positionalArguments().isEmpty() ? QString() : QFileInfo(parser.positionalArguments().first()).absoluteFilePath();
    const auto message = QJsonDocument(QJsonObject{{"action", action}, {"file", file}}).toJson(QJsonDocument::Compact) + '\n';
    const QString runtime = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    const QString socketPath = runtime + "/lensdesk.socket";
    QLocalServer server;
    QLockFile lock(runtime + "/lensdesk.lock");
    if (!preview) {
        QLocalSocket existing;
        existing.connectToServer(socketPath);
        if (existing.waitForConnected(250)) {
            existing.write(message); existing.waitForBytesWritten(1000); return 0;
        }
        if (!lock.tryLock(0)) { std::fprintf(stderr, "Lensdesk is already running but could not be reached.\n"); return 1; }
        QLocalServer::removeServer(socketPath);
        server.setSocketOptions(QLocalServer::UserAccessOption);
        if (!server.listen(socketPath)) { std::fprintf(stderr, "Could not create the Lensdesk local control socket.\n"); return 1; }
    }

    QTemporaryDir previewState;
    QString languageFile;
    if (preview && parser.isSet("language")) {
        languageFile = previewState.filePath("language");
        QFile language(languageFile);
        if (!language.open(QIODevice::WriteOnly)) return 1;
        language.write(parser.value("language").toUtf8()); language.close();
    }
    Translator translator(languageFile);
    app.installTranslator(&translator);
    Theme theme(preview ? previewState.path() : QString());
    Backend backend(preview, preview ? previewState.path() : QString());
    if (preview) backend.seedPreview();
    QQmlApplicationEngine engine;
    QObject::connect(&translator, &Translator::changed, &engine, &QQmlEngine::retranslate);
    engine.rootContext()->setContextProperty("translator", &translator);
    engine.rootContext()->setContextProperty("theme", &theme);
    engine.rootContext()->setContextProperty("backend", &backend);
    engine.rootContext()->setContextProperty("previewMode", preview);
    engine.load(QUrl("qrc:/Main.qml"));
    if (engine.rootObjects().isEmpty()) return 1;
    auto window = qobject_cast<QQuickWindow *>(engine.rootObjects().first());

    const auto handle = [&backend](const QJsonObject &object) {
        emit backend.activateRequested();
        const QString file = object.value("file").toString();
        if (!file.isEmpty()) backend.loadFile(QUrl::fromLocalFile(file));
        else if (object.value("action").toString() == "capture") backend.capture();
        else if (object.value("action").toString() == "text") backend.capture(true);
    };
    QObject::connect(&server, &QLocalServer::newConnection, &app, [&server, handle] {
        while (auto socket = server.nextPendingConnection()) {
            QObject::connect(socket, &QLocalSocket::disconnected, socket, &QObject::deleteLater);
            QTimer::singleShot(2000, socket, &QLocalSocket::abort);
            QObject::connect(socket, &QLocalSocket::readyRead, socket, [socket, handle] {
                QByteArray data = socket->property("request").toByteArray() + socket->readAll();
                if (data.size() > 8192) { socket->abort(); return; }
                if (!data.contains('\n')) { socket->setProperty("request", data); return; }
                handle(QJsonDocument::fromJson(data.left(data.indexOf('\n'))).object());
                socket->disconnectFromServer();
            });
        }
    });
    if (!preview) QTimer::singleShot(0, &app, [handle, message] { handle(QJsonDocument::fromJson(message).object()); });
    if (preview && parser.isSet("screenshot")) {
        const QString output = parser.value("screenshot");
        QTimer::singleShot(800, &app, [&app, window, output] {
            app.exit(window && window->grabWindow().save(output) ? 0 : 1);
        });
    }
    return app.exec();
}
