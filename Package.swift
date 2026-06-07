// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "JapaneseKeyboard",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: [
        .library(name: "JapaneseKeyboardCore", targets: ["JapaneseKeyboardCore"]),
        .library(name: "JapaneseKeyboardUI", targets: ["JapaneseKeyboardUI"]),
        .library(name: "JapaneseKeyboardAI", targets: ["JapaneseKeyboardAI"]),
        .library(name: "KeyboardPreferences", targets: ["KeyboardPreferences"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter",
            .upToNextMinor(from: "0.11.1")
        ),
        .package(
            url: "https://github.com/KeyboardKit/KeyboardKit.git",
            .upToNextMinor(from: "10.4.1")
        ),
        .package(
            url: "https://github.com/supabase/supabase-swift",
            from: "2.5.1"
        ),
    ],
    targets: [
        .target(
            name: "KeyboardPreferences"
        ),
        .target(
            name: "JapaneseKeyboardCore",
            dependencies: [
                "KeyboardPreferences",
                .product(
                    name: "KanaKanjiConverterModuleWithDefaultDictionary",
                    package: "AzooKeyKanaKanjiConverter"
                ),
            ],
            resources: [
                .process("Resources"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]
        ),
        .target(
            name: "JapaneseKeyboardAI",
            dependencies: [
                "KeyboardPreferences",
            ]
        ),
        .target(
            name: "JapaneseKeyboardUI",
            dependencies: [
                "JapaneseKeyboardCore",
                "KeyboardPreferences",
                .product(name: "KeyboardKit", package: "KeyboardKit"),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]
        ),
        .testTarget(
            name: "JapaneseKeyboardCoreTests",
            dependencies: ["JapaneseKeyboardCore", "KeyboardPreferences"],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]
        ),
        .testTarget(
            name: "JapaneseKeyboardAITests",
            dependencies: ["JapaneseKeyboardAI", "KeyboardPreferences"]
        ),
        .testTarget(
            name: "JapaneseKeyboardUITests",
            dependencies: ["JapaneseKeyboardUI"],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]
        ),
    ]
)
