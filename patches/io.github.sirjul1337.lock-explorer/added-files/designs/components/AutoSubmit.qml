import QtQuick

// One automatic submission per lock instance. Holds no password data.
Timer {
  id: timer
  interval: 1600
  repeat: false
  property bool available: false
  property bool hasText: false
  property bool attempted: false
  signal submitRequested()

  function edited() {
    stop()
    if (available && hasText && !attempted) restart()
  }
  function noteAttempt() { attempted = true; stop() }
  function resetSession() { stop(); attempted = false }
  onAvailableChanged: if (!available) stop()
  onHasTextChanged: if (!hasText) stop()
  onTriggered: {
    if (!available || !hasText || attempted) return
    attempted = true
    submitRequested()
  }
}
