import QtQuick
import qs.Commons
import qs.Commons as Commons
import ".."

Rectangle {
  id: weatherPill
  property var lock: null

  LiveWeather {
    id: weather
    lock: weatherPill.lock
  }

  height: 36
  radius: 18
  color: lock ? lock.withAlpha("#24283b", 0.75) : "#24283b"
  border.width: 1
  border.color: lock ? lock.withAlpha("#7dcfff", 0.3) : "#7dcfff"
  width: contentRow.implicitWidth + 24

  Row {
    id: contentRow
    anchors.centerIn: parent
    spacing: 8

    // Weather Glyph with gentle vertical float
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: weather.glyph.length > 0 ? weather.glyph : "󰖙"
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

    // Temp & Place / Condition
    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: (weather.tempC.length > 0 ? weather.tempC + " " : "")
        + (weather.place.length > 0 ? weather.place : (weather.condition.length > 0 ? weather.condition : "Tokyo"))
      textFormat: Text.PlainText
      font.family: "Adwaita Sans"
      font.pixelSize: 12
      font.weight: Font.Medium
      color: "#c0caf5"
    }
  }
}
