import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: win
    objectName: "mainWindow"
    width: Math.max(660, Math.min(backend.geometry().width, Screen.desktopAvailableWidth))
    height: Math.max(580, Math.min(backend.geometry().height, Screen.desktopAvailableHeight))
    minimumWidth: 660
    minimumHeight: 580
    x: Math.max(Screen.virtualX, Math.min(backend.geometry().x, Screen.virtualX + Screen.width - width))
    y: Math.max(Screen.virtualY, Math.min(backend.geometry().y, Screen.virtualY + Screen.height - height))
    visible: true
    title: "Lensdesk"
    color: "#111214"
    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius
    property bool pinned: false
    property bool requested: false
    property bool suspended: false
    property url pendingUrl: ""
    property url lastUrl: ""
    flags: Qt.Window | (pinned ? Qt.WindowStaysOnTopHint : 0)

    function showPanel() {
        show(); raise(); requestActivate()
        if (suspended) { suspended = false; pendingUrl = lastUrl }
    }
    function dismiss() {
        backend.saveGeometry(x, y, width, height)
        hide()
    }
    onClosing: function(close) { close.accepted = false; dismiss() }
    Timer {
        interval: 300000
        running: !win.visible && backend.lowMemory && !backend.busy && win.requested && !win.suspended
        onTriggered: {
            if (browser.item) win.lastUrl = browser.item.currentUrl
            win.suspended = true
            backend.pageStatus(qsTr("Results paused to save memory. Reopen to continue."))
        }
    }
    Connections {
        target: backend
        function onCaptureHiding() { win.hide() }
        function onCaptureFinished() { win.showPanel() }
        function onActivateRequested() { win.showPanel() }
        function onNavigateRequested(url) {
            win.pendingUrl = url; win.requested = true; win.suspended = false
            if (browser.item) browser.item.navigate(url)
        }
        function onTextReady() { if (backend.extractedText.length) textDialog.open() }
    }

    Shortcut { sequence: "Ctrl+N"; onActivated: backend.capture() }
    Shortcut { sequence: "Ctrl+O"; onActivated: backend.chooseFile() }
    Shortcut { sequence: "Ctrl+Shift+V"; onActivated: backend.pasteImage() }
    Shortcut { sequence: "Ctrl+Q"; onActivated: Qt.quit() }
    Shortcut { sequence: "Ctrl+Z"; enabled: !win.requested; onActivated: backend.undoCrop() }
    Shortcut { sequence: "?"; enabled: !win.requested; onActivated: helpDialog.open() }
    Shortcut { sequence: "Q"; enabled: !win.requested; onActivated: Qt.quit() }
    Shortcut { sequence: "Space"; enabled: !win.requested; onActivated: backend.capture() }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Image { source: "qrc:/lensdesk.svg"; sourceSize.width: 38; sourceSize.height: 38 }
            ColumnLayout {
                spacing: 2
                Label { text: "Lensdesk"; font.pixelSize: 21; font.bold: true; textFormat: Text.PlainText }
                Label { text: previewMode ? qsTr("Offline preview · browser not started") : qsTr("Capture. Explore. Keep your flow."); opacity: .6; font.pixelSize: 12; textFormat: Text.PlainText }
            }
            Item { Layout.fillWidth: true }
            ToolButton { text: win.pinned ? qsTr("Unpin") : qsTr("Pin"); onClicked: win.pinned = !win.pinned }
            ToolButton { text: qsTr("Hide"); onClicked: win.dismiss() }
            ToolButton { text: "⋮"; Accessible.name: qsTr("Settings"); onClicked: settingsMenu.open()
                Menu {
                    id: settingsMenu
                    MenuItem { text: qsTr("Release browser after 5 minutes hidden"); checkable: true; checked: backend.lowMemory; onTriggered: backend.lowMemory = checked }
                    MenuItem { text: qsTr("Original image quality"); checkable: true; checked: backend.originalQuality; onTriggered: backend.originalQuality = checked }
                    MenuSeparator {}
                    MenuItem { text: qsTr("Capture text locally"); enabled: !backend.busy; onTriggered: backend.capture(true) }
                    MenuItem { text: qsTr("Keyboard shortcuts"); onTriggered: helpDialog.open() }
                    MenuItem { text: qsTr("Quit"); onTriggered: { backend.saveGeometry(win.x, win.y, win.width, win.height); Qt.quit() } }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            ActionButton { objectName: "captureButton"; text: qsTr("New capture"); primary: true; enabled: !backend.busy; onClicked: backend.capture() }
            ActionButton { text: qsTr("Paste image"); enabled: !backend.busy; onClicked: backend.pasteImage() }
            ActionButton { text: qsTr("Open file"); enabled: !backend.busy; onClicked: backend.chooseFile() }
            Item { Layout.fillWidth: true }
            ToolButton { text: qsTr("Back"); enabled: browser.item ? browser.item.canGoBack : false; onClicked: browser.item.back() }
            ToolButton { text: qsTr("Browser"); enabled: browser.item !== null; onClicked: backend.openInBrowser(browser.item.currentUrl) }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: backend.hasImage ? 94 : 0
            visible: backend.hasImage
            color: "#1b1d21"
            radius: theme.radius
            border.color: "#30333b"
            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12
                Image { source: backend.previewSource; fillMode: Image.PreserveAspectFit; Layout.preferredWidth: 90; Layout.preferredHeight: 66 }
                ColumnLayout {
                    Layout.fillWidth: true
                    Label { text: qsTr("Current image"); font.bold: true; textFormat: Text.PlainText }
                    Label {
                        text: { translator.language; return backend.dimensions }
                        opacity: .6; font.pixelSize: 12; textFormat: Text.PlainText
                    }
                }
                ActionButton { objectName: "cropButton"; text: qsTr("Crop"); enabled: !backend.busy; onClicked: cropDialog.open() }
                ActionButton { text: qsTr("Extract text"); enabled: !backend.busy; onClicked: backend.extractText() }
                ActionButton { text: win.requested ? qsTr("Search again") : qsTr("Search"); primary: true; enabled: !backend.busy; onClicked: backend.search() }
            }
        }

        Rectangle {
            id: results
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#17191d"
            radius: theme.radius
            border.color: "#30333b"
            clip: true
            Loader {
                id: browser
                anchors.fill: parent
                anchors.margins: 1
                active: !previewMode && win.requested && !win.suspended
                source: active ? "BrowserPane.qml" : ""
                onLoaded: item.navigate(win.pendingUrl)
            }
            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - 64, 460)
                spacing: 16
                visible: !browser.active && !backend.hasImage
                Image { Layout.alignment: Qt.AlignHCenter; source: "qrc:/lensdesk.svg"; sourceSize.width: 72; sourceSize.height: 72; opacity: .85 }
                Label { Layout.fillWidth: true; text: qsTr("A closer look, one capture away."); font.pixelSize: 23; font.bold: true; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; textFormat: Text.PlainText }
                Label { Layout.fillWidth: true; text: qsTr("Search an image with Google Lens, or extract its text locally. Drop a PNG, JPEG, or WebP here to get started."); opacity: .65; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; textFormat: Text.PlainText }
                Label { Layout.fillWidth: true; text: qsTr("Visual search sends the selected image to Google. Text extraction stays on this device."); opacity: .45; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; font.pixelSize: 12; textFormat: Text.PlainText }
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 18
                visible: !browser.active && backend.hasImage
                Label { text: qsTr("IMAGE PREVIEW"); color: "#858b98"; font.pixelSize: 11; font.letterSpacing: 1.5; textFormat: Text.PlainText }
                Image { Layout.fillWidth: true; Layout.fillHeight: true; source: backend.previewSource; fillMode: Image.PreserveAspectFit }
                Label { Layout.fillWidth: true; text: qsTr("Search the image, crop a detail, or extract its text locally."); color: "#a6abb7"; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; textFormat: Text.PlainText }
            }
            DropArea {
                anchors.fill: parent
                enabled: !backend.busy
                onEntered: function(drag) { drag.accepted = drag.hasUrls && drag.urls.length === 1 && drag.urls[0].toString().indexOf("file:") === 0 }
                onDropped: function(drop) { if (drop.hasUrls && drop.urls.length === 1) { backend.loadFile(drop.urls[0]); drop.acceptProposedAction() } }
                Rectangle { anchors.fill: parent; color: "transparent"; border.width: 2; border.color: theme.accent; visible: parent.containsDrag }
            }
            ProgressBar { anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; height: 3; visible: backend.busy || (browser.item ? browser.item.loading : false); indeterminate: backend.busy; value: browser.item ? browser.item.progress / 100 : 0 }
        }

        RowLayout {
            Layout.fillWidth: true
            Label { Layout.fillWidth: true; text: backend.error || backend.status; color: backend.error ? "#ff9797" : "#a6abb7"; font.pixelSize: 12; wrapMode: Text.WordWrap; textFormat: Text.PlainText }
            Label { text: backend.lowMemory ? qsTr("Low memory") : qsTr("Keep ready"); color: theme.accent; font.pixelSize: 11; textFormat: Text.PlainText }
        }
    }

    Dialog {
        id: textDialog
        title: qsTr("Text extracted locally")
        anchors.centerIn: parent
        width: Math.min(win.width - 48, 620)
        height: Math.min(win.height - 80, 480)
        modal: true
        ColumnLayout {
            anchors.fill: parent
            ScrollView { Layout.fillWidth: true; Layout.fillHeight: true; TextArea { text: backend.extractedText; textFormat: TextEdit.PlainText; readOnly: true; wrapMode: TextEdit.Wrap; selectByMouse: true } }
            RowLayout { Layout.alignment: Qt.AlignRight
                Button { text: qsTr("Copy to clipboard"); onClicked: backend.copyText() }
                Button { text: qsTr("Close"); onClicked: textDialog.close() }
            }
        }
    }

    Dialog {
        id: cropDialog
        objectName: "cropDialog"
        title: qsTr("Drag to select a crop")
        anchors.centerIn: parent
        width: win.width - 48
        height: win.height - 90
        modal: true
        onOpened: cropArea.reset()
        ColumnLayout {
            anchors.fill: parent
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Image { id: cropImage; anchors.fill: parent; source: backend.previewSource; fillMode: Image.PreserveAspectFit }
                MouseArea {
                    id: cropArea
                    objectName: "cropArea"
                    x: (parent.width - cropImage.paintedWidth) / 2
                    y: (parent.height - cropImage.paintedHeight) / 2
                    width: cropImage.paintedWidth
                    height: cropImage.paintedHeight
                    property real startX: 0
                    property real startY: 0
                    property real endX: 0
                    property real endY: 0
                    function reset() { startX = 0; startY = 0; endX = 0; endY = 0 }
                    onPressed: function(mouse) { startX = mouse.x; startY = mouse.y; endX = mouse.x; endY = mouse.y }
                    onPositionChanged: function(mouse) { if (pressed) { endX = Math.max(0, Math.min(width, mouse.x)); endY = Math.max(0, Math.min(height, mouse.y)) } }
                    Rectangle { id: cropSelection; x: Math.min(cropArea.startX, cropArea.endX); y: Math.min(cropArea.startY, cropArea.endY); width: Math.abs(cropArea.startX - cropArea.endX); height: Math.abs(cropArea.startY - cropArea.endY); color: "#227aa2f7"; border.color: theme.accent; border.width: 2 }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Button { text: qsTr("Undo crop"); enabled: backend.canUndo; onClicked: { backend.undoCrop(); cropArea.reset() } }
                Item { Layout.fillWidth: true }
                Button { text: qsTr("Cancel"); onClicked: cropDialog.close() }
                Button { objectName: "cropApplyButton"; text: qsTr("Apply crop"); highlighted: true; enabled: cropSelection.width >= 2 && cropSelection.height >= 2; onClicked: { backend.crop(cropSelection.x / cropArea.width, cropSelection.y / cropArea.height, cropSelection.width / cropArea.width, cropSelection.height / cropArea.height); cropDialog.close() } }
            }
        }
    }

    Dialog {
        id: helpDialog
        title: qsTr("Keyboard shortcuts")
        anchors.centerIn: parent
        modal: true
        width: Math.min(win.width - 48, 500)
        standardButtons: Dialog.Close
        Label { width: parent.width; text: qsTr("Ctrl+N — New capture\nCtrl+O — Open image\nCtrl+Shift+V — Paste image\nCtrl+Q — Quit\nCtrl+Z — Undo crop (before search)\nSpace — Capture (before search)\n? — Help (before search)"); wrapMode: Text.WordWrap; textFormat: Text.PlainText }
    }
}
