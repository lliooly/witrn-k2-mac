import SwiftUI
import K2Core

struct EmarkView: View {
    @ObservedObject var emark: EmarkStore
    @ObservedObject var store: UpdaterStore
    @State private var confirmDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .top, spacing: 20) {
                    readoutPanel.frame(maxWidth: .infinity)
                    configurationList.frame(maxWidth: .infinity)
                }
                EmarkEditor(emark: emark).id(emark.selected)
            }
            .padding(20).frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .disabled(store.isBusy)
        .alert("删除这组配置？", isPresented: $confirmDelete) {
            Button("取消", role: .cancel) {}
            Button("删除", role: .destructive) { emark.remove() }
        } message: { Text("只修改本地配置集合，写入后才改变设备。") }
        .alert("E-Mark 操作未完成", isPresented: Binding(get: { emark.error != nil }, set: { if !$0 { emark.error = nil } })) {
            Button("好") { emark.error = nil }
        } message: { Text(emark.error ?? "") }
    }

    private var readoutPanel: some View {
        GroupBox("读出数据") {
            VStack(alignment: .leading, spacing: 16) {
                if let copied = emark.copied {
                    Label(copied.name.isEmpty ? "未命名" : copied.name, systemImage: "cable.connector")
                        .lineLimit(2).textSelection(.enabled)
                    Text(copied.pdVersion == 1 ? "PD 2.0" : "PD 3.0 / 3.1")
                    Spacer(minLength: 0)
                    HStack {
                        Button("添加") { emark.add(copied) }
                            .disabled(emark.bank.count >= EmarkBank.capacity || !emark.invalidFields.isEmpty)
                        Button("导出") { emark.export(copied) }
                            .disabled(!emark.invalidFields.isEmpty)
                    }
                } else {
                    Text("尚未读取").frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading).frame(height: 178)
            .padding(12)
        }
    }

    private var configurationList: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Table(rows, selection: Binding<Int?>(get: { emark.record == nil ? nil : emark.selected }, set: {
                    if let index = $0 { emark.selected = index }
                })) {
                    TableColumn("序号") { row in Text("\(row.id + 1)") }.width(32)
                    TableColumn("名称", value: \.name)
                    TableColumn("默认") { row in
                        if row.id == emark.bank.selected {
                            Image(systemName: "star.fill").accessibilityLabel("默认配置")
                        }
                    }.width(32)
                }
                .frame(height: 140)
                .disabled(!emark.invalidFields.isEmpty)
                HStack(spacing: 8) {
                    Button { emark.add() } label: { configurationIcon("plus") }
                        .help("新增配置").accessibilityLabel("新增配置")
                        .disabled(emark.bank.count >= EmarkBank.capacity)
                    Button { confirmDelete = true } label: { configurationIcon("minus") }
                        .help("删除配置").accessibilityLabel("删除配置").disabled(emark.record == nil)
                    Button { emark.duplicate() } label: { configurationIcon("doc.on.doc") }
                        .help("复制配置").accessibilityLabel("复制配置")
                        .disabled(emark.record == nil || emark.bank.count >= EmarkBank.capacity)
                    Spacer(minLength: 8)
                    Button { emark.move(-1) } label: { configurationIcon("arrow.up") }
                        .help("上移").accessibilityLabel("上移").disabled(emark.selected <= 0)
                    Button { emark.move(1) } label: { configurationIcon("arrow.down") }
                        .help("下移").accessibilityLabel("下移").disabled(emark.selected >= emark.bank.count - 1)
                    Button { emark.setDefault() } label: { configurationIcon("star") }
                        .help("设为默认").accessibilityLabel("设为默认")
                        .disabled(emark.record == nil || emark.selected == emark.bank.selected)
                }
                .buttonStyle(.bordered).controlSize(.regular)
                .buttonBorderShape(.roundedRectangle)
            }.padding(12).disabled(!emark.invalidFields.isEmpty)
        } label: {
            HStack { Text("写入列表"); Spacer(); Text("\(emark.bank.count) / 10").monospacedDigit() }
        }
    }

    private func configurationIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .regular))
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
    }

    private var rows: [EmarkConfigurationRow] {
        (0..<emark.bank.count).map { index in
            let name = emark.bank.record(index).name
            return EmarkConfigurationRow(id: index, name: name.isEmpty ? "未命名" : name)
        }
    }
}

private struct EmarkConfigurationRow: Identifiable {
    let id: Int
    let name: String
}

struct EmarkEditor: View {
    @ObservedObject var emark: EmarkStore
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let record = emark.record {
                EmarkGridLayout(columnBreakpoint: 580, columnSpacing: 20, rowSpacing: 20) {
                    GroupBox("设置") {
                        VStack(alignment: .leading, spacing: 12) {
                            EmarkInput(title: "配置名称", value: record.name, key: "name", emark: emark) { try $0.setName($1) }
                            HStack(spacing: 8) {
                                Text("PD 版本")
                                Spacer(minLength: 0)
                                EmarkOptionPicker(title: "PD 版本", options: ["PD 2.0", "PD 3.0 / 3.1"], selection: Binding(
                                    get: { record.pdVersion - 1 },
                                    set: { value in emark.update { try $0.setPDVersion(value + 1) } }
                                )).frame(width: 120)
                                Button("重置") { confirmReset = true }
                            }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(8)
                    }
                    fieldSection("ID Header VDO", offset: 25,
                                 fields: EmarkField.identity.filter { $0.offset == 25 }, record: record)
                    fieldSection("Cert Stat ID", offset: 29,
                                 fields: EmarkField.identity.filter { $0.offset == 29 }, record: record)
                    fieldSection("Product VDO", offset: 33,
                                 fields: EmarkField.identity.filter { $0.offset == 33 }, record: record)
                    vdoPreview(record)
                    fieldSection("Cable VDO", offset: 37, fields: EmarkField.cable, record: record)
                }
                GroupBox {
                    DisclosureGroup("扩展数据") {
                        VStack(spacing: 12) {
                            EmarkInput(title: "配置区域", value: String(record.area), key: "area", emark: emark) { record, text in
                                try record.setArea(Int(EmarkStore.number(text, maximum: 255)))
                            }
                            ForEach([0, 5, 6, 7, 8, 9, 10], id: \.self) { index in
                                rawInput(index, record)
                            }
                        }.padding(.top, 12)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                }
                HStack(spacing: 12) {
                    Button("导入参数…") { emark.importRecords() }
                        .disabled(emark.bank.count >= EmarkBank.capacity || !emark.invalidFields.isEmpty)
                    Button("保存参数…") { emark.export() }
                        .disabled(!emark.invalidFields.isEmpty)
                }
            } else {
                GroupBox("设置") {
                    VStack(spacing: 16) {
                        Image(systemName: "cable.connector").font(.largeTitle)
                        Text("尚无配置").font(.headline)
                        HStack(spacing: 12) {
                            Button("新增配置") { emark.add() }.buttonStyle(.borderedProminent)
                            Button("导入参数…") { emark.importRecords() }
                        }
                    }.frame(maxWidth: .infinity, minHeight: 240)
                }
            }
        }
        .buttonBorderShape(.roundedRectangle)
        .alert("重置当前配置？", isPresented: $confirmReset) {
            Button("取消", role: .cancel) {}
            Button("重置", role: .destructive) { emark.update { $0 = .standard }; emark.clearDraftErrors() }
        } message: { Text("当前配置将恢复为默认参数，可通过撤销恢复。") }
    }

    private func fieldSection(_ title: String, offset: Int, fields: [EmarkField], record: EmarkRecord) -> some View {
        GroupBox {
            Group {
                if fields.count <= 2 {
                    VStack(spacing: 12) {
                        ForEach(fields) { field in fieldControl(field, record: record) }
                    }
                } else {
                    EmarkGridLayout(columnBreakpoint: 450, columnSpacing: 20, rowSpacing: 12) {
                        ForEach(fields) { field in fieldControl(field, record: record) }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(8)
        } label: {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                Text(String(format: "0x%08X", record.word(offset))).font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }
        }
    }

    @ViewBuilder private func fieldControl(_ field: EmarkField, record: EmarkRecord) -> some View {
        if !field.options.isEmpty {
            HStack {
                Text(field.title).frame(width: 100, alignment: .leading)
                EmarkOptionPicker(title: field.title, options: field.options, selection: Binding(
                    get: { Int(record.value(field)) },
                    set: { value in emark.update { try $0.set(field, value: UInt32(value)) } }
                )).frame(maxWidth: .infinity)
            }
        } else {
            EmarkInput(title: field.title, value: String(format: field.width > 16 ? "%08X" : "%04X", record.value(field)), key: field.id, emark: emark) { record, text in
                try record.set(field, value: EmarkStore.number(text, maximum: field.maximum, hexadecimal: true))
            }
        }
    }

    private func vdoPreview(_ record: EmarkRecord) -> some View {
        GroupBox("编辑和预览") {
            VStack(spacing: 12) {
                ForEach(1..<5, id: \.self) { index in rawInput(index, record) }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(8)
        }
    }

    private func rawInput(_ index: Int, _ record: EmarkRecord) -> some View {
        EmarkInput(title: EmarkField.rawTitles[index], value: String(format: "%08X", record.word(21 + index * 4)), key: "raw\(index)", emark: emark) { record, text in
            try record.setWord(21 + index * 4, EmarkStore.number(text, hexadecimal: true))
        }
    }
}

struct EmarkInput: View {
    let title: String
    let value: String
    let key: String
    @ObservedObject var emark: EmarkStore
    let change: (inout EmarkRecord, String) throws -> Void
    @State private var text = ""
    @State private var problem: String?
    @State private var group = UUID()
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).frame(width: 100, alignment: .leading)
                TextField(title, text: $text).labelsHidden().textFieldStyle(.roundedBorder).focused($focused)
                    .accessibilityLabel(title)
            }
            if let problem { Text(problem).font(.caption).foregroundStyle(.red) }
        }
        .onAppear { text = emark.invalidDrafts[key] ?? value; problem = emark.validationMessages[key] }
        .onChange(of: focused) { active in if active { group = UUID() } else if problem == nil { text = value } }
        .onChange(of: text) { next in
            guard focused else { return }
            problem = emark.textEdited(key, text: next, group: group, change: change)
        }
        .onChange(of: value) { next in if !focused { text = next } }
        .onChange(of: emark.inputReset) { _ in focused = false; problem = nil; text = value }
    }
}
