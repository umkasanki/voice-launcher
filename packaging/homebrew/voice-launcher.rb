# Homebrew Cask for Voice Launcher.
#
# The live cask is Casks/voice-launcher.rb in umkasanki/homebrew-tap; the
# release workflow bumps its version and sha256 only, so change anything else
# in both places.
#
# Install (users):
#   brew tap umkasanki/tap
#   brew trust umkasanki/tap        # third-party taps must be trusted once
#   brew install --cask voice-launcher
cask "voice-launcher" do
  version "0.1.0"
  sha256 "REPLACE_WITH_DMG_SHA256"   # printed by App/make-dmg.sh

  url "https://github.com/umkasanki/voice-launcher/releases/download/v#{version}/VoiceLauncher-#{version}.dmg"
  name "Voice Launcher"
  desc "Runs apps and actions on spoken phrases, without ever typing text"
  homepage "https://github.com/umkasanki/voice-launcher"

  depends_on macos: :sonoma

  app "Voice Launcher.app"

  # Self-signed, not notarized: without this Gatekeeper refuses the first
  # launch, and the people this app is for may have no easy way to click
  # through the dialogs.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Voice Launcher.app"]
  end

  uninstall quit: "com.umkasanki.VoiceLauncher"

  zap trash: [
    "~/Library/Application Support/VoiceLauncher",
    "~/Library/Logs/VoiceLauncher.log",
    "~/Library/Preferences/com.umkasanki.VoiceLauncher.plist",
  ]

  caveats <<~EOS
    On first launch Voice Launcher asks for the microphone and for speech
    recognition. Both are needed; recognition runs on this Mac.
  EOS
end
