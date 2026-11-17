import QtQuick
import qs.Commons
import qs.Commons as Commons
import "../plugins/io.github.sirjul1337.lock-explorer/designs"

DesignBase {
  id: lock
  inputItem: field.input
  chromeRadius: 24
  showMediaStrip: false // Custom integrated music player handles media!

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

  readonly property bool wide: width >= 1020

  // 12h vs 24h hour & minute separation for dual-tone styling
  readonly property string rawTime: twelveHour ? clock("hh:mm").replace(" " + meridiem, "") : clock("HH:mm")
  readonly property string hourPart: rawTime.indexOf(":") !== -1 ? rawTime.split(":")[0] : rawTime
  readonly property string minutePart: rawTime.indexOf(":") !== -1 ? rawTime.split(":")[1] : ""

  // --- DYNAMIC GREETING ---
  readonly property string cuteGreeting: {
    var h = now.getHours()
    var name = lock.displayName.length > 0 ? lock.displayName : "Jestin"
    if (h < 5) return "Quiet night in Tokyo · Sweet dreams, " + name + " 🌙"
    if (h < 12) return "Good morning, " + name + " · Ready for a great day? ☀️"
    if (h < 17) return "Good afternoon, " + name + " · Stay hydrated 🍵"
    if (h < 22) return "Good evening, " + name + " · Time to unwind 🌸"
    return "Late night hours · Rest well, " + name + " ✨"
  }

  // --- NEKO COMPANION STATE LOGIC ---
  property bool isTypingActive: false
  Timer {
    id: typingDecayTimer
    interval: 1600
    repeat: false
    onTriggered: lock.isTypingActive = false
  }

  readonly property string nekoState: {
    if (lock.errorState) return "failed"
    if (lock.authenticatingPassword) return "checking"
    if (lock.isTypingActive || lock.passwordText.length > 0) return "typing"
    return "idle"
  }

  // --- TYPING INTERACTION & SPARKLES ---
  Typing {
    id: typingEvents
    lock: lock
    onTyped: function(index) {
      lock.isTypingActive = true
      typingDecayTimer.restart()
      nekoComp.reactToType()
      // Burst sparkles around the card & input
      var mappedField = field.mapToItem(lock, field.width / 2, field.height / 2)
      sparkleLayer.burst(mappedField.x, mappedField.y)
    }
    onCleared: {
      lock.isTypingActive = false
    }
  }

  // --- AUTO-SUBMIT TIMER ---
  Timer {
    id: autoSubmitTimer
    interval: 1600
    repeat: false
    property bool attempted: false
    onTriggered: {
      if (lock.passwordText.length > 0 && !attempted && field.input.activeFocus && !lock.authenticatingPassword) {
        attempted = true
        field.input.accepted()
      }
    }
    function edited() {
      stop()
      if (lock.passwordText.length > 0 && !attempted && field.input.activeFocus && !lock.authenticatingPassword) {
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

  // --- WALLPAPER & AMBIENT ATMOSPHERE ---
  Wallpaper {
    anchors.fill: parent
    lock: lock
    blur: 0.65
    dim: 0.32
    contrast: -0.08
    vignetteTop: 0.30
    vignetteBottom: 0.50
  }

  // Tokyo Night layered gradient tint
  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0.0; color: lock.withAlpha("#1a1b26", 0.72) }
      GradientStop { position: 0.45; color: lock.withAlpha("#13141c", 0.40) }
      GradientStop { position: 1.0; color: lock.withAlpha("#1a1b26", 0.88) }
    }
  }

  // Screen click to wake / refocus
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    onClicked: { lock.wakeRequested(); lock.forcePasswordFocus() }
    onPositionChanged: lock.wakeRequested()
  }

  // --- FLOATING SPARKLE PARTICLE LAYER ---
  Item {
    id: sparkleLayer
    anchors.fill: parent
    z: 200

    readonly property var particleGlyphs: ["✨", "🌸", "✧", "💖", "🐾", "⭐", "💫", "❀", "🍡"]
    property int nextParticleIdx: 0

    function burst(ox, oy) {
      var p = particlePool.itemAt(nextParticleIdx)
      if (p) {
        p.glyph = particleGlyphs[Math.floor(Math.random() * particleGlyphs.length)]
        p.x = ox + (Math.random() - 0.5) * 80 - 12
        p.y = oy + (Math.random() - 0.5) * 20 - 12
        p.anim.restart()
      }
      nextParticleIdx = (nextParticleIdx + 1) % 12
    }

    Repeater {
      id: particlePool
      model: 12
      Item {
        id: pItem
        width: 24; height: 24
        opacity: 0; visible: opacity > 0
        property string glyph: "✨"
        property alias anim: pAnim

        Text {
          anchors.centerIn: parent
          text: pItem.glyph
          font.pixelSize: 16
        }

        ParallelAnimation {
          id: pAnim
          NumberAnimation { target: pItem; property: "y"; to: pItem.y - (45 + Math.random() * 35); duration: 650; easing.type: Easing.OutCubic }
          NumberAnimation { target: pItem; property: "opacity"; from: 1.0; to: 0.0; duration: 650; easing.type: Easing.InQuad }
          NumberAnimation { target: pItem; property: "scale"; from: 0.7; to: 1.3; duration: 650; easing.type: Easing.OutBack }
        }
      }
    }
  }

  // Battery helper for status capsule
  LiveBattery {
    id: batterySource
  }

  // Live Weather source
  LiveWeather {
    id: weatherSource
    lock: lock
  }

  // ==========================================
  // TOP BAR: STATUS CAPSULES
  // ==========================================
  Item {
    id: topHeader
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.topMargin: 24
    anchors.leftMargin: 36
    anchors.rightMargin: 36
    height: 40
    z: 100

    // Top Left: Weather & Hostname Pills
    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12

      // Weather Pill
      Rectangle {
        height: 36
        radius: 18
        color: lock.withAlpha("#24283b", 0.75)
        border.width: 1
        border.color: lock.withAlpha("#7dcfff", 0.3)
        width: weatherRow.implicitWidth + 24

        Row {
          id: weatherRow
          anchors.centerIn: parent
          spacing: 8

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: weatherSource.glyph.length > 0 ? weatherSource.glyph : "󰖙"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: "#7dcfff"

            SequentialAnimation on y {
              loops: Animation.Infinite
              running: true
              NumberAnimation { to: -1.5; duration: 1500; easing.type: Easing.InOutQuad }
              NumberAnimation { to: 1.5; duration: 1500; easing.type: Easing.InOutQuad }
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: (weatherSource.tempC.length > 0 ? weatherSource.tempC + " " : "")
              + (weatherSource.place.length > 0 ? weatherSource.place : (weatherSource.condition.length > 0 ? weatherSource.condition : "Munnar"))
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            font.weight: Font.Medium
            color: "#c0caf5"
          }
        }
      }

      // Hostname Capsule
      Rectangle {
        height: 36
        radius: 18
        width: hostContent.implicitWidth + 24
        color: lock.withAlpha(lock.tokyoSurface, 0.75)
        border.width: 1
        border.color: lock.withAlpha(lock.tokyoLavender, 0.28)

        Row {
          id: hostContent
          anchors.centerIn: parent
          spacing: 6
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰌢"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: lock.tokyoLavender
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: lock.hostName
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            font.weight: Font.Medium
            color: lock.tokyoForeground
          }
        }
      }
    }

    // Top Right: Battery & Caps Lock Warning Pills
    Row {
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12

      // Caps Lock Warning Capsule
      Rectangle {
        visible: lock.capsLock
        height: 36
        radius: 18
        width: capsContent.implicitWidth + 24
        color: lock.withAlpha("#e0af68", 0.2)
        border.width: 1
        border.color: "#e0af68"

        Row {
          id: capsContent
          anchors.centerIn: parent
          spacing: 6
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰘲"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 14
            color: "#e0af68"
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "CAPS LOCK"
            font.family: "Adwaita Sans"
            font.pixelSize: 11
            font.weight: Font.Bold
            color: "#e0af68"
          }
        }
      }

      // Battery Capsule
      Rectangle {
        visible: batterySource.hasBattery
        height: 36
        radius: 18
        width: batContent.implicitWidth + 24
        color: lock.withAlpha(lock.tokyoSurface, 0.75)
        border.width: 1
        border.color: batterySource.charging ? lock.withAlpha(lock.tokyoGreen, 0.5) : lock.withAlpha(lock.tokyoBlue, 0.28)

        Row {
          id: batContent
          anchors.centerIn: parent
          spacing: 6
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: batterySource.glyph
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: batterySource.charging ? lock.tokyoGreen : (batterySource.percent <= 20 ? lock.tokyoRose : lock.tokyoBlue)
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: batterySource.percent + "%" + (batterySource.charging ? " ⚡" : "")
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            font.weight: Font.Medium
            color: lock.tokyoForeground
          }
        }
      }
    }
  }

  // ==========================================
  // MAIN CENTER COMPOSITION
  // ==========================================
  Item {
    id: mainComposition
    anchors.centerIn: parent
    width: Math.min(1080, lock.width - 64)
    height: lock.wide ? 420 : colNarrow.height
    opacity: 0
    scale: 0.98
    Component.onCompleted: { opacity = 1; scale = 1 }
    Behavior on opacity { NumberAnimation { duration: Style.duration(200); easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Style.duration(220); easing.type: Easing.OutCubic } }

    // ------------------------------------------
    // WIDE LAYOUT (Two Columns)
    // ------------------------------------------
    Item {
      anchors.fill: parent
      visible: lock.wide

      // LEFT COLUMN: GREETING, HERO CLOCK, DATE & MUSIC PLAYER
      Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - cardArea.width - 56
        spacing: 16

        // Dynamic Greeting Pill
        Rectangle {
          height: 34
          radius: 17
          width: greetingText.implicitWidth + 28
          color: lock.withAlpha(lock.tokyoSurface, 0.82)
          border.width: 1
          border.color: lock.withAlpha(lock.tokyoPink, 0.35)

          Text {
            id: greetingText
            anchors.centerIn: parent
            text: lock.cuteGreeting
            textFormat: Text.PlainText
            font.family: "Adwaita Sans"
            font.pixelSize: 12
            font.weight: Font.Medium
            color: lock.tokyoForeground
          }
        }

        // Giant Aesthetic Tokyo Night Clock
        Row {
          spacing: 6

          Text {
            id: hourText
            text: lock.hourPart
            textFormat: Text.PlainText
            color: lock.tokyoBlue
            font.family: "Adwaita Sans"
            font.pixelSize: 120
            font.weight: Font.Light
            font.letterSpacing: -4
          }

          Text {
            text: ":"
            color: lock.tokyoLavender
            font.family: "Adwaita Sans"
            font.pixelSize: 110
            font.weight: Font.Light
            anchors.baseline: hourText.baseline
            opacity: 0.85
          }

          Text {
            text: lock.minutePart
            textFormat: Text.PlainText
            color: "#c0caf5"
            font.family: "Adwaita Sans"
            font.pixelSize: 120
            font.weight: Font.Light
            font.letterSpacing: -4
          }

          // AM / PM Pill
          Rectangle {
            visible: lock.twelveHour
            width: meridiemLabel.implicitWidth + 20
            height: 28
            radius: 14
            anchors.bottom: parent.bottom
            anchors.bottomMargin: hourText.font.pixelSize * 0.16
            color: lock.withAlpha(lock.tokyoLavender, 0.16)
            border.width: 1
            border.color: lock.withAlpha(lock.tokyoLavender, 0.35)

            Text {
              id: meridiemLabel
              anchors.centerIn: parent
              text: lock.meridiem
              textFormat: Text.PlainText
              color: lock.tokyoLavender
              font.family: "Adwaita Sans"
              font.pixelSize: 12
              font.weight: Font.Bold
            }
          }
        }

        // Date Pill with Sakura Accent
        Row {
          spacing: 10
          Rectangle {
            width: 20
            height: 1
            color: lock.tokyoLavender
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "🌸  " + lock.date("dddd, d MMMM yyyy")
            textFormat: Text.PlainText
            color: lock.withAlpha(lock.tokyoForeground, 0.88)
            font.family: "Adwaita Sans"
            font.pixelSize: 16
            font.weight: Font.Normal
          }
        }

        Item { width: 1; height: 4 }

        // Live Music / Lo-Fi Player
        Rectangle {
          id: musicPillBox
          width: Math.min(440, parent.width)
          height: 48
          radius: 24
          color: lock.withAlpha("#24283b", 0.78)
          border.width: 1
          border.color: lock.withAlpha("#7aa2f7", 0.28)

          readonly property bool hasMedia: lock.lockMedia && lock.lockMedia.hasMedia
          readonly property bool isPlaying: lock.lockMedia && lock.lockMedia.playing

          // Active Media Row
          Row {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 10
            visible: musicPillBox.hasMedia

            // Vinyl Icon
            Rectangle {
              width: 30; height: 30; radius: 15
              anchors.verticalCenter: parent.verticalCenter
              color: lock.withAlpha("#bb9af7", 0.16)
              border.width: 1; border.color: lock.withAlpha("#bb9af7", 0.35)

              Text {
                anchors.centerIn: parent
                text: "󰝚"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                color: "#bb9af7"
              }
              RotationAnimation on rotation {
                loops: Animation.Infinite
                from: 0; to: 360; duration: 4000
                running: musicPillBox.isPlaying
              }
            }

            // Animated Equalizer Bars
            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 3
              Rectangle {
                width: 3; height: musicPillBox.isPlaying ? bar1Anim.barH : 4
                radius: 1.5; color: "#7aa2f7"; anchors.bottom: parent.bottom
                Item {
                  id: bar1Anim; property real barH: 4
                  SequentialAnimation on barH {
                    loops: Animation.Infinite; running: musicPillBox.isPlaying
                    NumberAnimation { to: 16; duration: 280; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 5; duration: 280; easing.type: Easing.InOutQuad }
                  }
                }
              }
              Rectangle {
                width: 3; height: musicPillBox.isPlaying ? bar2Anim.barH : 4
                radius: 1.5; color: "#bb9af7"; anchors.bottom: parent.bottom
                Item {
                  id: bar2Anim; property real barH: 6
                  SequentialAnimation on barH {
                    loops: Animation.Infinite; running: musicPillBox.isPlaying
                    NumberAnimation { to: 18; duration: 380; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 4; duration: 380; easing.type: Easing.InOutQuad }
                  }
                }
              }
              Rectangle {
                width: 3; height: musicPillBox.isPlaying ? bar3Anim.barH : 4
                radius: 1.5; color: "#7dcfff"; anchors.bottom: parent.bottom
                Item {
                  id: bar3Anim; property real barH: 8
                  SequentialAnimation on barH {
                    loops: Animation.Infinite; running: musicPillBox.isPlaying
                    NumberAnimation { to: 14; duration: 320; easing.type: Easing.InOutQuad }
                    NumberAnimation { to: 6; duration: 320; easing.type: Easing.InOutQuad }
                  }
                }
              }
            }

            // Track info
            Column {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.max(80, musicPillBox.width - 200)
              spacing: 1
              Text {
                width: parent.width
                text: lock.lockMedia ? lock.lockMedia.title : "Audio Playing"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: "Adwaita Sans"
                font.pixelSize: 12; font.weight: Font.Medium; color: "#c0caf5"
              }
              Text {
                width: parent.width
                text: lock.lockMedia ? lock.lockMedia.artist : "Media"
                textFormat: Text.PlainText
                elide: Text.ElideRight
                font.family: "Adwaita Sans"
                font.pixelSize: 10; color: lock.withAlpha("#a9b1d6", 0.7)
              }
            }

            // Controls
            Row {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 4
              Rectangle {
                width: 26; height: 26; radius: 13
                color: prevM.containsMouse ? lock.withAlpha("#7aa2f7", 0.25) : "transparent"
                Text { anchors.centerIn: parent; text: "󰒮"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: "#c0caf5" }
                MouseArea { id: prevM; anchors.fill: parent; hoverEnabled: true; onClicked: lock.mediaAct("previous") }
              }
              Rectangle {
                width: 28; height: 28; radius: 14
                color: lock.withAlpha("#7aa2f7", playM.containsMouse ? 0.35 : 0.20)
                border.width: 1; border.color: lock.withAlpha("#7aa2f7", 0.4)
                Text { anchors.centerIn: parent; text: musicPillBox.isPlaying ? "󰏤" : "󰐊"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; color: "#7aa2f7" }
                MouseArea { id: playM; anchors.fill: parent; hoverEnabled: true; onClicked: lock.mediaAct("toggle") }
              }
              Rectangle {
                width: 26; height: 26; radius: 13
                color: nextM.containsMouse ? lock.withAlpha("#7aa2f7", 0.25) : "transparent"
                Text { anchors.centerIn: parent; text: "󰒭"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12; color: "#c0caf5" }
                MouseArea { id: nextM; anchors.fill: parent; hoverEnabled: true; onClicked: lock.mediaAct("next") }
              }
            }
          }

          // Idle Lo-Fi text
          Row {
            anchors.centerIn: parent
            spacing: 8
            visible: !musicPillBox.hasMedia
            Text { text: "🌸"; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
            Text {
              text: "Tokyo Night Cozy Lo-Fi · All is peaceful ✨"
              textFormat: Text.PlainText
              font.family: "Adwaita Sans"; font.pixelSize: 12; font.weight: Font.Medium
              color: lock.withAlpha("#c0caf5", 0.85); anchors.verticalCenter: parent.verticalCenter
            }
          }
        }
      }
    }

    // ------------------------------------------
    // NARROW LAYOUT (Vertical Stack)
    // ------------------------------------------
    Column {
      id: colNarrow
      anchors.centerIn: parent
      width: parent.width
      spacing: 24
      visible: !lock.wide

      Column {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        Row {
          anchors.horizontalCenter: parent.horizontalCenter
          spacing: 4
          Text {
            text: lock.hourPart; color: lock.tokyoBlue
            font.family: "Adwaita Sans"; font.pixelSize: Math.round(Math.min(84, mainComposition.width * 0.20)); font.weight: Font.Light
          }
          Text {
            text: ":"; color: lock.tokyoLavender
            font.family: "Adwaita Sans"; font.pixelSize: Math.round(Math.min(80, mainComposition.width * 0.19)); font.weight: Font.Light
          }
          Text {
            text: lock.minutePart; color: "#c0caf5"
            font.family: "Adwaita Sans"; font.pixelSize: Math.round(Math.min(84, mainComposition.width * 0.20)); font.weight: Font.Light
          }
        }

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: lock.date("dddd, d MMMM yyyy")
          color: lock.withAlpha(lock.tokyoForeground, 0.85)
          font.family: "Adwaita Sans"; font.pixelSize: 14
        }
      }
    }

    // ------------------------------------------
    // THE CUTE LOGIN CARD & NEKO COMPANION
    // ------------------------------------------
    Item {
      id: cardArea
      width: Math.min(410, mainComposition.width)
      height: card.height + 60
      anchors.right: lock.wide ? parent.right : undefined
      anchors.horizontalCenter: lock.wide ? undefined : parent.horizontalCenter
      anchors.verticalCenter: lock.wide ? parent.verticalCenter : undefined
      y: lock.wide ? undefined : colNarrow.y + colNarrow.height + 24

      // THE ANIMATED NEKO (CAT COMPANION) SITTING PROUDLY ON THE CARD!
      Item {
        id: nekoComp
        anchors.horizontalCenter: card.horizontalCenter
        anchors.bottom: card.top
        anchors.bottomMargin: -18
        width: 140
        height: 110
        z: 10

        property bool eyeClosed: false
        property bool earTwitch: false

        // Idle blink timer
        Timer {
          interval: 3800; repeat: true; running: lock.nekoState === "idle"
          onTriggered: { nekoComp.eyeClosed = true; unblinkT.restart() }
        }
        Timer { id: unblinkT; interval: 130; repeat: false; onTriggered: nekoComp.eyeClosed = false }

        // Ear twitch
        Timer {
          interval: 5200; repeat: true; running: true
          onTriggered: { nekoComp.earTwitch = true; untwitchT.restart() }
        }
        Timer { id: untwitchT; interval: 220; repeat: false; onTriggered: nekoComp.earTwitch = false }

        function reactToType() { nekoComp.earTwitch = true; untwitchT.restart() }

        Item {
          id: nekoFloat
          anchors.fill: parent
          SequentialAnimation on y {
            loops: Animation.Infinite; running: true
            NumberAnimation { to: -3; duration: 1800; easing.type: Easing.InOutQuad }
            NumberAnimation { to: 0; duration: 1800; easing.type: Easing.InOutQuad }
          }

          // Wagging tail
          Item {
            x: 105; y: 50; width: 30; height: 40; transformOrigin: Item.BottomLeft
            SequentialAnimation on rotation {
              loops: Animation.Infinite; running: true
              NumberAnimation { to: 16; duration: 1200; easing.type: Easing.InOutSine }
              NumberAnimation { to: -6; duration: 1200; easing.type: Easing.InOutSine }
            }
            Rectangle {
              width: 12; height: 34; radius: 6; color: "#24283b"
              border.width: 1; border.color: "#7aa2f7"; rotation: 25
            }
          }

          // Left Ear
          Item {
            x: 24; y: 12; width: 28; height: 32
            rotation: nekoComp.earTwitch ? -14 : -6
            Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            Rectangle { anchors.fill: parent; radius: 6; color: "#24283b"; border.width: 1; border.color: "#7aa2f7"; rotation: 45 }
            Rectangle { width: 14; height: 16; anchors.centerIn: parent; radius: 3; color: "#ff7a93"; opacity: 0.85; rotation: 45 }
          }

          // Right Ear
          Item {
            x: 88; y: 12; width: 28; height: 32
            rotation: nekoComp.earTwitch ? 14 : 6
            Behavior on rotation { NumberAnimation { duration: 120; easing.type: Easing.OutBack } }
            Rectangle { anchors.fill: parent; radius: 6; color: "#24283b"; border.width: 1; border.color: "#7aa2f7"; rotation: 45 }
            Rectangle { width: 14; height: 16; anchors.centerIn: parent; radius: 3; color: "#ff7a93"; opacity: 0.85; rotation: 45 }
          }

          // Sakura Hairpin
          Text { x: 82; y: 20; text: "🌸"; font.pixelSize: 18; rotation: 15 }

          // Cat Head
          Rectangle {
            x: 20; y: 26; width: 100; height: 72; radius: 36
            color: "#24283b"; border.width: 1; border.color: "#7aa2f7"
            rotation: lock.nekoState === "checking" ? -6 : (lock.nekoState === "failed" ? 8 : 0)
            Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }

            // Cheeks
            Rectangle { x: 12; y: 42; width: 16; height: 10; radius: 5; color: "#f7768e"; opacity: lock.nekoState === "failed" ? 0.75 : 0.42 }
            Rectangle { x: 72; y: 42; width: 16; height: 10; radius: 5; color: "#f7768e"; opacity: lock.nekoState === "failed" ? 0.75 : 0.42 }

            // Nose
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 40; width: 6; height: 4; radius: 2; color: "#ff7a93" }

            // Mouth
            Text {
              anchors.horizontalCenter: parent.horizontalCenter; y: 44
              text: lock.nekoState === "failed" ? "﹏" : "ω"
              font.family: Style.font.family; font.pixelSize: 13; font.weight: Font.DemiBold
              color: lock.nekoState === "failed" ? "#ff7a93" : "#a9b1d6"
            }

            // Normal Blinking Anime Eyes
            Item {
              anchors.fill: parent
              visible: lock.nekoState !== "typing" && lock.nekoState !== "failed"

              Rectangle {
                x: 26; y: 30; width: 14; height: nekoComp.eyeClosed ? 2 : 14; radius: 7
                color: nekoComp.eyeClosed ? "#7aa2f7" : "#13141c"
                border.width: 1; border.color: "#7aa2f7"
                Rectangle { visible: !nekoComp.eyeClosed; x: 3; y: 3; width: 5; height: 5; radius: 2.5; color: "#ffffff" }
                Rectangle { visible: !nekoComp.eyeClosed; x: 8; y: 8; width: 2.5; height: 2.5; radius: 1.25; color: "#7aa2f7" }
              }
              Rectangle {
                x: 60; y: 30; width: 14; height: nekoComp.eyeClosed ? 2 : 14; radius: 7
                color: nekoComp.eyeClosed ? "#7aa2f7" : "#13141c"
                border.width: 1; border.color: "#7aa2f7"
                Rectangle { visible: !nekoComp.eyeClosed; x: 3; y: 3; width: 5; height: 5; radius: 2.5; color: "#ffffff" }
                Rectangle { visible: !nekoComp.eyeClosed; x: 8; y: 8; width: 2.5; height: 2.5; radius: 1.25; color: "#7aa2f7" }
              }
            }

            // Happy Typing Eyes (^ ^)
            Item {
              anchors.fill: parent; visible: lock.nekoState === "typing"
              Text { x: 24; y: 22; text: "^"; font.family: Style.font.family; font.pixelSize: 22; font.bold: true; color: "#7aa2f7" }
              Text { x: 62; y: 22; text: "^"; font.family: Style.font.family; font.pixelSize: 22; font.bold: true; color: "#7aa2f7" }
            }

            // Dizzy Failed Eyes (> <)
            Item {
              anchors.fill: parent; visible: lock.nekoState === "failed"
              Text { x: 25; y: 24; text: ">"; font.family: Style.font.family; font.pixelSize: 18; font.bold: true; color: "#f7768e" }
              Text { x: 63; y: 24; text: "<"; font.family: Style.font.family; font.pixelSize: 18; font.bold: true; color: "#f7768e" }
              Text { x: 86; y: 16; text: "💧"; font.pixelSize: 14 }
            }
          }

          // Paws Over Edge
          Rectangle {
            x: 36; y: 88; width: 22; height: 18; radius: 9; color: "#c0caf5"
            border.width: 1; border.color: "#7aa2f7"
            Rectangle { anchors.centerIn: parent; width: 8; height: 6; radius: 3; color: "#ff7a93"; opacity: 0.7 }
          }
          Rectangle {
            x: 82; y: 88; width: 22; height: 18; radius: 9; color: "#c0caf5"
            border.width: 1; border.color: "#7aa2f7"
            Rectangle { anchors.centerIn: parent; width: 8; height: 6; radius: 3; color: "#ff7a93"; opacity: 0.7 }
          }
        }
      }

      // Frosted Glassmorphic Login Card
      Rectangle {
        id: card
        anchors.bottom: parent.bottom
        width: parent.width
        height: cardContent.implicitHeight + 48
        radius: 30
        color: lock.withAlpha("#1f2335", 0.88)
        border.width: 1
        border.color: lock.withAlpha(lock.tokyoLavender, 0.32)

        // Subtle gradient highlight line along top edge
        Rectangle {
          width: parent.width * 0.55
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
          id: cardContent
          anchors.centerIn: parent
          width: parent.width - 52
          spacing: 16

          // Greeting & User Profile Pill
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            Rectangle {
              width: 38; height: 38; radius: 19
              color: lock.withAlpha(lock.tokyoBlue, 0.18)
              border.width: 1; border.color: lock.withAlpha(lock.tokyoBlue, 0.4)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                anchors.centerIn: parent
                text: lock.userInitial
                font.family: "Adwaita Sans"
                font.pixelSize: 17; font.bold: true
                color: lock.tokyoBlue
              }
            }

            Column {
              anchors.verticalCenter: parent.verticalCenter
              spacing: 1

              Text {
                text: "Welcome Home"
                font.family: "Adwaita Sans"
                font.pixelSize: 11
                color: lock.withAlpha(lock.tokyoMuted, 0.75)
              }
              Text {
                text: lock.displayName
                font.family: "Adwaita Sans"
                font.pixelSize: 18
                font.weight: Font.DemiBold
                color: "#c0caf5"
              }
            }
          }

          // Password Field
          PasswordField {
            id: field
            lock: lock
            width: parent.width
            height: 52
            radius: 20
            outlineThickness: 2
            outlineColor: lock.withAlpha(lock.tokyoBlue, (field.input && field.input.activeFocus) ? 0.78 : 0.28)
            outlineErrorColor: lock.tokyoRose
            accentColor: lock.tokyoBlue
            color: lock.withAlpha(lock.tokyoSurface, 0.85)
            placeholder: "Type password here 🐾"
            fontScale: 0.90
            shakeOnFail: true

            Behavior on outlineColor { ColorAnimation { duration: Style.duration(120) } }
          }

          // Status & Helper Message
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: lock.authenticatingPassword ? "Verifying with pam... ✨"
              : lock.errorState ? "Incorrect password · Press Enter ( > ﹏ < )"
              : autoSubmitTimer.attempted ? "Press Enter to unlock 🐾"
              : "Type password · Pause to unlock ✨"
            color: lock.errorState ? lock.tokyoRose : lock.withAlpha(lock.tokyoMuted, 0.75)
            font.family: "Adwaita Sans"
            font.pixelSize: 12
          }
        }
      }
    }
  }

  // ==========================================
  // BOTTOM BAR: CUTE FOOTER
  // ==========================================
  Item {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: 36
    anchors.rightMargin: 36
    anchors.bottomMargin: 24
    height: 36
    z: 100

    Row {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8

      Text {
        text: "✦  Omarchy OS · Tokyo Night Kawaii Edition  ✦"
        textFormat: Text.PlainText
        font.family: "Adwaita Sans"
        font.pixelSize: 12
        font.weight: Font.Medium
        color: lock.withAlpha(lock.tokyoMuted, 0.55)
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
