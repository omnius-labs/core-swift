import Dispatch

final class Map<TKey: Hashable, TValue>: @unchecked Sendable {
    private var map: [TKey: TValue] = [:]
    private let dispatchQueue = DispatchQueue(label: "Map")

    func get(key: TKey) -> TValue? {
        return self.dispatchQueue.sync {
            return self.map[key]
        }
    }

    func getOrDefault(key: TKey, _ create: () -> TValue) -> TValue {
        return self.dispatchQueue.sync {
            if let value = self.map[key] {
                return value
            }
            let value = create()
            self.map[key] = value
            return value
        }
    }

    func set(key: TKey, value: TValue) {
        self.dispatchQueue.sync {
            self.map[key] = value
        }
    }

    func remove(key: TKey) {
        let _ = self.dispatchQueue.sync {
            self.map.removeValue(forKey: key)
        }
    }
}
