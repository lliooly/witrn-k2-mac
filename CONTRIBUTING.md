# 参与贡献

欢迎改进维简 Mac 的使用体验、协议说明、错误处理和测试。文档、复现步骤、兼容性反馈与代码一样有价值。贡献者和上游来源见 [CONTRIBUTORS](CONTRIBUTORS.md)。

## 先找对入口

- 应用、安装、曲线记录与 UI 问题：在[本仓库](https://github.com/lliooly/witrn-k2-mac/issues)报告。
- HID 命令、文件格式、研究证据与通用接口：参考 [reverse 仓库](https://github.com/lliooly/WITRN-K2-REVERSE)，跨仓库改动遵循[联动约定](docs/repository-map.md)。
- 安全漏洞：按 [SECURITY](SECURITY.md) 使用私密渠道，不在公开 Issue 中提供可利用细节。

## 开发环境

Python 3.9+；Swift 包声明 tools version 5.9，运行目标为 macOS 13+。当前 UI 使用 macOS 26 API（按系统版本保护），编译需要 Xcode 26 或更新版本及其 SDK。应用打包另外需要 Python 3.9 和 `requirements-app.txt`。先做离线检查，无需设备或厂商程序。

```sh
python3 -m unittest discover -s tests -v
python3 script/check_docs.py
CLANG_MODULE_CACHE_PATH="$PWD/build/ModuleCache" \
SWIFT_MODULE_CACHE_PATH="$PWD/build/ModuleCache" \
swift test --package-path macos --disable-sandbox \
  --scratch-path "$PWD/build/swift-tests" --cache-path "$PWD/build/swift-cache" --manifest-cache local
```

截图使用现有 `UISnapshotHarness`；设置 `K2_SNAPSHOT_DIR` 后运行指定渲染测试。来源和截图规则见 [assets/README](docs/assets/README.md)。离线 CI 覆盖 Python、Swift 与文档，不连接设备；截图和完整打包在本地单独检查。

## 修改与验证

- 保持 Python 兼容性；新增依赖应说明必要性和许可。
- 协议、固件、资源写入改动需说明证据来源、地址范围、失败状态与验证边界；补充有意义的合成样本和故障覆盖。
- 保留未知字段、未使用槽位与同扇区其他数据；不要在读取失败后自动修复回写。
- UI 改动检查无设备状态、窄窗口、浅 / 深色、键盘操作，以及任务期间的禁用与关闭保护。
- 测试通过不代表硬件兼容。真实设备验证需单独明确操作范围并保留本地备份。

## PR 与署名

标题建议使用 Conventional Commits，可用中文，例如 `fix(表盘): 保留布局未知字段`。PR 写明具体问题、最终行为、验证结果和剩余限制；需要时同步更新 CHANGELOG。

提交前检查 diff 和 `git status`。禁止提交厂商二进制、固件、设备备份、原始通信日志、序列号、密钥及私人路径；反馈截图同样需要脱敏。新增第三方材料须标注来源及许可，并更新 NOTICE。

提交原创贡献表示同意按本仓库 MIT 许可分发该贡献，不要求转让版权。保留原有版权及第三方许可；新贡献者可在 PR 中补充署名偏好。请围绕可复现的问题讨论，尊重其他参与者。
