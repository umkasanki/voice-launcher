import AudioToolbox
import Foundation

/// Plays the app's cues as system sound effects. NSSound follows the default
/// output, which may be a speaker in another room; sound effects go to the
/// device chosen in System Settings → Sound → "Play sound effects through".
@MainActor
enum SoundCue {
    private static var ids: [String: SystemSoundID] = [:]

    static func play(_ name: String) {
        if ids[name] == nil {
            let url = URL(fileURLWithPath: "/System/Library/Sounds/\(name).aiff") as CFURL
            var id: SystemSoundID = 0
            guard AudioServicesCreateSystemSoundID(url, &id) == kAudioServicesNoError else { return }
            ids[name] = id
        }
        if let id = ids[name] { AudioServicesPlaySystemSound(id) }
    }
}
