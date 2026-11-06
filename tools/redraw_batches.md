# 统一造型重绘 · 台账（暗黑颓废定稿 · 覆盖 1.0 + 自动化精修完成）

> 身份母版 = 原始 `idle.png`（仅作生成参考，不被覆盖）；游戏成品 = `assets/anim/redraw_clean/`。
> 统一锚点：束黑高髻、络腮短须、方脸、交领暗色整袍、绑腿布鞋、水墨写意；暗沉青灰近墨、磨损毛边、低饱和低明度、神态沉郁；完整交领不袒胸、无冠、无念珠、非光头。
> 道具规则：徒手技空手；持刀技一把朴素中式单刀；饮酒帧保留酒坛/酒杯并压暗去亮。
> 播放器 `ANIM_DIRS = redraw_clean/ → clean/ → anim/`；原图与 `clean/` 只读；删除 `redraw_clean/` 即整体回退。

## 覆盖与回归（客观口径）

- **唯一被引用帧 46 / 46 全部重绘入库，待处理 0（stand/air/ground/bust 全 0）。**
- `check_redraw_spec.py` PASS（RGBA 512×640、四角透明、fg>2%、无 stray）；`verify_frame_links.py` 零断链；主场景 headless RC=0、无 SCRIPT/ERR_FILE；`clean/` 90 张未改动。
- `tools/diff_redraw_frames.py`：主色距 idle 全部 ≤20（无色调漂移）、fg 与分组尺寸无异常。

## 管线能力（tools/build_redraw_frames.py）

下载 → rembg(u2net) 去背 → **孤立小连通域碎块清理（scipy 4 邻域，删 <140px 碎点）** → **亮灰中性半透明边缘去灰衰减** → 四组缩放锚点 → 512×640 RGBA：

| 组 | 限高/限宽 | 锚点 | 帧 |
|---|---|---|---|
| stand | 480 / 420 | 脚底基线 y=612 | 全身站姿/拳/刀/受击 |
| air | 300 / 430 | 腾空居中偏上 | jump 族、launched |
| ground | 210 / 440 | 躺地锚点 | knockdown、wakeup |
| bust | 380 / 400 | 垂直居中偏上（不贴脚底线） | drink×4、draw-knife、drawknife |

## 精修落地（task17 自动化部分）

1. **jump-down**：已重出，双臂改为躯干两侧斜下方缓冲张开、双手不高于肩，不再上举（air 组）。
2. **draw-knife**：已重出，仅一把出鞘朴素单刀，删除腰侧多余刀鞘（bust 组）。
3. **碎块清理＋边缘去灰**：已并入管线并对全量重建生效；scipy 可用时执行连通域清理，近白低饱和半透明边衰减，暗墨衣边保留。
4. **半身帧锚点**：6 帧 bust 组统一限高 380、居中偏上，body 高 374–378，不再按全身脚底线贴位，消除高度/位置突兀。
5. **全套客观 diff**：`tools/diff_redraw_frames.py` 输出 bbox/fg/亮度/灰边占比/主色距离；无 color-far、无 fg 离群、无尺寸离群。

### 待编辑器目视（人工项，headless 不可替代，docs/07 §6.4）

- 8 张动态/蹲/受击帧水墨飞白偏亮（diff gray 3.6–5.1%，经目视确认为水墨留白笔触、非 rembg 白边，未重出）：punch-start、crouch-punch、crouch、headbutt、rising-punch、uppercut-start、dash、hurt-head；如觉过亮可在编辑器整体压暗或单帧再调。
- 全部帧脚位/缩放/重心与动态连贯性，需在 Godot 2D 视图实跑各动作序列目视；bust 特写帧与全身帧切换的视觉衔接可微调锚点偏移。
- 后续可选提升（非阻断）：刀光/酒气独立图层、补间级连贯中帧。

## 回归命令

- `python tools/check_redraw_spec.py`
- `python tools/verify_frame_links.py`
- `python tools/inventory_frames.py`
- `python tools/diff_redraw_frames.py`
- 仅当改动 GDScript/数据后补跑：`godot --headless --path 'D:\水滸g\game' --script res://tools/check_visual_fps.gd`、`... selftest_hitbox.gd`
