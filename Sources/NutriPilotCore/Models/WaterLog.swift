import Foundation

public struct WaterLog: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public var date: Date
    public var amountMl: Double
    public var loggedAt: Date

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        amountMl: Double,
        loggedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.amountMl = amountMl
        self.loggedAt = loggedAt
    }
}
