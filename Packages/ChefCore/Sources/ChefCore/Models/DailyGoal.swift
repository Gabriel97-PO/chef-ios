import Foundation

public struct DailyGoal: Codable, Sendable, Equatable {
    public var calories: Double
    public var protein: Double
    public var carbs: Double?
    public var fat: Double?
    public var fiber: Double?
    /// Meta de água em ml.
    public var water: Double?

    public init(calories: Double, protein: Double, carbs: Double? = nil, fat: Double? = nil, fiber: Double? = nil, water: Double? = nil) {
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.fiber = fiber
        self.water = water
    }
}

public struct UserProfile: Codable, Sendable, Equatable {
    public var name: String
    public var goal: DailyGoal
    public var startingWeight: Double?
    public var createdAt: Date

    public init(name: String, goal: DailyGoal, startingWeight: Double? = nil, createdAt: Date = Date()) {
        self.name = name
        self.goal = goal
        self.startingWeight = startingWeight
        self.createdAt = createdAt
    }
}

public struct WeightEntry: Identifiable, Codable, Sendable, Equatable {
    public var id: String
    public var date: String
    public var weightKg: Double

    public init(id: String = UUID().uuidString, date: String, weightKg: Double) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
    }
}
