// swift-tools-version:5.9

import PackageDescription

let package = Package(
  name: "Packages",
  platforms: [.iOS(.v13), .macOS(.v10_15)],
  products: [
    .library(name: "KernelBridge", targets: ["KernelBridge"]),
    .library(name: "Kernel", targets: ["Kernel"]),
    .library(name: "Parameters", targets: ["Parameters"]),
    .library(name: "ParameterAddress", targets: ["ParameterAddress"]),
    .library(name: "Theme", targets: ["Theme"]),
    .library(name: "UI", targets: ["UI"])
  ],
  dependencies: [
    .package(url: "https://github.com/bradhowes/AUv3Support", exact: "13.0.4"),
    // .package(path: "/Users/howes/src/Mine/AUv3Support")
  ],
  targets: [
    .target(
      name: "UI",
      dependencies: [.product(name: "AUv3-Support", package: "AUv3Support", condition: .none),
                     "Kernel",
                     "KernelBridge",
                     "ParameterAddress",
                     "Parameters"
                    ],
      exclude: ["README.md"]
    ),
    .target(
      name: "Theme",
      resources: [.process("Resources")]
    ),
    .target(
      name: "KernelBridge",
      dependencies: [
        "Kernel",
        .product(name: "AUv3-Support", package: "AUv3Support", condition: .none),
      ],
      exclude: ["README.md"]
    ),
    .target(
      name: "Kernel",
      dependencies: [
        .product(name: "AUv3-Support", package: "AUv3Support", condition: .none),
        .product(name: "AUv3-DSP-Headers", package: "AUv3Support", condition: .none),
        "ParameterAddress"
      ],
      exclude: ["README.md"],
      cxxSettings: [.unsafeFlags(["-fmodules", "-fcxx-modules"], .none)]
    ),
    .target(
      name: "ParameterAddress",
      dependencies: [
        .product(name: "AUv3-Support", package: "AUv3Support", condition: .none),
      ],
      exclude: ["README.md"]
    ),
    .target(
      name: "Parameters",
      dependencies: [
        .product(name: "AUv3-Support", package: "AUv3Support", condition: .none),
        "Kernel"
      ],
      exclude: ["README.md"]
    ),
    .testTarget(
      name: "KernelTests",
      dependencies: ["Kernel", "ParameterAddress"],
      cxxSettings: [.unsafeFlags(["-fmodules", "-fcxx-modules"], .none)],
      linkerSettings: [.linkedFramework("AVFoundation")]
    ),
    .testTarget(
      name: "ParameterAddressTests",
      dependencies: ["ParameterAddress"]
    ),
    .testTarget(
      name: "ParametersTests",
      dependencies: ["Parameters"]
    ),
  ],
  cxxLanguageStandard: .cxx20
)
