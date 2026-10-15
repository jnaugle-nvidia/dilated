import Foundation
import Testing
@testable import Dilated

struct DilatedTests {
    @Test func appIsInGamesCategory() {
        // Game Mode only turns on for apps in the Games category (arch.md §8.4).
        let category = Bundle.main.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String
        #expect(category == "public.app-category.games")
    }
}
