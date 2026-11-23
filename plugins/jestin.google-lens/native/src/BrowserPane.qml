import QtQuick
import QtWebEngine

Item {
    id: pane
    readonly property url currentUrl: web.url
    readonly property bool canGoBack: web.canGoBack
    readonly property bool loading: web.loading
    readonly property int progress: web.loadProgress
    function navigate(url) { web.url = url }
    function back() { web.goBack() }
    function reload() { web.reload() }
    WebEngineProfile {
        id: persistentProfile
        storageName: "lensdesk"
        offTheRecord: false
        persistentStoragePath: backend.profilePath
        cachePath: backend.cachePath
        httpCacheMaximumSize: 64 * 1024 * 1024
        persistentCookiesPolicy: WebEngineProfile.AllowPersistentCookies
    }
    WebEngineView {
        id: web
        anchors.fill: parent
        profile: persistentProfile
        backgroundColor: "#202124"
        onLoadingChanged: function(info) {
            if (info.status === WebEngineView.LoadFailedStatus)
                backend.pageStatus(qsTr("Page could not load. Check your connection and retry."), true)
            else if (info.status === WebEngineView.LoadSucceededStatus && web.url.toString().indexOf("http://127.0.0.1:") !== 0)
                backend.pageStatus(qsTr("Results ready. Complete any verification shown by Google."))
        }
        onNewWindowRequested: function(request) { request.openIn(web) }
        onPermissionRequested: function(permission) { permission.deny() }
        onRenderProcessTerminated: backend.pageStatus(qsTr("The results process stopped. Retry your search."), true)
    }
}
