# 水滸：妖魔劫 — 灰盒測試版 v2

## 操作（手柄為主，鍵鼠保留）

### P1 武松

| 動作 | 手柄 | 鍵盤 |
|---|---|---|
| 移動 | 左搖桿 | A / D |
| 蹲 | 左搖桿↓ | S |
| 跳躍（二段跳） | Y鍵 | 空格 |
| 輕攻擊（三連段） | A鍵 | J |
| 重攻擊 | X鍵 | K |
| 格擋 | B鍵 | L |
| 衝刺（6幀無敵） | LB | Shift |
| 醉打蔣門神（穿身無敵·CD 4s） | RB | U |
| 打虎拳（↓↘→ + 重） | 方向↓↘→ + X | 方向↓↘→ + K |
| 昇龍對空（→↓↘ + 重） | 方向→↓↘ + X | 方向→↓↘ + K |
| 飛雲浦反擊（↓↙← + 重，或防禦中重） | 方向↓↙← + X | 方向↓↙← + K |
| 喝酒（漲酒氣） | LT | I |
| 覺醒必殺 | RT | O |

> 手柄標準 Xbox 佈局：A=輕 / X=重 / B=防 / Y=跳 / LB=衝 / RB=特殊 / LT=酒 / RT=覺醒

### P2（測試用）

| 動作 | 鍵盤 |
|---|---|
| 移動 | ← / → |
| 蹲 | ↓ |
| 跳躍 | ↑ |
| 輕攻 | U |
| 重攻 | I |
| 格擋 | O |

## 已實現

- [x] 移動/走路/蹲/跳/二段跳
- [x] 三連輕攻取消鏈（J→J→J）
- [x] 重攻
- [x] 衝刺（LB，6幀無敵）
- [x] 格擋（減傷50%+藍閃）
- [x] 受擊硬直 + 白閃反饋
- [x] 擊退物理
- [x] 投擲（輕+重同按，近身110傷，打浮空）
- [x] 指令技方向輸入：236+重=打虎拳 / 623+重=昇龍對空
- [x] 受身滾（倒地中按跳，6幀無敵）
- [x] 浮空追打（Light3/投擲/昇龍把人打浮空，可以追跳）
- [x] 牆族（撞到牆彈回）
- [x] 打虎拳（RB/236+重，直線衝拳110傷）
- [x] 昇龍（623+重，對空130傷打浮空）
- [x] 喝酒（LT，漲酒氣30）
- [x] 血量條 + 酒氣條 HUD
- [x] 自動面向對手
- [x] 輸入緩衝系統（18 幀內方向輸入有效）

## V0.1.1 幀動畫毫秒管線（本輪重構，詳見 `../docs/07-動畫幀毫秒映射規格.md`）

- [x] 60fps 邏輯幀 × 30fps 視覺幀雙時鐘，幀↔毫秒統一換算（`data/action_frame_data.gd`）
- [x] 移除 sin 縮放/搖晃偽造，姿態由 `scripts/frame_animator.gd` 按毫秒序列播放
- [x] 命中判定改為啟動/活躍/恢復幀窗口；Light1→Light2→Light3 取消鏈由取消幀驅動
- [x] 格擋減傷 50%、受擊 12 幀硬直、Dash 無敵窗口、喝酒 48 幀，全部數據驅動
- [x] 素材唯讀盤點 `tools/normalize_assets.py`（源 90 檔：15 真 PNG / 75 JPEG 偽裝）
- [x] **V0.1.2 素材治理**：`tools/build_anim_frames.py` 以 rembg(u2net) 去背，90 張成品輸出 `assets/anim/clean/`（真 RGBA、統一 512×640、腳基線對齊、四角透明）；原始素材不動；播放器 `clean/` 優先、原始目錄兜底；`tools/check_clean_spec.py` 規格驗收全綠、`tools/verify_frame_links.py` 校驗無斷鏈
- [x] P0 姿態歸併入幀：Idle 4 / Walk 6 / Light1 4 / Light2 4 / Light3 7 / Heavy 5 / Block 2 / HurtStand 3
- [x] **實體 Area2D 判定盒（V0.1.3）**：HitBox(layer2)/HurtBox(layer4) 重疊取代 dx/dy 距離比較，活躍幀開盒、收招關盒；`tools/selftest_hitbox.gd` 無頭自測 Light1 命中扣血 40（800→760）
- [x] 指令序列緩衝補完：214 下→下後→後反擊、236 下→下前→前打虎拳、623 前→下→下前昇龍全部共用同一方向緩衝隊列（V0.2.0 完成）；受身/浮空追打/牆族細化後續
- [x] **V0.1.4 素材/時序收尾**：Light3 7 槽按蓄力→上升→頂點→滯空→空中拳→下落→起身重排；倒地/騰空分組縮放錨點（stand 71 / air 8 / ground 11，docs/07 §6.5）；高速技提速 Light3 40、Heavy·CmdTiger 45、AirLight·AirHeavy·CmdUp 50（docs/07 §6.6）；`tools/check_visual_fps.gd` 無頭斷言 PASS、邏輯窗口不變
- [x] **V0.1.5 統一造型第一批（高速/空中鏈路，暗黑頹廢定稿）**：以 idle 為身份母版 `image_edit` 保姿態重繪 6 幀（uppercut、jump-punch、jump、jump-down、jump-slash、launched），去冠、去念珠、不袒胸，暗沉青灰近墨＋磨損毛邊；`tools/build_redraw_frames.py` 去背分組縮放輸出 `assets/anim/redraw_clean/`，播放器 `ANIM_DIRS` 最高優先 `redraw_clean/`→`clean/`→原始目錄，缺圖自動回退、刪目錄即整體回退；`tools/check_redraw_spec.py` 6/6 PASS；斷鏈/帧率/命中無頭回歸全綠
- [x] **V0.1.6 統一造型覆蓋 1.0（46/46 唯一被引用幀，暗黑頹廢定稿）**：在第一批基礎上續完成 ground 2、待機/行走 9、C2 輕拳 8、C3 重拳突進 8、C4 防禦/受擊/覺醒 6、C5 飲酒/拔刀 6、jump-up 1；持刀技保留一把樸素中式單刀、徒手技空手、飲酒保酒具並壓暗；`tools/inventory_frames.py` 唯一 46＝已重繪 46、待處理 0；`check_redraw_spec.py` PASS、`verify_frame_links.py` 零斷鏈、主場景 headless RC=0 無錯；批次與精修台賬見 `tools/redraw_batches.md`
- [x] 純美術精修（程序可代勞部分已完成）：jump-down 張臂方向、draw-knife 腰鞘多餘刀、碎飄帶連通域清理＋暗色邊緣去灰、半身飲酒/拔刀幀錨點縮放與全身幀銜接、全套逐幀 diff 回調離群——見 V0.2.4；腳位/重心逐帧量測并入断言——見 V0.2.5；刀光/酒氣獨立圖層——見 V0.2.6；剩餘純目視項：Sprite 腳位/縮放在編輯器 2D 視圖實跑各動作序列（docs/07 §6.4）、補間級連貫中幀（後續提升，非阻斷）
- [x] **V0.1.7 玩法補全（`tools/selftest_gameplay.gd` 18 項斷言 PASS）**：覺醒必殺 Super 滿酒氣按 O(RT) 觸發、全程無敵、active 窗口 320 傷害、金黃 modulate 脈衝演出、結束清氣；飛雲浦反擊 Counter（站/蹲防中或受擊前 4 邏輯幀按重，前 6 幀招架無敵、命中 120 浮空；完整 214 方向序列緩衝留待後續）；防禦分化＝站防 50%／蹲防 CrouchBlock 35% 小退卻／空防 AirBlock 40% 且不浮空；順帶修復「無敵招式攻擊盒被誤關閉、Super/醉打打不中」的耦合問題；回歸 selftest_hitbox、check_visual_fps、主場景 headless 全綠
- [x] **V0.1.8 P1 酒氣條 HUD（`tools/selftest_hud.gd` 7 項斷言 PASS）**：MainRigged 場景於 P1 血條下新增 P1Wine 進度條（0–100）與滿氣提示 Label，主邏輯每幀同步 wine_gauge；滿 100 時氣條轉金黃高亮、顯示「覺醒可發（O / RT）」，Super 結束清氣後自動回落；P2 為占位 AI 不繪氣條；補上此前文檔已列但代碼缺失的酒氣條；回歸 gameplay／hitbox／fps／headless 全綠
- [x] **V0.1.9 飛雲浦反擊完整指令技 214（`tools/selftest_gameplay.gd` 23 項斷言 PASS）**：新增相對朝向方向歷史緩衝窗口（18 邏輯幀），識別方向序列並按重觸發 Counter；與既有簡化觸發（站/蹲防中按重、受擊前 4 幀按重）並存，出手即清空緩衝；本次只接入 214，236/623 方向緩衝尚未實現（現 CmdTiger/CmdUp 仍為按鍵直觸）；回歸 hitbox／fps／hud／主場景 headless 全綠
- [x] **V0.2.0 指令技完整方向緩衝 236/623（`tools/selftest_gameplay.gd` 46 項斷言 PASS）**：方向記錄重做為數字小鍵盤語義（5 中／2 下／1 下後／3 下前／4 後／6 前／7 上後／8 上／9 上前，皆相對朝向），`_has_cmd` 通用順序匹配（允許中間夾中立或其他方向），派生 214 ↓↙←、236 ↓↘→、623 →↓↘；重鍵分派優先級 214>623>236 → Counter／CmdUp／CmdTiger，出手即清空緩衝；同步修正 V0.1.9 中 214 的錯誤序列（後→下→前 改為 下→下後→後）；自測新增物理接線斷言（落地後 236+重真的切 CmdTiger、623+重切 CmdUp、214+重切 Counter、無指令+重切 Heavy、236+輕不誤觸）；滿氣待機新增 AwakenIdle 拔刀立繪（draw-knife）＋柔和金輝呼吸，進入戰鬥狀態即回落正常幀，Super 仍使用 awaken
- [x] **V0.2.1 覺醒過場演出（`tools/selftest_cinematic.gd` 21 項斷言 PASS）**：MainRigged 新增 BattleCam(960,540) 與 Cinematic 層（Dim 暗角／Slash 金色刀光／Flash 定格白閃）；P1 進入 Super 即啟動 2.0s 時間軸——0–0.30s 推鏡（zoom→1.20 並追隨 P1、暗角→0.55）、0.28–0.55s 刀光橫掃＋白閃定格、1.30–2.00s 全部復位；演出期間 P2 定格外，離開 Super 或超時即中斷復位；HUD 屬獨立 CanvasLayer 不受鏡頭影響；回歸 gameplay／hud／hitbox／fps／主場景 headless 全綠
- [x] **V0.2.2 醉打蔣門神接入（`tools/selftest_gameplay.gd` 59 項斷言 PASS）**：`CmdDrunk` 補上輸入路徑（P1 的 `p1_special`＝RB／U），4s 冷卻（`_tick_cooldowns` 逐幀遞減，冷卻中按鍵無效）、起手＋活躍段（邏輯幀 1–13）以 360 速度前衝、8–18 幀無敵、穿身以 `add_collision_exception_with(opponent)` 只忽略對手身體碰撞（地面／牆仍保留，離開狀態即恢復例外）；並將 `CmdDrunk` 補入 `ATTACKS`，否則攻擊盒不會開啟（與 V0.1.7 修過的「無敵招式打不中」屬同一類耦合）；自測新增 13 項（觸發、冷卻封鎖／遞減／歸零、傷害 70、總 33 幀、active 8–12、invuln 僅 8–17、攻擊盒歸類、穿身例外增減）
- [x] **V0.2.3 醉打冷卻 HUD（`tools/selftest_hud.gd` 13 項斷言 PASS）**：P1 酒氣條新增一行 `P1DrunkHint`——可發時顯示「醉打可發（RB / U）」暖色，冷卻中灰化並改為「醉打冷卻 X.Xs」逐幀倒數，主邏輯每幀讀 `$P1._drunk_cd` 同步；自測新增 6 項（節點存在、倒數文案、秒數、灰化、恢復可發、恢復非灰）
- [x] **V0.2.4 美術精修三項（`tools/check_frame_outliers.py` PASS 0 fail、`check_redraw_spec.py` PASS）**：
  ① **8 張飛白偏亮幀壓暗**（punch-start／crouch-punch／crouch／headbutt／rising-punch／uppercut-start／dash／hurt-head）：新增 `tools/refine_rules.py` 的高光肩部壓縮（pivot 0.60、gain 0.78），只降 0.60 以上的高光、暗部與 alpha 不動；亮像素佔比中位由 1.80% 降到 1.16%（全身組 1.24%），主體亮度 61→61 不變，避免把飛白壓成灰泥；
  ② **bust 半身幀與全身幀銜接**：6 幀 bust 高度統一 378–380、水平中心 256、頂邊由 108/109 下移到 132＝全身 stand 組頂邊中位數，切換時頭頂不再跳 27px；`paste_at_top` 只平移不縮放，等比與身份不變；
  ③ **逐帧 diff 回調離群**：新增帶閾值的 `tools/check_frame_outliers.py`（fg／主體亮度／主色距／亮像素／水平中心／bust 高度與頂邊硬性判 FAIL，灰邊佔比只提示需目視，另加腳位斷言：stand／air／ground 組底邊必須落在基線 611±2，浮空或壓線即 FAIL），46 幀全過；順帶修正度量口徑——bbox 改用 alpha>0 與管線 `getbbox` 一致，先前 alpha>8 會把淡邊像素算成偏移（wakeup 誤報 cx=262）。
  全套 46 幀總覽圖 `docs/preview/art-all-frames.png`（按 stand／air／ground／bust 排序、標出落地基線）。
  三項規則同時寫回 `tools/build_redraw_frames.py`，整目錄重建可復現；目視對照圖在 `D:\水滸g\docs\preview\`

- [x] **V0.2.6 刀光／酒氣獨立圖層（`tools/selftest_fx.gd` 30 項斷言 PASS）**：純程序繪製，不引入額外貼圖。`scripts/fighter_fx.gd` 掛在 `RiggedFighter.tscn` 新增的 `Fx`（Node2D）下，四層各管一件事——`SlashCore`（Line2D，26 點弧＋兩端收尖 `width_curve`）／`SlashHalo`（Line2D，更寬、`blend_mode=1` 疊加、alpha 0.55）／`Aura`（Sprite2D，128×128 徑向漸變輝光，z=−1 落在身體之後）／`DrunkVapor`（CPUParticles2D 酒霧，僅醉打期間 emitting）。
  - 六種刀光預設 `ARC_KINDS`：light 112 / heavy 128 / rising 126 / low 100 / air 114 / drunk 140，核心寬度 5–9，生命 0.18–0.32s；朝向右時弧在右側，`face=−1` 整弧鏡像；`CmdUp` 弧向上掃（自測斷言 last.y < first.y）。
  - 酒氣三態：Super 金脈衝（alpha 0.40–0.70、scale 脈動）／滿氣待機柔和呼吸（0.14–0.30）／醉打酒紅（0.24–0.48）；退出即熄。
  - 接線：`change_state()` 末行 `_fx_state()` 觸發（Light1·2·Counter→light、Light3·Heavy·CmdTiger→heavy、CrouchLight→low、AirLight·AirHeavy→air、CmdUp→rising、CmdDrunk·Super→drunk），**刀光延遲到 startup 走完（= 進入 active 命中窗口）才亮**，與攻擊盒開盒同步；切入非攻擊狀態即 `fx.cancel()` 收回未出鞘的刀。`_physics_process()` 首部 `_fx_sync()` 每邏輯幀同步 aura 模式與酒霧開關；特效只讀 `_state/_frame/wine_gauge/face_direction`，不回寫戰鬥數值、不碰判定盒。
   - 層級修正：主場景 `Background` 原與角色同層 z=0，會把 z=−1 的 aura 整塊蓋掉（截圖一度全黑無輝光）；已把 Background 壓到 z=−2，並在自測加兩條層級断言（aura<0、刀光>0）。
  - **時序修正（V0.2.7）**：刀光不再於「進入招式」瞬間亮、而是等 `startup` 幀走完（`delay = startup / 60`，由 `DATA.spec(...).logic.startup` 讀取）才出刀，落到 active 第一幀，和攻擊盒開盒對齊；`CmdDrunk`/`Super` 各一刀（原本醉打誤觸發兩次已改單次）；中途被受擊或待機打斷則 `cancel()` 收回。自測新增 3 項（startup 內不出刀、延遲值＝startup/60、到點清零）。
  - 截圖工具改為 **SubViewport 離屏**：`tools/capture_fx_preview.gd` 用 1280×720 SubViewport 渲染、主視窗 16×16 並移到螢幕外，角色 `process_mode=DISABLED` 凍結（先前只關 physics 仍會自由落體，導致畫面逐張下沉放大）；六張對照拼圖 `tools/fx_sheet.py` 出 `docs/preview/fx-sheet.png`（Light／Heavy／CmdUp／Awaken／Super／CmdDrunk）。
  - 觀感取捨：刀光由「寬月牙」收成細筆鋒（核心寬 5–9、halo 只 +4 且疊加混合），避免糊成實心色帶；酒氣輝光半徑放到 3.0×3.3 並提亮，暗背景下一眼可辨。

## 待實現

- [x] 酒氣滿自動拔刀（立繪切換：正常→覺醒版+金黃閃光）
- [x] 導入第一張美術素材（武松水墨立繪替換灰色方塊）
- [x] 導入舞台背景（景陽岡月夜山道概念圖）
- [x] 6張動作關鍵幀（直拳/上勾拳/掃堂腿/受擊/跳躍/拔刀）
- [x] 狀態機切換貼圖（不同動作顯示不同姿態）
- [x] 補充關鍵幀：走路A/B、重劈、喝酒
- [x] CPU AI（P2自動靠近+攻擊+防禦+喝酒）
- [x] 覺醒必殺基礎版（RT/O 滿氣觸發、全程無敵、320 傷害、金黃脈衝；完整過場鏡頭演出後續）
- [x] 飛雲浦反擊：簡化觸發（防中/受擊前 4 幀按重）＋完整 214（後→下→前）+重；招架無敵 + 120 浮空
- [ ] 牆邊連段獎勵
- [ ] CPU 對手（先做最簡單的AI）

## 如何運行

1. 用 Godot **4.7.x** 打開 `D:\水滸g\game\project.godot`
2. 首次打開等待 `assets/anim` 素材導入完成
3. F5 運行；P1：A/D 移動、S 蹲、Space 跳、J 輕、K 重、L 格擋、Shift 衝、I 喝酒

> 註：`水滸：妖魔劫-(4.2)/` 為早期 C# 灰盒版，其啟動/活躍/恢復幀設計被本目錄 GDScript 版的 `data/action_frame_data.gd` 繼續採用；實際運行以本目錄為準。
