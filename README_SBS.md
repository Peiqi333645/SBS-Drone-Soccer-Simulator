# SBS 无人机足球模拟器 v0.1.0

这是基于 SkySim 3.0 物理核心制作的第一版无人机足球训练原型。项目保留原始 MIT License，新增的场景、界面和训练逻辑同样采用 MIT License。

## 第一版功能

- 单一封闭无人机足球操场
- 蓝、黄双方圆形发光球门
- 球形防护笼四旋翼模型与球形碰撞
- SkySim C++ 旋翼、空气动力、地效、涡环状态和 PID 物理
- USB HID 遥控器检测
- 油门、偏航、俯仰、横滚四步校准向导
- 死区、Expo、通道方向和本机配置保存
- 自稳训练飞行模式
- 第三人称与 FPV 第一视角切换
- 球门触发、双方计分、训练计时和自动复位
- Windows x64 与 macOS Universal 导出预设

## 开发环境

1. 安装 Godot 4.3 Standard。
2. 安装 CMake 3.22+、C++20 编译器和 Git。
3. 在项目根目录运行 `scripts/build.sh Release`。Windows 使用 `scripts/build.bat Release`。
4. 用 Godot 打开根目录的 `project.godot`。
5. 运行项目，默认进入 `demo/soccer_arena.tscn`。

首次编译会自动从 GitHub 获取与 Godot 4.3 匹配的 `godot-cpp`。

## 遥控器操作

- 将富斯 PL18、Radiomaster 或其他遥控器设置为 USB Joystick/HID 模式。
- 启动后按 `K` 打开校准。
- 按向导依次移动油门、偏航、俯仰、横滚完整行程。
- `Enter` 解锁，`Backspace` 锁定，`R` 复位，`C` 切换视角。

校准结果保存在 Godot 的 `user://sbs_controller_profile.json`，退出软件不会丢失。

## 当前边界

- v0.1.0 是单人自稳训练版，尚未加入多人联网、AI 对手、完整比赛规则和 Acro Rate 模式。
- macOS 未签名测试包首次打开时可能需要在“系统设置 → 隐私与安全性”中允许。
- 不同遥控器的 HID 轴顺序不一致，因此正式飞行前必须完成校准。

## 商用说明

MIT 许可证允许修改、分发和收费销售，但发布的软件或源码中必须保留根目录 `LICENSE` 的原版权和许可文本。使用新模型、字体、音效或贴图时，应分别确认其商业授权。
