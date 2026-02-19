// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GitGrove",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "GitGrove",
            path: "GitTree"
        )
    ]
)
