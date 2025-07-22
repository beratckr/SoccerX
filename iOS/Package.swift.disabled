// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SoccerX",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "SoccerX",
            targets: ["SoccerX"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.24.0")
    ],
    targets: [
        .target(
            name: "SoccerX",
            dependencies: [
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk")
            ]),
    ]
)