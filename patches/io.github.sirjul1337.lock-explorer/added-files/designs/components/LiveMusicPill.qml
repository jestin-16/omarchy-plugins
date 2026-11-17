import QtQuick
import qs.Commons
import qs.Commons as Commons

Rectangle {
  id: pill
  property var lock: null
  readonly property var media: lock ? lock.lockMedia : null
  readonly property bool hasMedia: media ? media.hasMedia : false
  readonly property bool isPlaying: media ? media.playing : false
  readonly property string title: media ? media.title : ""
  readonly property string artist: media ? media.artist : ""

  height: 48
  radius: 24
  color: lock ? lock.withAlpha("#24283b", 0.78) : "#24283b"
  border.width: 1
  border.color: lock ? lock.withAlpha("#7aa2f7", 0.28) : "#7aa2f7"

  // Active Media Display
  Row {
    anchors.fill: parent
    anchors.leftMargin: 12
    anchors.rightMargin: 12
    spacing: 10
    visible: pill.hasMedia

    // Vinyl / Music Icon with rotation when playing
    Rectangle {
      width: 30
      height: 30
      radius: 15
      anchors.verticalCenter: parent.verticalCenter
      color: lock ? lock.withAlpha("#bb9af7", 0.16) : "#bb9af7"
      border.width: 1
      border.color: lock ? lock.withAlpha("#bb9af7", 0.35) : "#bb9af7"

      Text {
        anchors.centerIn: parent
        text: "󰝚"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 15
        color: "#bb9af7"
      }

      RotationAnimation on rotation {
        loops: Animation.Infinite
        from: 0
        to: 360
        duration: 4000
        running: pill.isPlaying
      }
    }

    // Animated Bouncy Equalizer Bars
    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3

      Rectangle {
        width: 3
        height: pill.isPlaying ? bar1Anim.barHeight : 4
        radius: 1.5
        color: "#7aa2f7"
        anchors.bottom: parent.bottom

        Item {
          id: bar1Anim
          property real barHeight: 4
          SequentialAnimation on barHeight {
            loops: Animation.Infinite
            running: pill.isPlaying
            NumberAnimation { to: 16; duration: 280; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 5; duration: 280; easing.type: Easing.InOutQuad }
          }
        }
      }

      Rectangle {
        width: 3
        height: pill.isPlaying ? bar2Anim.barHeight : 4
        radius: 1.5
        color: "#bb9af7"
        anchors.bottom: parent.bottom

        Item {
          id: bar2Anim
          property real barHeight: 6
          SequentialAnimation on barHeight {
            loops: Animation.Infinite
            running: pill.isPlaying
            NumberAnimation { to: 18; duration: 380; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 4; duration: 380; easing.type: Easing.InOutQuad }
          }
        }
      }

      Rectangle {
        width: 3
        height: pill.isPlaying ? bar3Anim.barHeight : 4
        radius: 1.5
        color: "#7dcfff"
        anchors.bottom: parent.bottom

        Item {
          id: bar3Anim
          property real barHeight: 8
          SequentialAnimation on barHeight {
            loops: Animation.Infinite
            running: pill.isPlaying
            NumberAnimation { to: 14; duration: 320; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 6; duration: 320; easing.type: Easing.InOutQuad }
          }
        }
      }
    }

    // Track Title and Artist
    Column {
      anchors.verticalCenter: parent.verticalCenter
      width: Math.max(80, pill.width - 200)
      spacing: 1

      Text {
        width: parent.width
        text: pill.title.length > 0 ? pill.title : "Audio Playing"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        font.weight: Font.Medium
        color: "#c0caf5"
      }
      Text {
        width: parent.width
        text: pill.artist.length > 0 ? pill.artist : "Media"
        textFormat: Text.PlainText
        elide: Text.ElideRight
        font.family: "Adwaita Sans"
        font.pixelSize: 10
        color: lock ? lock.withAlpha("#a9b1d6", 0.7) : "#a9b1d6"
      }
    }

    // Mini Media Controls
    Row {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4

      // Prev
      Rectangle {
        width: 26
        height: 26
        radius: 13
        color: prevArea.containsMouse ? (lock ? lock.withAlpha("#7aa2f7", 0.25) : "#7aa2f7") : "transparent"
        Text {
          anchors.centerIn: parent
          text: "󰒮"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 12
          color: "#c0caf5"
        }
        MouseArea {
          id: prevArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: if (pill.lock) pill.lock.mediaAct("previous")
        }
      }

      // Play/Pause
      Rectangle {
        width: 28
        height: 28
        radius: 14
        color: lock ? lock.withAlpha("#7aa2f7", playArea.containsMouse ? 0.35 : 0.20) : "#7aa2f7"
        border.width: 1
        border.color: lock ? lock.withAlpha("#7aa2f7", 0.4) : "#7aa2f7"

        Text {
          anchors.centerIn: parent
          text: pill.isPlaying ? "󰏤" : "󰐊"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 13
          color: "#7aa2f7"
        }
        MouseArea {
          id: playArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: if (pill.lock) pill.lock.mediaAct("toggle")
        }
      }

      // Next
      Rectangle {
        width: 26
        height: 26
        radius: 13
        color: nextArea.containsMouse ? (lock ? lock.withAlpha("#7aa2f7", 0.25) : "#7aa2f7") : "transparent"
        Text {
          anchors.centerIn: parent
          text: "󰒭"
          font.family: "JetBrainsMono Nerd Font"
          font.pixelSize: 12
          color: "#c0caf5"
        }
        MouseArea {
          id: nextArea
          anchors.fill: parent
          hoverEnabled: true
          onClicked: if (pill.lock) pill.lock.mediaAct("next")
        }
      }
    }
  }

  // Cozy Idle Display (when no active media)
  Row {
    anchors.centerIn: parent
    spacing: 8
    visible: !pill.hasMedia

    Text {
      text: "🌸"
      font.pixelSize: 14
      anchors.verticalCenter: parent.verticalCenter
    }

    Text {
      text: "Tokyo Night Cozy Lo-Fi · All is peaceful ✨"
      textFormat: Text.PlainText
      font.family: "Adwaita Sans"
      font.pixelSize: 12
      font.weight: Font.Medium
      color: lock ? lock.withAlpha("#c0caf5", 0.85) : "#c0caf5"
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
