import SwiftUI

/// All regions use pixels in the final, cropped screenshot (1090 × 1060).
/// A number refers to the same step in ResourceTutorialOverlay; several regions
/// may belong to one step. Device-only steps intentionally have no UI region.
struct TutorialScreenshot: View {
    let kind: ResourceTutorialKind
    let usesBackground: Bool
    var thumbnailWidth: CGFloat = 360
    @State private var enlarged = false

    private struct Mark: Identifiable {
        let id: String
        let step: Int
        let rect: CGRect
        let label: String
    }

    private func mark(_ id: String, _ step: Int, _ x: CGFloat, _ y: CGFloat,
                      _ width: CGFloat, _ height: CGFloat, _ label: String) -> Mark {
        Mark(id: id, step: step, rect: CGRect(x: x, y: y, width: width, height: height), label: label)
    }

    private var marks: [Mark] {
        let connection = mark("connection", 2, 838, 175, 242, 127, "DFU 维护与连接设备")
        switch kind {
        case .dial:
            return [
                mark("background", 1, 370, 75, 198, 36, "使用背景与导入背景"),
                mark("elements", 1, 16, 520, 798, 430, "表盘元素编辑区"),
                connection,
                // Background and layout are separate steps when a background is used.
                mark("layout", usesBackground ? 4 : 3, 839, 509, 122, 61, "表盘布局写入")
            ] + (usesBackground ? [mark("write-background", 3, 839, 430, 122, 61, "表盘背景写入")] : [])
        case .startup:
            return [
                mark("import", 1, 700, 75, 114, 36, "导入图片"),
                mark("preview", 1, 232, 142, 365, 365, "开机图预览"),
                connection,
                mark("write", 3, 839, 430, 122, 61, "开机图写入")
            ]
        case .emark:
            return [
                mark("list", 1, 420, 76, 394, 238, "写入列表与默认组"),
                mark("parameters", 1, 16, 329, 798, 257, "配置名称与身份参数"),
                connection,
                mark("read", 2, 839, 400, 80, 37, "读取菜单"),
                mark("write", 3, 923, 400, 60, 37, "写入配置列表")
            ]
        }
    }

    private var screenshot: NSImage? {
        let name = kind == .dial && !usesBackground ? "dial-layout" : kind.rawValue
        guard let url = Bundle.module.url(forResource: "tutorial-\(name)", withExtension: "png",
                                          subdirectory: "Resources/Tutorials") else { return nil }
        return NSImage(contentsOf: url)
    }

    var body: some View {
        VStack(spacing: 8) {
            Button { enlarged = true } label: {
                annotatedImage.frame(maxWidth: thumbnailWidth).frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(kind.title)操作截图，编号对应下方教程步骤，点击放大")
            HStack(alignment: .top) {
                Text("图中编号对应下方教程步骤 · 未连接设备的界面示例")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 8)
                Button { enlarged = true } label: {
                    Label("放大查看", systemImage: "arrow.up.left.and.arrow.down.right")
                }.buttonStyle(.borderless).font(.caption)
            }
        }
        .sheet(isPresented: $enlarged) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(kind.title).font(.headline)
                    Spacer()
                    Button("关闭") { enlarged = false }.keyboardShortcut(.cancelAction)
                }
                ScrollView { annotatedImage }
                Text("图中编号与教程步骤一致，关闭图片后继续阅读。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(minWidth: 800, idealWidth: 1100, maxWidth: 1100,
                               minHeight: 600, idealHeight: 820, maxHeight: 820)
        }
    }

    var annotatedImage: some View {
        Group {
            if let screenshot {
                // Constrain the canvas itself to the image ratio so the overlay
                // never measures an aspect-fit's empty margins.
                GeometryReader { geometry in
                    Image(nsImage: screenshot).resizable()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    ForEach(marks) { mark in
                        let badgeSize = min(23, max(8, geometry.size.width * 0.06))
                        let rect = CGRect(x: mark.rect.minX / 1090 * geometry.size.width,
                                          y: mark.rect.minY / 1060 * geometry.size.height,
                                          width: mark.rect.width / 1090 * geometry.size.width,
                                          height: mark.rect.height / 1060 * geometry.size.height)
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                        Text("\(mark.step)").font(.system(size: badgeSize * 0.52, weight: .bold))
                            .foregroundStyle(.black).frame(width: badgeSize, height: badgeSize)
                            .background(Color.orange, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: badgeSize > 16 ? 2 : 1))
                            .position(x: max(badgeSize / 2, rect.minX), y: max(badgeSize / 2, rect.minY))
                    }.allowsHitTesting(false)
                }
                .aspectRatio(1090.0 / 1060.0, contentMode: .fit)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("界面截图：" + marks.map { "步骤\($0.step)，\($0.label)" }.joined(separator: "；"))
            } else {
                Label("截图未能加载，请按下方教程步骤操作", systemImage: "photo")
            }
        }
    }
}
