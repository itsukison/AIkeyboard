// swift-tools-version: 6.1
import PackageDescription

// Batch conversion checker for dictionary-gap mining. Runs the same
// AzooKeyKanaKanjiConverter the keyboard ships (classical mode) on macOS.
// Uses upstream (not the CPU fork) because the fork's llama.xcframework is
// iOS-only; with zenzaiMode .off the converter behavior is identical.
let package = Package(
    name: "ConvProbe",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            url: "https://github.com/azooKey/AzooKeyKanaKanjiConverter",
            exact: "0.11.2",
            traits: ["Zenzai"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "ConvProbe",
            dependencies: [
                .product(
                    name: "KanaKanjiConverterModuleWithDefaultDictionary",
                    package: "AzooKeyKanaKanjiConverter"
                ),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]
        ),
    ]
)
