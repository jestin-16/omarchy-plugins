import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: weather

  property string locationQuery: ""
  property var report: null
  property bool loading: true
  property bool failed: false

  readonly property var current: report && report.current_condition && report.current_condition.length ? report.current_condition[0] : null
  readonly property string tempC: current ? current.temp_C + "°" : ""
  readonly property string tempF: current ? current.temp_F + "°" : ""
  readonly property string condition: {
    if (!current) return ""
    return current.weatherDesc && current.weatherDesc.length ? String(current.weatherDesc[0].value) : ""
  }
  readonly property string place: report && report.nearest_area && report.nearest_area.length && report.nearest_area[0].areaName
    ? String(report.nearest_area[0].areaName[0].value) : ""
  readonly property string glyph: current ? glyphFor(current.weatherCode) : "󰖐"

  function glyphFor(code) {
    var c = parseInt(code || "0")
    if (c === 113) return "󰖙"
    if (c === 116) return "󰖕"
    if (c === 119 || c === 122) return "󰖐"
    if (c === 143 || c === 248 || c === 260) return "󰖑"
    if ([200, 386, 389, 392].indexOf(c) !== -1) return "󰖓"
    if ([179, 227, 230, 323, 326, 329, 332, 335, 338, 368, 371, 395].indexOf(c) !== -1) return "󰖘"
    if ([182, 185, 281, 284, 311, 314, 317, 320, 350, 362, 365, 374, 377].indexOf(c) !== -1) return "󰙿"
    if ([305, 308, 356, 359].indexOf(c) !== -1) return "󰖖"
    if (c >= 176) return "󰖗"
    return "󰖐"
  }

  function refresh() {
    if (!fetchProc.running && locationKnown) fetchProc.running = true
  }
  property bool locationKnown: false

  FileView {
    path: Quickshell.env("HOME") + "/.local/state/omarchy/settings/weather.json"
    printErrors: false
    onLoaded: {
      try {
        var d = JSON.parse(text())
        var lat = parseFloat(d.latitude), lon = parseFloat(d.longitude)
        if (!isNaN(lat) && !isNaN(lon)) weather.locationQuery = lat + "," + lon
        else if (d.name) weather.locationQuery = encodeURIComponent(d.name)
      } catch (e) {}
      weather.locationKnown = true
      weather.refresh()
    }
  }

  Process {
    id: fetchProc
    command: ["curl", "-s", "--max-time", "3", "https://wttr.in/" + (weather.locationQuery || "") + "?format=j1"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          weather.report = JSON.parse(text)
          weather.loading = false
          weather.failed = false
        } catch (e) {
          weather.failed = true
        }
      }
    }
  }
}
