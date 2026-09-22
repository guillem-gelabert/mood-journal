import Foundation
import SwiftData

@Model
final class DiaryNote {
    @Attribute(.unique) var dayKey: String
    var text: String
    var updatedAt: Date

    init(dayKey: String, text: String, updatedAt: Date = Date()) {
        self.dayKey = dayKey
        self.text = text
        self.updatedAt = updatedAt
    }
}
