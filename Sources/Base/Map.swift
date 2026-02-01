public struct Map<TKey: Hashable & Sendable, TValue: Sendable>: Sendable {
    private var map: [TKey: TValue] = [:]

    public init() {}

    public func get(key: TKey) -> TValue? {
        return self.map[key]
    }

    public mutating func getOrDefault(key: TKey, _ create: () -> TValue) -> TValue {
        if let value = self.map[key] {
            return value
        }
        let value = create()
        self.map[key] = value
        return value
    }

    public mutating func set(key: TKey, value: TValue) {
        self.map[key] = value
    }

    public mutating func remove(key: TKey) {
        self.map.removeValue(forKey: key)
    }
}
