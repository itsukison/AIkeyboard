// swift-tools-version: 6.1
import PackageDescription

// Quality probe for zenz next-word candidate rescoring. Runs on macOS against
// the mac-probe worktree of our converter fork (upstream 0.11.2 + the
// evaluateZenzaiContinuations API; upstream's llama.xcframework has mac
// slices, our CPU fork's is iOS-only). See ../conversion-gapmine/ConvProbe
// for the classical-conversion sibling.
let package = Package(
    name: "RescoreProbe",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(
            path: "../../../AzooKeyKanaKanjiConverter-macprobe",
            traits: ["Zenzai"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "RescoreProbe",
            dependencies: [
                .product(
                    name: "KanaKanjiConverterModuleWithDefaultDictionary",
                    package: "AzooKeyKanaKanjiConverter-macprobe"
                ),
            ],
            swiftSettings: [
                .interoperabilityMode(.Cxx),
            ]
        ),
    ]
)
