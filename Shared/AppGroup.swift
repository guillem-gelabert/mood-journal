import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

/// The container the phone app shares with its notification and widget extensions.
///
/// The identifier comes from each target's Info.plist, where it is derived from the bundle
/// identifier, so it follows whatever signing config is in use. The watch has no group and
/// gets standard defaults.
enum AppGroup {
    static let identifier = Bundle.main.object(forInfoDictionaryKey: "MoodAppGroup") as? String

    static let defaults: UserDefaults = identifier.flatMap(UserDefaults.init(suiteName:)) ?? .standard

    /// After anything the widget reads from the group changes.
    static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
