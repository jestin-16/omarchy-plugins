#pragma once

#include <QFutureWatcher>
#include <QImage>
#include <QObject>
#include <QProcess>
#include <QSettings>
#include <QTcpServer>
#include <QTemporaryDir>
#include <QUrl>
#include <functional>

class Backend : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool hasImage READ hasImage NOTIFY changed)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QString previewSource READ previewSource NOTIFY changed)
    Q_PROPERTY(QString dimensions READ dimensions NOTIFY changed)
    Q_PROPERTY(QString extractedText READ extractedText NOTIFY textReady)
    Q_PROPERTY(bool lowMemory READ lowMemory WRITE setLowMemory NOTIFY preferencesChanged)
    Q_PROPERTY(bool originalQuality READ originalQuality WRITE setOriginalQuality NOTIFY preferencesChanged)
    Q_PROPERTY(QString profilePath READ profilePath CONSTANT)
    Q_PROPERTY(QString cachePath READ cachePath CONSTANT)

public:
    explicit Backend(bool preview = false, const QString &stateRoot = {}, QObject *parent = nullptr);
    ~Backend() override;
    bool busy() const { return m_busy; }
    bool hasImage() const { return !m_image.isNull(); }
    bool canUndo() const { return !m_undo.isNull(); }
    QString status() const { return m_status; }
    QString error() const { return m_error; }
    QString previewSource() const { return m_previewSource; }
    QString dimensions() const;
    QString extractedText() const { return m_text; }
    bool lowMemory() const;
    bool originalQuality() const;
    void setLowMemory(bool enabled);
    void setOriginalQuality(bool enabled);
    QString profilePath() const;
    QString cachePath() const;
    QImage image() const { return m_image; }

    Q_INVOKABLE void capture(bool textOnly = false);
    Q_INVOKABLE void pasteImage();
    Q_INVOKABLE void loadFile(const QUrl &url);
    Q_INVOKABLE void chooseFile();
    Q_INVOKABLE void search();
    Q_INVOKABLE void extractText();
    Q_INVOKABLE void copyText();
    Q_INVOKABLE void crop(double x, double y, double width, double height);
    Q_INVOKABLE void undoCrop();
    Q_INVOKABLE void openInBrowser(const QUrl &url);
    Q_INVOKABLE void pageStatus(const QString &status, bool failed = false);
    Q_INVOKABLE QVariantMap geometry() const;
    Q_INVOKABLE void saveGeometry(int x, int y, int width, int height);
    void setImage(const QImage &image);
    void seedPreview();
    static QRect cropRectangle(const QSize &image, double x, double y, double width, double height);
    static QByteArray uploadHtml(const QString &imageRoute);
    static bool canOpenExternally(const QUrl &url);

signals:
    void changed();
    void preferencesChanged();
    void navigateRequested(const QUrl &url);
    void captureHiding();
    void captureFinished();
    void textReady();
    void activateRequested();

private slots:
    void portalResponse(uint response, const QVariantMap &results);

private:
    void fail(const QString &message);
    void run(const QString &program, const QStringList &args, int timeout,
             std::function<void(int, const QByteArray &, const QByteArray &)> finished);
    void refreshImage();
    void serveUpload(const QByteArray &png);
    QString m_root;
    bool m_preview = false;
    bool m_busy = false;
    QImage m_image, m_undo;
    QString m_status, m_error, m_previewSource, m_text, m_portalPath;
    QTemporaryDir m_temporary;
    QSettings m_settings;
    QTcpServer m_server;
    QByteArray m_uploadPng;
    QString m_route;
    QFutureWatcher<QImage> m_decoder;
    QFutureWatcher<QByteArray> m_encoder;
    std::function<void()> m_afterDecode;
};
