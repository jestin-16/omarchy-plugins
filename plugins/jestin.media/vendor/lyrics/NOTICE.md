# Reused lyrics plugin source

Model.js and bin/lrclib are adapted from Carmine Paolino’s crmne/omarchy-lyrics:
https://github.com/crmne/omarchy-lyrics
Retrieved 2026-11-17 through the browser tool (cached upstream source).
The upstream project declares the MIT license.

Local changes: strip YouTube’s “ - Topic” artist suffix; enforce a total lookup
deadline. The media card uses the existing matching, LRC parsing, HTTPS fetch,
response limits and cache code. lookup.py adapts its input to environment
variables, so track metadata does not appear in process arguments.
These are vendored components, not a separately installed/updatable plugin.
