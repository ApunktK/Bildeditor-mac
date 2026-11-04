// swift-tools-version:5.9
// Plattformunabhängiger Kern des Bildeditors (läuft auch unter Linux für schnelle Tests).
import PackageDescription

let package = Package(
    name: "EditorKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "EditorCore", targets: ["EditorCore"]),
        .library(name: "EditorDocument", targets: ["EditorDocument"]),
    ],
    targets: [
        .target(name: "EditorCore"),
        .target(name: "EditorDocument", dependencies: ["EditorCore"]),
        .testTarget(name: "EditorCoreTests", dependencies: ["EditorCore"]),
        .testTarget(name: "EditorDocumentTests", dependencies: ["EditorDocument"]),
    ]
)
