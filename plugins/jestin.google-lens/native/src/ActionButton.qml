import QtQuick
import QtQuick.Controls

Button {
    id: control
    property bool primary: false
    implicitHeight: 38
    implicitWidth: contentItem.implicitWidth + 28
    leftPadding: 14
    rightPadding: 14
    contentItem: Text {
        text: control.text
        textFormat: Text.PlainText
        font.pixelSize: 13
        font.weight: control.primary ? Font.DemiBold : Font.Normal
        color: !control.enabled ? "#696d77" : control.primary ? theme.accentForeground : "#e8e9ed"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        radius: Math.min(4, theme.radius)
        color: !control.enabled ? "#1b1d21" : control.primary ? theme.accent : control.down ? "#363a43" : control.hovered ? "#2b2e35" : "#22252b"
        border.width: control.activeFocus ? 2 : 1
        border.color: control.activeFocus ? theme.accent : control.primary && control.enabled ? theme.accent : "#383c45"
    }
}
