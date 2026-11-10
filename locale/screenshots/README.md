# 1.5 商店截图

- `1.5/<语言>/01-flower.png`：向日葵与刺猬小屋花盆的真实界面截图。
- `1.5/upload/<语言>/06-flower.png`：1206×2622 RGB PNG；其余五张沿用 1.3。
- `1.5/upload/<语言>/07-moth-orchid.png` 至 `10-kalanchoe.png`：蝴蝶兰、君子兰、仙客来和长寿花的真实界面。
- `1.5/manifest.json`：十种语言、共 100 张上传文件的尺寸和 SHA-256。
- `1.5/status.md`：构建与提交状态。

生成向日葵原图：`python3 locale/screenshots/generate.py --flower-only`；生成全部五种花：`python3 locale/screenshots/generate.py --all-flowers`。

# 1.3 商店截图

每种语言六张，上传顺序：Timer、Schedule、单次提醒、提前出发、每周起止时间、养花。

- `1.3/<语言>/`：1320×2868 的原始真实界面渲染。
- `1.3/upload/<语言>/`：1206×2622 RGB PNG，已上传到 App Store Connect 的对应语言中等屏幕 iPhone 栏位；其他屏幕继承。
- `1.3/manifest.json`：上传文件的尺寸和 SHA-256。
- `metadata.json`：本次使用的商店各字段。
- `generate.py` / `capture.gd`：独立临时工程和示例存档中的截图脚本。脚本只在临时副本中固定语言并关闭教程回放，不修改发布代码或正式存档。

生成原图：`python3 locale/screenshots/generate.py`；也可以在末尾指定 `en-US` 或其他语言。原图中的示例日期随运行日期变化。

整个目录带 `.gdignore`，不会加入 Godot 游戏资源。网站使用 `docs/media/` 内压缩后的本地化预览图。
