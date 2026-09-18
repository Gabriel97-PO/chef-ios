import SwiftUI

/// Silhueta do chapéu de chef (corpo único, sem bloco separado embaixo,
/// coroa de 4 pontas) — mesma geometria do ícone do app (ver
/// `make_icon6.py` no histórico de commits), portada aqui como `Shape` de
/// verdade pra poder animar a folha e a faixa separadamente na tela de
/// loading. O contorno (stroke sutil contra o fundo quase da mesma cor) é
/// o que faz o chapéu ler como chapéu sem precisar de preenchimento na cor
/// de marca — só a faixa e a folha carregam o acento, nunca o chapéu.
struct ChefHatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        func box(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> CGRect {
            CGRect(
                x: rect.minX + x0 * rect.width,
                y: rect.minY + y0 * rect.height,
                width: (x1 - x0) * rect.width,
                height: (y1 - y0) * rect.height
            )
        }

        path.addRoundedRect(in: box(0.2379, 0.516, 0.7621, 0.892), cornerSize: CGSize(width: rect.width * 0.137, height: rect.width * 0.137))
        path.addEllipse(in: box(0.2607, 0.2196, 0.7393, 0.6185))

        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (0.2778, 0.3564, 0.1094),
            (0.4134, 0.206, 0.1185),
            (0.5866, 0.206, 0.1185),
            (0.7222, 0.3564, 0.1094),
        ]
        for (cx, cy, r) in puffs {
            let center = CGPoint(x: rect.minX + cx * rect.width, y: rect.minY + cy * rect.height)
            let radius = r * rect.width
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }
}

/// A faixa fina de acento perto da base do chapéu — nunca um bloco, só uma
/// linha, igual ao fluxo de marca.
struct ChefStripeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let box = CGRect(
            x: rect.minX + 0.2493 * rect.width,
            y: rect.minY + 0.6869 * rect.height,
            width: (0.7507 - 0.2493) * rect.width,
            height: (0.7165 - 0.6869) * rect.height
        )
        var path = Path()
        path.addRoundedRect(in: box, cornerSize: CGSize(width: box.height / 2, height: box.height / 2))
        return path
    }
}

struct ChefLeafShape: Shape {
    private static let localPoints: [CGPoint] = [
        CGPoint(x: 0, y: -0.1051), CGPoint(x: 0.0210, y: -0.0904), CGPoint(x: 0.0389, y: -0.0630),
        CGPoint(x: 0.0515, y: -0.0273), CGPoint(x: 0.0546, y: 0.0126), CGPoint(x: 0.0452, y: 0.0483),
        CGPoint(x: 0.0252, y: 0.0757), CGPoint(x: 0, y: 0.0925), CGPoint(x: -0.0252, y: 0.0757),
        CGPoint(x: -0.0452, y: 0.0483), CGPoint(x: -0.0546, y: 0.0126), CGPoint(x: -0.0515, y: -0.0273),
        CGPoint(x: -0.0389, y: -0.0630), CGPoint(x: -0.0210, y: -0.0904),
    ]

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.minX + 0.7439 * rect.width, y: rect.minY + 0.8237 * rect.height)
        // `cos`/`sin` direto em CGFloat é ambíguo (Darwin vs CoreGraphics
        // disputam o overload) — calcula em Double, sem ambiguidade, e só
        // converte pra CGFloat no resultado.
        let angleRadians = 30.0 * Double.pi / 180
        let cosA = CGFloat(cos(angleRadians))
        let sinA = CGFloat(sin(angleRadians))
        // Fator ~1.2 sobre a largura pra bater com a escala usada na
        // geração do ícone (leaf_scale_frac ≈ 0.0012 × 1024 ≈ 1.2×largura).
        let leafScale: CGFloat = 1.2

        let points = Self.localPoints.map { local -> CGPoint in
            let x = local.x * rect.width * leafScale
            let y = local.y * rect.width * leafScale
            let rx = x * cosA - y * sinA
            let ry = x * sinA + y * cosA
            return CGPoint(x: center.x + rx, y: center.y + ry)
        }

        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}
