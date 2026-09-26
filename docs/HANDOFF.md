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

## Tarefa pendente: o ícone dentro da splash ainda é o design antigo

Confirmado pelo usuário: a animação em si está funcionando bem, mas o ícone desenhado dentro do container (chapéu, faixa da base e folha) ainda usa o design antigo, não o design novo do chapéu que já está valendo no ícone real do app.

### Onde está o problema

- O ícone real do app (o que aparece na tela inicial do iPhone) já foi atualizado com a arte definitiva do designer: `ChefApp/Resources/Assets.xcassets/AppIcon.appiconset/icon-light-1024.png` e `icon-dark-1024.png` (já commitados no repositório). Esse design tem o contorno inteiro do chapéu em laranja/Volt Green, não só um contorno sutil como a versão antiga.
- A splash, porém, desenha o ícone através de três `Shape` procedurais (paths desenhados à mão em coordenadas Bézier), definidos em `ChefApp/Sources/DesignSystem/ChefMark.swift`: `ChefHatShape`, `ChefStripeShape`, `ChefLeafShape`. Esses paths são uma aproximação vetorial antiga, criada antes de existirem as imagens de referência definitivas do designer, e não batem com a geometria do ícone atual.
- `ChefLoadingView.swift` usa essas mesmas três `Shape` na propriedade computada `iconContent`. Por isso, o ícone animado dentro da splash continua parecendo o design antigo mesmo depois do ícone real do app já ter sido corrigido.

### Por que não é um ajuste trivial

A splash precisa que o ícone seja separável em pelo menos duas partes que animam de forma independente:

1. A folha, que inclina (variável `leafRotation`) durante a etapa de ativação.
2. A faixa da base, que "brilha" (variável `stripeGlow`, uma sombra que pulsa) na mesma etapa.

Além disso, o ícone precisa recolorir sozinho entre os temas claro e escuro (laranja `#FF7A00` / Volt Green `#CCFF00`), sem precisar de duas imagens coladas manualmente.

Isso é simples com `Shape` vetorial (preenche com `Color.chefPrimary`, que já é dinâmica por tema), mas fica difícil com uma imagem raster estática (PNG), porque:

- Uma imagem PNG não anima "só a folha" a menos que a folha seja um arquivo separado, isolado do resto do desenho.
- Recolorir uma imagem PNG exige duas versões prontas (uma clara, uma escura) ou usar `.renderingMode(.template)` com uma máscara monocromática, o que só funciona se a arte for uma silhueta sólida, sem gradiente nem sombra interna.

### Opções pra resolver (decidir com o Gabriel antes de implementar)

1. Retraçar os paths de `ChefHatShape`, `ChefStripeShape` e `ChefLeafShape` em `ChefMark.swift` pra bater com a geometria do ícone novo. Mantém toda a flexibilidade de animação e recoloração por tema, mas exige trabalho manual de precisão pra copiar a arte do designer em coordenadas Bézier.
2. Pedir pro designer exportar o novo desenho em camadas separadas (chapéu, faixa, folha), cada uma como uma máscara monocromática com fundo transparente, e usar `Image(...).renderingMode(.template).foregroundStyle(Color.chefPrimary)` no lugar de `Shape`. Mantém a animação por partes, mas depende de assets em camadas preparados assim (a arte atual, de origem, não veio separada).
3. Simplificar a splash pra não depender de sub-partes animadas: usar a imagem raster inteira (`icon-light-1024` / `icon-dark-1024`) como um bloco único, e trocar a animação da folha/faixa por algo que anime o ícone inteiro (por exemplo, leve escala ou sombra pulsando). Perde a nuance da folha/faixa animando sozinhas, mas ganha fidelidade visual imediata sem trabalho de retraçado.

Recomendação: a opção 1 é provavelmente a melhor a longo prazo (preserva tudo que já funciona), mas exige mais cuidado na precisão visual do retraçado. Vale confirmar com o Gabriel qual caminho ele prefere antes de começar a implementação.

### Arquivos envolvidos

- `ChefApp/Sources/DesignSystem/ChefMark.swift`: as formas vetoriais antigas que precisam ser atualizadas ou substituídas.
- `ChefApp/Sources/App/ChefLoadingView.swift`: usa essas formas na splash, na propriedade `iconContent`.
- `ChefApp/Resources/Assets.xcassets/AppIcon.appiconset/icon-light-1024.png` e `icon-dark-1024.png`: a arte definitiva já usada no ícone real do app, serve de referência visual pra qualquer uma das opções acima.

## Outras notas úteis pra continuar

- A busca online de alimentos (Open Food Facts) é sabidamente instável: o serviço devolve erro 503 de forma intermitente sob carga, confirmado por fora do app (direto por `curl`, sem relação com o Chef). `ChefApp/Sources/Features/Diet/OpenFoodFactsService.swift` já tenta de novo até 5 vezes antes de mostrar erro pro usuário. Se o problema voltar a aparecer, esse é o primeiro lugar pra olhar, mas é bom lembrar que é uma limitação do serviço externo, não um bug do app.
- O número de build (`CURRENT_PROJECT_VERSION` em `project.yml`) deve ser incrementado a cada release nova. O iOS guarda o ícone do app em cache no SpringBoard, e reinstalar por cima do mesmo número de build às vezes não invalida esse cache, mesmo com o ícone já correto no bundle (isso já aconteceu: o ícone da notificação continuou mostrando a versão antiga até o build number mudar).
- Ao instalar uma build nova especificamente por causa de mudança de ícone, apagar o app do iPhone antes de reinstalar (não só instalar por cima) evita esse mesmo problema de cache com mais segurança.
