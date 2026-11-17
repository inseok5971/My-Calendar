// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MyCalendar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MyCalendar", targets: ["MyCalendar"])
    ],
    targets: [
        .executableTarget(
            name: "MyCalendar",
            path: "Sources/MyCalendar"
        )
    ]
)
