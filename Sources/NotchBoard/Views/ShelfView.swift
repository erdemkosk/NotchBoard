import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication

/// Grid of parked files/images grouped into collections (tabs). Accepts drops
/// from anywhere and lets items be dragged back out into other apps.
struct ShelfView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var isTargeted = false
    @State private var lastSelectedIndex: Int?

    private var shelf: ShelfManager { viewModel.shelf }
    private let columns = [GridItem(.adaptive(minimum: 180, maximum: 250), spacing: 14)]

    var body: some View {
        VStack(spacing: 10) {
            if !shelf.selection.isEmpty {
                batchToolbar
            }
            content
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: shelf.selection.isEmpty)
        .onChange(of: shelf.selectedCollectionID) { _, newID in
            if let col = shelf.selectedCollection, col.isLocked && !viewModel.unlockedCollectionIDs.contains(newID) {
                authenticateCollection(id: newID)
            }
        }
    }

    // MARK: - Batch toolbar

    private var batchToolbar: some View {
        HStack(spacing: 8) {
            Text(L.selectedCount(shelf.selection.count))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Spacer(minLength: 0)

            MultiFileDragHandle(
                urls: { shelf.selectedURLs },
                onBegin: { DragProviders.beginDrag() }
            )
            .frame(width: 30, height: 26)
            .overlay(
                Image(systemName: "arrow.up.forward.app")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .allowsHitTesting(false)
            )
            .help(L.dragOutSelected)

            toolbarButton(icon: "square.and.arrow.up", help: L.share) {
                ShareHelper.share(urls: shelf.selectedURLs)
            }
            toolbarButton(icon: "doc.zipper", help: L.zipSelected) {
                zipSelected()
            }
            Menu {
                ForEach(shelf.collections.filter { $0.id != shelf.selectedCollectionID }) { dest in
                    Button {
                        shelf.move(shelf.selection, to: dest.id)
                        shelf.clearSelection()
                    } label: {
                        Label(dest.name, systemImage: "tray.full")
                    }
                }
                if shelf.collections.count <= 1 {
                    Text(L.noOtherCollections)
                }
            } label: {
                Image(systemName: "folder")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30, height: 26)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .help(L.moveToCollection)

            toolbarButton(icon: "trash", help: L.remove, role: .destructive) {
                shelf.remove(ids: shelf.selection)
            }
            toolbarButton(icon: "xmark", help: L.cancel) {
                shelf.clearSelection()
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func toolbarButton(
        icon: String,
        help: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(role == .destructive ? Color.red.opacity(0.9) : .white.opacity(0.8))
                .frame(width: 30, height: 26)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Content grid

    private var isCurrentCollectionLocked: Bool {
        guard let col = shelf.selectedCollection else { return false }
        return col.isLocked && !viewModel.unlockedCollectionIDs.contains(col.id)
    }

    private func authenticateCollection(id: UUID) {
        guard viewModel.isOpen else { return }
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: L.t("Unlock Collection", "Koleksiyonun Kilidini Aç")) { success, evaluationError in
                DispatchQueue.main.async {
                    if success {
                        withAnimation {
                            _ = viewModel.unlockedCollectionIDs.insert(id)
                        }
                    }
                }
            }
        } else {
            withAnimation {
                _ = viewModel.unlockedCollectionIDs.insert(id)
            }
        }
    }

    private var lockOverlay: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.04))
                    .frame(width: 80, height: 80)
                Image(systemName: "lock.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white.opacity(0.85))
            }
            VStack(spacing: 6) {
                Text(L.t("Locked Collection", "Kilitli Koleksiyon"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                Text(L.t("This collection is secured. Unlock to view items.", "Bu koleksiyon güvenli. İçeriği görmek için kilidini açın."))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 240)
            }
            Button {
                if let id = shelf.selectedCollection?.id {
                    authenticateCollection(id: id)
                }
            } label: {
                Label(L.t("Unlock with Touch ID", "Touch ID / Şifre ile Aç"), systemImage: "touchid")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let id = shelf.selectedCollection?.id {
                authenticateCollection(id: id)
            }
        }
    }

    private var content: some View {
        ZStack {
            if isCurrentCollectionLocked {
                lockOverlay
            } else if shelf.visibleItems.isEmpty {
                EmptyState(
                    icon: "tray.and.arrow.down",
                    title: L.emptyShelfTitle,
                    subtitle: L.emptyShelfSubtitle
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        ForEach(shelf.visibleItems) { item in
                            ShelfCard(item: item, isSelected: shelf.selection.contains(item.id))
                                .hoverFeedback()
                                .onTapGesture {
                                    if let index = shelf.visibleItems.firstIndex(of: item) {
                                        handleTap(item, index: index)
                                    }
                                }
                                .onDrag {
                                    DragProviders.beginDrag()
                                    DragProviders.draggingShelfItemID = item.id
                                    return DragProviders.provider(for: item)
                                } preview: {
                                    Image(nsImage: item.thumbnail)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 120, height: 120)
                                }
                                .contextMenu {
                                    Button {
                                        ShareHelper.share(urls: [item.fileURL])
                                    } label: {
                                        Label(L.share, systemImage: "square.and.arrow.up")
                                    }
                                    Button {
                                        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
                                    } label: {
                                        Label(L.revealInFinder, systemImage: "folder")
                                    }
                                    if shelf.collections.count > 1 {
                                        Menu {
                                            ForEach(shelf.collections.filter { $0.id != item.collectionID }) { dest in
                                                Button {
                                                    shelf.move([item.id], to: dest.id)
                                                } label: {
                                                    Label(dest.name, systemImage: "tray.full")
                                                }
                                            }
                                        } label: {
                                            Label(L.moveToCollection, systemImage: "folder")
                                        }
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        shelf.remove(item)
                                    } label: {
                                        Label(L.remove, systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 6)
                    .animation(.easeInOut(duration: 0.22), value: shelf.visibleItems)
                }
                .scrollIndicators(.never)
                .scrollEdgeFade()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if !shelf.selection.isEmpty { shelf.clearSelection() }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isTargeted ? Color.accentColor : Color.white.opacity(0.08),
                    style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: [6, 4])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
                )
        )
        .onDrop(
            of: [.fileURL, .image, .png, .tiff, .pdf],
            isTargeted: $isTargeted
        ) { providers in
            handleDrop(providers)
        }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }

    // MARK: - Selection

    private func handleTap(_ item: ShelfItem, index: Int) {
        let shiftHeld = NSEvent.modifierFlags.contains(.shift)
        if shiftHeld, let anchor = lastSelectedIndex {
            let lower = min(anchor, index)
            let upper = max(anchor, index)
            let ids = shelf.visibleItems[lower...upper].map { $0.id }
            shelf.selection.formUnion(ids)
        } else {
            shelf.toggleSelection(item.id)
            lastSelectedIndex = index
        }
    }

    // MARK: - Actions

    private func zipSelected() {
        let urls = shelf.selectedURLs
        guard !urls.isEmpty else { return }
        let name = shelf.selectedCollection?.name ?? "Archive"
        if let archive = ZipArchiver.makeArchive(of: urls, named: name) {
            shelf.addFile(at: archive)
            try? FileManager.default.removeItem(at: archive)
            shelf.clearSelection()
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        // A shelf tile dragged and dropped back onto the shelf: consume it so we
        // don't duplicate it (the dropped data may be a temp copy URL).
        if DragProviders.draggingShelfItemID != nil {
            DragProviders.draggingShelfItemID = nil
            return true
        }
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: NSURL.self) {
                handled = true
                _ = provider.loadObject(ofClass: NSURL.self) { object, _ in
                    guard let url = object as? URL, url.isFileURL else { return }
                    Task { @MainActor in viewModel.shelf.addFile(at: url) }
                }
            } else if provider.canLoadObject(ofClass: NSImage.self) {
                handled = true
                _ = provider.loadObject(ofClass: NSImage.self) { object, _ in
                    guard let image = object as? NSImage,
                          let tiff = image.tiffRepresentation,
                          let rep = NSBitmapImageRep(data: tiff),
                          let png = rep.representation(using: .png, properties: [:]) else { return }
                    Task { @MainActor in
                        viewModel.shelf.addImageData(png, suggestedName: "dropped-\(Int(Date().timeIntervalSince1970)).png")
                    }
                }
            }
        }
        return handled
    }
}

/// A single shelf tile: thumbnail plus filename.
private struct ShelfCard: View {
    let item: ShelfItem
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.white.opacity(0.05)
                if item.isImage {
                    ThumbnailImage(url: item.fileURL, maxPixel: 256, contentMode: .fill)
                } else {
                    Image(nsImage: item.thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(18)
                }
            }
            .frame(height: 92)
            .frame(maxWidth: .infinity)
            .clipped()

            HStack(spacing: 5) {
                Text(item.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
        }
        .frame(height: 140)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.white.opacity(0.06),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.accentColor, .white)
                    .padding(6)
            }
        }
    }
}
