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
| bust | 380 / 400 | 顶边对齐全身帧顶边中位 132（不贴脚底线） | drink×4、draw-knife、drawknife |

## 精修落地（task17 自动化部分）

1. **jump-down**：已重出，双臂改为躯干两侧斜下方缓冲张开、双手不高于肩，不再上举（air 组）。
2. **draw-knife**：已重出，仅一把出鞘朴素单刀，删除腰侧多余刀鞘（bust 组）。
3. **碎块清理＋边缘去灰**：已并入管线并对全量重建生效；scipy 可用时执行连通域清理，近白低饱和半透明边衰减，暗墨衣边保留。
4. **半身帧锚点**：6 帧 bust 组统一限高 380、居中偏上，body 高 374–378，不再按全身脚底线贴位，消除高度/位置突兀（第二轮进一步把顶边对齐到全身帧 132，见第 7 条）。
5. **全套客观 diff**：`tools/diff_redraw_frames.py` 输出 bbox/fg/亮度/灰边占比/主色距离；无 color-far、无 fg 离群、无尺寸离群。

## 精修第二轮（V0.2.4，全部有客观判据）

6. **8 张飞白偏亮帧压暗**：`tools/refine_rules.py` 高光肩部压缩（`TONE_PIVOT=0.60`、`TONE_HI_GAIN=0.78`），只动 0.60 以上高光，alpha 与暗部不变。亮像素（L>200）占前景比（%）：crouch-punch 2.09→1.46、crouch 1.78→1.07、dash 2.71→1.26、headbutt 1.02→0.60、hurt-head 3.21→2.61、punch-start 1.74→1.06、rising-punch 1.83→1.33、uppercut-start 1.64→0.96；8 帧中位 1.80→1.16，对齐全身组中位 1.24。主体亮度（alpha>128 均值）61→61 基本不变，五官/刀锋高光不受损。档位对比见 `docs/preview/art-tone-variants.png`（0.78 与 0.62 并列，0.62 已发浊故未采用）。
7. **bust 与全身帧衔接**：6 帧 bust 顶边此前在 108/109，比全身 stand 组顶边中位数 132 高 27px，仰头饮酒/拔刀切换时头顶会跳。现以 `paste_at_top` 只平移不缩放对齐到 132，高度仍 378–380、水平中心 256（顶边差 0px）。`docs/preview/art-bust-vs-fullbody.png` 可见全身与半身头顶连成一线。
8. **逐帧离群断言**：`tools/check_frame_outliers.py` 把 diff 升级为带阈值判据——fg 0.05–0.42、主体亮度 42–78、主色距 ≤42、亮像素 ≤3.0%、水平中心 ±4px、bust 高度 368–386 与顶边 ±6px 判 FAIL；灰边占比 >3.5% 只作 INFO（水墨飞白与去背白边数值重叠，必须目视）。46 帧 0 FAIL。同时修正度量口径：bbox 取 alpha>0，与管线 `getbbox` 一致（旧口径 alpha>8 会因淡边像素误报 wakeup 偏移 6px）。
9. **脚位（落地基线）**：新增 `tools/refine_baseline_report.py` 与断言项——stand/air/ground 组底边必须落在 611±2（基线 612 的最后一像素行）。实测 46 帧底边范围 −2~−1px，浮空 0、压线 0；`docs/preview/art-all-frames.png` 为 46 帧总览（按 stand/air/ground/bust 排序并画出基线）。
10. **刀光／酒气独立图层（V0.2.6，非美术帧，纯程序）**：`scripts/fighter_fx.gd` 四层（SlashCore／SlashHalo／Aura／DrunkVapor）挂在 `RiggedFighter.tscn` 的 `Fx` 下，不依赖任何新贴图。踩坑两条已固化为断言/文档：① 主场景 `Background` 与角色同层 z=0，会把 z=−1 的 aura 全遮（截图曾因此“酒气不可见”），已把 Background 压到 z=−2 并加 `aura z<0`、`刀光 z>0` 两条断言；② 截图脚本只关 `set_physics_process` 不足以冻结角色，仍会自由落体（y 614→888），必须 `process_mode=DISABLED` 并手动推 `visual.play_action`／`fx._physics_process`。离屏渲染走 1280×720 SubViewport，主窗口 16×16 并移到屏幕外（`--display-driver headless` 是 dummy 渲染器，取纹理必 null）。对照图 `docs/preview/fx-sheet.png`（六态拼图）。
11. **刀光时序对齐 active 帧（V0.2.7）**：原先一 `change_state` 就亮刀，亮起时攻击盒还没开（Light1 startup 6 帧=0.1s，刀光 0.18s 提前烧掉一半）。现 `strike()` 接受 `delay = startup/60`，`Fx` 自行计时到点才建弧；切入非攻击状态 `cancel()` 收回。自测 3 项（startup 内不可见、`pending_delay()==0.1`、到点清零），截图脚本也改成“startup+4 帧”再截，六张对照无一空帧。

### 待编辑器目视（人工项，headless 不可替代，docs/07 §6.4）

- 全部帧脚位/缩放/重心与动态连贯性，需在 Godot 2D 视图实跑各动作序列目视；bust 顶边已数值对齐（0px 差），若观感仍跳可微调 `refine_rules.STAND_TOP_Y`。
- 8 张飞白帧灰边占比仍 3.6–5.1%（已压暗一轮），属水墨留白笔触；若仍觉亮可调 `TONE_HI_GAIN`（更小更暗，0.62 会发浊）后重跑 `python tools/refine_frames.py apply`。
- 后续可选提升（非阻断）：补间级连贯中帧。

## 精修命令（第二輪）

- `python tools/refine_frames.py report`（只读指标与 bust 锚点核对）
- `python tools/refine_frames.py apply --align-bust`（压暗 + 顶边对齐，幂等；`--gain` 可换档）
- `python tools/check_frame_outliers.py`（阈值断言，0 FAIL 才算过）
- `python tools/refine_preview.py`、`python tools/refine_tone_variants.py`、`python tools/refine_bust_sheet.py`（对视/档位/衔接对照图 → `docs/preview/`）

## 回归命令

- `python tools/check_redraw_spec.py`
- `python tools/verify_frame_links.py`
- `python tools/inventory_frames.py`
- `python tools/diff_redraw_frames.py`
- 仅当改动 GDScript/数据后补跑：`godot --headless --path 'D:\水滸g\game' --script res://tools/check_visual_fps.gd`、`... selftest_hitbox.gd`、`... selftest_fx.gd`
- 要重出特效对照图（16×16、屏幕外，不弹大窗）：`godot --path 'D:\水滸g\game' --resolution 16x16 --position -32000,-32000 --script res://tools/capture_fx_preview.gd`，再 `python -X utf8 tools/fx_sheet.py` 拼图
