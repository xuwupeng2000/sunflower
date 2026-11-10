# 已停用的生长预览

用户已明确：所有花取消幼株状态；只有向日葵按既有茎节继续长高，其他花固定高度。本预览未接入正式 App。以下保留历史记录。

# Sunflower growth stage review

Current user-approved direction: use the existing plant and existing growth method, partitioned into stages. Do not use a separate juvenile model. No smoke or transition effects.

Run res://scenes/previews/sunflower_seedling_growth.tscn. The preview uses the normal sunflower controller and cat pot. It holds at 0, 2, and 4 additional stem sections; the same growth controller interpolates smoothly between the holds. Camera and pot size stay fixed. Imported original plant parts are not scaled. Only new stem sections are added using the existing UV-matched interfaces.

The stage labels describe existing stalk growth, not a botanical seedling-to-flower lifecycle. The sunflower is already in bloom at stage 1, as it is in the existing source model. This review is isolated from actual saved care progress.

Verified in Godot: 101 captured frames, section counts asserted against ceil(growth), no script or shader errors. Outputs: build/seedling_preview/sunflower-three-stage-growth.gif and sunflower-three-stages.png.

Earlier seedling, local bloom deformation and smoke experiments are superseded and not loaded by the preview. Source assets are retained for reference.
