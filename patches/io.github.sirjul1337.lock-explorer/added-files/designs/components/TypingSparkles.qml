import QtQuick

Item {
  id: sparkles
  anchors.fill: parent

  property var symbols: ["✨", "🌸", "✧", "💖", "🐾", "⭐", "💫", "❀", "🍡"]
  property int nextIndex: 0
  readonly property int poolSize: 14

  function burst(originX, originY) {
    var p = repeater.itemAt(nextIndex)
    if (p) {
      p.spawn(originX, originY, symbols[Math.floor(Math.random() * symbols.length)])
    }
    nextIndex = (nextIndex + 1) % poolSize
  }

  Repeater {
    id: repeater
    model: sparkles.poolSize

    Item {
      id: particle
      width: 24
      height: 24
      opacity: 0
      visible: opacity > 0

      property string glyph: "✨"

      function spawn(ox, oy, symbol) {
        glyph = symbol
        x = ox + (Math.random() - 0.5) * 80 - 12
        y = oy + (Math.random() - 0.5) * 20 - 12
        anim.restart()
      }

      Text {
        anchors.centerIn: parent
        text: particle.glyph
        font.pixelSize: 16
      }

      ParallelAnimation {
        id: anim
        NumberAnimation {
          target: particle
          property: "y"
          to: particle.y - (45 + Math.random() * 35)
          duration: 650
          easing.type: Easing.OutCubic
        }
        NumberAnimation {
          target: particle
          property: "opacity"
          from: 1.0
          to: 0.0
          duration: 650
          easing.type: Easing.InQuad
        }
        NumberAnimation {
          target: particle
          property: "scale"
          from: 0.7
          to: 1.3
          duration: 650
          easing.type: Easing.OutBack
        }
      }
    }
  }
}
