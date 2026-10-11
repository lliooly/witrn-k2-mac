import SwiftUI
import K2Core

struct ConnectionSidebar: View {
    @ObservedObject var updater: UpdaterStore
    @ObservedObject var monitor: MonitorStore
    @ObservedObject var picture: PictureStore
    @ObservedObject var emark: EmarkStore
    let section: ToolSection
    @State private var selectedModes: [ToolSection: String] = [:]
    @State private var writeIntent: ResourceWriteIntent?

    private var occupied: Bool { updater.isBusy || monitor.connected }
    private var isDialOrStartup: Bool { section == .dial || section == .startup }
    private var mode: String {
        if monitor.connected { return "normal" }
        return selectedModes[section] ?? (isDialOrStartup || section == .emark ? "dfu" : "normal")
    }
    private var modeSelection: Binding<String> {
        Binding(get: { mode }, set: { selectedModes[section] = $0 })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("设备连接").font(.title3.weight(.semibold))

                deviceSelection
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Text("连接用途").font(.callout.weight(.semibold))
                    AnimatedSegmentedPicker(title: "连接用途", selection: modeSelection,
                                            options: [("normal", "正常采集"), ("dfu", "DFU 维护")])
                        .disabled(occupied)
                    if monitor.connected || mode == "normal" { normalControls }
                    else { dfuControls }
                }

                // 各编辑页面共享右侧设备操作入口。
                if isDialOrStartup {
                    Divider()
                    deviceOperations
                }

                if section == .emark {
                    Divider()
                    emarkDeviceOperations
                }

                if mode == "dfu" {
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("设备信息").font(.callout.weight(.semibold))
                        VStack(alignment: .leading, spacing: 6) {
                            infoRow("型号", updater.identity?.confirmedK2 == true ? "K2 已确认" : "未读取")
                            infoRow("固件版本", updater.identity?.currentVersion ?? "未读取")
                        }
                        if let identity = updater.identity, let boot = identity.bootStrings.last {
                            Text(boot).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }
                }
                if let error = monitor.errorMessage {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red)
                            Text(error).font(.callout).foregroundStyle(.red).textSelection(.enabled)
                        }
                        Button("关闭错误提示") { monitor.errorMessage = nil }
                    }.padding(10).background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonBorderShape(.roundedRectangle)
        .frame(width: LayoutMetrics.connectionSidebarWidth)
        .frame(maxHeight: .infinity)
        .modifier(SystemSidebarSurface())
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }.font(.callout)
    }

    private var deviceSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("设备接口").font(.callout.weight(.semibold))
                Spacer()
            }
            Picker("设备接口", selection: $updater.selectedPath) {
                Text("选择 K2 接口").tag("")
                ForEach(updater.devices) { device in
                    Text("\(device.title) · 接口 \(device.interfaceNumber ?? 0)").tag(device.pathHex)
                }
            }.labelsHidden().disabled(occupied)
                .onChange(of: updater.selectedPath) { _ in updater.deviceChanged() }
            if let device = updater.selectedDevice {
                Text(device.detail).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
                    Text("未发现或未选择接口，请检查数据线及 CC1/HID 口").font(.caption).foregroundStyle(.orange)
                }
            }
        }
    }

    private var normalControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill").foregroundStyle(.blue).font(.caption)
                Text("正常开机，从 CC1/HID 口接入，不按减号键").font(.caption).foregroundStyle(.blue)
            }
            if monitor.connected {
                Button { monitor.disconnect() } label: {
                    Label(monitor.disconnecting ? "正在保存并断开…" : "断开采集连接", systemImage: "xmark.circle")
                }
                    .disabled(monitor.disconnecting).frame(maxWidth: .infinity, alignment: .leading)
                Text("断开时会提交当前记录。切换页面不会中断采集").font(.caption).foregroundStyle(.secondary)
            } else {
                Button { monitor.connect() } label: { Label("连接设备", systemImage: "cable.connector") }
                    .buttonStyle(.borderedProminent)
                    .disabled(updater.isBusy || updater.selectedDevice == nil)
            }
        }
    }

    private var dfuControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption)
                Text("按住减号键，从 CC1/HID 口连接，进入 DFU").font(.caption).foregroundStyle(.orange)
            }
            Button { updater.probe() } label: { Label("连接设备", systemImage: "cable.connector") }
            .buttonStyle(.borderedProminent)
            .disabled(occupied)
            .frame(maxWidth: .infinity, alignment: .leading)
            if let error = updater.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.red).textSelection(.enabled)
            }
        }
    }

    private var emarkDeviceOperations: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设备操作").font(.callout.weight(.semibold))
            Button { updater.openResourceTutorial(.emark) } label: {
                Label("阅读教程", systemImage: "book")
            }.buttonStyle(.bordered).disabled(updater.isBusy)
            HStack(spacing: 8) {
                Menu("读取") {
                    Button("读取设备配置") {
                        guard emark.allowDiscard() else { return }
                        updater.readResource(.emark) { emark.acceptRead($0, kind: $1) }
                    }
                    Button("读取复制数据") {
                        updater.readResource(.emarkCopy) { emark.acceptRead($0, kind: $1) }
                    }
                }.menuStyle(.borderedButton).fixedSize()
                    .disabled(!updater.canUseResources)
                Button("写入") {
                    writeIntent = ResourceWriteIntent(kind: .emark, data: emark.bank.data, manifest: nil, manifestHash: nil)
                }.buttonStyle(.borderedProminent)
                    .disabled(!updater.canUseResources || !emark.invalidFields.isEmpty)
            }.font(.caption)
            if !updater.canUseResources {
                Label("需进入 DFU 模式", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.red)
            }
            Label("每次写入后重新进入 DFU", systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(.red)
        }
        .alert("写入 \(emark.bank.count) 组 E-Mark 配置？", isPresented: Binding(
            get: { section == .emark && writeIntent != nil },
            set: { if !$0 { writeIntent = nil } }
        )) {
            Button("取消", role: .cancel) { writeIntent = nil }
            Button("备份并写入") {
                if let intent = writeIntent { updater.writeResource(intent) }
                writeIntent = nil
            }
        } message: {
            Text("\(emark.bank.count == 0 ? "将清空有效配置列表。" : "默认组：第 \(emark.bank.selected + 1) 组。")先双遍备份配置扇区，再写入并完整读回校验。请保持连接。")
        }
    }

    // 设备操作部分（表盘/开机图）
    private var deviceOperations: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设备操作")
                .font(.callout)
                .fontWeight(.semibold)

            let kind: ResourceTutorialKind = section == .dial ? .dial : .startup
            let acknowledged = updater.hasReadTutorial(for: section == .dial ? .layout : .startup)
            Label(acknowledged ? "已阅读教程，每次写入前请确认 DFU 连接" : "写入前请先阅读教程并确认（至少 \(Int(kind.readingSeconds)) 秒）", systemImage: "exclamationmark.circle")
                .font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            Button { updater.openResourceTutorial(kind) } label: {
                Label(acknowledged ? "重新阅读教程" : "阅读教程", systemImage: "book")
            }.buttonStyle(.bordered).disabled(updater.isBusy)

            if section == .dial {
                resourceButtons(.background)
                Divider()
                resourceButtons(.layout)
                if !updater.canWriteDialLayoutInSequence(usesBackground: picture.project.usesBackground) {
                    Text("先成功写入背景，再重新进入 DFU 写入布局")
                        .font(.caption).foregroundStyle(.orange)
                } else if !picture.project.usesBackground {
                    Text("未使用背景，可直接写入布局")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if section == .startup {
                resourceButtons(.startup)
            }

            if !updater.canUseResources {
                Text("⚠ 需进入 DFU 模式")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Text("⚠ " + (section == .startup ? "每次写入后重新进入 DFU" : "每次完成后重新进入 DFU"))
                .font(.caption)
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .alert("\(writeIntent?.restoring == true ? "恢复" : "写入")\(writeIntent?.kind.title ?? "资源")？",
               isPresented: Binding(get: { writeIntent != nil }, set: { if !$0 { writeIntent = nil } })) {
            Button("取消", role: .cancel) { writeIntent = nil }
            Button("确认") {
                if let intent = writeIntent { updater.writeResource(intent, usesDialBackground: picture.project.usesBackground) }
                writeIntent = nil
            }
        } message: {
            Text("先读取目标资源并备份，再擦除、写入并校验")
        }
    }

    private func resourceButtons(_ kind: PictureResource) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind.title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("读取") {
                    updater.readResource(kind) { picture.acceptRead($0, kind: $1) }
                }.disabled(!updater.canUseResources).font(.caption)
                Button("写入") {
                    do {
                        writeIntent = ResourceWriteIntent(
                            kind: kind,
                            data: try picture.resourceData(kind),
                            manifest: nil,
                            manifestHash: nil
                        )
                    }
                    catch {
                        picture.error = error.localizedDescription
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!updater.canWriteResource(kind, usesDialBackground: picture.project.usesBackground) ||
                         (kind == .background && picture.project.background == nil) ||
                         (kind == .startup && picture.project.startup == nil))
                .font(.caption)
            }
        }
    }
}
