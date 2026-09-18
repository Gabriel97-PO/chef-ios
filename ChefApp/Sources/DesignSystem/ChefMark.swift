import SwiftUI

/// Silhueta do chapéu de chef, redesenhada em vetor a partir do fluxo de
/// marca (chapéu + folha) — mesma geometria usada pra gerar o ícone do app,
/// só que aqui como `Shape` de verdade, pra poder animar a folha e o
/// chapéu separadamente na tela de loading. As referências em PNG que
/// vieram do fluxo de marca têm o xadrez de "transparência" gravado direto
/// nos pixels (alpha 100% opaco na imagem toda), então não dá pra usá-las
/// aqui sem mostrar o quadriculado — só servem pro ícone do app, achatadas
/// sobre um fundo sólido.
private struct ChefHatShape: Shape {
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

        path.addEllipse(in: box(0.2372, 0.2306, 0.7628, 0.7789))
        path.addRoundedRect(in: box(0.2601, 0.7195, 0.7399, 0.8909), cornerSize: CGSize(width: rect.width * 0.04, height: rect.width * 0.04))

        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (0.3721, 0.2968, 0.1006),
            (0.5, 0.2168, 0.1165),
            (0.6279, 0.2968, 0.1006),
        ]
        for (cx, cy, r) in puffs {
            let center = CGPoint(x: rect.minX + cx * rect.width, y: rect.minY + cy * rect.height)
            let radius = r * rect.width
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }
}

private struct ChefLeafShape: Shape {
    private static let localPoints: [CGPoint] = [
        CGPoint(x: 0, y: -0.1051), CGPoint(x: 0.0210, y: -0.0904), CGPoint(x: 0.0389, y: -0.0630),
        CGPoint(x: 0.0515, y: -0.0273), CGPoint(x: 0.0546, y: 0.0126), CGPoint(x: 0.0452, y: 0.0483),
        CGPoint(x: 0.0252, y: 0.0757), CGPoint(x: 0, y: 0.0925), CGPoint(x: -0.0252, y: 0.0757),
        CGPoint(x: -0.0452, y: 0.0483), CGPoint(x: -0.0546, y: 0.0126), CGPoint(x: -0.0515, y: -0.0273),
        CGPoint(x: -0.0389, y: -0.0630), CGPoint(x: -0.0210, y: -0.0904),
    ]

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.minX + 0.756 * rect.width, y: rect.minY + 0.8201 * rect.height)
        let angle = 32.0 * .pi / 180

        let points = Self.localPoints.map { local -> CGPoint in
            let x = local.x * rect.width
            let y = local.y * rect.width
            let rx = x * cos(angle) - y * sin(angle)
            let ry = x * sin(angle) + y * cos(angle)
            return CGPoint(x: center.x + rx, y: center.y + ry)
        }

        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

/// Marca do Chef (chapéu + folha) pronta pra usar em qualquer tela — tela
/// de loading, header, etc.
struct ChefMarkView: View {
    var hatColor: Color
    var accentColor: Color

    var body: some View {
        ZStack {
            ChefHatShape().fill(hatColor)
            ChefLeafShape().fill(accentColor)
        }
    }
}
