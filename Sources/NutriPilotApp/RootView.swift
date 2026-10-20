import SwiftUI
import NutriPilotCore

public struct RootView: View {
    @State private var selectedTab: AppTab = .dashboard

    public init() {}

    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Hoje", systemImage: "bolt.fill")
                }
                .tag(AppTab.dashboard)

            FoodLoggingView()
                .tabItem {
                    Label("Comida", systemImage: "fork.knife")
                }
                .tag(AppTab.food)

            WaterView()
                .tabItem {
                    Label("Água", systemImage: "drop.fill")
                }
                .tag(AppTab.water)

            BodyProgressView()
                .tabItem {
                    Label("Corpo", systemImage: "figure.walk")
                }
                .tag(AppTab.body)

            MealPlanView()
                .tabItem {
                    Label("Plano", systemImage: "list.clipboard.fill")
                }
                .tag(AppTab.plan)
        }
        .tint(.green)
    }
}

public enum AppTab: Hashable, Sendable {
    case dashboard
    case food
    case water
    case body
    case plan
}
