# 首页图片来源

首页应用图标来自 `script/generate_icon.swift` 生成的本项目图标。

`monitor.png`、`dial.png`、`startup.png`、`emark.png` 由当前源码的 SwiftUI 页面渲染生成，使用 `macos/Tests/K2UpdaterTests/UISnapshotHarness.swift`；不连接硬件，不读写设备，也不访问官网。表盘显示固定预览读数，未连接设备是实际截图状态。

重新生成示例：

```sh
K2_README_CAPTURE_DIR="$PWD/build/readme-final" K2_COMPOSITED_SNAPSHOTS=1 \
CLANG_MODULE_CACHE_PATH="$PWD/build/ModuleCache" \
SWIFT_MODULE_CACHE_PATH="$PWD/build/ModuleCache" \
swift test --package-path macos --disable-sandbox \
  --scratch-path "$PWD/build/swift-tests" --cache-path "$PWD/build/swift-cache" \
  --manifest-cache local --filter UISnapshotHarness/testRenderReadmePages
```

从输出选择 `monitor-composited.png`、`dial-composited.png`、`startup-composited.png`、`emark-composited.png`，去掉文件名中的 `-composited` 后复制到本目录。系统窗口截图需要屏幕录制权限；未使用窗口合成的离屏图不能完整呈现原生玻璃控件。E-Mark 页展示本应用模板，非设备读取结果。请先目视检查是否截断、是否含个人信息、是否符合当前 UI；不要用生成式图片替代真实操作界面。固件页可能展示第三方 DFU 图，本次首页不复制该截图。
