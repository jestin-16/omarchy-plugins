import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons
import "."

// ============================================================================
// OMARCHY · TOKYO NIGHT MINIMALIST MONO LOCKSCREEN
// Monospaced JetBrains typography, grand geometric clock, ambient aurora,
// sleek frosted glass card, live weather & battery.
// ============================================================================
DesignBase {
  id: lock
  inputItem: field.input
  chromeRadius: 24
  showMediaStrip: false // Custom integrated minimalist player handles media
  shakeOnFail: false
  flashOnFail: false

  // --- TOKYO NIGHT PASTEL PALETTE ---
  readonly property color tokyoBlue: "#7aa2f7"
  readonly property color tokyoCyan: "#7dcfff"
  readonly property color tokyoLavender: "#bb9af7"
  readonly property color tokyoMagenta: "#ad8ee6"
  readonly property color tokyoPink: "#ff7a93"
  readonly property color tokyoRose: "#f7768e"
  readonly property color tokyoGreen: "#9ece6a"
  readonly property color tokyoYellow: "#e0af68"
  readonly property color tokyoSurface: "#24283b"
  readonly property color tokyoDarkBg: "#1a1b26"
  readonly property color tokyoForeground: "#c0caf5"
  readonly property color tokyoMuted: "#a9b1d6"

  // Primary UI Font: JetBrains Mono Nerd Font
  readonly property string monoFont: "JetBrainsMono Nerd Font"

  // 12h vs 24h separation for dual-tone minimalist typography
  readonly property string rawTime: twelveHour ? clock("hh:mm").replace(" " + meridiem, "") : clock("HH:mm")
  readonly property string hourPart: rawTime.indexOf(":") !== -1 ? rawTime.split(":")[0] : rawTime
  readonly property string minutePart: rawTime.indexOf(":") !== -1 ? rawTime.split(":")[1] : ""

  // Auto-Submit Timer
  Timer {
    id: autoSubmitTimer
    interval: 1600
    repeat: false
    property bool attempted: false
    onTriggered: {
      if (lock.passwordText.length > 0 && !attempted && field.input && field.input.activeFocus && !lock.authenticatingPassword) {
        attempted = true
        field.input.accepted()
      }
    }
    function edited() {
      stop()
      if (lock.passwordText.length > 0 && !attempted && field.input && field.input.activeFocus && !lock.authenticatingPassword) {
        restart()
      }
    }
    function noteAttempt() { attempted = true; stop() }
    function resetSession() { stop(); attempted = false }
  }

  onPasswordTextChanged: Qt.callLater(autoSubmitTimer.edited)
  onAuthenticatingPasswordChanged: if (authenticatingPassword) autoSubmitTimer.noteAttempt()
  onFailedAttemptsChanged: if (failedAttempts > 0) autoSubmitTimer.noteAttempt()
  onInputEnabledChanged: if (!lock.inputEnabled) autoSubmitTimer.resetSession()

  // Interactive Typing Sparkles
  Typing {
    id: typingEvents
    lock: lock
    onTyped: function(index) {
      var mappedField = field.mapToItem(lock, field.width / 2, field.height / 2)
      sparkleLayer.burst(mappedField.x, mappedField.y)
    }
  }

  // --- WALLPAPER & DREAMY AMBIENCE ---
  Wallpaper {
    anchors.fill: parent
    lock: lock
    blur: 0.48
    dim: 0.14
    contrast: -0.04
    vignetteTop: 0.30
    vignetteMiddle: 0.08
    vignetteBottom: 0.48
  }

  // Ethereal Ambient Tokyo Night Aurora Blobs
  Item {
    id: auroraLayer
    anchors.fill: parent
    z: 1
    opacity: 0.35
    layer.enabled: true
    layer.effect: MultiEffect {
      blurEnabled: true
      blur: 1.0
      blurMax: 64
      blurMultiplier: 2.5
    }

    Rectangle {
      width: lock.width * 0.45
      height: width
      radius: width / 2
      color: lock.tokyoBlue
      x: lock.width * 0.15
      y: lock.height * 0.25
      SequentialAnimation on x {
        loops: Animation.Infinite; running: lock.screenAwake
        NumberAnimation { to: lock.width * 0.35; duration: 18000; easing.type: Easing.InOutSine }
        NumberAnimation { to: lock.width * 0.15; duration: 18000; easing.type: Easing.InOutSine }
      }
      SequentialAnimation on y {
        loops: Animation.Infinite; running: lock.screenAwake
        NumberAnimation { to: lock.height * 0.40; duration: 14000; easing.type: Easing.InOutSine }
        NumberAnimation { to: lock.height * 0.25; duration: 14000; easing.type: Easing.InOutSine }
      }
    }

    Rectangle {
      width: lock.width * 0.40
      height: width
      radius: width / 2
      color: lock.tokyoLavender
      x: lock.width * 0.50
      y: lock.height * 0.30
      SequentialAnimation on x {
        loops: Animation.Infinite; running: lock.screenAwake
        NumberAnimation { to: lock.width * 0.30; duration: 20000; easing.type: Easing.InOutSine }
        NumberAnimation { to: lock.width * 0.50; duration: 20000; easing.type: Easing.InOutSine }
      }
      SequentialAnimation on y {
        loops: Animation.Infinite; running: lock.screenAwake
        NumberAnimation { to: lock.height * 0.20; duration: 16000; easing.type: Easing.InOutSine }
        NumberAnimation { to: lock.height * 0.30; duration: 16000; easing.type: Easing.InOutSine }
      }
    }
  }

  // Screen click to wake / refocus
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // --- TYPING BURST SPARKLES ---
  Item {
    id: sparkleLayer
    anchors.fill: parent
    z: 200

    readonly property var particleGlyphs: ["✨", "✦", "✧", "🌸", "⭐", "💫"]
    property int nextParticleIdx: 0

    function burst(ox, oy) {
      var p = burstPool.itemAt(nextParticleIdx)
      if (p) {
        p.glyph = particleGlyphs[Math.floor(Math.random() * particleGlyphs.length)]
        p.x = ox + (Math.random() - 0.5) * 140 - 12
        p.y = oy + (Math.random() - 0.5) * 30 - 12
        p.anim.restart()
      }
      nextParticleIdx = (nextParticleIdx + 1) % 10
    }

    Repeater {
      id: burstPool
      model: 10
      Item {
        id: pItem
        width: 24; height: 24
        opacity: 0; visible: opacity > 0
        property string glyph: "✨"
        property alias anim: pAnim

        Text {
          anchors.centerIn: parent
          text: pItem.glyph
          font.family: lock.monoFont
          font.pixelSize: 15
        }

        ParallelAnimation {
          id: pAnim
          NumberAnimation { target: pItem; property: "y"; to: pItem.y - (45 + Math.random() * 30); duration: 600; easing.type: Easing.OutCubic }
          NumberAnimation { target: pItem; property: "opacity"; from: 1.0; to: 0.0; duration: 600; easing.type: Easing.InQuad }
          NumberAnimation { target: pItem; property: "scale"; from: 0.6; to: 1.25; duration: 600; easing.type: Easing.OutBack }
        }
      }
    }
  }

  // Status Sources
  LiveBattery { id: batterySource }
  LiveWeather { id: weatherSource; lock: lock }

  // ==========================================
  // TOP BAR: SLEEK FLOATING CAPSULES
  // ==========================================
  Item {
    id: topBar
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: 28
    anchors.leftMargin: 40
    anchors.rightMargin: 40
    height: 36
    z: 100

    // Top Left: Weather Capsule
    Rectangle {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      height: 32
      radius: 16
      width: weatherRow.implicitWidth + 22
      color: lock.withAlpha("#1a1b26", 0.55)
      border.width: 1
      border.color: lock.withAlpha("#7dcfff", 0.24)

      Row {
        id: weatherRow
        anchors.centerIn: parent
        spacing: 8

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: weatherSource.glyph.length > 0 ? weatherSource.glyph : "󰖙"
          font.family: lock.monoFont
          font.pixelSize: 14
          color: "#7dcfff"
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: (weatherSource.tempC.length > 0 ? weatherSource.tempC + " · " : "")
            + (weatherSource.place.length > 0 ? weatherSource.place : (weatherSource.condition.length > 0 ? weatherSource.condition : "Tokyo"))
          textFormat: Text.PlainText
          font.family: lock.monoFont
          font.pixelSize: 11
          font.weight: Font.Medium
          color: "#c0caf5"
        }
      }
    }

    // Top Right: System & Battery Status
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 10

      // Caps Lock Warning
      Rectangle {
        visible: lock.capsLock
        height: 32
        radius: 16
        width: capsRow.implicitWidth + 20
        color: lock.withAlpha("#e0af68", 0.22)
        border.width: 1
        border.color: "#e0af68"

        Row {
          id: capsRow
          anchors.centerIn: parent
          spacing: 6
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰘲"
            font.family: lock.monoFont
            font.pixelSize: 13
            color: "#e0af68"
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "CAPS"
            font.family: lock.monoFont
            font.pixelSize: 10
            font.weight: Font.Bold
            color: "#e0af68"
          }
        }
      }

      // Battery Pill
      Rectangle {
        visible: batterySource.hasBattery
        height: 32
        radius: 16
        width: batRow.implicitWidth + 22
        color: lock.withAlpha("#1a1b26", 0.55)
        border.width: 1
        border.color: batterySource.charging ? lock.withAlpha(lock.tokyoGreen, 0.45) : lock.withAlpha(lock.tokyoBlue, 0.24)

        Row {
          id: batRow
          anchors.centerIn: parent
          spacing: 6
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: batterySource.glyph
            font.family: lock.monoFont
            font.pixelSize: 14
            color: batterySource.charging ? lock.tokyoGreen : (batterySource.percent <= 20 ? lock.tokyoRose : lock.tokyoBlue)
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: batterySource.percent + "%" + (batterySource.charging ? " ⚡" : "")
            textFormat: Text.PlainText
            font.family: lock.monoFont
            font.pixelSize: 11
            font.weight: Font.Medium
            color: lock.tokyoForeground
          }
        }
      }

      // Locked Status
      Rectangle {
        height: 32
        radius: 16
        width: lockLabelRow.implicitWidth + 20
        color: lock.withAlpha("#1a1b26", 0.55)
        border.width: 1
        border.color: lock.withAlpha(lock.tokyoLavender, 0.24)

        Row {
          id: lockLabelRow
          anchors.centerIn: parent
          spacing: 6
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰌾"
            font.family: lock.monoFont
            font.pixelSize: 13
            color: lock.tokyoLavender
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "LOCKED"
            font.family: lock.monoFont
            font.pixelSize: 10
            font.weight: Font.Bold
            font.letterSpacing: 1
            color: lock.withAlpha(lock.tokyoForeground, 0.8)
          }
        }
      }
    }
  }

  // ==========================================
  // CENTERPIECE: MINIMALIST CLOCK & LOGIN CARD
  // ==========================================
  Column {
    id: centerStack
    anchors.centerIn: parent
    anchors.verticalCenterOffset: -12
    spacing: 24
    width: Math.min(420, lock.width - 48)
    z: 20

    // 1. Sleek Monospaced Hero Clock
    Column {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 8

      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Text {
          text: lock.hourPart
          textFormat: Text.PlainText
          color: lock.tokyoBlue
          font.family: lock.monoFont
          font.pixelSize: 84
          font.weight: Font.Light
          font.letterSpacing: 1
          layer.enabled: true
          layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: lock.withAlpha(lock.tokyoBlue, 0.35)
            shadowBlur: 0.8
            shadowVerticalOffset: 2
          }
        }

        Text {
          text: ":"
          color: lock.tokyoLavender
          font.family: lock.monoFont
          font.pixelSize: 76
          font.weight: Font.Light
          opacity: 0.85
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: -4
          layer.enabled: true
          layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: lock.withAlpha(lock.tokyoLavender, 0.35)
            shadowBlur: 0.8
            shadowVerticalOffset: 2
          }
        }

        Text {
          text: lock.minutePart
          textFormat: Text.PlainText
          color: "#c0caf5"
          font.family: lock.monoFont
          font.pixelSize: 84
          font.weight: Font.Light
          font.letterSpacing: 1
          layer.enabled: true
          layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: lock.withAlpha(lock.tokyoLavender, 0.30)
            shadowBlur: 0.8
            shadowVerticalOffset: 2
          }
        }

        // Meridiem Pill for 12-hour format
        Rectangle {
          visible: lock.twelveHour
          width: meridiemText.implicitWidth + 14
          height: 24
          radius: 12
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: 12
          color: lock.withAlpha(lock.tokyoLavender, 0.18)
          border.width: 1
          border.color: lock.withAlpha(lock.tokyoLavender, 0.35)

          Text {
            id: meridiemText
            anchors.centerIn: parent
            text: lock.meridiem
            textFormat: Text.PlainText
            color: lock.tokyoLavender
            font.family: lock.monoFont
            font.pixelSize: 11
            font.weight: Font.Bold
          }
        }
      }

      // Elegant Minimalist Date Line
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Text {
          text: "󰃭"
          font.family: lock.monoFont
          font.pixelSize: 13
          color: lock.tokyoBlue
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: lock.date("ddd, dd MMM yyyy").toUpperCase()
          textFormat: Text.PlainText
          font.family: lock.monoFont
          font.pixelSize: 12
          font.weight: Font.Medium
          font.letterSpacing: 2
          color: lock.withAlpha(lock.tokyoForeground, 0.88)
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: "·"
          font.family: lock.monoFont
          font.pixelSize: 14
          color: lock.tokyoLavender
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          text: lock.hostName
          textFormat: Text.PlainText
          font.family: lock.monoFont
          font.pixelSize: 12
          font.weight: Font.Medium
          font.letterSpacing: 1
          color: lock.tokyoLavender
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    // 2. Frosted Glassmorphic Login Card
    Rectangle {
      id: glassCard
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      height: cardLayout.implicitHeight + 42
      radius: 26
      color: lock.withAlpha("#1a1b26", 0.62)
      border.width: 1
      border.color: lock.withAlpha(lock.tokyoLavender, 0.28)

      layer.enabled: true
      layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.rgba(0, 0, 0, 0.55)
        shadowBlur: 1.0
        shadowVerticalOffset: 12
      }

      // Top edge highlight line
      Rectangle {
        width: parent.width * 0.65
        height: 1
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 0.0; color: "transparent" }
          GradientStop { position: 0.5; color: lock.tokyoLavender }
          GradientStop { position: 1.0; color: "transparent" }
        }
      }

      Column {
        id: cardLayout
        anchors.centerIn: parent
        width: parent.width - 44
        spacing: 16

        // User Avatar & Clean Identity Row
        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 14

          Rectangle {
            width: 44; height: 44; radius: 22
            color: lock.withAlpha(lock.tokyoBlue, 0.16)
            border.width: 1
            border.color: lock.withAlpha(lock.tokyoBlue, 0.45)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.centerIn: parent
              text: lock.userInitial
              font.family: lock.monoFont
              font.pixelSize: 18
              font.bold: true
              color: lock.tokyoBlue
            }
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Text {
              text: lock.displayName
              font.family: lock.monoFont
              font.pixelSize: 16
              font.weight: Font.DemiBold
              color: "#c0caf5"
            }

            Text {
              text: lock.authenticatingPassword ? "Authenticating…"
                : lock.errorState ? (lock.failureMessage.length > 0 ? lock.failureMessage : "Incorrect password")
                : (lock.failedAttempts > 0 ? (lock.failedAttempts === 1 ? "1 failed attempt" : lock.failedAttempts + " failed attempts")
                : "System Locked · Enter password")
              font.family: lock.monoFont
              font.pixelSize: 11
              color: lock.errorState ? lock.tokyoRose : lock.withAlpha(lock.tokyoMuted, 0.75)
            }
          }
        }

        // Password Field
        PasswordField {
          id: field
          lock: lock
          width: parent.width
          height: 48
          radius: 24
          outlineThickness: 2
          outlineColor: lock.withAlpha(lock.tokyoBlue, (field.input && field.input.activeFocus) ? 0.85 : 0.24)
          outlineErrorColor: lock.tokyoRose
          accentColor: lock.tokyoBlue
          color: lock.withAlpha("#13141c", 0.72)
          placeholder: lock.tr("Password")
          fontScale: 0.88
          shakeOnFail: true

          Behavior on outlineColor { ColorAnimation { duration: Style.duration(120) } }
        }

        // Active Now Playing Bar (Only rendered when music is playing!)
        Rectangle {
          visible: lock.lockMedia && lock.lockMedia.hasMedia && lock.lockMedia.playing
          width: parent.width
          height: 38
          radius: 19
          color: lock.withAlpha("#16161e", 0.65)
          border.width: 1
          border.color: lock.withAlpha(lock.tokyoBlue, 0.25)

          Row {
            anchors.fill: parent
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 8

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "󰝚"
              font.family: lock.monoFont
              font.pixelSize: 14
              color: lock.tokyoLavender
              RotationAnimation on rotation {
                loops: Animation.Infinite
                from: 0; to: 360; duration: 4000
                running: lock.lockMedia && lock.lockMedia.playing
              }
            }

            Text {
              width: parent.width - 90
              anchors.verticalCenter: parent.verticalCenter
              text: lock.lockMedia ? (lock.lockMedia.title + " · " + lock.lockMedia.artist) : ""
              textFormat: Text.PlainText
              elide: Text.ElideRight
              font.family: lock.monoFont
              font.pixelSize: 11
              color: "#c0caf5"
            }

            Rectangle {
              width: 24; height: 24; radius: 12
              anchors.verticalCenter: parent.verticalCenter
              color: lock.withAlpha(lock.tokyoBlue, 0.25)
              Text {
                anchors.centerIn: parent
                text: "󰏤"
                font.family: lock.monoFont
                font.pixelSize: 11
                color: lock.tokyoBlue
              }
              MouseArea {
                anchors.fill: parent
                onClicked: lock.mediaAct("toggle")
              }
            }
          }
        }
      }
    }
  }

  // ==========================================
  // FOOTER: SUBTLE BRANDING WATERMARK
  // ==========================================
  Item {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 24
    height: 24
    z: 100

    Text {
      anchors.centerIn: parent
      text: "OMARCHY  //  TOKYO NIGHT"
      textFormat: Text.PlainText
      font.family: lock.monoFont
      font.pixelSize: 11
      font.weight: Font.Medium
      font.letterSpacing: 3
      color: lock.withAlpha(lock.tokyoLavender, 0.40)
    }
  }
}
