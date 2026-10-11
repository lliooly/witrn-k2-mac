import SwiftUI

struct ResourceTutorialOverlay: View {
    @ObservedObject var store: UpdaterStore
    let kind: ResourceTutorialKind
    let usesBackground: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.24).ignoresSafeArea()
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: kind == .emark ? "cable.connector" : (kind == .dial ? "speedometer" : "photo"))
                            .font(.title2).foregroundStyle(.orange)
                        Text(kind.title).font(.title2.weight(.semibold))
                        Spacer()
                    }
                    ViewThatFits(in: .vertical) {
                        tutorialContent(screenshotWidth: 280)
                        tutorialContent(screenshotWidth: 210)
                        tutorialContent(screenshotWidth: 180)
                        tutorialContent(screenshotWidth: 140)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    HStack(spacing: 12) {
                        Spacer()
                        Button("取消") { store.cancelResourceTutorial() }
                            .keyboardShortcut(.cancelAction)
                            .modifier(TutorialActionButtonSurface())
                        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
                            let remaining = store.tutorialGate.remaining()
                            Button(remaining > 0 ? "确认（\(remaining)s）" : "确认") {
                                store.confirmResourceTutorial()
                            }
                            .disabled(remaining > 0)
                            .modifier(TutorialActionButtonSurface(prominent: true))
                            .accessibilityLabel(remaining > 0 ? "阅读倒计时，剩余 \(remaining) 秒" : "确认已阅读教程")
                        }
                    }.buttonStyle(.plain)
                }
                .padding(24).frame(width: min(1120, geometry.size.width - 48))
                .frame(height: min(840, max(240, geometry.size.height - 48)))
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12), lineWidth: 1))
                .shadow(color: .black.opacity(0.18), radius: 30, y: 12)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityAddTraits(.isModal)
    }

    private func tutorialContent(screenshotWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TutorialScreenshot(kind: kind, usesBackground: usesBackground, thumbnailWidth: screenshotWidth)
            if kind == .dial {
                Text(usesBackground ? "当前流程：背景 → 重新进入 DFU → 布局" : "当前流程：仅写入布局，不写背景")
                    .font(.callout.weight(.semibold)).foregroundStyle(.blue)
                dialSteps
            } else if kind == .emark { emarkSteps }
            else { startupSteps }
            Divider()
            Text("每次写入都会先双遍备份目标扇区，再写入并完整读回校验。等待应用提示完成，期间保持连接。")
                .font(.callout).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top) {
                Text("设备操作参考：JohnScotttt · WITRN K2 快速查询手册 " + (kind == .emark ? "§6" : "§5.1、§5.2、§7.1"))
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Link("查看原文 · GPL-3.0", destination: kind.referenceURL).font(.caption)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var emarkSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            step(1, "准备配置", "在参数区编辑线材身份，或导入 .wtemark 文件，加入写入列表。确认列表内容与默认组。")
            step(2, "进入 DFU 并读取", "按住减号键，从 CC1/HID 口连接电脑。在右栏选择 DFU 维护并连接；「读取」菜单可读取设备配置或 copied emark 复制数据。")
            step(3, "写入配置列表", "点击右栏「写入」并确认，等待备份、写入和校验完成。本次列表会覆盖设备原有的自定义配置列表。")
            step(4, "选择虚拟 E-Mark", "写入完成后正常上电，在 K2 的虚拟 E-Mark 菜单中选择配置。虚拟身份不改变线材的实际能力。")
        }
    }

    private var dialSteps: some View {
        Group {
            if usesBackground {
                step(1, "准备背景与布局", "当前已勾选「使用背景」。设备固件需为 V2.9 或更新版本，导入 240 × 240 背景图片，编辑元素坐标、颜色及字号，并保存工程；外部布局参数可通过「打开」导入 .pic。")
                dfuStep
                step(3, "先写入表盘背景", "在「设备操作 → 表盘背景」点击「写入」，确认备份并写入，等待完成。背景成功写入并校验前，布局写入保持禁用。")
                step(4, "重新进入 DFU，写入布局", "背景写入后设备退出 DFU。按第 2 步重新连接并确认 K2 已识别，再在「表盘布局」点击「写入」，等待完成。")
                themeStep(5)
            } else {
                step(1, "准备表盘布局", "当前未勾选「使用背景」。设备固件需为 V2.9 或更新版本，编辑元素坐标、颜色及字号并保存工程；也可通过「打开」导入 .pic。不需要导入背景，也不需要先写入空白背景。")
                dfuStep
                step(3, "直接写入布局", "在「设备操作 → 表盘布局」点击「写入」，确认备份并写入，等待完成。本次只备份、写入和校验布局区，不写入或清除背景区，设备原有背景保留。")
                themeStep(4)
                Text("若希望显示纯黑背景，请关闭教程，勾选「使用背景」并导入 240 × 240 的纯黑图片，再按背景先写、布局后写的流程操作。")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }
    private var dfuStep: some View {
        step(2, "进入 DFU 并连接", "断开设备电源，按住减号键，将电脑的数据线接入 K2 的 CC1/HID 口。在右栏选择「DFU 维护」并连接，确认 K2 已识别。")
    }
    private func themeStep(_ number: Int) -> some View {
        step(number, "开启主题屏", "写入完成后拔线，正常上电。在 K2 第四页的「设置 → 主题屏开关」开启自定义表盘，再检查读数位置与设备上的实际显示。")
    }
    private var startupSteps: some View {
        Group {
            step(1, "准备开机图片", "设备固件需为 V2.9 或更新版本。导入图片并确认裁剪，本应用将图片处理为 235 × 235 像素；可使用 BMP、PNG 或 JPEG。")
            step(2, "进入 DFU 并连接", "断开设备电源，按住减号键，将电脑的数据线接入 K2 的 CC1/HID 口。在右栏选择「DFU 维护」并连接，确认 K2 已识别。")
            step(3, "写入开机图", "在「设备操作 → 开机图」点击「写入」，确认备份并写入，等待完成。开机图不需要上传表盘布局，也不需要开启主题屏开关。")
            step(4, "重新上电查看", "写入完成后拔线，正常上电查看开机图。若需再次写入，先重新进入 DFU。")
        }
    }
    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(number)).font(.callout.weight(.semibold)).frame(width: 28, height: 28)
                .background(.orange.opacity(0.15), in: Circle()).foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Let the system own glass rendering, press interaction and accessibility.
struct TutorialActionButtonSurface: ViewModifier {
    var prominent = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                content.buttonStyle(.glassProminent).controlSize(.large).buttonBorderShape(.capsule)
            } else {
                content.buttonStyle(.glass).controlSize(.large).buttonBorderShape(.capsule)
            }
        } else {
            if prominent {
                content.buttonStyle(.borderedProminent).controlSize(.large)
            } else {
                content.buttonStyle(.bordered).controlSize(.large)
            }
        }
    }
}
