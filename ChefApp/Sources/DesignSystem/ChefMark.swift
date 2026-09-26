import SwiftUI

// Marca do Chef (chapéu, pregas, faixa da base e folha) como `Shape`s
// separadas, pra tela de loading animar a folha e a faixa sozinhas e
// recolorir tudo por tema via `Color.chefPrimary`.
//
// A geometria não é desenhada à mão: é o contorno de cada traço da arte
// definitiva do designer (`AppIcon.appiconset/icon-dark-1024.png`, onde o
// traço é todo numa cor só e sem relevo), vetorizado automaticamente
// (contorno com precisão de subpixel, suavizado e simplificado com
// tolerância de 0,8px). O resultado cobre ~97,6% dos pixels da arte original.
// Cada traço tem espessura variável (mais fino nas pontas, igual à arte),
// por isso são polígonos preenchidos, não linhas com `stroke`.
//
// As coordenadas estão no próprio espaço 1024×1024 do ícone: desenhar num
// frame do tamanho do container reproduz a composição do ícone real. Se a
// arte do ícone mudar de novo, os pontos precisam ser gerados de novo a
// partir do PNG novo, não ajustados na mão.

/// Contorno do chapéu (coroa de 3 gomos, laterais e base curva). Só o
/// traço: o miolo fica vazado e mostra o fundo do container, igual ao ícone.
struct ChefHatShape: Shape {
    func path(in rect: CGRect) -> Path {
        ChefMarkGeometry.path(ChefMarkGeometry.hat, in: rect)
    }
}

/// As 3 pregas verticais dentro do chapéu. Separadas do contorno porque
/// mudam de cor por tema: no ícone claro são relevo quase branco, no escuro
/// são Volt Green como o resto.
struct ChefPleatsShape: Shape {
    func path(in rect: CGRect) -> Path {
        ChefMarkGeometry.path(ChefMarkGeometry.pleats, in: rect)
    }
}

/// A faixa curva perto da base do chapéu.
struct ChefStripeShape: Shape {
    func path(in rect: CGRect) -> Path {
        ChefMarkGeometry.path(ChefMarkGeometry.stripe, in: rect)
    }
}

/// A folha (contorno, nervura e cabo, num traço só).
struct ChefLeafShape: Shape {
    /// Ponta de baixo do cabo da folha, no mesmo espaço unitário do frame.
    /// Pivô natural pra inclinar a folha sem descolar ela do lugar.
    static let stemAnchor = UnitPoint(x: 0.660, y: 0.894)

    func path(in rect: CGRect) -> Path {
        ChefMarkGeometry.path(ChefMarkGeometry.leaf, in: rect)
    }
}

private enum ChefMarkGeometry {
    static let artboardSide: CGFloat = 1024

    /// Cada polígono é uma lista plana `x, y, x, y, ...` em pixels do ícone
    /// de 1024. Lista plana de `CGFloat` (e não de `CGPoint` ou tupla) de
    /// propósito: literal grande de tipo simples compila rápido, literal
    /// grande de struct/tupla pode travar o type checker.
    static func path(_ polygons: [[CGFloat]], in rect: CGRect) -> Path {
        let scaleX = rect.width / artboardSide
        let scaleY = rect.height / artboardSide
        var path = Path()
        for flat in polygons {
            let points = stride(from: 0, to: flat.count - 1, by: 2).map { i in
                CGPoint(x: rect.minX + flat[i] * scaleX, y: rect.minY + flat[i + 1] * scaleY)
            }
            path.addLines(points)
            path.closeSubpath()
        }
        return path
    }

    /// Contorno do chapéu (coroa de 3 gomos + laterais + base curva), traço aberto.
    static let hat: [[CGFloat]] = [
        [
            510.6, 897.0, 480.0, 897.6, 453.0, 896.3, 426.1, 893.3, 395.1, 887.4, 368.6, 879.9,
            349.8, 872.7, 331.7, 862.8, 321.3, 853.2, 317.1, 845.4, 314.7, 835.0, 312.4, 743.0,
            306.3, 675.1, 296.7, 619.9, 281.8, 565.7, 278.5, 558.0, 254.6, 547.8, 231.1, 532.4,
            216.1, 518.4, 203.4, 503.1, 191.4, 483.2, 184.3, 466.3, 178.8, 445.8, 176.5, 426.0,
            176.7, 405.0, 178.7, 391.0, 182.3, 375.7, 187.0, 362.5, 194.2, 347.7, 203.1, 333.7,
            213.0, 321.5, 224.6, 310.1, 238.0, 299.5, 251.0, 291.5, 277.6, 280.1, 305.0, 274.6,
            339.6, 274.2, 348.2, 245.6, 360.3, 220.7, 373.6, 202.1, 395.0, 180.5, 414.8, 166.3,
            439.6, 154.2, 465.3, 146.8, 493.0, 143.7, 514.7, 144.9, 544.3, 151.3, 571.5, 162.9,
            593.8, 177.7, 614.9, 197.7, 631.5, 220.0, 643.8, 244.6, 652.5, 274.2, 687.0, 274.7,
            713.4, 280.1, 740.0, 291.5, 765.3, 309.1, 785.7, 330.8, 794.6, 343.9, 801.9, 357.6,
            807.6, 371.8, 811.5, 386.0, 814.3, 410.0, 813.3, 436.0, 809.8, 454.3, 801.8, 477.4,
            791.3, 496.8, 776.1, 516.6, 757.4, 533.9, 734.3, 548.8, 712.0, 558.6, 703.2, 582.7,
            693.6, 616.1, 679.7, 630.1, 661.2, 651.8, 666.0, 624.4, 673.3, 594.7, 681.3, 567.7,
            692.2, 539.7, 697.9, 534.4, 721.1, 524.6, 743.0, 510.5, 761.4, 491.9, 775.7, 469.3,
            782.8, 451.4, 786.3, 436.0, 787.7, 416.0, 785.6, 395.9, 777.6, 370.9, 766.3, 351.2,
            759.3, 342.1, 747.9, 330.7, 732.2, 319.3, 711.3, 309.2, 691.0, 303.8, 669.0, 302.2,
            642.0, 304.3, 636.4, 303.1, 632.0, 300.4, 627.1, 292.4, 623.7, 271.9, 619.7, 258.7,
            608.8, 235.6, 593.5, 215.0, 582.9, 204.7, 569.8, 194.7, 557.3, 187.3, 541.3, 180.3,
            525.8, 175.8, 505.9, 172.9, 490.0, 172.6, 472.1, 174.6, 457.5, 178.1, 440.8, 184.3,
            424.0, 193.5, 410.2, 203.8, 397.6, 216.1, 388.7, 227.2, 379.2, 242.7, 373.3, 255.7,
            368.0, 273.0, 364.8, 293.3, 359.0, 301.5, 350.0, 304.4, 321.4, 302.0, 307.0, 302.7,
            291.1, 305.5, 276.7, 310.3, 259.9, 318.4, 244.1, 329.6, 230.6, 343.1, 221.3, 355.7,
            210.3, 377.7, 204.7, 398.0, 203.0, 421.3, 206.8, 448.7, 212.3, 464.2, 218.3, 476.2,
            227.5, 490.0, 237.3, 501.2, 246.1, 509.4, 262.6, 520.9, 275.8, 527.6, 295.2, 535.3,
            299.7, 539.8, 302.7, 546.7, 317.6, 596.9, 324.3, 628.1, 330.2, 665.1, 334.3, 702.0,
            337.2, 744.0, 338.6, 829.0, 340.0, 834.5, 342.6, 838.9, 349.1, 844.4, 356.7, 848.7,
            383.7, 858.8, 421.2, 867.2, 457.0, 871.4, 493.0, 872.8, 525.0, 872.3, 573.9, 868.2,
            636.2, 858.8, 638.4, 859.1, 640.0, 861.2, 637.0, 865.5, 623.1, 872.6, 588.5, 885.0,
            549.8, 893.2,
        ],
    ]

    /// As 3 pregas verticais dentro do chapéu, da esquerda pra direita.
    static let pleats: [[CGFloat]] = [
        [
            405.7, 705.2, 401.4, 705.1, 399.9, 702.7, 397.3, 664.0, 391.2, 608.2, 384.3, 565.1,
            369.8, 496.7, 370.2, 493.7, 372.1, 492.7, 375.2, 495.4, 383.9, 515.6, 397.8, 556.7,
            408.2, 597.3, 418.4, 650.0, 424.4, 698.8, 421.3, 701.8,
        ],
        [
            504.7, 695.2, 485.0, 695.5, 482.8, 694.8, 481.7, 692.0, 488.9, 536.1, 492.3, 488.0,
            493.2, 484.7, 495.0, 483.9, 497.5, 486.1, 498.3, 493.0, 503.2, 585.0, 506.7, 690.0,
            506.2, 693.7,
        ],
        [
            584.8, 705.3, 566.4, 702.1, 562.9, 698.7, 569.8, 653.2, 580.1, 605.6, 596.2, 550.7,
            611.3, 511.8, 619.4, 494.9, 622.7, 492.9, 624.4, 494.3, 624.5, 497.0, 610.9, 549.4,
            599.7, 604.2, 590.8, 663.2, 587.3, 701.9,
        ],
    ]

    /// A faixa curva da base, o elemento que "brilha" na ativação.
    static let stripe: [[CGFloat]] = [
        [
            615.8, 802.2, 581.4, 792.1, 556.0, 786.6, 527.0, 782.7, 492.0, 781.1, 457.0, 782.6,
            433.1, 785.7, 402.2, 791.8, 365.3, 802.2, 362.0, 800.4, 360.8, 797.8, 360.6, 782.0,
            362.6, 776.1, 368.5, 772.0, 393.6, 764.1, 423.1, 757.7, 473.0, 752.4, 499.0, 752.2,
            526.0, 753.6, 552.8, 756.8, 577.9, 761.6, 615.3, 773.2, 619.4, 777.2, 620.4, 782.0,
            620.2, 797.7, 618.4, 801.0,
        ],
    ]

    /// Folha (contorno + nervura + cabo), o elemento que inclina na ativação.
    static let leaf: [[CGFloat]] = [
        [
            676.9, 917.1, 673.7, 915.9, 671.9, 912.7, 672.3, 884.0, 676.6, 849.1, 684.2, 816.7,
            695.1, 786.6, 708.4, 760.9, 722.6, 740.1, 737.1, 723.6, 752.3, 710.8, 766.9, 701.4,
            786.7, 693.2, 791.8, 692.1, 793.8, 693.6, 792.6, 697.1, 770.1, 716.7, 754.6, 733.1,
            738.8, 753.3, 727.4, 770.9, 716.3, 791.7, 707.0, 813.5, 699.7, 837.2, 695.2, 859.8,
            709.8, 846.2, 725.8, 835.3, 777.6, 811.2, 800.0, 797.5, 813.9, 786.4, 823.3, 776.8,
            832.4, 765.9, 843.7, 749.2, 857.9, 718.4, 866.3, 685.8, 870.3, 644.0, 871.2, 580.6,
            839.4, 595.8, 777.6, 616.1, 753.4, 626.8, 738.8, 635.3, 722.7, 647.2, 710.3, 658.8,
            699.6, 671.1, 687.7, 688.2, 680.3, 701.7, 673.2, 718.6, 667.4, 738.0, 663.9, 760.3,
            663.4, 778.0, 665.7, 798.9, 669.4, 814.9, 662.0, 842.5, 660.4, 844.0, 652.3, 827.3,
            646.0, 806.6, 642.7, 784.0, 642.6, 765.0, 644.7, 745.1, 649.9, 722.5, 659.1, 697.6,
            667.6, 680.8, 680.5, 661.0, 698.0, 640.6, 716.1, 624.6, 736.9, 610.4, 766.5, 596.0,
            838.4, 571.8, 861.1, 560.6, 882.0, 548.5, 885.7, 547.9, 888.6, 548.9, 891.3, 552.3,
            892.0, 558.0, 892.2, 634.0, 890.2, 671.9, 886.3, 696.8, 880.7, 718.2, 872.8, 739.4,
            861.7, 761.3, 841.4, 789.9, 830.3, 801.9, 812.9, 816.4, 799.2, 825.7, 782.4, 834.8,
            730.8, 857.3, 711.2, 870.7, 696.6, 886.1, 688.3, 898.8, 680.9, 914.4,
        ],
    ]
}
