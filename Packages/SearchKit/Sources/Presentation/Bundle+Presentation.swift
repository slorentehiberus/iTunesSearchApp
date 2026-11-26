import Foundation

extension Bundle {
    /// Resource bundle of the Presentation module (its String Catalog). Internal: tests reach it with `@testable`.
    static var presentation: Bundle { .module }
}
