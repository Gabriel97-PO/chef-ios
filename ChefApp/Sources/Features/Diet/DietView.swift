import SwiftUI
import SwiftData
import ChefCore

private enum DietTab: String, CaseIterable {
    case meta = "Meta"
    case fixas = "Fixas"
    case receitas = "Receitas"
    case compras = "Compras"
}

/// Metas, refeições fixas e receitas (Fase 4 do plano de migração).
struct DietView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [SDUserProfile]
    @Query(sort: \SDFixedMeal.name) private var fixedMeals: [SDFixedMeal]
    @Query(sort: \SDRecipe.name) private var recipes: [SDRecipe]
    @Query(sort: \SDFood.name) private var foods: [SDFood]
    @Query(sort: \SDDietVersion.importedAt, order: .reverse) private var dietVersions: [SDDietVersion]
    @Query(sort: \SDWeightEntry.date) private var weights: [SDWeightEntry]

    @State private var tab: DietTab = .meta
    @State private var showImport = false

    private var activeDiet: SDDietVersion? { dietVersions.first { $0.active } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        ChefHeader(title: "Dieta")
                        Button {
                            showImport = true
                        } label: {
                            Label("Importar", systemImage: "square.and.arrow.down")
                                .font(.subheadline.weight(.semibold))
                        }
                    }

                    if let activeDiet {
                        Label("Dieta ativa: **\(activeDiet.label)** · importada em \(activeDiet.importedAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "doc.text.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Picker("Aba", selection: $tab) {
                        ForEach(DietTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch tab {
                    case .meta:
                        if let profile = profiles.first {
                            GoalCalculatorCard(
                                profile: profile,
                                currentWeightKg: weights.last?.weightKg,
                                hasActiveDiet: activeDiet != nil
                            )
                            GoalForm(profile: profile)
                        }
                    case .fixas:
                        FixedMealsTab(fixedMeals: fixedMeals, foods: foods)
                    case .receitas:
                        RecipesTab(recipes: recipes, foods: foods)
                    case .compras:
                        ShoppingListView(fixedMeals: fixedMeals, recipes: recipes)
                    }
                }
                .padding()
                .padding(.bottom, 90)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .chefKeyboardDismissToolbar()
            .sheet(isPresented: $showImport) {
                DietImportView()
            }
        }
    }
}

private struct GoalForm: View {
    @Bindable var profile: SDUserProfile
    @Environment(\.modelContext) private var context
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Minhas metas", systemImage: "target")
                .font(.title3.weight(.bold))
            HStack(spacing: 12) {
                NumberField(label: "Meta diária (kcal)", value: $profile.goal.calories, highlight: true)
                NumberField(label: "Proteína (g)", value: $profile.goal.protein, highlight: true)
            }
            Text("OPCIONAIS")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                NumberField(label: "Carboidratos (g)", value: optionalBinding(\.carbs))
                NumberField(label: "Gorduras (g)", value: optionalBinding(\.fat))
            }
            HStack(spacing: 12) {
                NumberField(label: "Fibras (g)", value: optionalBinding(\.fiber))
                NumberField(label: "Água (ml)", value: optionalBinding(\.water))
            }

            Button {
                try? context.save()
                Haptics.success()
                saved = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    saved = false
                }
            } label: {
                Text(saved ? "✓ Meta salva" : "Salvar meta")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .tint(.chefPrimary)
        }
        .chefGlassCard()
    }

    private func optionalBinding(_ keyPath: WritableKeyPath<DailyGoal, Double?>) -> Binding<Double> {
        Binding(
            get: { profile.goal[keyPath: keyPath] ?? 0 },
            set: { profile.goal[keyPath: keyPath] = $0 }
        )
    }
}

private struct NumberField: View {
    let label: String
    @Binding var value: Double
    var highlight = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(label, value: $value, format: .number)
                .keyboardType(.decimalPad)
                .font(.headline)
                .foregroundStyle(highlight ? Color.chefPrimary : Color.primary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(highlight ? Color.chefPrimary.opacity(0.08) : Color.gray.opacity(0.08), in: .rect(cornerRadius: 12))
    }
}

private struct FixedMealsTab: View {
    let fixedMeals: [SDFixedMeal]
    let foods: [SDFood]

    @Environment(\.modelContext) private var context
    @State private var creating = false
    @State private var name = ""
    @State private var ingredients: [RecipeIngredient] = []
    @State private var addTarget: SDFixedMeal?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(fixedMeals) { meal in
                let totals = NutritionEngine.sumNutrition(meal.items.map(\.nutrition))
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(meal.name).font(.headline)
                        Spacer()
                        Button { FixedMealStore.remove(meal, in: context) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                    Text(meal.items.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("~\(Int(totals.calories)) kcal · ~\(totals.protein.formatted(.number.precision(.fractionLength(1))))g proteína")
                        .font(.caption.weight(.semibold))

                    // Horário ao qual essa refeição pertence — é o que faz
                    // ela aparecer na aba Hoje (roadmap item 5). O nome da
                    // dieta importada costuma dizer isso ("ALMOÇO"), mas
                    // quando não diz, dá pra escolher aqui.
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Picker("Horário", selection: Binding(
                            get: { meal.slot },
                            set: { meal.slot = $0; try? context.save() }
                        )) {
                            Text("Sem horário").tag(MealSlot?.none)
                            ForEach(MealSlot.allCases) { slot in
                                Text(slot.label).tag(MealSlot?.some(slot))
                            }
                        }
                        .pickerStyle(.menu)
                        .font(.caption)
                    }

                    Button("Adicionar ao dia") { addToDay(meal) }
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.chefPrimary, in: .rect(cornerRadius: 10))
                        .foregroundStyle(Color.chefOnPrimary)
                }
                .chefGlassCard(cornerRadius: 16, padding: 14)
            }

            if creating {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Ex: Meu almoço", text: $name)
                        .padding(10)
                        .background(.thinMaterial, in: .rect(cornerRadius: 10))
                    IngredientPicker(ingredients: $ingredients, foods: foods)
                    HStack {
                        Button("Cancelar") { creating = false; name = ""; ingredients = [] }
                        Spacer()
                        Button("Salvar") {
                            FixedMealStore.create(name: name, items: ingredients.map { FoodEntry(foodId: $0.foodId, name: $0.name, quantity: $0.quantity, unit: $0.unit, nutrition: $0.nutrition) }, in: context)
                            creating = false
                            name = ""
                            ingredients = []
                        }
                        .disabled(name.isEmpty || ingredients.isEmpty)
                    }
                }
                .chefGlassCard(cornerRadius: 16, padding: 14)
            } else {
                Button("+ Nova refeição fixa") { creating = true }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .contentShape(Rectangle())
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5])))
            }
        }
        .confirmationDialog("Adicionar em qual refeição?", isPresented: Binding(get: { addTarget != nil }, set: { if !$0 { addTarget = nil } }), titleVisibility: .visible) {
            ForEach(MealSlot.allCases) { slot in
                Button(slot.label) {
                    if let meal = addTarget {
                        MealStore.addItems(meal.items, date: DateKey.today(), slot: slot, in: context)
                    }
                    addTarget = nil
                }
            }
        }
    }

    private func addToDay(_ meal: SDFixedMeal) {
        addTarget = meal
    }
}

private struct RecipesTab: View {
    let recipes: [SDRecipe]
    let foods: [SDFood]

    @Environment(\.modelContext) private var context
    @State private var creating = false
    @State private var name = ""
    @State private var servings = 2
    @State private var ingredients: [RecipeIngredient] = []
    @State private var addTarget: SDRecipe?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(recipes) { recipe in
                let perServing = NutritionEngine.calculateRecipePerServing(recipe.asRecipe)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(recipe.name).font(.headline)
                        Spacer()
                        Button { RecipeStore.remove(recipe, in: context) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                    Text("\(recipe.ingredients.map(\.name).joined(separator: ", ")) · rende \(recipe.servings) porç\(recipe.servings == 1 ? "ão" : "ões")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Por porção: \(Int(perServing.calories)) kcal · \(perServing.protein.formatted(.number.precision(.fractionLength(1))))g proteína")
                        .font(.caption.weight(.semibold))
                    Button("Adicionar ao dia") { addTarget = recipe }
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.chefPrimary, in: .rect(cornerRadius: 10))
                        .foregroundStyle(Color.chefOnPrimary)
                }
                .chefGlassCard(cornerRadius: 16, padding: 14)
            }

            if creating {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Nome da receita", text: $name)
                        .padding(10)
                        .background(.thinMaterial, in: .rect(cornerRadius: 10))
                    Stepper("Rende \(servings) porções", value: $servings, in: 1...12)
                    IngredientPicker(ingredients: $ingredients, foods: foods)
                    HStack {
                        Button("Cancelar") { creating = false; name = ""; ingredients = [] }
                        Spacer()
                        Button("Salvar") {
                            RecipeStore.create(name: name, ingredients: ingredients, servings: servings, in: context)
                            creating = false
                            name = ""
                            ingredients = []
                            servings = 2
                        }
                        .disabled(name.isEmpty || ingredients.isEmpty)
                    }
                }
                .chefGlassCard(cornerRadius: 16, padding: 14)
            } else {
                Button("+ Nova receita") { creating = true }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .contentShape(Rectangle())
                    .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5])))
            }
        }
        .confirmationDialog("Adicionar em qual refeição?", isPresented: Binding(get: { addTarget != nil }, set: { if !$0 { addTarget = nil } }), titleVisibility: .visible) {
            ForEach(MealSlot.allCases) { slot in
                Button(slot.label) {
                    if let recipe = addTarget {
                        let perServing = NutritionEngine.calculateRecipePerServing(recipe.asRecipe)
                        let entry = FoodEntry(name: "\(recipe.name) (1 porção)", quantity: 1, unit: .unidade, nutrition: perServing)
                        MealStore.addItems([entry], date: DateKey.today(), slot: slot, in: context)
                    }
                    addTarget = nil
                }
            }
        }
    }
}

#Preview {
    DietView()
}
