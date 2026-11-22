import QtQuick
import qs.Commons as Commons

Item {
  id: root
  property bool active: true
  property real phase: 0
  readonly property real cycleMs: Commons.Style.duration(6000)
  readonly property real intensity: Commons.Style.reduceMotion ? 0.75 : 0.75 - 0.25 * Math.cos(phase)
  readonly property var alphaKeys: ["popups.border-alpha", "tooltip.border-alpha",
    "notifications.border-alpha", "launcher.border-alpha", "menu.border-alpha",
    "image-picker.selected-border-alpha"]

  // Keep theme edits live and restore the ordinary palette when disabled.
  function palette() {
    var merged = {}
    var key
    for (key in Commons.Color.themeShellValues) merged[key] = Commons.Color.themeShellValues[key]
    for (key in Commons.Color.userShellValues) merged[key] = Commons.Color.userShellValues[key]
    for (var i = 0; i < alphaKeys.length; ++i) {
      key = alphaKeys[i]
      var base = merged[key] === undefined ? 0.5 : Number(merged[key])
      if (!isFinite(base)) base = 0.5
      merged[key] = String(Math.max(0, Math.min(1, base)) * intensity)
    }
    return merged
  }

  Binding {
    target: Commons.Color
    property: "shellValues"
    when: root.active
    value: root.palette()
    restoreMode: Binding.RestoreBindingOrValue
  }

  // A slow cosine breath needs only 20 small opacity updates per second.
  // No commands, configuration rewrites, or shell restarts during animation.
  Timer {
    interval: 50
    repeat: true
    running: root.active && root.cycleMs > 0
    onTriggered: root.phase = (root.phase + 2 * Math.PI * interval / root.cycleMs) % (2 * Math.PI)
  }

  Component.onDestruction: {
    root.active = false
    Commons.Color.mergeShell()
  }
}
