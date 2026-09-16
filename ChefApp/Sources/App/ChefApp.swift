import SwiftUI
import SwiftData

@main
struct ChefApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: SDUserProfile.self, SDFood.self, SDMealEntry.self, SDWeightEntry.self, SDRecipe.self)
        } catch {
            fatalError("Não foi possível criar o ModelContainer do SwiftData: \(error)")
        }
        SeedDataService.seedIfNeeded(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
