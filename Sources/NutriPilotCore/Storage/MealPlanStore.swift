import Foundation
import Observation

/// Gerenciador com persistência local em disco JSON para o plano alimentar ativo e a lista de compras consolidada.
@Observable
public final class MealPlanStore: @unchecked Sendable {
    public static let shared = MealPlanStore()

    public private(set) var activePlan: DailyMealPlan?
    public private(set) var groceryList: GroceryList?

    private let fileManager = FileManager.default
    private let customStorageURL: URL?
    private let lock = NSRecursiveLock()

    public init(storageURL: URL? = nil) {
        self.customStorageURL = storageURL
        loadFromDisk()
    }

    private var storageURL: URL {
        if let custom = customStorageURL {
            return custom
        }
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupportDir = paths[0].appendingPathComponent("NutriPilot", isDirectory: true)

        if !fileManager.fileExists(atPath: appSupportDir.path) {
            try? fileManager.createDirectory(at: appSupportDir, withIntermediateDirectories: true)
        }

        return appSupportDir.appendingPathComponent("nutripilot_meal_plan_v1.json")
    }

    // MARK: - Plano Alimentar

    public func setActivePlan(_ plan: DailyMealPlan) {
        lock.lock()
        defer { lock.unlock() }

        self.activePlan = plan
        // Atualiza a lista de compras automaticamente
        self.groceryList = GroceryListGenerator.generateGroceryList(from: plan, numberOfDays: 7)
        persistToDisk()
    }

    @discardableResult
    public func generateAndSetActivePlan(
        target: NutritionTarget,
        foods: [FoodItem] = TBCAFoodDatabase.foods
    ) -> DailyMealPlan {
        let plan = MealPlanGenerator.generateDailyPlan(target: target, foods: foods)
        setActivePlan(plan)
        return plan
    }

    // MARK: - Lista de Compras

    @discardableResult
    public func generateGroceryList(numberOfDays: Int = 7) -> GroceryList? {
        lock.lock()
        defer { lock.unlock() }

        guard let plan = activePlan else { return nil }
        let list = GroceryListGenerator.generateGroceryList(from: plan, numberOfDays: numberOfDays)
        self.groceryList = list
        persistToDisk()
        return list
    }

    public func toggleGroceryItem(id: UUID) {
        lock.lock()
        defer { lock.unlock() }

        guard var list = groceryList else { return }
        if let idx = list.items.firstIndex(where: { $0.id == id }) {
            list.items[idx].isChecked.toggle()
            self.groceryList = list
            persistToDisk()
        }
    }

    public func clear() {
        lock.lock()
        defer { lock.unlock() }

        self.activePlan = nil
        self.groceryList = nil
        persistToDisk()
    }

    // MARK: - Persistência JSON

    private func persistToDisk() {
        let payload = MealPlanStoragePayload(activePlan: activePlan, groceryList: groceryList)
        do {
            let data = try JSONEncoder().encode(payload)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Erro ao persistir plano alimentar e lista de compras: \(error)")
        }
    }

    private func loadFromDisk() {
        guard fileManager.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let payload = try JSONDecoder().decode(MealPlanStoragePayload.self, from: data)
            self.activePlan = payload.activePlan
            self.groceryList = payload.groceryList
        } catch {
            print("Erro ao carregar plano alimentar e lista de compras: \(error)")
        }
    }
}

private struct MealPlanStoragePayload: Codable {
    let activePlan: DailyMealPlan?
    let groceryList: GroceryList?
}
