// swift-tools-version: 5.10
import PackageDescription

/// ChefCore: camada de domínio e lógica de aplicação do Chef — modelos,
/// motor nutricional e Chef Nutrition Protocol (CNP). Não depende de
/// SwiftUI/UIKit/SwiftData de propósito: é a mesma camada que a seção 5 do
/// plano de migração chama de "Domain Logic", isolada da apresentação e da
/// persistência para poder ser testada sozinha (`swift test`, sem Xcode) e
/// depois importada tanto pelo app iOS quanto por testes.
let package = Package(
    name: "ChefCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "ChefCore", targets: ["ChefCore"])
    ],
    targets: [
        .target(name: "ChefCore"),
        .testTarget(name: "ChefCoreTests", dependencies: ["ChefCore"]),
    ]
)
