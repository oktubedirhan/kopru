// swift-tools-version: 6.0
// Köprü uygulaması. Derlemek ve .app paketi oluşturmak için: scripts/build-app.sh
// Testler: cd App && swift test        Xcode'da açmak için: open App/Package.swift
import PackageDescription

let package = Package(
    name: "Kopru",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(name: "Kopru", path: "Sources/Kopru"),
        .testTarget(name: "KopruTests", dependencies: ["Kopru"], path: "Tests/KopruTests"),
    ]
)
