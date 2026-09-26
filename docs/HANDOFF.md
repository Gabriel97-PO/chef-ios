# Chef iOS, notas de continuidade

Este documento existe pra qualquer sessão (Claude Code, monocode, ou humano) continuar o trabalho no Chef sem precisar reconstruir todo o contexto do zero. Data desta versão: 26/set/2026.

## Contexto do projeto

- Chef é um app nativo iOS (SwiftUI) de acompanhamento alimentar: metas diárias, escaneamento de tabela nutricional, diário de refeições, lista de compras.
- O Mac usado no desenvolvimento é um MacBook Pro 2017 rodando uma versão de macOS sem suporte oficial (15.5), que não consegue rodar o Xcode localmente. Por isso, todo build, teste e captura de tela acontece via GitHub Actions (runner `macos-15`), um padrão de "CI como compilador".
- Fluxo de trabalho padrão: editar código localmente, commit, push, acompanhar com `gh run watch <id>`, baixar o `.ipa` do artifact do job "Chef app (device .ipa for sideloading)", instalar no iPhone via AltStore/SideStore (sideload, sem conta paga de Apple Developer).
- Repositório: `github.com/Gabriel97-PO/chef-ios`, público de propósito, pra ter minutos ilimitados de GitHub Actions.
- Workflow de CI: `.github/workflows/build.yml`, com três jobs: `ChefCore` (testes unitários do pacote Swift puro), `Chef app (xcodebuild)` (build + testes de UI + screenshots no simulador) e `Chef app (device .ipa for sideloading)` (arquivo `.ipa` pronto pra sideload).
- Arquitetura: `Packages/ChefCore` (lógica de domínio pura, sem SwiftData/UIKit, testável com `swift test` sozinho) e `ChefApp` (SwiftUI + SwiftData + câmera/Vision).
- Regra crítica de SwiftData (aprendida de um crash real em produção): adicionar uma propriedade não opcional a um `@Model` que já tem dados persistidos quebra o app no lançamento, a menos que a propriedade tenha valor padrão já na própria declaração (não só no `init`). Propriedades opcionais são sempre seguras de adicionar. Tipos `@Model` novos também são sempre seguros.

## Estado atual da splash (tela de abertura)

Estilo "morphing container": um único container muda de forma, tamanho e cor em 7 etapas (entrada, ativação, morph pra círculo, progresso, conclusão, retorno, saída), terminando ao expandir cobrindo a tela inteira e revelar a home por baixo com fade.

Arquivos:

- `ChefApp/Sources/App/ChefLoadingView.swift`: a view e a sequência de animação (`runSequence`).
- `ChefApp/Sources/App/ChefLoadingConfig.swift`: todos os parâmetros centralizados (tamanhos, springs, curvas de tempo exatas em cubic-bezier, durações de cada etapa, cores específicas dessa splash).
- `ChefApp/Sources/App/ChefLoadingPreviewView.swift`: tela de preview acessível pelo Perfil ("Pré-visualizar splash"), com toggle de tema, "reduzir movimento" simulado e controle de velocidade (0,25x / 0,5x / 1x). Existe porque não há Xcode local pra usar o canvas de preview do SwiftUI; é a única forma real de testar a animação, direto no aparelho.

A mecânica de animação (morph do container, crossfade com blur entre camadas de conteúdo, springs, curvas de tempo) já foi validada pelo usuário e está funcionando como esperado.

## Ícone dentro da splash (resolvido em 26/set/2026)

O ícone desenhado dentro do container da splash agora usa a mesma arte definitiva do ícone real do app (opção 1 da análise anterior: redesenhar as formas vetoriais).

- `ChefApp/Sources/DesignSystem/ChefMark.swift` tem quatro `Shape`s: `ChefHatShape` (contorno do chapéu), `ChefPleatsShape` (as 3 pregas), `ChefStripeShape` (faixa curva da base) e `ChefLeafShape` (folha com nervura e cabo).
- A geometria não foi desenhada à mão: é o contorno de cada traço de `icon-dark-1024.png`, vetorizado automaticamente (contorno com precisão de subpixel, suavizado, simplificado com tolerância de 0,8px, cobrindo ~97,6% dos pixels da arte). São polígonos preenchidos, não `stroke`, porque a espessura do traço varia ao longo do desenho.
- As coordenadas estão no espaço 1024×1024 do ícone, e o frame do ícone na splash (`iconContentSize`) é igual ao container, então a composição bate com o ícone real.
- Se a arte do ícone mudar de novo, gerar os pontos de novo a partir do PNG novo (mesmo processo: máscara da cor de destaque, componentes conectados, contorno, simplificação), em vez de ajustar na mão.
- As pregas usam uma cor própria por tema (`ChefLoadingConfig.iconPleats`), porque no ícone claro elas são relevo quase branco e no escuro são Volt Green.
- Na ativação, só a folha inclina (pivô na ponta do cabo, `ChefLeafShape.stemAnchor`). Antes a faixa girava junto com a folha. Agora a faixa fica parada e só brilha.
- Pendente: validar no aparelho, pela tela "Pré-visualizar splash", nos dois temas.

## Outras notas úteis pra continuar

- A busca online de alimentos (Open Food Facts) é sabidamente instável: o serviço devolve erro 503 de forma intermitente sob carga, confirmado por fora do app (direto por `curl`, sem relação com o Chef). `ChefApp/Sources/Features/Diet/OpenFoodFactsService.swift` já tenta de novo até 5 vezes antes de mostrar erro pro usuário. Se o problema voltar a aparecer, esse é o primeiro lugar pra olhar, mas é bom lembrar que é uma limitação do serviço externo, não um bug do app.
- O número de build (`CURRENT_PROJECT_VERSION` em `project.yml`) deve ser incrementado a cada release nova. O iOS guarda o ícone do app em cache no SpringBoard, e reinstalar por cima do mesmo número de build às vezes não invalida esse cache, mesmo com o ícone já correto no bundle (isso já aconteceu: o ícone da notificação continuou mostrando a versão antiga até o build number mudar).
- Ao instalar uma build nova especificamente por causa de mudança de ícone, apagar o app do iPhone antes de reinstalar (não só instalar por cima) evita esse mesmo problema de cache com mais segurança.
