import Foundation

// PHASE 101
// Render cache

public final class ReviewProRenderCacheV1 {

    private var cache: [String: Data] = [:]

    public init() {}

    public func store(key: String, data: Data) {
        cache[key] = data
    }

    public func fetch(key: String) -> Data? {
        cache[key]
    }

    public func clear() {
        cache.removeAll()
    }

    public var count: Int {
        cache.count
    }
}
