// swift-tools-version: 5.9
import PackageDescription

// VoiceLauncherCore holds what can be tested without a microphone: the command
// model and the phrase matcher. The menu-bar application in Sources/VoiceLauncher
// is assembled into a bundle by App/build-app.sh — no Xcode project.
let package = Package(
    name: "VoiceLauncher",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "VoiceLauncherCore",
            path: "Sources/VoiceLauncherCore"
        ),
        .executableTarget(
            name: "VoiceLauncher",
            dependencies: ["VoiceLauncherCore"],
            path: "Sources/VoiceLauncher"
        ),
        .testTarget(
            name: "VoiceLauncherCoreTests",
            dependencies: ["VoiceLauncherCore"],
            path: "Tests/VoiceLauncherCoreTests"
        ),
    ]
)
