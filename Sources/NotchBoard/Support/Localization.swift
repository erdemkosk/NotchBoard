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
    static var copyPlain: String { t("Copy as plain text", "Düz metin olarak kopyala") }
    static var transform: String { t("Transform", "Dönüştür") }
    static var transformUppercase: String { t("UPPERCASE", "BÜYÜK HARF") }
    static var transformLowercase: String { t("lowercase", "küçük harf") }
    static var transformTrim: String { t("Trim whitespace", "Boşlukları kırp") }
    static var transformJSON: String { t("Beautify JSON", "JSON güzelleştir") }
    static var transformURLEncode: String { t("URL encode", "URL kodla") }
    static var transformURLDecode: String { t("URL decode", "URL çöz") }
    static var transformBase64Encode: String { t("Base64 encode", "Base64 kodla") }
    static var transformBase64Decode: String { t("Base64 decode", "Base64 çöz") }
    static func copiedKind(_ kind: ClipboardItem.Kind) -> String {
        switch kind {
        case .text: return t("Text copied", "Metin kopyalandı")
        case .link: return t("Link copied", "Link kopyalandı")
        case .color: return t("Color copied", "Renk kopyalandı")
        case .image: return t("Image copied", "Görsel kopyalandı")
        case .file: return t("File copied", "Dosya kopyalandı")
        }
    }
    static var copy: String { t("Copy", "Kopyala") }
    static var delete: String { t("Delete", "Sil") }
    static var remove: String { t("Remove", "Kaldır") }
    static var addToShelf: String { t("Add to Shelf", "Rafa ekle") }
    static var revealInFinder: String { t("Reveal in Finder", "Finder'da göster") }
    static var clearCurrentTab: String { t("Clear current tab", "Bu sekmeyi temizle") }
    static var pin: String { t("Add to Favorites", "Favorilere ekle") }
    static var unpin: String { t("Remove from Favorites", "Favorilerden çıkar") }
    static var pinToTop: String { t("Pin to top", "Yukarı sabitle") }
    static var unpinFromTop: String { t("Unpin", "Sabitlemeyi kaldır") }
    static var newSnippet: String { t("New Snippet", "Yeni Snippet") }
    static var newSnippetTitle: String { t("New snippet", "Yeni snippet") }
    static var newSnippetHint: String { t("Save reusable text (signature, address, code). It stays pinned at the top.", "Tekrar kullanılabilir metin kaydet (imza, adres, kod). Üstte sabit kalır.") }
    static var snippetPlaceholder: String { t("Type or paste your snippet…", "Snippet'ini yaz veya yapıştır…") }
    static var save: String { t("Save", "Kaydet") }
    static var addTag: String { t("Add Tag…", "Etiket Ekle…") }
    static var addTagTitle: String { t("Add a tag", "Etiket ekle") }
    static var addTagHint: String { t("Type a label to organize this item, then press Add.", "Bu öğeyi düzenlemek için bir etiket yaz, sonra Ekle'ye bas.") }
    static var tagPlaceholder: String { t("e.g. API, key, work", "ör. API, anahtar, iş") }
    static var add: String { t("Add", "Ekle") }
    static var cancel: String { t("Cancel", "İptal") }
    static var removeTag: String { t("Remove tag", "Etiketi kaldır") }
    static var tags: String { t("Tags", "Etiketler") }
    static var nameItem: String { t("Name…", "İsim ver…") }
    static var renameItem: String { t("Rename…", "Yeniden adlandır…") }
    static var nameItemTitle: String { t("Name this item", "Bu öğeye isim ver") }
    static var nameItemHint: String { t("Give this clipboard item a short label to find it faster.", "Bu pano öğesine kısa bir etiket ver; daha kolay bulursun.") }
    static var itemNamePlaceholder: String { t("e.g. API key, logo, meeting notes", "ör. API anahtarı, logo, toplantı notları") }
    static var removeName: String { t("Remove name", "İsmi kaldır") }

    static var emptyHistoryTitle: String { t("No clipboard history yet", "Henüz pano geçmişi yok") }
    static var emptyHistorySubtitle: String { t("Copy text, links, images or files and they'll appear here.", "Metin, link, görsel veya dosya kopyala; burada görünür.") }
    static var emptyFavoritesTitle: String { t("No favorites yet", "Henüz favori yok") }
    static var emptyFavoritesSubtitle: String { t("Star items to keep them here.", "Öğeleri yıldızlayarak burada tut.") }
    static var noMatchesTitle: String { t("No matches", "Sonuç yok") }
    static var noMatchesSubtitle: String { t("Try a different search.", "Farklı bir arama dene.") }
    static var emptyShelfTitle: String { t("Drop files here", "Dosyaları buraya bırak") }
    static var emptyShelfSubtitle: String { t("Drag images or files onto the notch to keep them handy, then drag them into any app.", "Görsel veya dosyaları notch'a sürükleyip sakla, sonra herhangi bir uygulamaya sürükle.") }
    static var browseFiles: String { t("Browse…", "Gözat…") }
    static var browseFilesTitle: String { t("Add to Shelf", "Rafa ekle") }
    static var browseFilesMessage: String { t("Select files or folders to add to this collection.", "Bu koleksiyona eklemek için dosya veya klasör seç.") }
    static var choose: String { t("Choose", "Seç") }
    static var saveTo: String { t("Save to…", "Kaydet…") }
    static var saveToTitle: String { t("Save file", "Dosyayı kaydet") }
    static var download: String { t("Download", "İndir") }

    // Shelf collections
    static var shelfDefaultName: String { t("Shelf", "Raf") }
    static var newCollection: String { t("New collection", "Yeni koleksiyon") }
    static var newCollectionTitle: String { t("New collection", "Yeni koleksiyon") }
    static var newCollectionHint: String { t("Name this shelf (e.g. Design, Work, Temp).", "Bu rafa bir ad ver (ör. Tasarım, İş, Geçici).") }
    static var collectionPlaceholder: String { t("e.g. Design, Work", "ör. Tasarım, İş") }
    static var renameCollection: String { t("Rename…", "Yeniden adlandır…") }
    static var recolorCollection: String { t("Color", "Renk") }
    static var deleteCollection: String { t("Delete collection", "Koleksiyonu sil") }
    static var moveToCollection: String { t("Move to", "Taşı") }
    static var noOtherCollections: String { t("No other collections", "Başka koleksiyon yok") }
    static func colorName(_ hex: String) -> String {
        switch hex.uppercased() {
        case "#34C759": return t("Green", "Yeşil")
        case "#0A84FF": return t("Blue", "Mavi")
        case "#FF9F0A": return t("Orange", "Turuncu")
        case "#FF375F": return t("Pink", "Pembe")
        case "#BF5AF2": return t("Purple", "Mor")
        case "#5AC8FA": return t("Teal", "Camgöbeği")
        case "#FFD60A": return t("Yellow", "Sarı")
        case "#8E8E93": return t("Gray", "Gri")
        default: return hex
        }
    }

    // Shelf batch actions
    static var share: String { t("Share…", "Paylaş…") }
    static var zipSelected: String { t("Zip selected", "Seçilenleri sıkıştır") }
    static var dragOutSelected: String { t("Drag selected out", "Seçilenleri sürükle") }
    static func selectedCount(_ n: Int) -> String { t("\(n) selected", "\(n) seçili") }

    // Settings
    static var settings: String { t("Settings", "Ayarlar") }
    static var settingsTitle: String { t("NotchBoard Settings", "NotchBoard Ayarları") }
    static var launchAtLogin: String { t("Launch at login", "Açılışta başlat") }
    static var skipSensitive: String { t("Skip passwords / sensitive content", "Parola / hassas içeriği atla") }
    static var maxItems: String { t("Max history items", "Maksimum geçmiş öğesi") }
    static var hotkeyHint: String { t("Open with Keyboard Shortcut", "Klavye Kısayolu ile aç") }
    static var autoDelete: String { t("Auto-delete history", "Geçmişi otomatik sil") }
    static var autoDeleteHint: String { t("Pinned items and favorites are always kept.", "Sabitlenmiş öğeler ve favoriler her zaman korunur.") }
    static var keyboardShortcut: String { t("Keyboard Shortcut", "Klavye Kısayolu") }
    static var autoPaste: String { t("Auto-Paste copied item", "Otomatik Yapıştırma") }
    static var autoPasteHint: String { t("Automatically paste the clicked/selected item into the frontmost app. Requires Accessibility permission.", "Tıklanan veya seçilen öğeyi o an aktif olan uygulamaya otomatik olarak yapıştırır. Erişilebilirlik izni gerektirir.") }
    static var captureHUD: String { t("Copy confirmation", "Kopyalama bildirimi") }
    static var captureHUDHint: String { t("Shows a brief \"Copied\" pill near the notch when new clipboard content is captured.", "Yeni içerik yakalandığında notch yanında kısa bir \"Kopyalandı\" bildirimi gösterir.") }
    static var hideFromScreenCapture: String { t("Hide from screen recordings", "Ekran kayıtlarından gizle") }
    static var hideFromScreenCaptureHint: String { t("Prevents the NotchBoard panel from appearing in screenshots, video recordings, and screen sharing.", "NotchBoard panelinin ekran resimlerinde, video kayıtlarında ve ekran paylaşımlarında görünmesini engeller.") }

    // Trigger pill (non-notch screens)
    static var triggerPillSection: String { t("Trigger pill (screens without a notch)", "Tetikleyici pil (notch'suz ekranlar)") }
    static var pillWidth: String { t("Width", "Genişlik") }
    static var pillHeight: String { t("Height", "Yükseklik") }
    static var pillCorner: String { t("Corner radius", "Köşe yuvarlaklığı") }
    static var pillHint: String { t("Customizes the pill shown under the menu bar on Macs and displays without a hardware notch.", "Donanım notch'u olmayan Mac ve ekranlarda menü çubuğu altında görünen pili özelleştirir.") }
    static func retentionLabel(_ minutes: Int) -> String {
        switch minutes {
        case 0: return t("Never", "Asla")
        case 5: return t("After 5 minutes", "5 dakika sonra")
        case 15: return t("After 15 minutes", "15 dakika sonra")
        case 30: return t("After 30 minutes", "30 dakika sonra")
        case 60: return t("After 1 hour", "1 saat sonra")
        case 60 * 24: return t("After 1 day", "1 gün sonra")
        case 60 * 24 * 7: return t("After 1 week", "1 hafta sonra")
        case 60 * 24 * 30: return t("After 30 days", "30 gün sonra")
        default: return "\(minutes) min"
        }
    }

    // Onboarding
    static var onboardingWelcomeTitle: String { t("Welcome to NotchBoard", "NotchBoard'a hoş geldin") }
    static var onboardingWelcomeBody: String { t("Your clipboard history and a handy shelf, right under the notch. Move your mouse to the notch or press Cmd+Shift+V to open it.", "Pano geçmişin ve kullanışlı bir raf, tam notch'un altında. Açmak için fareyi notch'a götür ya da Cmd+Shift+V'ye bas.") }
    static var onboardingDoneTitle: String { t("You're all set", "Her şey hazır") }
    static var onboardingDoneBody: String { t("Copy anything and it'll appear in History. Pin frequently used text as snippets, and drop files onto the notch to stash them on the Shelf.", "Bir şey kopyala, Geçmiş'te görünsün. Sık kullandığın metinleri snippet olarak sabitle, dosyaları notch'a bırakıp Raf'ta sakla.") }
    static var next: String { t("Next", "İleri") }
    static var back: String { t("Back", "Geri") }
    static var getStarted: String { t("Get Started", "Başla") }
    static var setupGuide: String { t("Setup Guide", "Kurulum Rehberi") }

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
    static var visitWebsite: String { t("Visit Website", "Web sitesini ziyaret et") }
}
