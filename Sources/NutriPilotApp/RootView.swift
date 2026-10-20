import SwiftUI
import NutriPilotCore

public struct RootView: View {
    @State private var store = ProfileStore.shared
    @State private var waterStore = WaterStore.shared
    @State private var mealStore = MealStore.shared
    @State private var selectedTab: AppTab = .dashboard

    public init() {}

    public var body: some View {
        Group {
            if store.hasCompletedOnboarding, let profile = store.currentProfile, let target = store.currentTarget {
                TabView(selection: $selectedTab) {
                    DashboardView(
                        profile: profile,
                        target: target,
                        waterStore: waterStore,
                        mealStore: mealStore
                    )
                    .tabItem {
                        Label("Hoje", systemImage: "bolt.fill")
                    }
                    .tag(AppTab.dashboard)

                    FoodLoggingView(mealStore: mealStore)
                        .tabItem {
                            Label("Comida", systemImage: "fork.knife")
                        }
                        .tag(AppTab.food)

                    WaterView(
                        targetWaterMl: target.waterMl,
                        store: waterStore
                    )
                    .tabItem {
                        Label("Água", systemImage: "drop.fill")
                    }
                    .tag(AppTab.water)

                    BodyProgressView()
                        .tabItem {
                            Label("Corpo", systemImage: "figure.walk")
                        }
                        .tag(AppTab.body)

                    MealPlanView(targetCalories: target.calories)
                        .tabItem {
                            Label("Plano", systemImage: "list.clipboard.fill")
                        }
                        .tag(AppTab.plan)
                }
                .tint(.green)
            } else {
                OnboardingView(store: store)
            }
        }
    }
}

public enum AppTab: Hashable, Sendable {
    case dashboard
    case food
    case water
    case body
    case plan
}
