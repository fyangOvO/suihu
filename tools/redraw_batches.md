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
12. **牆族／牆邊連段獎勵（V0.2.8，玩法）**：舞台补左右边界墙（StaticBody2D，40×1200，layer 1，墙面 x=0/1920）；`take_damage()` 沿击退方向 `test_move` 探 20px，只有 `StaticBody2D` 才算墙（对手身体不算）；命中即 +25% 额外伤害、粘墙 30 帧定身、再以 (−wall*320, −280) 弹回转 `HurtAir`。踩坑两条已固化：① `change_state()` 会清 `velocity.x`，弹回速度必须在切状态之后赋；② 物理帧回调里 add_child 整张主场景，角色 `body->get_space()` 恒 null，端到端墙检必须放在 `_initialize`，且不能用 `process_mode=DISABLED`（物理查询会失效）。自测 `selftest_wall.gd` 21 项 + `selftest_wall_stage.gd` 6 项。
13. **伥鬼 AI（V0.2.9，AI 层）**：`_run_ai` 从「一直走近 + 定时轻攻」改为 `ai_plan(ctx)` 纯决策 + `_ai_apply` 虚拟输入。距离四档（>300 接近 / 150–300 走或 25% 前冲 / ≤150 轻攻或 25% 重砸 / 冷却等待）；对手 startup/active 且 ≤220 站防，收招硬直才重招惩罚；受击写 0.5s 后退计时；<30% 血出手间隔 1.2s→0.5s；决策输出白名单里没有跳/蹲防/投掷。踩坑：① GDScript 没有具名参数，测试里 `_ctx(200, roll: 0.1)` 直接 Parse Error，改用重载字典；② `add_child` 触发的 `_ready`/`_physics_process` 在首个物理帧才生效，首帧 `set_physics_process(false)` 才真的冻得住假人，血量基准也要在首帧取（否则基准是 0，`hp < before` 恒假）；③ 防中按重会走飞云浦反击，AI 的惩罚重招只在 `_state == "Idle"` 时出手。`selftest_ai.gd` 24 项。
14. **伥鬼数值落地（V0.2.10）**：P2 实例 `max_hp = 180`，HUD `P2HP` 上限同步、且每帧由 `main_rigged.gd` 从角色 `max_hp` 回写（不再场景写死 800）；出手 startup 用 `ENEMY_STARTUP_BONUS = {Light1:+2, Heavy:+3}` + `_spec()` 做实例级补偿（伥鬼 8/15 帧，武松 6/12 不动），`_spec()` 复制 `logic` 再改，绝不写回 `SPECS`。**坑**：`DATA.spec()` 返回的是全局字典引用，直接改会污染整张表（自测加 “global table untouched” 断言）；AI 读对手规格必须用 `opponent._spec()`，否则架招/惩罚的时序和真实出招错位。
15. **伥鬼伤害列（V0.2.11）**：`ENEMY_STARTUP_BONUS` 升级为 `ENEMY_OVERRIDES = {Light1: {startup:+2, damage:65}, Heavy: {startup:+3, damage:130}}`，`_spec()` 同时覆盖 startup 与 damage，仍只对非 P1 生效。实跑断言：强制伥鬼出 Light1，P1 实际扣 65（而武松自己打 40）。
16. **伥鬼扔石头（V0.2.12）**：`scripts/rock_projectile.gd` 用纯 Node2D 走弧线＋矩形重叠，不建 Area2D——物理回调里 `add_child` 的 Area2D 拿不到 space 是旧坑，这里彻底绕开。落点由 `flight_time = clamp(dist/430, 0.55, 1.5)` 反算，`vy = -0.5*g*T`，正好压到对面受击框。AI 侧 `dist > 360` 才掷、冷却 2.5s，中近距不掷。**命名坑**：计划串不能叫 `throw`——`_contains_forbidden()` 把 `throw` 当作投技（指令投）列入禁项，改叫 `rock`。离屏预览 `docs/preview/rock-preview.png`（1920 渲染后缩 960）。

17. **伥鬼死亡化青煙 + 掉落（V0.2.13，演出／掉落層）**：血量歸零（含牆族加成、架招磨死）走 `_begin_death()`，`_physics_process` 頂端 `_dying` 分支完全接管（不讀輸入不出招），0.25s 起本體淡出 0.8s、1.05s 收尾隱藏本體＋關碰撞；青煙初版為程序粒子（已於第 18 條改為手繪六幀）。掉落補上工程原本沒有的系統：`scripts/coin_pickup.gd` 純 Node2D 程序繪製＋64×180 重疊判定＋上下浮動，碎銀必掉、木牌 10%（`drop_chance` 可 export 調），主場景加「拾得：xxx」提示並在青煙散完後才判勝（`$P2._death_done`）。**踩坑**：自測同時讓引擎與手動各推一次 P2 的 `_physics_process`，死亡計時兩倍速（n=35 就 finished、alpha=0），淡出斷言必假——引擎推進與手動推進只能留一條；另 `selftest_ai` 受擊後退段原本把假人血量壓到 1，現在會直接判死凍住 AI，已改成 50。
18. **青煙改手繪六幀序列（V0.2.13.1 → V0.2.13.2 換第二版，美術／特效層）**：不再用程序粒子，改成一張六格橫向水墨序列原畫（`docs/preview/death-mist-sheet-src.png`，3072×1024 檔位、生成後 3547×1182），`tools/build_death_mist_frames.py` 依「全黑列」自動偵測六格邊界（實測 6 格全部命中，無需等寬硬切），逐格以亮度反推 Alpha（`max(r,g,b)` → alpha，乘 1.5 提亮）並把亮度映射成灰綠墨色，等比縮到 300×560 後貼進 512×640 畫布、底邊 612 對齊。踩坑：初版 alpha 只乘 1.15 且 sprite scale 0.7，暗底實機截圖裡整縷煙幾乎看不見（覆蓋率 16%→實機細線），提亮＋放大到 0.9 才立住。遊戲端 `AnimatedSprite2D` + 運行時 `SpriteFrames`（9fps、loop=false），播完停最淡一幀、1.8s 後 `queue_free`；`_mist_node` 供自測斷言 6 幀。第二版（`death-mist-sheet-src2.png`）把六格收成細長上升煙縷、去掉團塊與樹枝狀分叉，第 1 格只剩貼地小團、第 6 格近乎空白；實機四連拍對比後採用第二版（細而利，更貼水墨青煙）。**換圖踩坑**：只覆蓋 png 而不動 `.import`，Godot 會沿用 `.godot/imported` 裡的舊 ctex，實機截圖還是舊幀——必須同時刪 `assets/fx/death_mist/*.import` 與 `.godot/imported/mist_*` 再 `--import`，否則比對結果會自我欺騙。六幀總覽 `docs/preview/death-mist-frames-v2.png`，實機四時點連拍 `docs/preview/death-mist-sequence.png`（0.20/0.43/0.70/0.97s）。

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
