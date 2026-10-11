# 发布检查表

本页区分开发完成和公开分发。离线测试、签名检查及硬件验证分别记录；CI 不自动发布安装包，也不声称通过实机验收。

## 源码与文档

- [ ] 更新 `script/package_app.py` 中的版本 / 构建号，并同步 README 与 CHANGELOG。
- [ ] Python、Swift 和 `python3 script/check_docs.py` 检查通过。
- [ ] 复核所有待发布改动；确认没有厂商程序、固件、设备日志、备份、研究嵌套仓库或个人数据。
- [ ] 协议改动关联 reverse 仓库的具体提交，并更新验证边界。
- [ ] 截图来自本次 UI，标明示例数据，未展示序列号或私人路径。

## 构建与产物

```sh
./script/build_and_run.sh --build-only
.venv-app/bin/python script/validate_app.py 'dist/K2 Updater.app'
```

- [ ] 验证移动后的应用、内置后台、HID / SQLite、两种架构、签名与完整离线模拟流程。
- [ ] 核对 LICENSE、NOTICE、第三方许可及教程资源已打包。
- [ ] 在可用真实环境中验证启动与关键交互；列明 Intel、最低系统与硬件覆盖的缺口。
- [ ] 使用 Developer ID 分发时完成签名、公证和票据核对；若仍为 ad-hoc，在发布说明中明确写出。

## 发布附件

先完成检查，再创建与版本对应的 Git tag 和 GitHub Release。版本相同的附件不得静默替换；修订时递增版本或构建号并注明差异。

```sh
# 只打包生成的应用，不压缩整个工作区。
ditto -c -k --sequesterRsrc --keepParent 'dist/K2 Updater.app' 'dist/witrn-k2-mac-0.7.1-universal2.zip'
shasum -a 256 'dist/witrn-k2-mac-0.7.1-universal2.zip' > 'dist/SHA256SUMS.txt'
```

- [ ] 发布说明列出版本、系统、架构、签名状态、验证结果和未验证项。
- [ ] 上传应用 ZIP 与 SHA-256 摘要，只含公开分发材料。
- [ ] 从附件重新下载并核对摘要与解压启动；不得以本机原始目录的启动替代下载验收。

真实设备升级、资源恢复与长时间记录需要单独计划；本次收尾不自动执行它们。
