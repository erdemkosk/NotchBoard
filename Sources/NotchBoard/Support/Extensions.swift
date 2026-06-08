import AppKit
import SwiftUI

extension NSColor {
    /// Parses colors from "#RRGGBB", "#RRGGBBAA", "#RGB" or "rgb(r,g,b)" strings.
    convenience init?(hex raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if s.hasPrefix("rgb") {
            let nums = s
                .replacingOccurrences(of: "rgba", with: "")
                .replacingOccurrences(of: "rgb", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: ",")
                .compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard nums.count >= 3 else { return nil }
            let a = nums.count >= 4 ? nums[3] : 1.0
            self.init(srgbRed: nums[0] / 255, green: nums[1] / 255, blue: nums[2] / 255, alpha: a)
            return
        }

        if s.hasPrefix("#") { s.removeFirst() }
        guard s.allSatisfy({ $0.isHexDigit }) else { return nil }

        if s.count == 3 {
            s = s.map { "\($0)\($0)" }.joined()
        }
        guard s.count == 6 || s.count == 8 else { return nil }

        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)

        let r, g, b, a: CGFloat
        if s.count == 8 {
            r = CGFloat((value & 0xFF000000) >> 24) / 255
            g = CGFloat((value & 0x00FF0000) >> 16) / 255
            b = CGFloat((value & 0x0000FF00) >> 8) / 255
            a = CGFloat(value & 0x000000FF) / 255
        } else {
            r = CGFloat((value & 0xFF0000) >> 16) / 255
            g = CGFloat((value & 0x00FF00) >> 8) / 255
            b = CGFloat(value & 0x0000FF) / 255
            a = 1.0
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }

    /// Heuristic: is a trimmed string a parseable color literal?
    static func looksLikeColor(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard t.count <= 30 else { return false }
        if t.hasPrefix("#") || t.lowercased().hasPrefix("rgb") {
            return NSColor(hex: t) != nil
        }
        return false
    }
}

extension Color {
    init(nsColor: NSColor) {
        self.init(nsColor as NSColor)
    }

    /// Deterministic, vivid color derived from a tag string (stable per label).
    static func tagColor(_ tag: String) -> Color {
        var hash: UInt64 = 5381
        for byte in tag.lowercased().utf8 {
            hash = (hash &* 33) ^ UInt64(byte)
        }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.6, brightness: 0.9)
    }
}

/// Modal prompt for entering/creating a tag.
@MainActor
enum TagPrompt {
    static func run() -> String? {
        let alert = NSAlert()
        alert.messageText = L.addTagTitle
        alert.informativeText = L.addTagHint
        alert.addButton(withTitle: L.add)
        alert.addButton(withTitle: L.cancel)

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = L.tagPlaceholder
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        // The notch panel sits at `.statusBar` level, so a default alert would be
        // hidden behind it. Float above the panel and drop the dialog lower-center
        // on the active screen so it's clearly visible.
        let win = alert.window
        win.level = .popUpMenu
        DispatchQueue.main.async {
            let screen = NotchScreenMetrics.active.screen
            let sf = screen.frame
            let size = win.frame.size
            let x = sf.midX - size.width / 2
            let y = sf.midY - size.height / 2 - 80
            win.setFrameOrigin(NSPoint(x: x, y: y))
        }

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

/// Generic single-line text prompt (used for naming/renaming shelf collections).
@MainActor
enum TextPrompt {
    static func run(
        title: String,
        hint: String,
        placeholder: String,
        initial: String = "",
        confirm: String
    ) -> String? {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = hint
        alert.addButton(withTitle: confirm)
        alert.addButton(withTitle: L.cancel)

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = placeholder
        field.stringValue = initial
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        let win = alert.window
        win.level = .popUpMenu
        DispatchQueue.main.async {
            let screen = NotchScreenMetrics.active.screen
            let sf = screen.frame
            let size = win.frame.size
            win.setFrameOrigin(NSPoint(x: sf.midX - size.width / 2, y: sf.midY - size.height / 2 - 80))
            field.selectText(nil)
        }

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let value = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

/// Modal prompt for creating a reusable, pinned text snippet (multiline).
@MainActor
enum SnippetPrompt {
    static func run() -> String? {
        let alert = NSAlert()
        alert.messageText = L.newSnippetTitle
        alert.informativeText = L.newSnippetHint
        alert.addButton(withTitle: L.save)
        alert.addButton(withTitle: L.cancel)

        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 320, height: 110))
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        let textView = NSTextView(frame: scroll.bounds)
        textView.autoresizingMask = [.width]
        textView.font = .systemFont(ofSize: 13)
        textView.isRichText = false
        scroll.documentView = textView
        alert.accessoryView = scroll
        alert.window.initialFirstResponder = textView

        let win = alert.window
        win.level = .popUpMenu
        DispatchQueue.main.async {
            let screen = NotchScreenMetrics.active.screen
            let sf = screen.frame
            let size = win.frame.size
            win.setFrameOrigin(NSPoint(x: sf.midX - size.width / 2, y: sf.midY - size.height / 2 - 60))
        }

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return nil }
        let value = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
