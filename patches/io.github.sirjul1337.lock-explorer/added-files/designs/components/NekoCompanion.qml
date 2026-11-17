import QtQuick
import qs.Commons
import qs.Commons as Commons

Item {
  id: neko
  width: 140
  height: 110

  property string stateMode: "idle" // "idle", "typing", "checking", "failed", "success"
  property color furColor: "#24283b"
  property color furOutline: "#7aa2f7"
  property color earInnerColor: "#ff7a93"
  property color blushColor: "#f7768e"
  property color eyeColor: "#7aa2f7"
  property color pawColor: "#c0caf5"

  property bool eyeClosed: false
  property bool earTwitch: false

  // Idle blink timer
  Timer {
    interval: 3800
    repeat: true
    running: neko.stateMode === "idle"
    onTriggered: {
      neko.eyeClosed = true
      unblinkTimer.restart()
    }
  }

  Timer {
    id: unblinkTimer
    interval: 130
    repeat: false
    onTriggered: neko.eyeClosed = false
  }

  // Periodic subtle ear twitch
  Timer {
    interval: 5200
    repeat: true
    running: true
    onTriggered: {
      neko.earTwitch = true
      untwitchTimer.restart()
    }
  }

  Timer {
    id: untwitchTimer
    interval: 220
    repeat: false
    onTriggered: neko.earTwitch = false
  }

  function reactToType() {
    neko.earTwitch = true
    untwitchTimer.restart()
  }

  // Gentle floating / breathing idle animation
  Item {
    id: floatingBody
    anchors.fill: parent

    SequentialAnimation on y {
      loops: Animation.Infinite
      running: true
      NumberAnimation { to: -3; duration: 1800; easing.type: Easing.InOutQuad }
      NumberAnimation { to: 0; duration: 1800; easing.type: Easing.InOutQuad }
    }

    // --- WAGGING TAIL ---
    Item {
      id: tailContainer
      x: 105
      y: 50
      width: 30
      height: 40
      transformOrigin: Item.BottomLeft

      SequentialAnimation on rotation {
        loops: Animation.Infinite
        running: true
        NumberAnimation { to: 16; duration: 1200; easing.type: Easing.InOutSine }
        NumberAnimation { to: -6; duration: 1200; easing.type: Easing.InOutSine }
      }

      Rectangle {
        width: 12
        height: 34
        radius: 6
        color: neko.furColor
        border.width: 1.5
        border.color: neko.furOutline
        rotation: 25
      }
    }

    // --- LEFT EAR ---
    Item {
      x: 24
      y: 12
      width: 28
      height: 32
      rotation: neko.earTwitch ? -14 : -6
      Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

      Rectangle {
        anchors.fill: parent
        radius: 6
        color: neko.furColor
        border.width: 1.5
        border.color: neko.furOutline
        rotation: 45
      }
      Rectangle {
        width: 14
        height: 16
        anchors.centerIn: parent
        radius: 3
        color: neko.earInnerColor
        opacity: 0.85
        rotation: 45
      }
    }

    // --- RIGHT EAR ---
    Item {
      x: 88
      y: 12
      width: 28
      height: 32
      rotation: neko.earTwitch ? 14 : 6
      Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }

      Rectangle {
        anchors.fill: parent
        radius: 6
        color: neko.furColor
        border.width: 1.5
        border.color: neko.furOutline
        rotation: 45
      }
      Rectangle {
        width: 14
        height: 16
        anchors.centerIn: parent
        radius: 3
        color: neko.earInnerColor
        opacity: 0.85
        rotation: 45
      }
    }

    // --- SAKURA FLOWER PIN ON EAR ---
    Text {
      x: 82
      y: 20
      text: "🌸"
      font.pixelSize: 18
      rotation: 15
    }

    // --- HEAD ---
    Rectangle {
      id: head
      x: 20
      y: 26
      width: 100
      height: 72
      radius: 36
      color: neko.furColor
      border.width: 1.5
      border.color: neko.furOutline

      // Head tilt when checking
      rotation: neko.stateMode === "checking" ? -6 : (neko.stateMode === "failed" ? 8 : 0)
      Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

      // --- CHEEK BLUSH ---
      Rectangle {
        x: 12
        y: 42
        width: 16
        height: 10
        radius: 5
        color: neko.blushColor
        opacity: neko.stateMode === "failed" ? 0.75 : 0.42
      }
      Rectangle {
        x: 72
        y: 42
        width: 16
        height: 10
        radius: 5
        color: neko.blushColor
        opacity: neko.stateMode === "failed" ? 0.75 : 0.42
      }

      // --- NOSE ---
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 40
        width: 6
        height: 4
        radius: 2
        color: neko.earInnerColor
      }

      // --- MOUTH ---
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 44
        text: neko.stateMode === "failed" ? "﹏" : "ω"
        font.family: Style.font.family
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: neko.stateMode === "failed" ? neko.earInnerColor : "#a9b1d6"
      }

      // --- EYES ---
      // 1. Idle or Normal Mode
      Item {
        id: normalEyes
        anchors.fill: parent
        visible: neko.stateMode !== "typing" && neko.stateMode !== "failed" && neko.stateMode !== "success"

        // Left eye
        Rectangle {
          x: 26
          y: 30
          width: 14
          height: neko.eyeClosed ? 2 : 14
          radius: 7
          color: neko.eyeClosed ? neko.furOutline : "#13141c"
          border.width: 1
          border.color: neko.eyeColor
          Behavior on height { NumberAnimation { duration: 60 } }

          // Double sparkle shine
          Rectangle {
            visible: !neko.eyeClosed
            x: 3
            y: 3
            width: 5
            height: 5
            radius: 2.5
            color: "#ffffff"
          }
          Rectangle {
            visible: !neko.eyeClosed
            x: 8
            y: 8
            width: 2.5
            height: 2.5
            radius: 1.25
            color: neko.eyeColor
          }
        }

        // Right eye
        Rectangle {
          x: 60
          y: 30
          width: 14
          height: neko.eyeClosed ? 2 : 14
          radius: 7
          color: neko.eyeClosed ? neko.furOutline : "#13141c"
          border.width: 1
          border.color: neko.eyeColor
          Behavior on height { NumberAnimation { duration: 60 } }

          // Double sparkle shine
          Rectangle {
            visible: !neko.eyeClosed
            x: 3
            y: 3
            width: 5
            height: 5
            radius: 2.5
            color: "#ffffff"
          }
          Rectangle {
            visible: !neko.eyeClosed
            x: 8
            y: 8
            width: 2.5
            height: 2.5
            radius: 1.25
            color: neko.eyeColor
          }
        }
      }

      // 2. Typing or Success Mode (Happy curved smiling eyes)
      Item {
        id: happyEyes
        anchors.fill: parent
        visible: neko.stateMode === "typing" || neko.stateMode === "success"

        Text {
          x: 24
          y: 22
          text: "^"
          font.family: Style.font.family
          font.pixelSize: 22
          font.bold: true
          color: neko.eyeColor
        }
        Text {
          x: 62
          y: 22
          text: "^"
          font.family: Style.font.family
          font.pixelSize: 22
          font.bold: true
          color: neko.eyeColor
        }
      }

      // 3. Failed Mode (Dizzy eyes > <)
      Item {
        id: dizzyEyes
        anchors.fill: parent
        visible: neko.stateMode === "failed"

        Text {
          x: 25
          y: 24
          text: ">"
          font.family: Style.font.family
          font.pixelSize: 18
          font.bold: true
          color: "#f7768e"
        }
        Text {
          x: 63
          y: 24
          text: "<"
          font.family: Style.font.family
          font.pixelSize: 18
          font.bold: true
          color: "#f7768e"
        }
        // Sweat drop
        Text {
          x: 86
          y: 16
          text: "💧"
          font.pixelSize: 14
        }
      }
    }

    // --- PAWS HOLDING CARD EDGE ---
    // Left paw
    Rectangle {
      x: 36
      y: 88
      width: 22
      height: 18
      radius: 9
      color: neko.pawColor
      border.width: 1
      border.color: neko.furOutline

      // Tiny pink paw pad
      Rectangle {
        anchors.centerIn: parent
        width: 8
        height: 6
        radius: 3
        color: neko.earInnerColor
        opacity: 0.7
      }
    }

    // Right paw
    Rectangle {
      x: 82
      y: 88
      width: 22
      height: 18
      radius: 9
      color: neko.pawColor
      border.width: 1
      border.color: neko.furOutline

      // Tiny pink paw pad
      Rectangle {
        anchors.centerIn: parent
        width: 8
        height: 6
        radius: 3
        color: neko.earInnerColor
        opacity: 0.7
      }
    }
  }
}
