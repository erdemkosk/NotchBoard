import SwiftUI

/// The expanded notch panel: search field, tabs, and the active tab content.
struct ExpandedPanel: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var resizeBase: CGSize?
    @State private var dragBaseOffset: CGFloat = 0
    @FocusState private var searchFocused: Bool

    /// Vertical space reserved at the top so search + History/Shelf tabs never
    /// sit under the hardware notch.
    private var headerClearance: CGFloat {
        viewModel.notchHeight + 10
    }

    var body: some View {
        VStack(spacing: 12) {
            tabBar
                .fixedSize(horizontal: false, vertical: true)

            if viewModel.selectedTab == .history {
                searchBar
                    .fixedSize(horizontal: false, vertical: true)

                if !viewModel.availableKinds.isEmpty {
                    kindFilterBar
                }
            } else if viewModel.selectedTab == .shelf {
                ShelfCollectionBar(viewModel: viewModel)
            }

            content
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
        .padding(.top, headerClearance)
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: viewModel.selectedTab)
        .frame(width: viewModel.openWidth, height: viewModel.openHeight)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(alignment: .top) { notchConnector }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.18), .white.opacity(0.04), .accentColor.opacity(0.18)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(alignment: .bottomTrailing) { resizeHandle }
        .shadow(color: .black.opacity(0.5), radius: 30, y: 14)
        .shadow(color: .accentColor.opacity(0.28), radius: 26, y: 6)
        .onAppear {
            if viewModel.selectedTab == .shelf {
                FilePickerHelper.warmUp()
            }
            guard viewModel.pendingSearchFocus else { return }
            viewModel.pendingSearchFocus = false
            // The panel mounts via a spring animation; defer a tick so the field
            // exists and reliably accepts first responder.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                searchFocused = true
            }
        }
        .onChange(of: viewModel.selectedTab) { _, tab in
            if tab == .shelf {
                FilePickerHelper.warmUp()
            }
        }
    }

    /// Black tab at the very top that blends the panel into the hardware notch.
    private var notchConnector: some View {
        UnevenRoundedRectangle(
            bottomLeadingRadius: 14,
            bottomTrailingRadius: 14
        )
        .fill(Color.black)
        .frame(width: viewModel.notchWidth, height: viewModel.notchHeight)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    guard !viewModel.hasHardwareNotch else { return }
                    if dragBaseOffset == 0 {
                        dragBaseOffset = viewModel.horizontalOffset
                    }
                    let newOffset = dragBaseOffset + value.translation.width
                    viewModel.updateHorizontalOffset(newOffset)
                }
                .onEnded { _ in
                    dragBaseOffset = 0
                    viewModel.commitHorizontalOffset()
                }
        )
        .onHover { inside in
            guard !viewModel.hasHardwareNotch else { return }
            if inside { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
        }
        .help(viewModel.hasHardwareNotch ? "" : L.t("Drag to move horizontally", "Yatay olarak taşımak için sürükle"))
    }

    /// Corner grip: drag to resize the panel. Width grows symmetrically (the
    /// panel is centered under the notch), height grows downward. Size is saved.
    private var resizeHandle: some View {
        Image(systemName: "arrow.down.right.and.arrow.up.left")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white.opacity(0.7))
            .rotationEffect(.degrees(90))
            .padding(6)
            .background(Color.white.opacity(0.1), in: Circle())
            .padding(7)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if resizeBase == nil {
                            resizeBase = CGSize(width: viewModel.openWidth, height: viewModel.openHeight)
                        }
                        guard let base = resizeBase else { return }
                        viewModel.resizePanel(
                            width: base.width + value.translation.width * 2,
                            height: base.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        resizeBase = nil
                        viewModel.commitPanelSize()
                    }
            )
            .onHover { inside in
                if inside { NSCursor.crosshair.set() } else { NSCursor.arrow.set() }
            }
            .help(L.t("Drag to resize", "Boyutlandırmak için sürükle"))
    }

    private var panelBackground: some View {
        ZStack {
            Color.black.opacity(0.55)
            Rectangle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L.searchPlaceholder, text: $viewModel.searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .focused($searchFocused)
            if !viewModel.searchText.isEmpty {
                Button {
                    viewModel.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tabBar: some View {
        HStack(spacing: 8) {
            if viewModel.selectedTab == .history {
                favoritesChip
            }
            ForEach(NotchTab.allCases) { tab in
                TabChip(
                    tab: tab,
                    count: count(for: tab),
                    isSelected: viewModel.selectedTab == tab
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.selectedTab = tab
                        viewModel.selectedIndex = 0
                    }
                }
            }
            Spacer()
            if viewModel.selectedTab == .history {
                snippetButton
            }
            clearButton
        }
    }

    @ViewBuilder
    private var snippetButton: some View {
        Button {
            if let text = SnippetPrompt.run() {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.clipboard.addSnippet(text)
                    viewModel.selectedIndex = 0
                }
            }
        } label: {
            Image(systemName: "text.badge.plus")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(8)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .help(L.newSnippet)
    }

    private var kindFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                KindChip(
                    title: L.allKinds,
                    icon: "square.grid.2x2",
                    count: viewModel.clipboard.items.count,
                    isSelected: viewModel.selectedKind == nil
                ) {
                    selectKind(nil)
                }
                ForEach(viewModel.availableKinds, id: \.self) { kind in
                    KindChip(
                        title: L.kindName(kind),
                        icon: L.kindIcon(kind),
                        count: viewModel.count(of: kind),
                        isSelected: viewModel.selectedKind == kind
                    ) {
                        selectKind(kind)
                    }
                }

                if !viewModel.clipboard.allTags.isEmpty {
                    Divider().frame(height: 18).padding(.horizontal, 2)
                    ForEach(viewModel.clipboard.allTags, id: \.self) { tag in
                        TagChip(
                            tag: tag,
                            isSelected: viewModel.selectedTag == tag
                        ) {
                            selectTag(viewModel.selectedTag == tag ? nil : tag)
                        }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func selectTag(_ tag: String?) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewModel.selectedTag = tag
            viewModel.selectedIndex = 0
        }
    }

    private func selectKind(_ kind: ClipboardItem.Kind?) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            viewModel.selectedKind = kind
            viewModel.selectedIndex = 0
        }
    }

    private var favoritesChip: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                viewModel.showFavoritesOnly.toggle()
                viewModel.selectedIndex = 0
            }
        } label: {
            Image(systemName: viewModel.showFavoritesOnly ? "star.fill" : "star")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(viewModel.showFavoritesOnly ? .black : .white)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(viewModel.showFavoritesOnly ? Color.yellow : Color.white.opacity(0.08))
                .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.9))
        .help(L.favorites)
    }

    @ViewBuilder
    private var clearButton: some View {
        Button {
            switch viewModel.selectedTab {
            case .history: viewModel.clipboard.clearAll()
            case .shelf: viewModel.shelf.clearAll()
            }
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(8)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .help(L.clearCurrentTab)
    }

    @ViewBuilder
    private var content: some View {
        Group {
            switch viewModel.selectedTab {
            case .history:
                HistoryView(viewModel: viewModel)
            case .shelf:
                ShelfView(viewModel: viewModel)
            }
        }
        .id(viewModel.selectedTab)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)),
            removal: .opacity
        ))
        .animation(.spring(response: 0.32, dampingFraction: 0.85), value: viewModel.selectedTab)
    }

    private func count(for tab: NotchTab) -> Int {
        switch tab {
        case .history: return viewModel.clipboard.items.count
        case .shelf: return viewModel.shelf.items.count
        }
    }
}

/// Colored pill for filtering history by a user tag.
private struct TagChip: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void

    private var color: Color { .tagColor(tag) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 7, height: 7)
                Text(tag)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.9))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.9) : Color.white.opacity(0.07))
            .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.92))
    }
}

/// Smaller pill used for filtering history by content type.
private struct KindChip: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isSelected ? .black.opacity(0.5) : .secondary)
                }
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.85))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(isSelected ? Color.white : Color.white.opacity(0.07))
            .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.92))
    }
}

/// Pill-style tab selector matching the reference UI.
private struct TabChip: View {
    let tab: NotchTab
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                Text(tab.title)
                    .font(.system(size: 14, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? .black.opacity(0.55) : .secondary)
                }
            }
            .foregroundStyle(isSelected ? .black : .white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(isSelected ? Color.white : Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.93))
    }
}
