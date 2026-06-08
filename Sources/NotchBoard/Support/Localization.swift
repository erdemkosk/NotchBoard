import Foundation

/// Lightweight in-app localization (Turkish + English) without a resource bundle,
/// which keeps the SwiftPM executable target simple.
enum L {
    static let isTurkish: Bool = {
        let code = Locale.current.language.languageCode?.identifier ?? "en"
        return code == "tr"
    }()

    static func t(_ en: String, _ tr: String) -> String {
        isTurkish ? tr : en
    }

    // Common UI strings.
    static var searchPlaceholder: String { t("Search clipboard history", "Pano geçmişinde ara") }
    static var tabHistory: String { t("History", "Geçmiş") }
    static var tabShelf: String { t("Shelf", "Raf") }
    static var favorites: String { t("Favorites", "Favoriler") }
    static var allKinds: String { t("All", "Tümü") }

    static func kindName(_ kind: ClipboardItem.Kind) -> String {
        switch kind {
        case .text: return t("Text", "Metin")
        case .link: return t("Links", "Linkler")
        case .color: return t("Colors", "Renkler")
        case .image: return t("Images", "Görseller")
        case .file: return t("Files", "Dosyalar")
        }
    }

    static func kindIcon(_ kind: ClipboardItem.Kind) -> String {
        switch kind {
        case .text: return "textformat"
        case .link: return "link"
        case .color: return "paintpalette"
        case .image: return "photo"
        case .file: return "doc"
        }
    }
    static var copied: String { t("Copied", "Kopyalandı") }
    static var copy: String { t("Copy", "Kopyala") }
    static var delete: String { t("Delete", "Sil") }
    static var remove: String { t("Remove", "Kaldır") }
    static var addToShelf: String { t("Add to Shelf", "Rafa ekle") }
    static var revealInFinder: String { t("Reveal in Finder", "Finder'da göster") }
    static var clearCurrentTab: String { t("Clear current tab", "Bu sekmeyi temizle") }
    static var pin: String { t("Add to Favorites", "Favorilere ekle") }
    static var unpin: String { t("Remove from Favorites", "Favorilerden çıkar") }
    static var addTag: String { t("Add Tag…", "Etiket Ekle…") }
    static var addTagTitle: String { t("Add a tag", "Etiket ekle") }
    static var tagPlaceholder: String { t("e.g. API, key, work", "ör. API, anahtar, iş") }
    static var add: String { t("Add", "Ekle") }
    static var cancel: String { t("Cancel", "İptal") }
    static var removeTag: String { t("Remove tag", "Etiketi kaldır") }
    static var tags: String { t("Tags", "Etiketler") }

    static var emptyHistoryTitle: String { t("No clipboard history yet", "Henüz pano geçmişi yok") }
    static var emptyHistorySubtitle: String { t("Copy text, links, images or files and they'll appear here.", "Metin, link, görsel veya dosya kopyala; burada görünür.") }
    static var emptyFavoritesTitle: String { t("No favorites yet", "Henüz favori yok") }
    static var emptyFavoritesSubtitle: String { t("Star items to keep them here.", "Öğeleri yıldızlayarak burada tut.") }
    static var noMatchesTitle: String { t("No matches", "Sonuç yok") }
    static var noMatchesSubtitle: String { t("Try a different search.", "Farklı bir arama dene.") }
    static var emptyShelfTitle: String { t("Drop files here", "Dosyaları buraya bırak") }
    static var emptyShelfSubtitle: String { t("Drag images or files onto the notch to keep them handy, then drag them into any app.", "Görsel veya dosyaları notch'a sürükleyip sakla, sonra herhangi bir uygulamaya sürükle.") }

    // Settings
    static var settings: String { t("Settings", "Ayarlar") }
    static var settingsTitle: String { t("NotchBoard Settings", "NotchBoard Ayarları") }
    static var launchAtLogin: String { t("Launch at login", "Açılışta başlat") }
    static var autoPaste: String { t("Auto-paste on select", "Seçince otomatik yapıştır") }
    static var autoPasteHint: String { t("Requires Accessibility permission.", "Erişilebilirlik izni gerektirir.") }
    static var skipSensitive: String { t("Skip passwords / sensitive content", "Parola / hassas içeriği atla") }
    static var maxItems: String { t("Max history items", "Maksimum geçmiş öğesi") }
    static var hotkeyHint: String { t("Open with Cmd+Shift+V", "Cmd+Shift+V ile aç") }

    // Menu
    static var toggleNotch: String { t("Toggle NotchBoard", "NotchBoard'u Aç/Kapat") }
    static var quit: String { t("Quit NotchBoard", "NotchBoard'dan Çık") }

    // Updates
    static var version: String { t("Version", "Sürüm") }
    static var checkForUpdates: String { t("Check for Updates", "Güncellemeleri Denetle") }
    static var checking: String { t("Checking…", "Denetleniyor…") }
    static var upToDate: String { t("You're up to date.", "En güncel sürümdesin.") }
    static var downloading: String { t("Downloading…", "İndiriliyor…") }
    static var installing: String { t("Installing…", "Kuruluyor…") }
    static var restartToUpdate: String { t("Download & Install", "İndir ve Kur") }
    static func updateAvailable(_ v: String) -> String { t("Update available: \(v)", "Güncelleme mevcut: \(v)") }

    // About
    static var about: String { t("About", "Hakkında") }
    static let developer = "Mustafa Erdem Köşk"
    static var developedWithLove: String { t("Developed with", "Sevgiyle geliştirildi") }
    static var viewOnGitHub: String { t("View on GitHub", "GitHub'da görüntüle") }
}
