import QtQuick
import QtCore
import Quickshell
import Quickshell.Services.Pipewire
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "vendor/lyrics/Model.js" as LyricsModel

Column {
  id: panel
  required property var host
  readonly property var player: host.activePlayer
  readonly property color ink: "#a8b1c2"
  property bool showVolume: false
  property bool showLyrics: false
  readonly property color accent: Commons.Color.accent
  readonly property color capsuleInk: "#edf2fc"
  readonly property var output: Pipewire.defaultAudioSink
  readonly property var outputAudio: output ? output.audio : null
  PwObjectTracker { objects: panel.output ? [panel.output] : [] }
  Settings {
    id: preferences
    location: "file://" + Quickshell.env("HOME") + "/.local/state/omarchy/media-card.ini"
    property bool lyricsOnline: true
  }
  LyricsSource {
    id: lyrics
    player: panel.player
    online: preferences.lyricsOnline
    panelOpen: panel.host.popupOpen && panel.showLyrics
    position: panel.elapsed
  }
  function setVolume(value) {
    if (!outputAudio) return
    outputAudio.muted = false
    outputAudio.volume = Math.max(0, Math.min(1, value))
  }
  function toggleMute() { if (outputAudio) outputAudio.muted = !outputAudio.muted }
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
    if (trackReveal && host.popupOpen) trackReveal.restart()
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
    interval: 500; repeat: true
    running: panel.host.popupOpen && !!panel.player && panel.player.positionSupported && panel.host.isPlaying
    triggeredOnStart: true
    onTriggered: panel.refreshPosition()
  }
  component Label: Text {
    textFormat: Text.PlainText
    color: panel.ink
    font.family: Style.font.family
    font.pixelSize: Style.font.body
    Behavior on color { ColorAnimation { duration: Style.duration(140) } }
  }

  // Animate the actual layout height so the popup follows the drawer.
  // Keep it alive while closing, but stop accepting input immediately.
  component Reveal: Item {
    id: drawer
    default property alias contents: drawerBody.data
    property bool expanded: false
    property real spacing: 0
    width: parent.width
    height: expanded ? drawerBody.implicitHeight : 0
    implicitHeight: height
    opacity: expanded ? 1 : 0
    visible: height > 0
    enabled: expanded
    clip: true
    property Column body: Column {
      id: drawerBody
      parent: drawer
      width: drawer.width
      spacing: drawer.spacing
    }
    Behavior on height {
      enabled: panel.host.popupOpen
      NumberAnimation { duration: Style.duration(drawer.expanded ? 220 : 150); easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
      enabled: panel.host.popupOpen
      NumberAnimation { duration: Style.duration(drawer.expanded ? 180 : 100); easing.type: Easing.OutCubic }
    }
  }

  ParallelAnimation {
    id: trackReveal
    NumberAnimation { target: metadataRow; property: "opacity"; from: 0.55; to: 1; duration: Style.duration(180); easing.type: Easing.OutCubic }
    NumberAnimation { target: metadataRow; property: "scale"; from: 0.985; to: 1; duration: Style.duration(180); easing.type: Easing.OutCubic }
  }

  Rectangle {
    width: parent.width
    height: content.implicitHeight + Style.space(32)
    radius: Style.space(10)
    color: "#07090c"
    border.width: 1
    border.color: Qt.alpha(panel.accent, 0.8)

    Column {
      id: content
      x: Style.space(18); y: Style.space(16)
      width: parent.width - Style.space(36)
      spacing: 0

      Row {
        id: metadataRow
        transformOrigin: Item.Left
        width: parent.width
        height: Style.space(84)
        spacing: Style.space(14)
        Rectangle {
          id: artwork
          width: Style.space(84); height: width
          radius: Style.space(4)
          color: "#121823"
          border.width: 1; border.color: Qt.alpha(panel.accent, 0.4)
          Label {
            anchors.centerIn: parent
            visible: cover.status !== Image.Ready
            text: "󰎆"; color: Qt.alpha(panel.accent, 0.75); font.pixelSize: Style.space(26)
          }
          SizedImage {
            id: cover
            anchors.fill: parent; anchors.margins: 2
            crop: true
            url: panel.player && panel.player.trackArtUrl ? panel.player.trackArtUrl : ""
            opacity: status === Image.Ready ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
          }
        }
        Column {
          width: parent.width - artwork.width - Style.space(14)
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(6)
          Label {
            width: parent.width
            text: panel.host.title || strings.t("nothingPlaying")
            font.pixelSize: Style.space(15); font.weight: Font.DemiBold
            color: panel.capsuleInk; elide: Text.ElideRight
          }
          Label {
            width: parent.width
            text: LyricsModel.cleanArtist(panel.host.artist) || panel.host.playerName(panel.player)
            font.pixelSize: Style.space(13); elide: Text.ElideRight
          }
          Label {
            width: parent.width
            text: panel.player && panel.player.trackAlbum ? panel.player.trackAlbum : panel.host.playerName(panel.player)
            font.pixelSize: Style.space(11); color: "#778297"; elide: Text.ElideRight
          }
        }
      }
      Item { width: 1; height: Style.space(7) }
    Item {
      id: seekBar
      objectName: "seekBar"
      width: parent.width
      height: Style.space(18)
      LayoutMirroring.enabled: false
      readonly property bool seekable: panel.hasTimeline && !!panel.player.canSeek
      onSeekableChanged: if (!seekable) dragging = false
      property real preview: 0
      property bool dragging: false
      property var dragPlayer: null
      property string dragTrack: ""
      readonly property real fraction: panel.hasTimeline
        ? Math.max(0, Math.min(1, (dragging ? preview : panel.elapsed) / panel.trackDuration)) : 0
      property real displayFraction: fraction
      Behavior on displayFraction {
        enabled: panel.host.popupOpen && !seekBar.dragging && panel.seekDeadline === 0 && panel.elapsed > 0
        NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic }
      }
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
        height: Style.space(seekMouse.containsMouse || seekMouse.pressed ? 4 : 3)
        Behavior on height { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
        radius: height / 2
        color: "#242b37"
        Rectangle {
          width: parent.width * seekBar.displayFraction
          height: parent.height; radius: parent.radius
          color: panel.accent
        }
      }
      Rectangle {
        x: seekBar.width * seekBar.displayFraction - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(seekBar.dragging || seekMouse.containsMouse ? 10 : 6); height: width; radius: width / 2
        color: panel.accent
        Behavior on width { NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
        visible: seekBar.seekable
      }
      Rectangle {
        visible: seekBar.seekable && (seekMouse.containsMouse || seekMouse.pressed)
        width: seekTime.implicitWidth + Style.space(14)
        height: seekTime.implicitHeight + Style.space(8)
        x: Math.max(0, Math.min(seekBar.width - width, seekBar.width * (panel.hasTimeline ? seekBar.preview / panel.trackDuration : 0) - width / 2))
        anchors.bottom: parent.top
        radius: Style.space(6)
        color: "#1a2230"
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
      width: parent.width
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


      Item { width: 1; height: Style.space(15) }
      Rectangle { width: parent.width; height: 1; color: "#202630" }
      Item { width: 1; height: Style.space(12) }

      Flickable {
        width: parent.width
        height: Math.min(sourceList.implicitHeight, Style.space(190))
        contentHeight: sourceList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: sourceList
          width: parent.width
          spacing: Style.space(6)
          Repeater {
            model: panel.host.sourcePlayers
            Rectangle {
              id: sourceRow
              required property var modelData
              readonly property bool active: panel.player && panel.host.mediaService.playerKey(panel.player) === panel.host.mediaService.playerKey(modelData)
              width: sourceList.width; height: Style.space(54)
              radius: Style.space(6)
              color: active ? (rowMouse.containsMouse ? "#1d2635" : "#151d2a") : rowMouse.containsMouse ? "#111722" : "transparent"
              border.width: active ? 1 : 0
              border.color: Qt.alpha(panel.accent, 0.3)
              Behavior on color { ColorAnimation { duration: Style.duration(120) } }
              Rectangle {
                opacity: sourceRow.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Style.duration(150); easing.type: Easing.OutCubic } }
                x: 0; anchors.verticalCenter: parent.verticalCenter
                width: Style.space(2); height: Style.space(sourceRow.active ? 24 : 12); radius: 1
                Behavior on height { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
                color: panel.accent
              }
              MouseArea {
                id: rowMouse
                anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.host.selectPlayer(sourceRow.modelData)
              }
              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8); anchors.rightMargin: Style.space(10)
                spacing: Style.space(9)
                Button {
            focusable: true
                  width: Style.space(22); height: Style.space(28)
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: sourceRow.modelData.isPlaying ? "󰏤" : "󰐊"
                  iconSize: Style.space(14); foreground: sourceRow.active ? panel.accent : panel.capsuleInk
                  horizontalPadding: 0; verticalPadding: 0; radius: Style.space(4)
                  tooltipText: sourceRow.modelData.isPlaying ? strings.t("pause") : strings.t("play")
                  enabled: sourceRow.modelData.canTogglePlaying || sourceRow.modelData.canPlay || sourceRow.modelData.canPause
                  onClicked: panel.host.mediaService.runAction("playPause", false, panel.host.mediaService.playerKey(sourceRow.modelData))
                }
                Label {
                  width: Style.space(22)
                  anchors.verticalCenter: parent.verticalCenter
                  text: panel.host.playerIcon(sourceRow.modelData)
                  font.pixelSize: Style.space(21)
                  color: String(sourceRow.modelData.identity || "").toLowerCase().indexOf("spotify") >= 0 ? "#1ed760" : panel.ink
                }
                Column {
                  width: parent.width - Style.space(62)
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(3)
                  Label {
                    width: parent.width
                    text: sourceRow.modelData.trackTitle || panel.host.playerName(sourceRow.modelData)
                    color: sourceRow.active ? panel.capsuleInk : panel.ink
                    font.pixelSize: Style.space(13); font.weight: Font.DemiBold
                    elide: Text.ElideRight
                  }
                  Label {
                    width: parent.width
                    text: LyricsModel.cleanArtist(sourceRow.modelData.trackArtist) || panel.host.playerName(sourceRow.modelData)
                    font.pixelSize: Style.space(11); color: "#8b96a9"
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }
        }
      }
      Item { width: 1; height: Style.space(9) }
      Item {
        width: parent.width; height: Style.space(26)
        Row {
          anchors.left: parent.left; spacing: Style.space(3)
          Button {
            focusable: true
            width: Style.space(29); height: Style.space(26)
            background: "#10151d"
            iconText: "󰒮"; iconSize: Style.space(16); foreground: panel.ink
            horizontalPadding: 0; verticalPadding: 0; radius: Style.space(4)
            tooltipText: strings.t("previous")
            enabled: !!panel.player && panel.player.canGoPrevious
            onClicked: panel.host.mediaService.runAction("previous", false, panel.host.mediaService.playerKey(panel.player))
          }
          Button {
            focusable: true
            width: Style.space(29); height: Style.space(26)
            background: "#10151d"
            iconText: "󰒭"; iconSize: Style.space(16); foreground: panel.ink
            horizontalPadding: 0; verticalPadding: 0; radius: Style.space(4)
            tooltipText: strings.t("next")
            enabled: !!panel.player && panel.player.canGoNext
            onClicked: panel.host.mediaService.runAction("next", false, panel.host.mediaService.playerKey(panel.player))
          }
        }
        Row {
          anchors.right: parent.right; spacing: Style.space(8)
          Button {
            focusable: true
            height: Style.space(26)
            text: strings.t("volumeCompact"); iconText: "󰕾"
            fontSize: Style.space(11); iconSize: Style.space(13)
            foreground: panel.showVolume ? panel.accent : panel.ink
            background: Qt.alpha(panel.accent, panel.showVolume ? 0.13 : 0.04)
            Behavior on foreground { ColorAnimation { duration: Style.duration(140) } }
            Behavior on background { ColorAnimation { duration: Style.duration(140) } }
            horizontalPadding: Style.space(8); verticalPadding: 0; radius: Style.space(5)
            onClicked: panel.showVolume = !panel.showVolume
          }
          Button {
            focusable: true
            height: Style.space(26)
            text: strings.t("lyricsCompact"); iconText: "󰍬"
            fontSize: Style.space(11); iconSize: Style.space(13)
            foreground: panel.showLyrics ? panel.accent : panel.ink
            background: Qt.alpha(panel.accent, panel.showLyrics ? 0.13 : 0.04)
            Behavior on foreground { ColorAnimation { duration: Style.duration(140) } }
            Behavior on background { ColorAnimation { duration: Style.duration(140) } }
            horizontalPadding: Style.space(8); verticalPadding: 0; radius: Style.space(5)
            onClicked: panel.showLyrics = !panel.showLyrics
          }
        }
      }
      Reveal {
        objectName: "volumeDrawer"
        expanded: panel.showVolume
        width: parent.width
        Item { width: 1; height: Style.space(10) }
        Rectangle { width: parent.width; height: 1; color: "#202630" }
        Item { width: 1; height: Style.space(6) }
        Row {
          width: parent.width; spacing: Style.space(8)
          Button {
            focusable: true
            objectName: "muteButton"
            width: Style.space(24); height: Style.space(28)
            iconText: panel.outputAudio && panel.outputAudio.muted ? "󰖁" : "󰕾"
            iconSize: Style.space(16); foreground: panel.ink
            horizontalPadding: 0; verticalPadding: 0; radius: Style.space(4)
            tooltipText: strings.t("mute"); enabled: !!panel.outputAudio
            onClicked: panel.toggleMute()
          }
          PanelSlider {
            id: volumeSlider
            objectName: "volumeSlider"
            width: parent.width - Style.space(84)
            enabled: !!panel.outputAudio
            value: panel.outputAudio ? panel.outputAudio.volume : 0
            fillColor: panel.accent; knobColor: panel.capsuleInk; trackColor: "#242b37"
            knobSize: Style.space(8); trackHeight: Style.space(3)
            onMoved: function(value) { panel.setVolume(value) }
            onRightClicked: panel.toggleMute()
          }
          Label {
            width: Style.space(44); anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight; font.pixelSize: Style.space(11)
            text: panel.outputAudio ? Commons.I18n.formatNumber(Math.round((volumeSlider.dragging ? volumeSlider.liveValue : panel.outputAudio.volume) * 100)) + "%" : "—"
          }
        }
      }
      Reveal {
        objectName: "lyricsDrawer"
        expanded: panel.showLyrics
        width: parent.width
        spacing: Style.space(8)
        Rectangle { width: parent.width; height: 1; color: "#202630" }
        Row {
          width: parent.width; height: Style.space(22); spacing: Style.space(6)
          Label {
            width: parent.width - Style.space(114)
            anchors.verticalCenter: parent.verticalCenter
            text: lyrics.synced ? strings.t("lyricsCredit") : strings.t("lyricsCompact")
            font.pixelSize: Style.space(10); color: "#8b96a9"
            elide: Text.ElideRight
          }
          Button {
            focusable: true
            width: Style.space(22); height: parent.height
            iconText: "󰑐"; iconSize: Style.space(13); foreground: panel.ink
            horizontalPadding: 0; verticalPadding: 0; radius: Style.space(4)
            tooltipText: strings.t("retry")
            enabled: preferences.lyricsOnline && lyrics.state !== "searching"
            onClicked: lyrics.lookup(true)
          }
          Button {
            focusable: true
            width: Style.space(80); height: parent.height
            text: preferences.lyricsOnline ? strings.t("lyricsOn") : strings.t("lyricsOff")
            fontSize: Style.space(10); foreground: panel.ink
            horizontalPadding: 0; verticalPadding: 0; radius: Style.space(4)
            tooltipText: strings.t("lyricsToggle")
            onClicked: preferences.lyricsOnline = !preferences.lyricsOnline
          }
        }
    ListView {
      id: lyricList
      objectName: "lyricList"
      width: parent.width
      height: Style.space(92)
      clip: true; spacing: Style.space(9)
      visible: preferences.lyricsOnline && lyrics.state === "ready"
      model: lyrics.synced ? lyrics.lines : lyrics.plain
      currentIndex: lyrics.activeIndex
      onCurrentIndexChanged: {
        if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Center)
        else positionViewAtBeginning()
      }
      onModelChanged: Qt.callLater(function() {
        if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Center)
        else positionViewAtBeginning()
      })
      delegate: Text {
        required property var modelData
        required property int index
        width: lyricList.width
        textFormat: Text.PlainText
        text: lyrics.synced ? (modelData.text || "♪") : modelData
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        color: lyrics.synced && index === lyrics.activeIndex ? panel.capsuleInk : panel.ink
        opacity: !lyrics.synced || index === lyrics.activeIndex ? 1 : 0.55
        Behavior on opacity { NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Style.duration(180) } }
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.weight: index === lyrics.activeIndex ? Font.DemiBold : Font.Normal
        MouseArea {
          anchors.fill: parent
          enabled: lyrics.synced && !!panel.player && panel.player.canSeek
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            panel.player.position = Math.max(0, modelData.time)
            panel.elapsed = Math.max(0, modelData.time)
          }
        }
      }
    }
    Label {
      width: parent.width; height: Style.space(72)
      visible: !lyricList.visible
      horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
      wrapMode: Text.Wrap; opacity: 0.65
      text: !preferences.lyricsOnline ? strings.t("lyricsDisabled")
        : lyrics.state === "searching" ? strings.t("lyricsSearching")
        : lyrics.state === "error" ? strings.t("lyricsError")
        : lyrics.record && lyrics.record.instrumental ? strings.t("lyricsInstrumental")
        : lyrics.state === "empty" ? strings.t("lyricsEmpty") : strings.t("lyricsWaiting")
    }

      }
    }
  }
}
