import AppKit
import SwiftUI
import XCTest
@testable import K2Updater
@testable import K2Core

/// Development-only offscreen renderer used to inspect layout while refactoring.
/// Set K2_SNAPSHOT_DIR to write PNGs; otherwise the test is a no-op.
final class UISnapshotHarness: XCTestCase {
    @MainActor
    func testRenderSidebarMaterials() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for scheme: ColorScheme in [.light, .dark] {
            applyAppearance(scheme)
            render(ContentView(store: UpdaterStore(), picture: PictureStore(), emark: EmarkStore(),
                               monitor: MonitorStore(), selection: .constant(.dial)),
                   size: CGSize(width: 1280, height: 880), name: "sidebars-\(scheme)",
                   scheme: scheme, dir: dir, nativeTitlebar: true)
        }
    }

    @MainActor
    func testRenderWorkspaceScrollEdges() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for scheme: ColorScheme in [.light, .dark] {
            applyAppearance(scheme)
            for offset: CGFloat in [0, 180] {
                render(ContentView(store: UpdaterStore(), picture: PictureStore(), emark: EmarkStore(),
                                   monitor: MonitorStore(), selection: .constant(.firmware)),
                       size: CGSize(width: 1280, height: 720),
                       name: "scroll-edge-\(scheme)-\(Int(offset))", scheme: scheme, dir: dir,
                       scrollOffset: offset, nativeTitlebar: true)
            }
        }
    }

    @MainActor
    func testRenderFirmwareWizard() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let updater = UpdaterStore()
        updater.devices = [DeviceInfo(pathHex: "test", productString: "K2", manufacturerString: nil,
                                     serialNumber: nil, interfaceNumber: 0)]
        updater.selectedPath = "test"
        updater.dfuConfirmed = true
        updater.identity = IdentityInfo(bootStrings: ["K2"], infoSha256: "", confirmedK2: true,
                                        currentVersion: "5.8", currentMarkerHex: nil)
        updater.firmware = FirmwareInfo(model: "K2", version: "5.9", date: "2026-10-10",
                                       appSize: 100000, fileSha256: "", eraseSectors: 49)
        for scheme: ColorScheme in [.light, .dark] {
            applyAppearance(scheme)
            for step in 0...3 {
                updater.firmwareWizardStep = step
                render(FirmwareView(store: updater, showConnection: {}).padding(24),
                       size: CGSize(width: 740, height: 720),
                       name: "firmware-\(scheme)-\(step)", scheme: scheme, dir: dir,
                       settleDelay: step == 3 ? 1 : 0.5)
            }
            updater.firmwareWizardStep = 2
            updater.isBusy = true
            updater.status = "读回校验"
            updater.stage = "verify"
            updater.firmwareProgressPhase = .upgrade
            updater.tracePath = ProcessInfo.processInfo.environment["K2_FIRMWARE_SNAPSHOT_TRACE"]
            updater.firmwareTaskTracePath = updater.tracePath
            updater.total = 100
            updater.current = 60
            render(FirmwareView(store: updater, showConnection: {}).padding(24),
                   size: CGSize(width: 620, height: 720), name: "firmware-\(scheme)-busy",
                   scheme: scheme, dir: dir)
            updater.isBusy = false
            updater.identity = nil
            updater.dfuConfirmed = false
            updater.errorMessage = "设备连接已断开，固件写入未完成"
            render(FirmwareView(store: updater, showConnection: {}).padding(24),
                   size: CGSize(width: 620, height: 720), name: "firmware-\(scheme)-failure",
                   scheme: scheme, dir: dir)
            updater.errorMessage = nil
            updater.dfuConfirmed = true
            updater.identity = IdentityInfo(bootStrings: ["K2"], infoSha256: "", confirmedK2: true,
                                            currentVersion: "5.8", currentMarkerHex: nil)
        }
    }

    @MainActor
    private func applyAppearance(_ scheme: ColorScheme) {
        NSApplication.shared.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
    }

    @MainActor
    func testRenderMonitor() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let monitor = MonitorStore()
        let updater = UpdaterStore()
        let picture = PictureStore()
        let emark = EmarkStore()
        let scheme: ColorScheme = ProcessInfo.processInfo.environment["K2_SNAPSHOT_LIGHT"] != nil ? .light : .dark
        applyAppearance(scheme)

        render(ContentView(store: updater, picture: picture, emark: emark, monitor: monitor,
                           selection: .constant(.monitor)),
               size: CGSize(width: 1280, height: 880), name: "01-content-monitor", scheme: scheme, dir: dir)

        render(MonitorWorkspace(monitor: monitor, updater: updater, showConnection: {},
                                workspace: .constant("live"), extraReadings: .constant(false),
                                statisticsExpanded: .constant(false)),
               size: CGSize(width: 800, height: 860), name: "02-monitor-live", scheme: scheme, dir: dir)

        render(MonitorWorkspace(monitor: monitor, updater: updater, showConnection: {},
                                workspace: .constant("history"), extraReadings: .constant(true),
                                statisticsExpanded: .constant(false)),
               size: CGSize(width: 800, height: 860), name: "03-monitor-history", scheme: scheme, dir: dir)

        // Minimum usable width: the single control lines must not wrap.
        render(MonitorWorkspace(monitor: monitor, updater: updater, showConnection: {},
                                workspace: .constant("live"), extraReadings: .constant(false),
                                statisticsExpanded: .constant(false)),
               size: CGSize(width: 620, height: 860), name: "04-monitor-narrow", scheme: scheme, dir: dir)

        render(LocalRecordsCard(records: Self.records, busy: false, connected: false,
                                onRefresh: {}, onOpen: { _ in }, onClose: {}),
               size: CGSize(width: 760, height: 190), name: "06-local-records", scheme: scheme, dir: dir)

        render(LocalRecordsCard(records: [], busy: false, connected: false,
                                onRefresh: {}, onOpen: { _ in }, onClose: {}),
               size: CGSize(width: 760, height: 120), name: "07-local-records-empty", scheme: scheme, dir: dir)
    }

    @MainActor
    func testRenderDenseMonitorCharts() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let points = try MonitorChartTests.samples()
        applyAppearance(.light)
        render(MonitorPlotExport(points: points, channels: [.voltage, .current, .tempOut],
                                 start: 0, end: 125),
               size: CGSize(width: 1100, height: 640), name: "08-dense-charts", scheme: .light, dir: dir)
    }

    @MainActor
    func testRenderCustomZoomAndTutorials() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        applyAppearance(.dark)
        for scale in [1.0, 1.5, 2.0] {
            render(ScrollView { DialEditorView(picture: PictureStore(), scale: .constant(scale)).padding(20) },
                   size: CGSize(width: 788, height: 1000), name: "dial-zoom-\(scale)",
                   scheme: .dark, dir: dir)
        }
        for kind in ResourceTutorialKind.allCases {
            for usesBackground in kind == .dial ? [false, true] : [false] {
                let store = UpdaterStore()
                let picture = PictureStore()
                picture.edit { $0.useBackground = usesBackground }
                store.openResourceTutorial(kind)
                let name = "tutorial-\(kind)" + (usesBackground ? "-background" : "")
                render(ContentView(store: store, picture: picture, emark: EmarkStore(), monitor: MonitorStore(),
                                   selection: .constant(kind == .emark ? .emark : (kind == .dial ? .dial : .startup))),
                       size: CGSize(width: 1280, height: 880), name: name,
                       scheme: .dark, dir: dir, nativeTitlebar: true)
                render(ContentView(store: store, picture: picture, emark: EmarkStore(), monitor: MonitorStore(),
                                   selection: .constant(kind == .emark ? .emark : (kind == .dial ? .dial : .startup))),
                       size: CGSize(width: 1280, height: 880), name: name + "-ready",
                       scheme: .dark, dir: dir, nativeTitlebar: true, settleDelay: kind.readingSeconds + 0.5)
            }
        }
    }

    @MainActor
    func testRenderBackgroundChoices() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let image = try PixelImage(width: 240, height: 240,
                                  rgba: Data(Array(repeating: [UInt8(40), 70, 90, 255], count: 240 * 240).flatMap { $0 }))
        for scheme: ColorScheme in [.light, .dark] {
            applyAppearance(scheme)
            let picture = PictureStore()
            picture.applyImage(image, kind: .background)
            for enabled in [true, false] {
                picture.edit { $0.useBackground = enabled }
                render(ScrollView { DialEditorView(picture: picture, scale: .constant(1.5)).padding(20) },
                       size: CGSize(width: 788, height: 860), name: "background-\(scheme)-\(enabled)",
                       scheme: scheme, dir: dir)
            }
        }
    }

    @MainActor
    func testRenderLargeTutorialCards() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for scheme: ColorScheme in [.light, .dark] {
            applyAppearance(scheme)
            for height: CGFloat in [720, 880] {
                for kind in ResourceTutorialKind.allCases {
                    for background in kind == .dial ? [false, true] : [false] {
                        let store = UpdaterStore()
                        store.openResourceTutorial(kind)
                        render(ResourceTutorialOverlay(store: store, kind: kind, usesBackground: background),
                               size: CGSize(width: height == 720 ? 1100 : 1280, height: height),
                               name: "large-\(kind)-\(background)-\(scheme)-\(Int(height))",
                               scheme: scheme, dir: dir)
                    }
                }
            }
        }
    }

    @MainActor
    func testRenderAnnotatedTutorials() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for scheme: ColorScheme in [.light, .dark] {
            applyAppearance(scheme)
            for kind in ResourceTutorialKind.allCases {
                render(TutorialScreenshot(kind: kind, usesBackground: true).annotatedImage.padding(24),
                       size: CGSize(width: 1138, height: 1108), name: "annotation-detail-\(kind)-\(scheme)",
                       scheme: scheme, dir: dir)
                render(ScrollView { TutorialScreenshot(kind: kind, usesBackground: true).padding(24) },
                       size: CGSize(width: 680, height: 900), name: "annotated-\(kind)-\(scheme)",
                       scheme: scheme, dir: dir)
            }
        }
    }

    /// Rebuild bundled tutorial screenshots from the actual views, without device I/O.
    @MainActor
    func testCaptureTutorialSources() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_TUTORIAL_CAPTURE_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        applyAppearance(.light)
        for section in [ToolSection.dial, .startup, .emark] {
            for background in section == .dial ? [true, false] : [false] {
                let picture = PictureStore()
                picture.edit { $0.useBackground = background }
                let emark = EmarkStore()
                emark.add()
                let name = section == .dial ? (background ? "dial" : "dial-layout") : section == .startup ? "startup" : "emark"
                render(ContentView(store: UpdaterStore(), picture: picture, emark: emark,
                                   monitor: MonitorStore(), selection: .constant(section)),
                       size: CGSize(width: 1280, height: 1060), name: "tutorial-\(name)",
                       scheme: .light, dir: dir, nativeTitlebar: true, cropLeading: 190)
            }
        }
    }

    @MainActor
    func testRenderCustomPages() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        applyAppearance(.dark)
        for section in [ToolSection.dial, .startup] {
            for width: CGFloat in [1100, 1280, 1600] {
                for offset: CGFloat in section == .dial ? [0, 2000] : [0] {
                    render(ContentView(store: UpdaterStore(), picture: PictureStore(), emark: EmarkStore(),
                                       monitor: MonitorStore(), selection: .constant(section)),
                           size: CGSize(width: width, height: 720),
                           name: "custom-\(section)-\(Int(width))-\(Int(offset))", scheme: .dark, dir: dir,
                           scrollOffset: offset, nativeTitlebar: true)
                }
            }
        }
    }

    @MainActor
    func testRenderEmarkWorkspace() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let emark = EmarkStore()
        emark.add()
        emark.add()
        emark.update { try $0.setName("USB4 cable") }
        emark.copied = .standard
        for scheme: ColorScheme in [.light, .dark] {
            applyAppearance(scheme)
            for width: CGFloat in [1100, 1280, 1600] {
                render(ContentView(store: UpdaterStore(), picture: PictureStore(), emark: emark,
                                   monitor: MonitorStore(), selection: .constant(.emark)),
                       size: CGSize(width: width, height: 880), name: "emark-\(scheme)-\(Int(width))",
                       scheme: scheme, dir: dir, nativeTitlebar: true)
            }
            let store = UpdaterStore()
            store.openResourceTutorial(.emark)
            render(ContentView(store: store, picture: PictureStore(), emark: emark,
                               monitor: MonitorStore(), selection: .constant(.emark)),
                   size: CGSize(width: 1280, height: 880), name: "emark-tutorial-\(scheme)",
                   scheme: scheme, dir: dir, nativeTitlebar: true)
        }
    }

    @MainActor
    func testRenderOtherPages() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_SNAPSHOT_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let monitor = MonitorStore()
        let updater = UpdaterStore()
        let picture = PictureStore()
        let emark = EmarkStore()
        let scheme: ColorScheme = ProcessInfo.processInfo.environment["K2_SNAPSHOT_LIGHT"] != nil ? .light : .dark
        applyAppearance(scheme)

        for (name, section) in [("10-content-firmware", ToolSection.firmware),
                                ("11-content-emark", .emark),
                                ("12-content-dial", .dial),
                                ("13-content-startup", .startup)] {
            render(ContentView(store: updater, picture: picture, emark: emark, monitor: monitor,
                               selection: .constant(section)),
                   size: CGSize(width: 1280, height: 880), name: name, scheme: scheme, dir: dir)
        }
    }

    /// Public README captures use the window compositor for native glass controls.
    @MainActor
    func testRenderReadmePages() throws {
        guard let dir = ProcessInfo.processInfo.environment["K2_README_CAPTURE_DIR"] else { return }
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        applyAppearance(.light)
        for (name, section) in [("monitor", ToolSection.monitor), ("dial", .dial),
                                ("startup", .startup), ("emark", .emark)] {
            let emark = EmarkStore()
            if section == .emark { emark.add() }
            render(ContentView(store: UpdaterStore(), picture: PictureStore(), emark: emark,
                               monitor: MonitorStore(), selection: .constant(section)),
                   size: CGSize(width: 1280, height: 1040), name: name, scheme: .light,
                   dir: dir, nativeTitlebar: true)
        }
    }

    static var records: [MonitorRecord] {
        [
            MonitorRecord(path: "/Users/k2/Recordings/K2-2026-10-09-2041.sqlite", count: 18422,
                          start: 0, end: 1842.5, metadata: ["closed": "1"]),
            MonitorRecord(path: "/Users/k2/Recordings/K2-2026-10-08-1130.sqlite", count: 9210,
                          start: 0, end: 921.0, metadata: ["closed": "0"])
        ]
    }

    @MainActor
    private func render(_ view: some View, size: CGSize, name: String,
                        scheme: ColorScheme, dir: String, scrollOffset: CGFloat? = nil,
                        nativeTitlebar: Bool = false, settleDelay: TimeInterval = 0.5, cropLeading: CGFloat = 0) {
        // Without an explicit opaque backdrop the capture keeps alpha, and the
        // default-coloured text becomes invisible against a white preview.
        let root = view
            .environment(\.colorScheme, scheme)
            .background(Color(nsColor: .windowBackgroundColor))
        let hosting = NSHostingView(rootView: root)
        hosting.frame = CGRect(origin: .zero, size: size)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: nativeTitlebar ? [.titled, .closable, .resizable, .fullSizeContentView] : [.borderless],
                              backing: .buffered, defer: false)
        if nativeTitlebar {
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
        }
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = hosting
        let composite = nativeTitlebar && ProcessInfo.processInfo.environment["K2_COMPOSITED_SNAPSHOTS"] == "1"
        if composite { window.orderFront(nil) }
        defer { if composite { window.orderOut(nil) } }
        window.layoutIfNeeded()
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(settleDelay))
        hosting.layoutSubtreeIfNeeded()
        if let scrollOffset {
            func descendants(_ view: NSView) -> [NSScrollView] {
                (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap(descendants)
            }
            let scroll = descendants(hosting)
                .filter { ($0.documentView?.frame.height ?? 0) > $0.contentView.bounds.height }
                .max { $0.frame.width < $1.frame.width }
            if let scroll, let document = scroll.documentView {
                if nativeTitlebar && scrollOffset == 0 {
                    XCTAssertGreaterThanOrEqual(scroll.contentInsets.top, LayoutMetrics.navigationSidebarHeaderHeight,
                                                "The initial content must reserve the full workspace toolbar height.")
                    XCTAssertLessThanOrEqual(scroll.contentView.bounds.minY, -LayoutMetrics.navigationSidebarHeaderHeight,
                                             "The wizard must begin below the toolbar in a titled window.")
                }
                let maximum = max(0, document.frame.height - scroll.contentView.bounds.height)
                scroll.contentView.scroll(to: CGPoint(x: 0, y: min(scroll.contentView.bounds.minY + scrollOffset, maximum)))
                scroll.reflectScrolledClipView(scroll.contentView)
                RunLoop.main.run(until: Date().addingTimeInterval(0.5))
                hosting.layoutSubtreeIfNeeded()
            }
        }
        if name.hasPrefix("sidebars-") {
            func sidebarBackdrops(_ view: NSView) -> [NSSplitView] {
                ((view as? NSSplitView).map { [$0] } ?? []) + view.subviews.flatMap(sidebarBackdrops)
            }
            let backdrops = sidebarBackdrops(hosting).filter {
                let rect = hosting.convert($0.bounds, from: $0)
                return rect.midX > size.width - LayoutMetrics.connectionSidebarWidth
            }
            XCTAssertFalse(backdrops.isEmpty)
            let local = NSPoint(x: size.width - 180, y: 95)
            let point = hosting.superview!.convert(local, from: hosting)
            let hit = hosting.hitTest(point)
            XCTAssertNotNil(hit, "The right sidebar must remain interactive")
            for backdrop in backdrops {
                XCTAssertFalse(hit?.isDescendant(of: backdrop) == true,
                               "The sidebar background must not intercept controls")
            }
        }
        if name.hasPrefix("custom-") {
            func exportButtons(_ view: NSView) -> [ToolbarExportMenuButton] {
                (view as? ToolbarExportMenuButton).map { [$0] } ?? view.subviews.flatMap(exportButtons)
            }
            let buttons = exportButtons(hosting).filter { !$0.isHidden && $0.visibleRect.width > 0 }
            XCTAssertFalse(buttons.isEmpty, "Export button must be present in \(name)")
            for button in buttons {
                XCTAssertEqual(button.bounds.width, 56, accuracy: 0.5)
                XCTAssertEqual(button.bounds.height, 40, accuracy: 0.5)
                for x: CGFloat in [1, 28, 50, 55] {
                    let point = hosting.superview!.convert(NSPoint(x: x, y: 20), from: button)
                    let hit = hosting.hitTest(point)
                    XCTAssertTrue(hit === button, "Entire export capsule must receive clicks in \(name), x=\(x)")
                }
            }
        }
        if composite {
            let capture = Process()
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-l", String(window.windowNumber),
                                 URL(fileURLWithPath: dir).appendingPathComponent("\(name)-composited.png").path]
            do {
                try capture.run()
                capture.waitUntilExit()
                XCTAssertEqual(capture.terminationStatus, 0, "Window compositor capture failed.")
            } catch { XCTFail("Window compositor capture failed: \(error)") }
        }
        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else {
            XCTFail("no bitmap for \(name)"); return
        }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        let outputRep: NSBitmapImageRep
        if cropLeading > 0, let cg = rep.cgImage {
            let ratio = CGFloat(cg.width) / size.width
            let crop = CGRect(x: cropLeading * ratio, y: 0,
                              width: (size.width - cropLeading) * ratio, height: CGFloat(cg.height))
            guard let cropped = cg.cropping(to: crop) else { XCTFail("Cannot crop capture"); return }
            outputRep = NSBitmapImageRep(cgImage: cropped)
        } else { outputRep = rep }
        guard let png = outputRep.representation(using: .png, properties: [:]) else {
            XCTFail("no png for \(name)"); return
        }
        let url = URL(fileURLWithPath: dir).appendingPathComponent("\(name).png")
        try? png.write(to: url)
        print("wrote \(url.path)")
    }
}
