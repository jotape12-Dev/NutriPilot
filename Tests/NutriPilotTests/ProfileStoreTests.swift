import XCTest
@testable import NutriPilotCore

final class ProfileStoreTests: XCTestCase {

    func testSaveAndCalculateProfile() {
        let store = ProfileStore.shared

        let birthDate = Calendar.current.date(byAdding: .year, value: -23, to: Date())!
        let profile = UserProfile(
            name: "João",
            birthDate: birthDate,
            sex: .male,
            heightCm: 178,
            currentWeightKg: 78,
            activityLevel: .moderate,
            goal: .recomposition
        )

        store.saveProfile(profile)

        XCTAssertTrue(store.hasCompletedOnboarding)
        XCTAssertEqual(store.currentProfile?.name, "João")
        XCTAssertNotNil(store.currentTarget)
        XCTAssertGreaterThan(store.currentTarget?.calories ?? 0, 2300)
        XCTAssertGreaterThan(store.currentTarget?.proteinGrams ?? 0, 160)
        XCTAssertGreaterThan(store.currentTarget?.waterMl ?? 0, 3000)
    }
}
