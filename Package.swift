// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ScriptKeyboardCore",
    platforms: [.iOS("27.0"), .macOS(.v15)],
    products: [.library(name: "KeyboardCore", targets: ["KeyboardCore"])],
    targets: [
        .target(name: "KeyboardCore", resources: [.process("Resources")]),
        .testTarget(name: "KeyboardCoreTests", dependencies: ["KeyboardCore"])
    ]
)
