import QtQuick
import Quickshell.Io
import "vendor/lyrics/Model.js" as Model

// Integration adapter; matching, LRC timing and network/cache code are reused
// from crmne.lyrics. Each request owns its process, so old tracks cannot win.
Item {
  id: root
  property var player: null
  property bool online: true
  property bool panelOpen: false
  property real position: 0
  property string state: "idle"
  property var record: null
  property var request: null
  property int serial: 0
  readonly property string key: player ? JSON.stringify([
    player.dbusName, player.uniqueId, player.trackTitle, player.trackArtist,
    player.trackAlbum, player.lengthSupported ? Math.round(player.length) : 0
  ]) : ""
  readonly property var lines: record && record.synced ? Model.parseSynced(record.synced) : []
  readonly property var plain: record && record.plain ? Model.plainLines(record.plain) : []
  readonly property bool synced: lines.length > 0
  readonly property int activeIndex: synced ? Model.activeLine(lines, position) : -1

  function cancel() {
    serial++
    debounce.stop()
    if (request) { request.running = false; request = null }
  }
  function reset() {
    cancel()
    record = null
    state = "idle"
    if (online && panelOpen && player && player.trackTitle) debounce.restart()
  }
  onKeyChanged: reset()
  onOnlineChanged: reset()
  onPanelOpenChanged: {
    if (!panelOpen) {
      cancel()
      if (state === "searching") state = "idle"
    } else if (state === "idle") debounce.restart()
  }
  Component.onCompleted: reset()
  Component.onDestruction: cancel()
  Timer { id: debounce; interval: 700; onTriggered: root.lookup(false) }

  function lookup(refresh) {
    if (!online || !panelOpen || !player || !player.trackTitle) return
    cancel()
    state = "searching"
    var env = {
      LRCLIB_ARTIST: Model.cleanArtist(player.trackArtist),
      LRCLIB_TITLE: Model.cleanTitle(player.trackTitle),
      LRCLIB_ALBUM: String(player.trackAlbum || ""),
      LRCLIB_DURATION: String(player.lengthSupported ? Math.round(player.length) : 0),
      LRCLIB_REFRESH: refresh ? "1" : "0"
    }
    request = worker.createObject(root, {token: serial, environment: env})
    request.running = true
  }
  function accept(raw, token) {
    if (token !== serial || !online) return
    var data = Model.parseHelperOutput(raw, 2 * 1024 * 1024)
    if (!data || !data.ok) { state = "error"; return }
    record = data.result || Model.pickCandidate(data.results,
      player.trackArtist, player.trackTitle, player.lengthSupported ? player.length : 0)
    state = record && (record.synced || record.plain) ? "ready" : "empty"
  }
  Component {
    id: worker
    Process {
      id: proc
      property int token: 0
      command: ["/usr/bin/timeout", "28", "/usr/bin/python3",
        decodeURIComponent(String(Qt.resolvedUrl("vendor/lyrics/lookup.py")).replace(/^(file|qs):\/\//, ""))]
      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: root.accept(text, proc.token)
      }
      onExited: {
        if (root.request === proc) root.request = null
        if (token === root.serial && root.state === "searching") root.state = "error"
        Qt.callLater(function() { proc.destroy() })
      }
    }
  }
}
