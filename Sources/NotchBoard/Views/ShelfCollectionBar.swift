import SwiftUI
import UniformTypeIdentifiers

/// Horizontal shelf-collection tabs shown in the panel's top row (same slot as
/// the History search field) so they always clear the notch.
struct ShelfCollectionBar: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var dropTargetedCollectionID: UUID?

    private var shelf: ShelfManager { viewModel.shelf }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(shelf.collections) { collection in
                    collectionChip(collection)
                }
                Button {
                    addCollection()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .background(Color.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .help(L.newCollection)
            }
            .padding(.horizontal, 2)
        }
        .scrollIndicators(.never)
    }

    private func collectionChip(_ collection: ShelfCollection) -> some View {
        let isSelected = collection.id == shelf.selectedCollectionID
        return Button {
            shelf.clearSelection()
            shelf.selectedCollectionID = collection.id
        } label: {
            HStack(spacing: 6) {
                if collection.isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                } else {
                    Circle()
                        .fill(collection.color)
                        .frame(width: 8, height: 8)
                }
                Text(collection.name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
                Text("\(shelf.count(in: collection.id))")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(
                    dropTargetedCollectionID == collection.id
                        ? collection.color.opacity(0.28)
                        : (isSelected ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
                )
            )
            .overlay(
                Capsule().strokeBorder(
                    dropTargetedCollectionID == collection.id
                        ? collection.color
                        : (isSelected ? collection.color.opacity(0.7) : Color.clear),
                    lineWidth: dropTargetedCollectionID == collection.id ? 1.5 : 1
                )
            )
        }
        .buttonStyle(.plain)
        .dropDestination(for: URL.self) { urls, _ in
            handleChipDrop(urls, to: collection.id)
        } isTargeted: { targeted in
            dropTargetedCollectionID = targeted ? collection.id : nil
            if targeted {
                shelf.selectedCollectionID = collection.id
            }
        }
        .contextMenu { collectionMenu(collection) }
    }

    @ViewBuilder
    private func collectionMenu(_ collection: ShelfCollection) -> some View {
        Button {
            renameCollection(collection)
        } label: {
            Label(L.renameCollection, systemImage: "pencil")
        }
        Button {
            let wasLocked = collection.isLocked
            shelf.toggleLockCollection(collection.id)
            if !wasLocked {
                viewModel.unlockedCollectionIDs.remove(collection.id)
            }
        } label: {
            Label(
                collection.isLocked ? L.t("Remove Lock", "Kilidi Kaldır") : L.t("Lock with Touch ID", "Touch ID ile Kilitle"),
                systemImage: collection.isLocked ? "lock.open" : "lock"
            )
        }
        Menu {
            ForEach(ShelfCollection.palette, id: \.self) { hex in
                Button {
                    shelf.recolorCollection(collection.id, to: hex)
                } label: {
                    Label {
                        Text(L.colorName(hex))
                    } icon: {
                        Image(nsImage: Self.colorSwatch(hex, selected: collection.colorHex == hex))
                    }
                }
            }
        } label: {
            Label(L.recolorCollection, systemImage: "paintpalette")
        }
        if shelf.collections.count > 1 {
            Divider()
            Button(role: .destructive) {
                shelf.removeCollection(collection.id)
            } label: {
                Label(L.deleteCollection, systemImage: "trash")
            }
        }
    }

    private func addCollection() {
        guard let name = TextPrompt.run(
            title: L.newCollectionTitle,
            hint: L.newCollectionHint,
            placeholder: L.collectionPlaceholder,
            confirm: L.add
        ) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? L.shelfDefaultName : trimmed
        shelf.addCollection(name: finalName)
    }

    private func renameCollection(_ collection: ShelfCollection) {
        guard let name = TextPrompt.run(
            title: L.renameCollection,
            hint: L.newCollectionHint,
            placeholder: L.collectionPlaceholder,
            initial: collection.name,
            confirm: L.save
        ) else { return }
        shelf.renameCollection(collection.id, to: name)
    }

    private func handleChipDrop(_ urls: [URL], to collectionID: UUID) -> Bool {
        dropTargetedCollectionID = nil
        if let draggedID = DragProviders.draggingShelfItemID {
            shelf.move([draggedID], to: collectionID)
            DragProviders.draggingShelfItemID = nil
            return true
        }
        let fileURLs = urls.filter { $0.isFileURL }
        guard !fileURLs.isEmpty else { return false }
        for url in fileURLs {
            shelf.addFile(at: url, to: collectionID)
        }
        return true
    }

    private static func colorSwatch(_ hex: String, selected: Bool) -> NSImage {
        let size = NSSize(width: 13, height: 13)
        let image = NSImage(size: size)
        image.lockFocus()
        let color = NSColor(hex: hex) ?? .systemBlue
        color.setFill()
        NSBezierPath(ovalIn: NSRect(origin: .zero, size: size)).fill()
        if selected {
            NSColor.white.setStroke()
            let ring = NSBezierPath(ovalIn: NSRect(x: 1.5, y: 1.5, width: size.width - 3, height: size.height - 3))
            ring.lineWidth = 1.5
            ring.stroke()
        }
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
