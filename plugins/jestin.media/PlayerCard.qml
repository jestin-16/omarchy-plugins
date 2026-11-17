import QtQuick
import QtQuick.Effects
import qs.Ui
import qs.Commons
import qs.Commons as Commons

Column {
  id: panel
  required property var host
  readonly property var player: host.activePlayer
  readonly property color ink: "#b6bdcf"
  readonly property color accent: Commons.Color.accent
  readonly property color capsuleInk: "#f0f1f4"
  // Preserve a known duration if an app temporarily drops it after seeking.
  // Never reuse it across tracks or sources.
  property real trackDuration: 0
  readonly property string timelineKey: player
    ? String(player.dbusName || player.identity || "") + "\n" + String(player.uniqueId || "") + "\n" + String(player.trackTitle || "") + "\n" + String(player.trackArtist || "") : ""
  readonly property bool hasTimeline: !!player && player.positionSupported && trackDuration > 0
  function updateDuration() {
    if (player && player.lengthSupported && isFinite(player.length) && player.length > 0)
      trackDuration = player.length
  }
  onTimelineKeyChanged: {
    trackDuration = 0
    seekDeadline = 0
    if (seekBar) seekBar.dragging = false
    updateDuration()
    refreshPosition()
  }
  property real elapsed: 0
  property double seekDeadline: 0
  spacing: Style.space(9)

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
  function refreshPosition() {
    if (seekBar && seekBar.dragging) return
    var position = player && player.positionSupported ? Math.max(0, player.position) : 0
    if (hasTimeline) position = Math.min(trackDuration, position)
    // Players acknowledge seeking asynchronously. Hold the chosen time until
    // it is acknowledged instead of letting stale updates snap the handle back.
    if (Date.now() < seekDeadline && Math.abs(position - elapsed) > 1.5) return
    seekDeadline = 0
    elapsed = position
  }
  function timestamp(seconds) {
    var n = Math.max(0, Math.floor(Number(seconds) || 0))
    return Math.floor(n / 60) + ":" + (n % 60 < 10 ? "0" : "") + (n % 60)
  }
  onPlayerChanged: {
    seekDeadline = 0
    trackDuration = 0
    updateDuration()
    if (seekBar) seekBar.dragging = false
    refreshPosition()
  }
  onHasTimelineChanged: refreshPosition()
  Component.onCompleted: { updateDuration(); refreshPosition() }
  Connections {
    target: panel.player
    function onPositionChanged() { panel.refreshPosition() }
    function onLengthChanged() { panel.updateDuration() }
    function onLengthSupportedChanged() { panel.updateDuration() }
    function onTrackChanged() {
      seekBar.dragging = false
      panel.seekDeadline = 0
      panel.refreshPosition()
    }
  }
  Timer {
    id: seekAcknowledgement
    interval: 1800
    onTriggered: { panel.seekDeadline = 0; panel.refreshPosition() }
  }
  Timer {
    interval: 1000; repeat: true
    running: panel.host.popupOpen && !!panel.player && panel.player.positionSupported && panel.host.isPlaying
    triggeredOnStart: true
    onTriggered: panel.refreshPosition()
  }
  component Label: Text {
    textFormat: Text.PlainText
    color: panel.ink
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }

  // Wide, glossy capsule with the compact top controls and album row from the reference.
  Rectangle {
    width: parent.width
    height: Style.space(198)
    radius: Style.space(30)
    clip: true
    gradient: Gradient {
      orientation: Gradient.Vertical
      GradientStop { position: 0; color: "#17181d" }
      GradientStop { position: 0.45; color: "#08090c" }
      GradientStop { position: 1; color: "#030405" }
    }
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.22)

    // Soft reflection gives the black surface a glassy, curved highlight.
    Rectangle {
      x: parent.width * 0.30; y: -parent.height * 0.57
      width: parent.width * 0.64; height: parent.height * 0.92
      radius: height / 2; rotation: -12
      opacity: 0.7
      gradient: Gradient {
        GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.11) }
        GradientStop { position: 1; color: Qt.rgba(1, 1, 1, 0) }
      }
    }

    Row {
      id: topControls
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.topMargin: Style.space(12)
      anchors.leftMargin: Style.space(17)
      anchors.rightMargin: Style.space(17)
      height: Style.space(32)
      spacing: Style.space(11)

      Label { text: panel.host.playerIcon(panel.player); color: panel.accent; font.pixelSize: Style.font.icon; anchors.verticalCenter: parent.verticalCenter }
      Label {
        text: panel.host.playerName(panel.player).toUpperCase()
        opacity: 0.95
        font.pixelSize: Style.font.caption
        font.weight: Font.DemiBold
        anchors.verticalCenter: parent.verticalCenter
      }
      Item { width: 1; height: 1 }
      Row {
        spacing: Style.space(3)
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
          model: [5, 10, 7, 13, 6]
          Rectangle {
            required property int modelData
            width: Style.space(3); height: Style.space(modelData); radius: width / 2
            anchors.verticalCenter: parent.verticalCenter
            color: panel.host.isPlaying ? panel.accent : Qt.alpha(panel.ink, 0.45)
            SequentialAnimation on height {
              running: panel.host.popupOpen && panel.host.isPlaying && !Style.reduceMotion
              loops: Animation.Infinite
              NumberAnimation { to: Style.space(4); duration: Style.duration(260); easing.type: Easing.OutCubic }
              NumberAnimation { to: Style.space(modelData); duration: Style.duration(260); easing.type: Easing.OutCubic }
            }
          }
        }
      }
    }

    Rectangle {
      id: artwork
      anchors.left: parent.left
      anchors.leftMargin: Style.space(18)
      anchors.top: topControls.bottom
      anchors.topMargin: Style.space(9)
      width: Style.space(94); height: width
      radius: Style.space(19)
      color: Qt.alpha(panel.accent, 0.16)
      clip: true
      Label { anchors.centerIn: parent; text: panel.host.playerIcon(panel.player); color: panel.accent; font.pixelSize: Style.space(34) }
      SizedImage {
        id: cover
        anchors.fill: parent
        crop: true
        url: panel.player && panel.player.trackArtUrl ? panel.player.trackArtUrl : ""
        visible: status === Image.Ready
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: coverMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1 }
      }
      Rectangle { id: coverMask; anchors.fill: parent; radius: artwork.radius; visible: false; layer.enabled: true; color: "white" }
    }

    Column {
      anchors.left: artwork.right
      anchors.leftMargin: Style.space(16)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(15)
      anchors.top: artwork.top
      spacing: Style.space(3)
      Label {
        width: parent.width
        text: panel.host.title || strings.t("nothingPlaying")
        font.pixelSize: Style.font.body
        font.weight: Font.DemiBold
        color: panel.capsuleInk
        elide: Text.ElideRight
      }
      Label {
        width: parent.width
        text: panel.host.artist || strings.t("player")
        font.pixelSize: Style.font.caption
        opacity: 0.95
        elide: Text.ElideRight
      }
      Row {
        spacing: Style.space(8)
        Button {
          width: Style.space(38); height: Style.space(34)
          iconText: "󰒮"; iconSize: Style.space(19); foreground: panel.capsuleInk
          horizontalPadding: 0; verticalPadding: 0
          radius: Style.space(10)
          tooltipText: strings.t("previous")
          enabled: !!panel.player && panel.player.canGoPrevious
          opacity: enabled ? 0.9 : 0.35
          onClicked: panel.host.mediaService.runAction("previous", false, panel.host.mediaService.playerKey(panel.player))
        }
        Button {
          width: Style.space(46); height: Style.space(40)
          iconText: panel.host.playIcon; iconSize: Style.space(21); foreground: panel.capsuleInk
          horizontalPadding: 0; verticalPadding: 0
          radius: Style.space(14); selected: true
          background: Qt.alpha(panel.accent, 0.18)
          tooltipText: panel.host.isPlaying ? strings.t("pause") : strings.t("play")
          enabled: !!panel.player && (panel.player.canTogglePlaying || panel.player.canPlay || panel.player.canPause)
          onClicked: panel.host.mediaService.runAction("playPause", false, panel.host.mediaService.playerKey(panel.player))
        }
        Button {
          width: Style.space(38); height: Style.space(34)
          iconText: "󰒭"; iconSize: Style.space(19); foreground: panel.capsuleInk
          horizontalPadding: 0; verticalPadding: 0
          radius: Style.space(10)
          tooltipText: strings.t("next")
          enabled: !!panel.player && panel.player.canGoNext
          opacity: enabled ? 0.9 : 0.35
          onClicked: panel.host.mediaService.runAction("next", false, panel.host.mediaService.playerKey(panel.player))
        }
        Label {
          text: panel.host.isPlaying ? strings.t("playing") : strings.t("paused")
          font.pixelSize: Style.font.caption; opacity: 0.85
          anchors.verticalCenter: parent.verticalCenter
        }
      }
    }

    Item {
      id: seekBar
      objectName: "seekBar"
      anchors.left: parent.left; anchors.right: parent.right
      anchors.leftMargin: Style.space(18); anchors.rightMargin: Style.space(18)
      anchors.bottom: parent.bottom; anchors.bottomMargin: Style.space(24)
      height: Style.space(28)
      LayoutMirroring.enabled: false
      readonly property bool seekable: panel.hasTimeline && !!panel.player.canSeek
      onSeekableChanged: if (!seekable) dragging = false
      property real preview: 0
      property bool dragging: false
      property var dragPlayer: null
      property string dragTrack: ""
      readonly property real fraction: panel.hasTimeline
        ? Math.max(0, Math.min(1, (dragging ? preview : panel.elapsed) / panel.trackDuration)) : 0
      function trackKey() {
        return panel.player ? String(panel.player.uniqueId) + "\n" + String(panel.player.trackTitle) + "\n" + String(panel.player.trackArtist) : ""
      }
      function updatePreview(x) {
        if (!seekable) return
        var ratio = Math.max(0, Math.min(1, x / Math.max(1, width)))
        preview = ratio * panel.trackDuration
      }
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Style.space(seekMouse.containsMouse || seekMouse.pressed ? 6 : 4)
        radius: height / 2
        color: Qt.rgba(1, 1, 1, 0.17)
        Rectangle {
          width: parent.width * seekBar.fraction
          height: parent.height; radius: parent.radius
          color: panel.accent
        }
      }
      Rectangle {
        x: seekBar.width * seekBar.fraction - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(seekBar.dragging ? 14 : 10); height: width; radius: width / 2
        color: panel.capsuleInk
        visible: seekBar.seekable
      }
      Rectangle {
        visible: seekBar.seekable && (seekMouse.containsMouse || seekMouse.pressed)
        width: seekTime.implicitWidth + Style.space(14)
        height: seekTime.implicitHeight + Style.space(8)
        x: Math.max(0, Math.min(seekBar.width - width, seekBar.width * (panel.hasTimeline ? seekBar.preview / panel.trackDuration : 0) - width / 2))
        anchors.bottom: parent.top
        radius: Style.space(6)
        color: "#24252b"
        Label { id: seekTime; anchors.centerIn: parent; text: panel.timestamp(seekBar.preview); color: panel.capsuleInk; font.pixelSize: Style.font.caption }
      }
      MouseArea {
        id: seekMouse
        anchors.fill: parent
        enabled: seekBar.seekable
        hoverEnabled: true
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
        onPressed: function(mouse) {
          seekAcknowledgement.stop()
          panel.seekDeadline = 0
          seekBar.dragPlayer = panel.player
          seekBar.dragTrack = seekBar.trackKey()
          seekBar.updatePreview(mouse.x)
          seekBar.dragging = true
        }
        onPositionChanged: function(mouse) { seekBar.updatePreview(mouse.x) }
        onReleased: function(mouse) {
          if (seekBar.dragging && seekBar.seekable && seekBar.dragPlayer === panel.player && seekBar.dragTrack === seekBar.trackKey()) {
            seekBar.updatePreview(mouse.x)
            const target = Math.min(seekBar.preview, Math.max(0, panel.trackDuration - 0.1))
            panel.elapsed = target
            panel.seekDeadline = Date.now() + 1800
            panel.player.position = target
            seekAcknowledgement.restart()
          }
          seekBar.dragging = false
          seekBar.dragPlayer = null
        }
        onCanceled: {
          seekBar.dragging = false
          seekBar.dragPlayer = null
          panel.refreshPosition()
        }
      }
    }
    Row {
      anchors.left: parent.left; anchors.right: parent.right
      anchors.leftMargin: Style.space(18); anchors.rightMargin: Style.space(18)
      anchors.bottom: parent.bottom; anchors.bottomMargin: Style.space(12)
      Label {
        width: parent.width * 0.8
        font.pixelSize: Style.font.caption
        text: panel.hasTimeline ? panel.timestamp(seekBar.dragging ? seekBar.preview : panel.elapsed)
          : strings.t("timelineUnavailable")
      }
      Label {
        width: parent.width * 0.2
        horizontalAlignment: Text.AlignRight
        font.pixelSize: Style.font.caption
        text: panel.hasTimeline ? panel.timestamp(panel.trackDuration)
          : "—:—"
      }
    }
  }

  // Source selection stays tucked below the visual player when multiple apps are active.
  Column {
    width: parent.width
    spacing: Style.space(4)
    visible: panel.host.sourcePlayers.length > 1
    Repeater {
      model: panel.host.sourcePlayers
      Rectangle {
        required property var modelData
        readonly property bool active: panel.player && panel.host.mediaService.playerKey(panel.player) === panel.host.mediaService.playerKey(modelData)
        width: parent.width; height: Style.space(34); radius: Style.space(17)
        color: active ? Qt.rgba(1, 1, 1, 0.16) : "#14151a"
        border.width: 1
        border.color: active ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.12)

        Row {
          anchors.fill: parent
          anchors.leftMargin: Style.space(12)
          anchors.rightMargin: Style.space(12)
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText
            text: panel.host.playerIcon(modelData)
            color: active ? panel.accent : Qt.alpha(panel.capsuleInk, 0.7)
            font.pixelSize: Style.font.icon
            font.family: Style.font.family
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            textFormat: Text.PlainText
            text: panel.host.playerName(modelData) + (modelData.trackTitle ? " · " + modelData.trackTitle : "")
            color: panel.capsuleInk
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
            font.weight: active ? Font.DemiBold : Font.Normal
            elide: Text.ElideRight
            width: parent.width - Style.space(36)
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: panel.host.selectPlayer(modelData)
        }
      }
    }
  }
}
