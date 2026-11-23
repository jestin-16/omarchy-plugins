#include <QFile>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QPainter>
#include <QStandardPaths>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>
#include <limits>

#include "backend.h"
#include "theme.h"
#include "translator.h"

class LensdeskTests : public QObject {
    Q_OBJECT
private slots:
    void validCropAndUndoPreserveOriginal() {
        QTemporaryDir directory;
        Backend backend(true, directory.path());
        QImage image(800, 600, QImage::Format_RGB32); image.fill(Qt::red);
        backend.setImage(image);
        backend.crop(.25, .25, .5, .5);
        QCOMPARE(backend.image().size(), QSize(400, 300));
        QVERIFY(backend.canUndo());
        backend.undoCrop();
        QCOMPARE(backend.image(), image);
        QVERIFY(!backend.canUndo());
    }
    void invalidCropLeavesImageUntouched() {
        QTemporaryDir directory;
        Backend backend(true, directory.path());
        QImage image(800, 600, QImage::Format_RGB32); image.fill(Qt::blue);
        backend.setImage(image);
        backend.crop(-.1, 0, .5, .5);
        QCOMPARE(backend.image(), image);
        QVERIFY(!backend.error().isEmpty());
        QVERIFY(Backend::cropRectangle(image.size(), 0, 0, std::numeric_limits<double>::quiet_NaN(), 1).isEmpty());
        QVERIFY(Backend::cropRectangle(image.size(), .9, .9, .2, .2).isEmpty());
    }
    void loadingLocalFileDoesNotUpload() {
        QTemporaryDir directory;
        QImage image(60, 40, QImage::Format_RGB32); image.fill(Qt::green);
        const QString path = directory.filePath("sample.png"); QVERIFY(image.save(path));
        QFile file(path); QVERIFY(file.open(QIODevice::ReadOnly)); const auto original = file.readAll(); file.close();
        Backend backend(false, directory.path());
        QSignalSpy navigation(&backend, &Backend::navigateRequested);
        backend.loadFile(QUrl::fromLocalFile(path));
        QTRY_VERIFY(!backend.busy());
        QCOMPARE(backend.image().size(), QSize(60, 40));
        QCOMPARE(navigation.size(), 0);
        QVERIFY(file.open(QIODevice::ReadOnly)); QCOMPARE(file.readAll(), original);
    }
    void remoteFilesAreRejected() {
        QTemporaryDir directory;
        Backend backend(true, directory.path());
        backend.loadFile(QUrl("https://example.invalid/image.png"));
        QVERIFY(!backend.hasImage()); QVERIFY(!backend.error().isEmpty()); QVERIFY(!backend.busy());
    }
    void corruptImagesAreRejected() {
        QTemporaryDir directory; QFile file(directory.filePath("bad.png"));
        QVERIFY(file.open(QIODevice::WriteOnly)); file.write("not a png"); file.close();
        Backend backend(true, directory.path()); backend.loadFile(QUrl::fromLocalFile(file.fileName()));
        QTRY_VERIFY(!backend.busy()); QVERIFY(!backend.hasImage()); QVERIFY(!backend.error().isEmpty());
    }
    void uploadFormCarriesImageAndDoesNotAcceptInjectedRoute() {
        const QString route = "/0123456789abcdef0123456789abcdef/image.png";
        const auto html = Backend::uploadHtml(route);
        QVERIFY(html.contains("https://lens.google.com/v3/upload"));
        QVERIFY(html.contains("name=\"encoded_image\""));
        QVERIFY(html.contains("form.submit()"));
        QVERIFY(html.contains(route.toUtf8()));
        QVERIFY(Backend::uploadHtml("/bad';alert(1);//").isEmpty());
    }
    void externalBrowserRejectsNonWebAndLocalHandoffUrls() {
        QVERIFY(Backend::canOpenExternally(QUrl("https://www.google.com/search?q=test")));
        QVERIFY(!Backend::canOpenExternally(QUrl("file:///etc/passwd")));
        QVERIFY(!Backend::canOpenExternally(QUrl("javascript:alert(1)")));
        QVERIFY(!Backend::canOpenExternally(QUrl("http://127.0.0.1:12345/secret")));
    }
    void preferencesAndGeometrySurviveRestart() {
        QTemporaryDir directory;
        { Backend backend(false, directory.path()); backend.setLowMemory(false); backend.setOriginalQuality(true); backend.saveGeometry(20, 30, 900, 700); }
        Backend backend(false, directory.path());
        QVERIFY(!backend.lowMemory()); QVERIFY(backend.originalQuality());
        QCOMPARE(backend.geometry().value("width").toInt(), 900);
    }
    void previewDoesNotStartNetwork() {
        QTemporaryDir directory; Backend backend(true, directory.path()); backend.seedPreview();
        QSignalSpy navigation(&backend, &Backend::navigateRequested);
        backend.search();
        QCOMPARE(navigation.size(), 0); QVERIFY(!backend.busy());
        QVERIFY(backend.status().contains("Offline preview"));
    }
    void localOcrReadsTextWithoutUploading() {
        if (QStandardPaths::findExecutable("tesseract").isEmpty()) QSKIP("Tesseract is not installed");
        QTemporaryDir directory; Backend backend(true, directory.path());
        QImage image(1100, 240, QImage::Format_RGB32); image.fill(Qt::white);
        QPainter painter(&image); painter.setPen(Qt::black); painter.setFont(QFont("sans-serif", 52));
        painter.drawText(QRect(50, 45, 1000, 150), Qt::AlignCenter, "ORBIT 12345"); painter.end();
        backend.setImage(image);
        QSignalSpy navigation(&backend, &Backend::navigateRequested);
        backend.extractText();
        QTRY_VERIFY_WITH_TIMEOUT(!backend.busy(), 10000);
        QVERIFY2(backend.error().isEmpty(), qPrintable(backend.error()));
        QVERIFY2(backend.extractedText().contains("ORBIT"), qPrintable(backend.extractedText()));
        QCOMPARE(navigation.size(), 0);
    }
    void cancellingCaptureRestoresPanelWithoutChangingImage() {
        QTemporaryDir directory;
        QFile picker(directory.filePath("omarchy-capture-region")); QVERIFY(picker.open(QIODevice::WriteOnly));
        picker.write("#!/bin/sh\nexit 1\n"); picker.close();
        QVERIFY(picker.setPermissions(QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner));
        const QByteArray oldPath = qgetenv("PATH");
        qputenv("PATH", directory.path().toUtf8() + ':' + oldPath);
        Backend backend(false, directory.path());
        QImage original(10, 10, QImage::Format_RGB32); original.fill(Qt::red); backend.setImage(original);
        QSignalSpy hidden(&backend, &Backend::captureHiding), restored(&backend, &Backend::captureFinished), navigation(&backend, &Backend::navigateRequested);
        backend.capture();
        QTRY_COMPARE(restored.size(), 1);
        qputenv("PATH", oldPath);
        QCOMPARE(hidden.size(), 1); QCOMPARE(navigation.size(), 0);
        QCOMPARE(backend.image(), original); QVERIFY(!backend.busy());
    }
    void themeAndTranslationUseLocalFixtures() {
        QTemporaryDir directory; QDir().mkpath(directory.filePath("theme"));
        QFile file(directory.filePath("theme/colors.toml")); QVERIFY(file.open(QIODevice::WriteOnly)); file.write("accent = \"#112233\"\n"); file.close();
        Theme theme(directory.path()); QCOMPARE(theme.accent(), QString("#112233"));
        QFile language(directory.filePath("language")); QVERIFY(language.open(QIODevice::WriteOnly)); language.write("da\n"); language.close();
        Translator translator(language.fileName());
        QCOMPARE(translator.translate("Main", "New capture"), QString("Nyt skærmudsnit"));
    }
    void nativeInterfaceLoadsAndCropDialogOpens() {
        QTemporaryDir directory;
        Backend backend(true, directory.path()); backend.seedPreview();
        Theme theme(directory.path()); Translator translator(directory.filePath("language"));
        QQmlApplicationEngine engine;
        engine.rootContext()->setContextProperty("backend", &backend);
        engine.rootContext()->setContextProperty("theme", &theme);
        engine.rootContext()->setContextProperty("translator", &translator);
        engine.rootContext()->setContextProperty("previewMode", true);
        engine.load(QUrl("qrc:/Main.qml"));
        QVERIFY(!engine.rootObjects().isEmpty());
        auto window = qobject_cast<QQuickWindow *>(engine.rootObjects().first()); QVERIFY(window);
        auto button = window->findChild<QQuickItem *>("cropButton"); QVERIFY(button);
        QTest::qWait(100);
        const QPoint center = button->mapToScene(QPointF(button->width() / 2, button->height() / 2)).toPoint();
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, center);
        auto dialog = window->findChild<QObject *>("cropDialog"); QVERIFY(dialog);
        QTRY_VERIFY(dialog->property("visible").toBool());
        QTest::qWait(200);
        auto area = window->findChild<QQuickItem *>("cropArea"); QVERIFY(area);
        const QPoint start = area->mapToScene(QPointF(area->width() * .25, area->height() * .25)).toPoint();
        const QPoint end = area->mapToScene(QPointF(area->width() * .75, area->height() * .75)).toPoint();
        QTest::mousePress(window, Qt::LeftButton, Qt::NoModifier, start);
        QTest::mouseMove(window, end, 40);
        QTest::mouseRelease(window, Qt::LeftButton, Qt::NoModifier, end);
        auto apply = window->findChild<QQuickItem *>("cropApplyButton"); QVERIFY(apply);
        QTRY_VERIFY(apply->isEnabled());
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, apply->mapToScene(QPointF(apply->width()/2, apply->height()/2)).toPoint());
        QTRY_VERIFY(!dialog->property("visible").toBool());
        QVERIFY(backend.canUndo());
        QVERIFY(qAbs(backend.image().width() - 500) < 6);
    }
};

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("Material");
    LensdeskTests tests;
    return QTest::qExec(&tests, argc, argv);
}
#include "lensdesk_tests.moc"
