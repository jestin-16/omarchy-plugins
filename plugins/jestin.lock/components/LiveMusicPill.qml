import QtQuick
import Quickshell.Services.Mpris
import qs.Commons
import qs.Commons as Commons

Rectangle {
  id: pill

  readonly property var players: Mpris.players ? Mpris.players.values : []
  readonly property var player: {
    var first = null
    for (var i = 0; i < players.length; i++) {
      var p = players[i]
      if (!p) continue
      if (p.playbackState === MprisPlaybackState.Playing) return p
      if (!first) first = p
    }
    return first
  }
  readonly property bool hasMedia: player !== null && String(player.trackTitle || "").length > 0
  readonly property bool isPlaying: hasMedia && player.playbackState === MprisPlaybackState.Playing
  readonly property string title: hasMedia ? String(player.trackTitle || "").substring(0, 160) : ""
  readonly property string artist: hasMedia ? String(player.trackArtist || "").substring(0, 160) : ""

  function mediaAct(action) {
    if (!player) return
    if (action === "previous" && player.canGoPrevious) player.previous()
    else if (action === "next" && player.canGoNext) player.next()
    else if (action === "toggle" && player.canTogglePlaying) player.togglePlaying()
  }

  height: 48
  radius: 24
  color: Qt.rgba(0.14, 0.16, 0.23, 0.78)
  border.width: 1
  border.color: Qt.rgba(0.48, 0.64, 0.97, 0.28)

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
      color: Qt.rgba(0.73, 0.60, 0.97, 0.16)
      border.width: 1
      border.color: Qt.rgba(0.73, 0.60, 0.97, 0.35)

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
        color: Qt.rgba(0.66, 0.69, 0.84, 0.7)
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
        color: prevArea.containsMouse ? Qt.rgba(0.48, 0.64, 0.97, 0.25) : "transparent"
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
          onClicked: pill.mediaAct("previous")
        }
      }

      // Play/Pause
      Rectangle {
        width: 28
        height: 28
        radius: 14
        color: Qt.rgba(0.48, 0.64, 0.97, playArea.containsMouse ? 0.35 : 0.20)
        border.width: 1
        border.color: Qt.rgba(0.48, 0.64, 0.97, 0.4)

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
          onClicked: pill.mediaAct("toggle")
        }
      }

      // Next
      Rectangle {
        width: 26
        height: 26
        radius: 13
        color: nextArea.containsMouse ? Qt.rgba(0.48, 0.64, 0.97, 0.25) : "transparent"
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
          onClicked: pill.mediaAct("next")
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
      color: Qt.rgba(0.75, 0.79, 0.96, 0.85)
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
