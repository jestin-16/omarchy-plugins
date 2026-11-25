.pragma library

// Positive sender timeouts are honored. Persistent critical alerts keep waiting.
function durationFor(urgency, requested, low, normal, maximum) {
  if (Number(urgency) === 2) return 0
  var ms = Number(requested)
  if (isFinite(ms) && ms > 0) return Math.max(750, Math.min(maximum, ms))
  return Number(urgency) === 0 ? low : normal
}
