import Foundation

/// Maps language ids from [`SourceLanguage`] to locales Whisper / Speech expect.
enum TranscriptionLocale {
    /// `SFSpeechRecognizer` locale identifier.
    static func speechLocaleIdentifier(for languageId: String) -> String {
        switch languageId {
        case "zh-Hans": return "zh-CN"
        case "pt": return "pt-BR"
        case "en": return "en-US"
        case "hi": return "hi-IN"
        case "ar": return "ar-SA"
        default: return languageId
        }
    }

    static func speechLocale(for languageId: String) -> Locale {
        Locale(identifier: speechLocaleIdentifier(for: languageId))
    }

    /// whisper.cpp `-l` code (ISO-639-1 where possible).
    static func whisperLanguageCode(for languageId: String) -> String {
        switch languageId {
        case "zh-Hans": return "zh"
        default:
            let id = languageId.split(separator: "-").first.map(String.init) ?? languageId
            return String(id.prefix(2))
        }
    }
}

/// Left-rail destinations (trimmed product surface).
enum SidebarSection: String, CaseIterable, Identifiable {
    case home
    case dictionary
    case snippets
    case scratchPad
    case inviteTeam
    case promoMonthFree
    case settings
    case help

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .dictionary: return "Dictionary"
        case .snippets: return "Snippets"
        case .scratchPad: return "Scratch Pad"
        case .inviteTeam: return "Invite your team"
        case .promoMonthFree: return "Get a month free"
        case .settings: return "Settings"
        case .help: return "Help"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .dictionary: return "book.fill"
        case .snippets: return "text.badge.plus"
        case .scratchPad: return "note.text"
        case .inviteTeam: return "person.3.fill"
        case .promoMonthFree: return "gift.fill"
        case .settings: return "gearshape.fill"
        case .help: return "questionmark.circle.fill"
        }
    }

}

/// Languages the user can speak in (translate / recognize **from**). Output is English for this MVP.
struct SourceLanguage: Identifiable, Hashable {
    let id: String
    let name: String
    let flag: String

    static let catalog: [SourceLanguage] = [
        SourceLanguage(id: "es", name: "Spanish", flag: "🇪🇸"),
        SourceLanguage(id: "fr", name: "French", flag: "🇫🇷"),
        SourceLanguage(id: "de", name: "German", flag: "🇩🇪"),
        SourceLanguage(id: "it", name: "Italian", flag: "🇮🇹"),
        SourceLanguage(id: "pt", name: "Portuguese", flag: "🇵🇹"),
        SourceLanguage(id: "ja", name: "Japanese", flag: "🇯🇵"),
        SourceLanguage(id: "ko", name: "Korean", flag: "🇰🇷"),
        SourceLanguage(id: "zh-Hans", name: "Chinese (Simplified)", flag: "🇨🇳"),
        SourceLanguage(id: "hi", name: "Hindi", flag: "🇮🇳"),
        SourceLanguage(id: "ar", name: "Arabic", flag: "🇸🇦"),
        SourceLanguage(id: "en", name: "English", flag: "🇺🇸"),
        SourceLanguage(id: "ru", name: "Russian", flag: "🇷🇺"),
        SourceLanguage(id: "pl", name: "Polish", flag: "🇵🇱"),
    ]
}
