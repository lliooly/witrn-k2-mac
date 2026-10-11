import SwiftUI
import K2Core

/// The central panel's top bar.
///
/// It carries the single page title (mirroring the left sidebar selection), the
/// page's contextual state, the page-level file actions and — at its trailing
/// edge, against the connection sidebar — the expand/collapse control for that
/// sidebar. At its leading edge it shows the navigation sidebar's expand button
/// while that sidebar is collapsed, since the sidebar's own control goes with it.
struct WorkspaceToolbar: View {
    let section: ToolSection
    @ObservedObject var store: UpdaterStore
    @ObservedObject var picture: PictureStore
    @ObservedObject var emark: EmarkStore
    @ObservedObject var monitor: MonitorStore
    @Binding var connectionExpanded: Bool
    @Binding var sidebarExpanded: Bool
    let onChooseResourceBackup: () -> Void
    var usesScrollEdge = false
    @GestureState private var maintenancePressed = false
    @State private var connectionPressed = false
    @State private var nameDraft = ""
    @FocusState private var editingName: Bool
    @Environment(\.colorScheme) private var colorScheme
    private var actionColor: Color { colorScheme == .dark ? .white : .black }
    private var toolbarActionPressed: Bool { maintenancePressed || connectionPressed }

    private var editor: Bool { section == .dial || section == .startup || section == .emark }
    private var isEmark: Bool { section == .emark }
    private var dirty: Bool { isEmark ? emark.dirty || emark.projectURL == nil || !emark.invalidFields.isEmpty : picture.dirty || picture.projectURL == nil }

    private var subtitle: String {
        if editor {
            return (isEmark ? emark.projectURL?.lastPathComponent : picture.projectURL?.lastPathComponent) ?? "未命名工程"
        }
        return section == .monitor ? "实时曲线与采集记录" : "检查固件、备份并更新设备"
    }

    var body: some View {
        Group {
            if section == .emark { emarkToolbar }
            else if section == .dial || section == .startup { pictureToolbar }
            else { standardToolbar }
        }
    }

    private var standardToolbar: some View {
        HStack(spacing: 14) {
            // The navigation sidebar folds away with its own toggle, so while it
            // is collapsed the top bar keeps a compact way back — placed clear of
            // the window traffic lights, which the workspace now sits beneath.
            if !sidebarExpanded {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    NavigationSidebarToggle(expanded: $sidebarExpanded,
                                            size: LayoutMetrics.navigationSidebarToggleSize)
                }
                .frame(width: LayoutMetrics.trafficLightTrailing - LayoutMetrics.pagePadding)
                .offset(x: LayoutMetrics.navigationSidebarCollapsedToggleTrailingOffset, y: 0)
                .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .trailing)))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(section.rawValue)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.leading, sidebarExpanded ? 0 : 25)

            if editor { saveState }

            Spacer(minLength: 12)

            if editor { editorActions }

            toolbarActionGroup
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .modifier(SystemGlassSurface(active: !usesScrollEdge))
        .disabled(store.isBusy)
    }

    private var emarkToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                emarkHeading
                Spacer(minLength: 8)
                emarkActions
                toolbarActionGroup
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    emarkHeading
                    Spacer(minLength: 8)
                    toolbarActionGroup
                }
                HStack { emarkActions; Spacer(minLength: 0) }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SystemGlassSurface(active: !usesScrollEdge))
        .disabled(store.isBusy)
        .onAppear { nameDraft = emark.projectName }
        .onChange(of: emark.projectName) { nameDraft = $0 }
        .onChange(of: editingName) { active in if !active { commitEmarkName() } }
    }

    private func commitEmarkName() {
        emark.renameProject(nameDraft)
        nameDraft = emark.projectName
    }

    private var emarkHeading: some View {
        HStack(spacing: 10) {
            if !sidebarExpanded {
                NavigationSidebarToggle(expanded: $sidebarExpanded, size: LayoutMetrics.navigationSidebarToggleSize)
                    .padding(.leading, LayoutMetrics.trafficLightTrailing - LayoutMetrics.pagePadding)
            }
            Text(section.rawValue).font(.title3.weight(.semibold)).fixedSize()
            TextField("工程名称", text: $nameDraft)
                .textFieldStyle(.plain).font(.callout)
                .focused($editingName).onSubmit { commitEmarkName(); editingName = false }
                .accessibilityLabel("工程名称").help("点击修改工程名称")
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 7))
                .frame(width: 110)
            saveState.fixedSize()
        }
    }

    @ViewBuilder private var emarkActions: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) { emarkActionButtons }
        } else { emarkActionButtons }
    }

    private var emarkActionButtons: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                pictureAction("新建", symbol: "doc.badge.plus") { commitEmarkName(); emark.newProject() }
                capsuleDivider
                pictureAction("打开", symbol: "folder") { commitEmarkName(); emark.open() }
                capsuleDivider
                pictureAction("另存为", symbol: "square.and.arrow.down.on.square") { commitEmarkName(); emark.save(asNew: true) }
            }.foregroundStyle(actionColor).modifier(EditorCapsuleSurface())
            ToolbarExportMenu(items: [
                ToolbarExportMenuItem(title: "导出配置 .wtemark", enabled: emark.record != nil && emark.invalidFields.isEmpty) { emark.export() }
            ])
            .modifier(EditorIconMenuSurface(symbol: "square.and.arrow.up", showsIndicator: true))
            .help("导出").accessibilityLabel("导出")
            pictureAction("保存", symbol: "square.and.arrow.down") { commitEmarkName(); emark.save() }
                .modifier(SystemGlassToolbarButtonSurface())
            HStack(spacing: 0) {
                pictureAction("撤销", symbol: "arrow.uturn.backward") { emark.undo() }
                    .disabled(!emark.undoAvailable)
                capsuleDivider
                pictureAction("重做", symbol: "arrow.uturn.forward") { emark.redo() }
                    .disabled(!emark.redoAvailable)
            }.foregroundStyle(actionColor).modifier(EditorCapsuleSurface())
        }.buttonStyle(.plain).font(.callout).fixedSize(horizontal: true, vertical: false)
    }

    private var pictureToolbar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                pictureHeading
                Spacer(minLength: 8)
                pictureActions
                toolbarActionGroup
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    pictureHeading
                    Spacer(minLength: 8)
                    toolbarActionGroup
                }
                HStack { pictureActions; Spacer(minLength: 0) }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(SystemGlassSurface(active: !usesScrollEdge))
        .disabled(store.isBusy)
        .onAppear { nameDraft = picture.projectName }
        .onChange(of: picture.projectName) { name in nameDraft = name }
        .onChange(of: editingName) { active in if !active { commitName() } }
    }

    private var pictureHeading: some View {
        HStack(spacing: 10) {
            if !sidebarExpanded {
                NavigationSidebarToggle(expanded: $sidebarExpanded, size: LayoutMetrics.navigationSidebarToggleSize)
                    .padding(.leading, LayoutMetrics.trafficLightTrailing - LayoutMetrics.pagePadding)
            }
            Text(section.rawValue).font(.title3.weight(.semibold)).fixedSize()
            TextField("工程名称", text: $nameDraft)
                .textFieldStyle(.plain).font(.callout)
                .padding(.horizontal, 9).padding(.vertical, 6)
                .background(.quaternary.opacity(editingName ? 0.6 : 0.3), in: RoundedRectangle(cornerRadius: 7))
                .frame(width: 110).focused($editingName)
                .onSubmit { commitName(); editingName = false }
                .accessibilityLabel("工程名称").help("点击修改工程名称")
            saveState.fixedSize()
        }
    }

    private func commitName() {
        picture.renameProject(nameDraft)
        nameDraft = picture.projectName
    }

    @ViewBuilder private var pictureActions: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 8) { pictureActionButtons }
        } else { pictureActionButtons }
    }

    private var pictureActionButtons: some View {
        HStack(spacing: 8) {
            HStack(spacing: 0) {
                pictureAction("新建", symbol: "doc.badge.plus") { commitName(); picture.newProject() }
                capsuleDivider
                pictureAction("打开", symbol: "folder") { commitName(); picture.open() }
                capsuleDivider
                pictureAction("另存为", symbol: "square.and.arrow.down.on.square") { commitName(); picture.save(asNew: true) }
            }.foregroundStyle(actionColor).modifier(EditorCapsuleSurface())
            ToolbarExportMenu(items: pictureExportItems)
            .modifier(EditorIconMenuSurface(symbol: "square.and.arrow.up", showsIndicator: true))
            .help("导出").accessibilityLabel("导出")
            pictureAction("保存", symbol: "square.and.arrow.down") { commitName(); picture.save() }
                .modifier(SystemGlassToolbarButtonSurface())
            HStack(spacing: 0) {
                Button { picture.undo() } label: { EditorIconLabel(symbol: "arrow.uturn.backward") }
                    .disabled(!picture.undoAvailable).help("撤销").accessibilityLabel("撤销")
                capsuleDivider
                Button { picture.redo() } label: { EditorIconLabel(symbol: "arrow.uturn.forward") }
                    .disabled(!picture.redoAvailable).help("重做").accessibilityLabel("重做")
            }.foregroundStyle(actionColor).modifier(EditorCapsuleSurface())
        }.buttonStyle(.plain).font(.callout).fixedSize(horizontal: true, vertical: false)
    }

    private var pictureExportItems: [ToolbarExportMenuItem] {
        if section == .dial {
            return [
                ToolbarExportMenuItem(title: "导出布局 .pic") { picture.export(.layout) },
                ToolbarExportMenuItem(title: "导出背景 BMP", enabled: picture.project.background != nil) { picture.export(.background) }
            ]
        }
        return [ToolbarExportMenuItem(title: "导出开机图 BMP", enabled: picture.project.startup != nil) { picture.export(.startup) }]
    }

    private var capsuleDivider: some View { Divider().frame(height: 16) }
    private func pictureAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            EditorIconLabel(symbol: symbol).foregroundStyle(actionColor)
        }.help(title).accessibilityLabel(title)
    }

    private var saveState: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dirty ? Color.orange : Color.green)
                .frame(width: 6, height: 6)
            Text(dirty ? "未保存" : "已保存")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var maintenanceMenu: some View {
        Menu {
            Button { onChooseResourceBackup() } label: {
                Label("恢复资源备份", systemImage: "clock.arrow.circlepath")
            }
            .disabled(!store.canUseResources)
            Divider()
            Button { store.showBackup() } label: {
                Label("打开备份文件夹", systemImage: "folder")
            }
            .disabled(store.backupPath == nil)
            Button { store.showLog() } label: {
                Label("查看日志", systemImage: "doc.text")
            }
            .disabled(store.tracePath == nil)
        } label: {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: LayoutMetrics.toolbarActionIconSize, weight: .medium))
                .frame(width: LayoutMetrics.toolbarActionHitSize,
                       height: LayoutMetrics.toolbarActionHitSize)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: LayoutMetrics.toolbarActionHitSize,
               height: LayoutMetrics.toolbarActionHitSize)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .simultaneousGesture(DragGesture(minimumDistance: 0)
            .updating($maintenancePressed) { _, isPressed, _ in isPressed = true })
        .help("维护")
        .accessibilityLabel("维护")
    }

    @ViewBuilder private var toolbarActionGroup: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: LayoutMetrics.toolbarGlassBlendSpacing) {
                toolbarActionButtons
            }
        } else {
            toolbarActionButtons
        }
    }

    private var toolbarActionButtons: some View {
        HStack(spacing: toolbarActionPressed ? LayoutMetrics.toolbarActionPressedSpacing : LayoutMetrics.toolbarActionSpacing) {
            maintenanceMenu
                .modifier(SystemGlassToolbarButtonSurface())
            ConnectionSidebarToggle(updater: store, monitor: monitor, expanded: $connectionExpanded,
                                    onPressChanged: { connectionPressed = $0 })
                .modifier(SystemGlassToolbarButtonSurface())
        }
        // Keep the group's width and center steady so both buttons move inward equally.
        .frame(width: LayoutMetrics.toolbarActionHitSize * 2 + LayoutMetrics.toolbarActionSpacing,
               alignment: .center)
        .animation(.easeInOut(duration: 0.16), value: toolbarActionPressed)
        .buttonStyle(.plain)
    }

    @ViewBuilder private var editorActions: some View {
        Menu("文件") {
            Button("新建工程") {
                if isEmark { commitEmarkName(); emark.newProject() } else { picture.newProject() }
            }
            Button("打开工程") {
                if isEmark { commitEmarkName(); emark.open() } else { picture.open() }
            }
            Button("另存为") {
                if isEmark { commitEmarkName(); emark.save(asNew: true) } else { picture.save(asNew: true) }
            }
            Divider()
            if isEmark {
                Button("导入 .wtemark") { emark.importRecords() }
                    .disabled(emark.bank.count >= 10 || !emark.invalidFields.isEmpty)
                Button("导出配置") { emark.export() }
                    .disabled(emark.record == nil || !emark.invalidFields.isEmpty)
            } else {
                Button("导出布局 .pic") { picture.export(.layout) }
                Button("导出背景 BMP") { picture.export(.background) }
                    .disabled(picture.project.background == nil)
                Button("导出开机图 BMP") { picture.export(.startup) }
                    .disabled(picture.project.startup == nil)
            }
        }
        .fixedSize()

        Button("保存") {
            if isEmark { commitEmarkName(); emark.save() } else { picture.save() }
        }

        Button("↶") {
            if isEmark { emark.undo() } else { picture.undo() }
        }
        .disabled(isEmark ? !emark.undoAvailable : !picture.undoAvailable)
        .help("撤销")
        .font(.title3)

        Button("↷") {
            if isEmark { emark.redo() } else { picture.redo() }
        }
        .disabled(isEmark ? !emark.redoAvailable : !picture.redoAvailable)
        .help("重做")
        .font(.title3)
    }
}
