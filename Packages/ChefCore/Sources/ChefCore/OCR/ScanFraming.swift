import CoreGraphics

/// Mapeia a moldura de enquadramento (desenhada na tela, em pontos) pro
/// retângulo correspondente em pixels da foto capturada — a padronização
/// da leitura da tabela nutricional (roadmap: "crie uma moldura... e
/// padronize a leitura") vem de sempre recortar a mesma região relativa
/// antes de mandar pro OCR, em vez de ler a foto inteira (que pode ter
/// texto de fundo, outras embalagens etc. confundindo o parser).
///
/// Puro `CoreGraphics`/`CGFloat`, sem UIKit/AVFoundation — dá pra testar a
/// matemática com `swift test` sem precisar de câmera nenhuma (nem
/// simulador nem CI têm câmera física).
public enum ScanFraming {
    /// Assume que o preview usa `.resizeAspectFill` (a câmera preenche a
    /// view inteira, cortando o excesso nas bordas, sempre centralizado) —
    /// mesmo comportamento configurado em `CameraPreviewView`.
    public static func imageRect(forViewRect viewRect: CGRect, viewSize: CGSize, imageSize: CGSize) -> CGRect {
        guard viewSize.width > 0, viewSize.height > 0, imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: imageSize)
        }

        let scale = max(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledImageSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let cropOriginX = (scaledImageSize.width - viewSize.width) / 2
        let cropOriginY = (scaledImageSize.height - viewSize.height) / 2

        let rect = CGRect(
            x: (viewRect.minX + cropOriginX) / scale,
            y: (viewRect.minY + cropOriginY) / scale,
            width: viewRect.width / scale,
            height: viewRect.height / scale
        )
        return rect.intersection(CGRect(origin: .zero, size: imageSize))
    }

    /// Retângulo padrão da moldura de enquadramento: um retângulo portrait
    /// (proporção comum de tabela nutricional), centralizado, ocupando a
    /// maior parte da largura da tela.
    public static func defaultGuideRect(in viewSize: CGSize) -> CGRect {
        let width = viewSize.width * 0.82
        let height = width / 0.72
        return CGRect(
            x: (viewSize.width - width) / 2,
            y: (viewSize.height - height) / 2,
            width: width,
            height: height
        )
    }
}
