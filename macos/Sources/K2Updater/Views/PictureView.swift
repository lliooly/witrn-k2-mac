import SwiftUI
import K2Core
import UniformTypeIdentifiers

struct PictureView: View {
    @ObservedObject var picture: PictureStore
    @ObservedObject var store: UpdaterStore
    let startup: Bool
    @SceneStorage("dialPreviewScale") private var scale = 1.5
    @State private var dropTarget = false
    var body: some View {
        ScrollView {
            Group { if startup { startupEditor } else { dialEditor } }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .disabled(store.isBusy)
        .sheet(item: $picture.imageImport) { ImageCropSheet(item: $0, picture: picture) }
        .alert("文件操作失败", isPresented: Binding(get: { picture.error != nil }, set: { if !$0 { picture.error = nil } })) {
            Button("好", role: .cancel) { picture.error = nil }
        } message: { Text(picture.error ?? "") }
        .onDrop(of: [.fileURL], isTargeted: $dropTarget, perform: acceptDrop)
        .overlay { if dropTarget { RoundedRectangle(cornerRadius: 8).stroke(.blue, lineWidth: 2).allowsHitTesting(false) } }
    }
    private var dialEditor: some View { DialEditorView(picture: picture, scale: $scale) }
    private var startupEditor: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                HStack(spacing: 12) {
                    Label("235 × 235", systemImage: "viewfinder")
                        .font(.callout).foregroundStyle(.primary)
                    Spacer()
                    Button { picture.chooseImage(.startup) } label: {
                        Label(picture.project.startup == nil ? "导入图片" : "替换图片", systemImage: "photo.badge.plus")
                    }.buttonStyle(.bordered).buttonBorderShape(.roundedRectangle)
                }.controlSize(.regular)
                Text("支持 BMP、PNG 和 JPEG").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            startupPreview.frame(maxWidth: .infinity, alignment: .center)
            if picture.project.startup != nil {
                HStack(spacing: 12) {
                    Button { picture.export(.startup) } label: { Label("导出 BMP", systemImage: "square.and.arrow.up") }
                    Button { picture.edit { $0.startup = nil } } label: { Label("移除图片", systemImage: "trash") }
                }.buttonStyle(.bordered)
            }
        }
    }
    private var startupPreview: some View {
        ZStack {
            Color.black
            if let image = picture.project.startup?.cgImage { Image(decorative: image, scale: 1).resizable().interpolation(.none) }
            else { Text("导入一张开机图").foregroundStyle(.white.opacity(0.65)) }
        }.frame(width: 352.5, height: 352.5)
    }
    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard !store.isBusy, let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
            Task { @MainActor in
                guard !store.isBusy else { return }
                if ["pic", "k2project"].contains(url.pathExtension.lowercased()) { picture.open(url) }
                else if ["bmp", "png", "jpg", "jpeg"].contains(url.pathExtension.lowercased()) { picture.importImage(url, kind: startup ? .startup : .background) }
                else { picture.error = "支持 .pic、.k2project、BMP、PNG 或 JPEG 文件" }
            }
        }
        return true
    }
}

struct DialEditorView: View {
    @ObservedObject var picture: PictureStore
    @Binding var scale: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 10) {
                Label("240 × 240", systemImage: "viewfinder")
                    .font(.callout).foregroundStyle(.primary)
                Spacer(minLength: 12)
                Toggle("使用背景", isOn: Binding(
                    get: { picture.project.usesBackground },
                    set: { enabled in picture.edit { $0.useBackground = enabled } }
                )).toggleStyle(.checkbox).fixedSize()
                    .help("勾选后先写入背景再写布局；取消勾选可直接写布局")
                Button { picture.chooseImage(.background) } label: {
                    Label("导入背景", systemImage: "photo.badge.plus")
                }.buttonStyle(.bordered).disabled(!picture.project.usesBackground)
                Menu {
                    Button { picture.edit { $0.background = nil } } label: {
                        Label("移除背景", systemImage: "trash")
                    }.disabled(picture.project.background == nil)
                    Button { picture.export(.background) } label: {
                        Label("导出 BMP", systemImage: "square.and.arrow.up")
                    }.disabled(picture.project.background == nil)
                } label: { Label("背景操作", systemImage: "ellipsis.circle") }
                Picker("缩放", selection: $scale) {
                    Text("100%").tag(1.0)
                    Text("150%").tag(1.5)
                    Text("200%").tag(2.0)
                }.frame(width: 110)
            }.controlSize(.regular)
            DialCanvas(picture: picture, scale: scale)
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .center)
            DialElementTable(picture: picture)
        }
    }
}
