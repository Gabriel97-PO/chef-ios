import SwiftUI
import UIKit

/// Botão "Concluído" nativo acima do teclado, em toda tela com campo de
/// texto. Sem isso o teclado numérico (`.decimalPad`/`.numberPad`, usado
/// em quase todo campo do app) não tem tecla de retorno nenhuma — só some
/// se o usuário souber tocar fora do campo, o que não é óbvio.
///
/// Usa `resignFirstResponder` via `sendAction` em vez de `@FocusState`
/// porque precisa fechar o teclado não importa qual campo da tela está
/// focado no momento, sem ter que dar nome e amarrar um `FocusState` a
/// cada `TextField`/`TextEditor` do app.
extension View {
    func chefKeyboardDismissToolbar() -> some View {
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Concluído") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
            }
        }
    }
}
