# Python 命令行

需要 Python 3.9+。`inspect` 和 `dry-run` 只访问本地文件或模拟器，不访问 USB；连接设备时安装 HIDAPI：

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python k2_updater.py inspect /path/to/K2_APP.k2
.venv/bin/python k2_updater.py dry-run /path/to/K2_APP.k2
```

`dry-run` 覆盖握手、擦除、写入、读回、提交和退出的模拟流程。`simulation_only: true` 与 `hardware_validated: false` 不能解释成设备兼容性结论。

按设备说明进入 DFU，再运行只读探测和备份：

```sh
.venv/bin/python k2_updater.py devices
.venv/bin/python k2_updater.py probe --dfu
.venv/bin/python k2_updater.py backup --dfu --output-dir k2_backups/before-upgrade
```

`flash` **会真实擦除并写入 K2 应用区**。核对设备、固件和备份，明确接受风险后执行：

```sh
.venv/bin/python k2_updater.py flash /path/to/K2_APP.k2 --dfu --yes
```

`--yes` 是真实写入的显式确认。CLI 与图形版的备份流程不同：CLI 使用者应先单独执行并保管 `backup`，不要将图形版的自动写前备份假定为每个底层接口的行为。固件在设备 I/O 前检查；回包异常、短写或读回不一致会停止，失败不自动重试。擦除后的失败可能使应用区不完整。

备份默认位于 `k2_backups/`，通信日志默认位于 `k2_logs/`。它们可能包含设备标识、原始帧或固件内容，不能直接公开。完整协议见[协议说明](protocol.md)。
