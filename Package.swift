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
        // Fork of AzooKeyKanaKanjiConverter 0.11.2 whose llama.cpp
        // binaryTarget is a CPU-only (GGML_METAL=OFF) xcframework — the stock
        // build's Metal backend aborts in the keyboard extension
        // (ggml_metal_init → kernel_get_rows_bf16 nil). See the fork's
        // BUILDING.md before touching the pin. cpu.2 adds
        // evaluateZenzaiContinuations (batched zenz candidate scoring for
        // next-word rescoring).
        .package(
            url: "https://github.com/itsukison/AzooKeyKanaKanjiConverter",
            exact: "0.11.2-cpu.2",
            traits: ["ZenzaiCPU"]
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
