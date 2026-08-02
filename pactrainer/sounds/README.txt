Drop WAV files here to enable audio cues. Recognized names:

  fanfare.wav    - plays when you eat all four ghosts on one energizer
  tier_ok.wav    - plays when your pattern tier drops to OK
  tier_bad.wav   - plays when your pattern tier drops to BAD
  tier_fail.wav  - plays when you die mid-board

Format: WAV is the only cross-platform format guaranteed to play. Other formats
work only if the host OS's default player supports them (PowerShell on Windows,
afplay on macOS, paplay/aplay on Linux).

Missing files silently no-op; the on-screen popmessage still fires.
