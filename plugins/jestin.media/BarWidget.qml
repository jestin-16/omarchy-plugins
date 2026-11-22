import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Ui
import qs.Commons
import qs.Commons as Commons
import "vendor/lyrics/Model.js" as LyricsModel

BarWidget {
  id: root
  moduleName: "jestin.media"

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  // Keep an explicit source selection local to the popup. The global service
  // prioritizes playing audio, which otherwise overrides a paused selection.
  property string selectedPlayerKey: ""
  readonly property var activePlayer: {
    if (selectedPlayerKey && mediaService) {
      for (var i = 0; i < sourcePlayers.length; ++i)
        if (mediaService.playerKey(sourcePlayers[i]) === selectedPlayerKey)
          return sourcePlayers[i]
    }
    return mediaService ? mediaService.activePlayer : null
  }
  function selectPlayer(player) {
    if (!mediaService || !player) return
    selectedPlayerKey = mediaService.playerKey(player)
    mediaService.selectPlayer(selectedPlayerKey)
  }
  onSourcePlayersChanged: {
    if (!selectedPlayerKey || !mediaService) return
    for (var i = 0; i < sourcePlayers.length; ++i)
      if (mediaService.playerKey(sourcePlayers[i]) === selectedPlayerKey) return
    selectedPlayerKey = ""
  }
  readonly property var sourcePlayers: mediaService ? mediaService.sourcePlayers : []

  readonly property bool hasMedia: activePlayer !== null && (activePlayer.trackTitle || activePlayer.trackArtist)
  readonly property bool isPlaying: !!activePlayer && !!activePlayer.isPlaying
  readonly property string playIcon: activePlayer && activePlayer.isPlaying ? "󰏤" : "󰐊"
  readonly property string title: activePlayer ? (activePlayer.trackTitle || "") : ""
  readonly property string artist: activePlayer ? (activePlayer.trackArtist || "") : ""

  property bool popupOpen: false

  function close() { popupOpen = false }

  onPopupOpenChanged: {
    if (!root.bar) return
    if (root.popupOpen) root.bar.requestPopout(root)
    else if (root.bar.activePopout === root) root.bar.releasePopout(root)
  }

  function playerIcon(player) {
    var id = String(player && (player.identity || player.desktopEntry || "")).toLowerCase()
    if (id.indexOf("vlc") !== -1) return "󰕼"
    if (id.indexOf("spotify") !== -1) return "󰓇"
    if (id.indexOf("firefox") !== -1) return "󰈹"
    if (id.indexOf("chrome") !== -1 || id.indexOf("brave") !== -1 || id.indexOf("chromium") !== -1 || id.indexOf("zen") !== -1) return "󰊯"
    if (id.indexOf("mpv") !== -1) return "󰝚"
    return "󰎆"
  }

  function playerName(player) {
    if (!player) return "Media Player"
    return player.identity || player.desktopEntry || "Media Player"
  }

  visible: hasMedia
  implicitWidth: hasMedia ? (root.vertical ? Style.bar.iconSlot : trackLabel.implicitWidth + Style.space(12)) : 0
  implicitHeight: barSize

  // Compact typography matches the clock and neighbouring bar labels.
  Row {
    id: trackLabel
    anchors.centerIn: parent
    spacing: Style.space(6)

    OpticalGlyph {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.bar.iconSize
      height: width
      text: "󰎆"
      fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
      fontSize: Style.bar.iconFont
      paintedSize: Style.bar.iconSize
      color: root.bar ? root.bar.barForeground : Commons.Color.foreground
    }

    Text {
      visible: !root.vertical
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, Style.space(76))
      textFormat: Text.PlainText
      text: root.title || root.playerName(root.activePlayer)
      elide: Text.ElideRight
      maximumLineCount: 1
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      color: root.bar ? root.bar.barForeground : Commons.Color.foreground
      opacity: root.isPlaying || mediaMouse.containsMouse ? 1 : 0.65
    }
  }

  MouseArea {
    id: mediaMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.activePlayer ? Qt.PointingHandCursor : Qt.ArrowCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

    onClicked: function(mouse) {
      if (!root.activePlayer) return
      if (mouse.button === Qt.MiddleButton) {
        if (root.mediaService) root.mediaService.runAction("next", false, root.mediaService.playerKey(root.activePlayer))
      } else if (mouse.button === Qt.RightButton) {
        if (root.mediaService) root.mediaService.runAction("playPause", false, root.mediaService.playerKey(root.activePlayer))
      } else {
        if (root.bar) root.bar.hideTooltip(root)
        root.popupOpen = !root.popupOpen
      }
    }
    onWheel: function(wheel) {
      if (!root.activePlayer) return
      if (wheel.angleDelta.y > 0 && root.mediaService) root.mediaService.runAction("previous", false, root.mediaService.playerKey(root.activePlayer))
      else if (wheel.angleDelta.y < 0 && root.mediaService) root.mediaService.runAction("next", false, root.mediaService.playerKey(root.activePlayer))
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.hasMedia ? LyricsModel.safeDisplayText(root.title + (root.artist ? " — " + root.artist : "")) : "")
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }

  PopupWindow {
    id: popup
    property Item anchorItem: root
    readonly property var anchorWindow: root.QsWindow.window
    readonly property var popupScreen: anchorWindow ? anchorWindow.screen : null
    readonly property real screenW: popupScreen ? popupScreen.width : 0
    readonly property real screenH: popupScreen ? popupScreen.height : 0
    readonly property int margin: Style.gapsOut
    readonly property real barThickness: !root.bar ? 0
      : (typeof root.bar.barSizeFor === "function" && popupScreen ? root.bar.barSizeFor(popupScreen.name) : root.bar.barSize)
    readonly property real availableCardWidth: screenW > 0
      ? Math.max(120, screenW - ((root.bar && (root.bar.position === "left" || root.bar.position === "right")) ? barThickness : 0) - margin * 2)
      : Style.space(360)
    readonly property real availableCardHeight: screenH > 0
      ? Math.max(120, screenH - ((root.bar && (root.bar.position === "top" || root.bar.position === "bottom")) ? barThickness : 0) - margin * 2)
      : Style.space(400)

    function fittedContentWidth(width) {
      var desired = Math.max(1, Number(width) || 1)
      var maxWidth = popup.availableCardWidth > 0 ? popup.availableCardWidth : desired
      return Math.round(Math.min(desired, maxWidth))
    }

    function fittedContentHeight(implicitHeight) {
      var desired = Number(implicitHeight) || 0
      var maxHeight = popup.availableCardHeight > 0 ? popup.availableCardHeight : desired
      return Math.round(Math.min(desired, maxHeight))
    }

    function close() {
      root.close()
    }

    visible: root.popupOpen || cardContainer.opacity > 0
    color: "transparent"
    mask: Region { item: root.popupOpen ? cardContainer : null }
    implicitWidth: fittedContentWidth(Style.space(404))
    implicitHeight: fittedContentHeight(mediaPanel.implicitHeight + Style.space(4))

    HyprlandFocusGrab {
      active: root.popupOpen
      windows: popup.anchorWindow ? [popup, popup.anchorWindow] : [popup]
      onCleared: root.close()
    }

    anchor {
      id: popupAnchor
      window: popup.anchorWindow
      adjustment: PopupAdjustment.Slide
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1

      onAnchoring: {
        if (!root || !root.bar) return

        var target = root
        var popupWidth = popup.implicitWidth
        var popupHeight = popup.implicitHeight
        var localX = target.width / 2 - popupWidth / 2
        var localY = target.height + popup.margin

        if (root.bar.position === "bottom") {
          localY = -popupHeight - popup.margin
        } else if (root.bar.position === "left") {
          localX = target.width + popup.margin
          localY = target.height / 2 - popupHeight / 2
        } else if (root.bar.position === "right") {
          localX = -popupWidth - popup.margin
          localY = target.height / 2 - popupHeight / 2
        }

        var window = target.QsWindow.window
        if (!window) return

        var point = window.contentItem.mapFromItem(target, localX, localY)

        if (root.bar.position === "top" || root.bar.position === "bottom") {
          point.x = Math.max(popup.margin, Math.min(point.x, window.width - popupWidth - popup.margin))
        } else {
          point.y = Math.max(popup.margin, Math.min(point.y, window.height - popupHeight - popup.margin))
        }

        popupAnchor.rect.x = Math.round(point.x)
        popupAnchor.rect.y = Math.round(point.y)
      }
    }

    Item {
      id: cardContainer
      anchors.fill: parent

      property real shown: root.popupOpen ? 1 : 0
      Behavior on shown {
        id: showing
        NumberAnimation {
          duration: Style.duration(showing.targetValue > 0 ? 220 : 130)
          easing.type: Easing.Bezier
          easing.bezierCurve: Style.easeOut
        }
      }
      opacity: shown
      scale: 0.97 + 0.03 * shown
      transform: Translate {
        x: !root.bar ? 0 : root.bar.position === "left" ? -Style.space(5) * (1 - cardContainer.shown)
          : root.bar.position === "right" ? Style.space(5) * (1 - cardContainer.shown) : 0
        y: !root.bar || root.bar.position === "top" ? -Style.space(5) * (1 - cardContainer.shown)
          : root.bar.position === "bottom" ? Style.space(5) * (1 - cardContainer.shown) : 0
      }
      transformOrigin: !root.bar || root.bar.position === "top" ? Item.Top
        : root.bar.position === "bottom" ? Item.Bottom
        : root.bar.position === "left" ? Item.Left : Item.Right

      PlayerCard {
        id: mediaPanel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Style.space(2)
        host: root
      }
    }
  }
}

