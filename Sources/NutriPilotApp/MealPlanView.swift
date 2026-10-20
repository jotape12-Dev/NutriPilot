import SwiftUI
import NutriPilotCore

public struct MealPlanView: View {
    public var targetCalories: Double
    @State private var showingShoppingList = false

    public init(targetCalories: Double = 2500) {
        self.targetCalories = targetCalories
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("Plano de Hoje (\(Int(targetCalories)) kcal)") {
                    mealRow(title: "Café da Manhã", items: "3 ovos mexidos, 2 fatias de pão integral, café preto", cals: 420, protein: 28)
                    mealRow(title: "Almoço", items: "200g peito de frango, 150g arroz branco, feijão e salada", cals: 680, protein: 55)
                    mealRow(title: "Lanche da Tarde", items: "1 dose Whey protein, 1 banana, 30g pasta de amendoim", cals: 390, protein: 32)
                    mealRow(title: "Jantar", items: "180g patinho moído, 200g batata inglesa, azeite", cals: 580, protein: 45)
                }

                Section("Ações") {
                    Button {
                        showingShoppingList = true
                    } label: {
                        Label("Gerar Lista de Compras", systemImage: "cart.fill")
                    }

                    Button {
                        // Regenerar opções do plano
                    } label: {
                        Label("Regenerar Opções do Plano", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .navigationTitle("Plano Alimentar")
            .sheet(isPresented: $showingShoppingList) {
                ShoppingListView()
            }
        }
    }

    private func mealRow(title: String, items: String, cals: Int, protein: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(cals) kcal")
                    .font(.subheadline.bold())
                    .foregroundColor(.orange)
            }
            Text(items)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Proteína: \(protein)g")
                .font(.caption2.bold())
                .foregroundColor(.blue)
        }
        .padding(.vertical, 4)
    }
}

public struct ShoppingListView: View {
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            List {
                Section("Proteínas") {
                    Label("Peito de Frango (1.5 kg)", systemImage: "circle")
                    Label("Ovos (30 unidades)", systemImage: "circle")
                    Label("Patinho Moído (1 kg)", systemImage: "circle")
                    Label("Whey Protein Concentrado", systemImage: "circle")
                }
                Section("Carboidratos") {
                    Label("Arroz Branco (1 kg)", systemImage: "circle")
                    Label("Pão Integral (1 pacote)", systemImage: "circle")
                    Label("Batata Inglesa (2 kg)", systemImage: "circle")
                    Label("Bananas (1 dúzia)", systemImage: "circle")
                }
            }
            .navigationTitle("Lista de Compras")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fechar") {
                        dismiss()
                    }
                }
            }
        }
    }
}
