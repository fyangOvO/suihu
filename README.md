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

- [x] **V0.2.8 牆族／牆邊連段獎勵（`tools/selftest_wall.gd` 21 項 + `tools/selftest_wall_stage.gd` 6 項 PASS）**：
  - 舞台加左右邊界牆：`MainRigged.tscn` 新增 `WallLeft`(x=-20)／`WallRight`(x=1940) 兩個 `StaticBody2D`，40×1200 矩形、collision_layer=1（與角色同層），牆面正好落在畫面 x=0／1920——補上 docs/01「不能走出邊界」這條。
  - 判定：`DATA` 新增 `WallStick` 狀態（0/0/30 邏輯幀，recovery 30 幀＝黏牆時長，貼圖沿用 `hurt.png`，不新增素材）；`take_damage()` 受擊前用 `test_move` 沿擊退方向探 20px，命中 `StaticBody2D` 才成立——對手身體不算牆，貼身對打不會誤觸發。
  - 效果：額外傷害 +25%（下限 10，例：100 傷害 → 125）、黏牆 30 幀完全定身（零速度、不計重力）、結束後以 (−wall_side×320, −280) 彈回並轉 `HurtAir`，可直接接浮空追打；黏牆期間 `_wall_bonus_last` 記錄加成供自測讀取。
  - 踩坑：`change_state()` 內會 `velocity.x = 0.0`，彈回速度必須在切狀態「之後」賦值，否則只有上拋沒有水平分量（自測 `bounce away from wall (vx<0)` 抓到）。
  - 踩坑：物理幀回調裡 `add_child` 整張主場景，角色的 `body->get_space()` 恆為 null（`test_move`／`move_and_collide` 直接報錯）；端到端牆體檢查必須在 `_initialize` 掛場景。另 `process_mode = DISABLED` 也會讓物理查詢失效，自測改用 `set_physics_process(false)`。

- [x] **V0.2.9 伥鬼 AI（docs/04 §2 第一個教學對手；`tools/selftest_ai.gd` 24 項 PASS）**：把原本「一直走近＋每 1.4s 戳一下」的 `_run_ai` 換成帶規格的決策機，行為全部落在 `ai_plan(ctx)` 這個純函數裡（只吃距離／血量／對手狀態與幀／冷卻／roll，不碰節點），`_ai_apply` 再映射成 P1 同一套虛擬輸入旗標——不另開 AI 專屬狀態機，所有招式仍走既有的 startup／active／cancel 鏈。
  - **距離四檔**：>300 先接近；150–300 走路為主、25% 前衝棍擊（Dash）；≤150 出手（輕攻為主，25% 改重招「下砸」）；冷卻中站著等（不空揮）。
  - **架招（會站防）**：對手在 startup／active 且距離 ≤220 → `Block`；只在對手收招硬直（frame ≥ startup+active）且貼身時用重招懲罰。防禦中不出重招，避免被 `_decide_free_state` 判成飛雲浦反擊。
  - **被打會後退**：`take_damage()` 對非 P1 角色寫入 0.5s 後退計時，期間往遠離對手的方向退——給玩家追打窗口。
  - **30% 血線慌亂**：出手間隔 1.2s → 0.5s，且不再守距離（貼身就揮）。
  - **不會跳／不會蹲防／不會投擲**：決策輸出是白名單（retreat/block/heavy/light/dash_attack/approach/wait），空中與蹲防姿態根本無法由 AI 產生；自測掃 100 個 roll 驗證合法性，實跑 420 幀驗證從未進入 AirUp／AirLight／AirHeavy。
  - **確定性**：roll 用黃金比例步進（`fmod(t + 0.618, 1)`），沒有隨機源也能重現同一串決策，自測可復現；純決策段 16 項 + 實跑段 8 項（接近／命中／不跳／受擊後退／站防）。
  - 尚未納入（需另開工單）：遠距扔石頭（工程沒有投射物系統）、死亡化青煙演出。

- [x] **V0.2.10 伥鬼數值落地（`selftest_hud` +4、`selftest_ai` +5）**：
  - **血量 180**：`MainRigged.tscn` 的 P2 實例寫 `max_hp = 180`（武松仍 800），HUD `P2HP` 上限同步 180；`main_rigged.gd` 改為每幀把兩條血條的 `max_value` 跟隨角色 `max_hp`，數值只集中在角色節點，不再有「場景寫死 800」的第二份真相。
  - **出手更慢（docs/04 §2：站輕啟動 8 幀、站重 15 幀）**：新增 `ENEMY_STARTUP_BONUS = {Light1: +2, Heavy: +3}` 與 `_spec()`——敵方實例在共用數據表上疊 startup 補償，P1 維持 6／12 不動；`_spec()` 回傳的是複製過的 `logic`，不會污染 `SPECS` 全局表（自測有「global table untouched」斷言）。AI 讀對手規格也改走 `opponent._spec()`，架招／懲罰的時序判定與真實出招一致。
  - 連段參照：武松 Light1 40 + Light2 45 + Light3 70 = 155，加一下補刀即可帶走 180——符合「一套連段帶走」的定位。
  - 未動：伥鬼的傷害值仍沿用同一張表（docs/04 未給它的傷害），若要讓它更有威脅需另定一組傷害。

- [x] **V0.2.11 伥鬼傷害列（`selftest_ai` 35 項 PASS）**：`ENEMY_OVERRIDES` 從只補 startup 擴成「startup + damage」兩欄——伥鬼站輕 65、站重 130（武松維持 40／90），仍只作用於非 P1 實例，全局 `SPECS` 不寫回。
  - 節奏對照：伥鬼一次輕攻 65／重砸 130，武松 800 血需 13 下輕或 7 下重才會死（站防再折半）；反過來武松 155 的三連段＋補刀即可帶走 180——「教玩家架招和連段」的壓力與容錯都在。
  - 自測新增 3 項（spec 傷害 65／130、P1 傷害仍 40、全局表 40／90 未被污染）＋1 項實跑（強制伥鬼出 Light1，斷言 P1 實際扣 65 而非 40）。

- [x] **V0.2.12 伥鬼扔石頭（docs/04 §2 特殊技）**：新增 `scripts/rock_projectile.gd`——純 Node2D 弧線飛行（不依賴 Area2D／body space，無頭與物理回調裡都可靠），落點按距離反算飛行時間（0.55–1.5s），跑到對手受擊框（64×180）就算命中，落地／出界／超時自行清理。
  - 傷害 75（介於站輕 65 與站重 130 之間）；命中同樣走 `is_blocking ? on_blocked : take_damage`，站防可減半。
  - AI：`dist > 360` 且攻擊冷卻已好、扔石頭冷卻已好時，按 `roll < 0.3` 出「rock」（冷卻 2.5s）；中近距離維持前衝與棍擊，貼身不會扔。
  - 「慢、可閃」的實現口徑：石頭按固定弧線飛、不追蹤，玩家走位或跳起即可躲開；直徑約 68px（1920 畫面寬的 3.5%），離屏截圖 `docs/preview/rock-preview.png` 已核對大小與暗底對比。
  - 自測新增 4 項：遠距擲石決策、冷卻壓制、中距離不擲石、實跑（420px 外扔出命中扣 75 且石頭自行釋放）；`selftest_ai` 共 39 項。

- [x] **V0.2.13 伥鬼死亡化青煙 + 掉落（docs/04 §2；`tools/selftest_death.gd` 16 項 PASS）**：
  - **死亡演出**：血量歸零（含被牆族加成打死、架招磨死）不再進常規 `HurtStand`，改走 `_begin_death()`——倒地姿態 + 青煙粒子，0.25s 起本體淡出 0.8s，1.05s 收尾（隱藏本體、關碰撞、掉東西）。`_physics_process` 頂端 `_dying` 分支完全接管該幀，不讀輸入、不出招；`take_damage()`／`on_blocked()` 對 `_dying` 直接 return，屍體不會被鞭屍重複結算。
  - **青煙是手繪六幀序列（第二版細長煙）**：`assets/fx/death_mist/mist_01–06.png`（512×640，底邊對齊 612）。原畫是一張六格橫向序列圖（`docs/preview/death-mist-sheet-src2.png`，第一版為 `death-mist-sheet-src.png`），`tools/build_death_mist_frames.py` 用純黑底亮度反推 Alpha、再按亮度映射灰綠墨色（濃 #2E4A3C → 亮處乳白），裁到 300×560 上限等比貼進畫布——因此沒有灰底、沒有方塊粒子邊。遊戲內 `AnimatedSprite2D` + 運行時 `SpriteFrames`（9fps、不循環、scale 0.9、位置 y=−288），播完停在最淡一幀，1.8s 後自清；本體淡出照舊，煙比人晚散。
  - **掉落系統（工程原本沒有）**：新增 `scripts/coin_pickup.gd`——純 Node2D 程序繪製（碎銀不規則銀塊／木牌木片+掛繩）、上下浮動、玩家受擊框（64×180）重疊即拾取並回調主場景。碎銀必掉、木牌按 `drop_chance`（默認 0.1，export 可調）；`main_rigged.gd` 加拾取提示 Label（「拾得：xxx」，2s 淡出）。
  - **勝負判定**改為 `$P2.current_hp <= 0 and $P2._death_done`——青煙散完才彈「武松勝！」，避免人還沒散就出結果。
  - **踩坑（自測時序）**：P2 若同時由引擎物理推進、又在物理回調裡手推 `_physics_process`，兩條推進疊加會讓 `_death_t` 兩倍速（n=35 就已 finished、alpha 0），「淡出中」斷言必假；只能選一條——現在 P2 交給引擎自走，只手推 `main._process`。
  - 全量回歸（10 個自測 + 主場景 `--quit-after 240`）全 RC=0；`selftest_ai` 受擊後退段的假人血量由 1 改成 50（原值會被新死亡演出判死、AI 直接凍住），其餘斷言不變。

- [x] **V0.3.0 線性章節流程（FLOW-01／02／03／06；`tools/selftest_flow.gd` 55 項 PASS）**：
  - **FLOW-01 章節管理器**：`data/story_beats.gd` 定義 B1–B9 與 D-01–D-10（單句 ≤40 字、每拍 ≤3 行），`scripts/chapter_manager.gd` 以 autoload `ChapterManager` 保存當前節拍、旗標、戰利品與玩家血量；`goto_beat()` 按 `SCENE_PATHS` 載入六場景。
  - **FLOW-02 對話系統**：`scripts/ui/dialogue_ui.gd` + `scenes/ui/DialogueUI.tscn`，34 字／秒打字機、按攻擊鍵先補滿再下一句、對話期間凍結雙方、結束回調。
  - **FLOW-03 檢查點**：單槽 `user://checkpoint.json`，先寫 `.tmp` 再 rename，rename 失敗回退直寫；讀檔驗證 JSON／節拍／flags／loot 型別，損壞檔拒絕載入；山神廟 SCN-04 自動存檔。
  - **六場景骨架**：`scenes/chapters/SCN_01_Inn`／`02_Trail`／`03_Forest`／`04_Temple`／`05_Ridge`／`06_Pool`，共用 `scripts/chapters/stage_base.gd`（背景／地面／牆／P1／可選敵人／HUD／對話／勝敗切換）。SCN-03 接吊睛小虎、SCN-05 接猛虎 Boss、SCN-06 以水面月亮＋字幕收尾回主菜單。
  - **入口**：`scenes/MainMenu.tscn` 取代舊 NodeMap 作為 `run/main_scene`，開始新局→SCN-01，續玩→讀檢查點回山神廟。
  - 已知留白：SCN-02 目前是「山道教學提示」骨架，伥鬼戰待美術／敵人素材；SCN-06 倒影、BOS-10 虎屍／黑霧畫面仍待 SC-06。

## 待實現

- [x] 酒氣滿自動拔刀（立繪切換：正常→覺醒版+金黃閃光）
- [x] 導入第一張美術素材（武松水墨立繪替換灰色方塊）
- [x] 導入舞台背景（景陽岡月夜山道概念圖）
- [x] 6張動作關鍵幀（直拳/上勾拳/掃堂腿/受擊/跳躍/拔刀）
- [x] 狀態機切換貼圖（不同動作顯示不同姿態）
- [x] 補充關鍵幀：走路A/B、重劈、喝酒
- [x] CPU AI（P2自動靠近+攻擊+防禦；V0.2.9 起改為 docs/04 伥鬼規格）
- [x] 覺醒必殺基礎版（RT/O 滿氣觸發、全程無敵、320 傷害、金黃脈衝；完整過場鏡頭演出後續）
- [x] 飛雲浦反擊：簡化觸發（防中/受擊前 4 幀按重）＋完整 214（後→下→前）+重；招架無敵 + 120 浮空
- [x] 牆邊連段獎勵／牆族（撞牆＝額外傷害＋黏牆 30 幀＋彈回可追打；見 V0.2.8）
- [x] CPU 對手（先做最簡單的AI）｜伥鬼：會站防、會輕攻、偶爾前衝棍擊（見 V0.2.9）

## 如何運行

1. 用 Godot **4.7.x** 打開 `D:\水滸g\game\project.godot`
2. 首次打開等待 `assets/anim` 素材導入完成
3. F5 運行進入主菜單，選「開始新局」→ 酒肆（SCN-01）；P1：A/D 移動、S 蹲、Space 跳、J 輕、K 重、L 格擋、Shift 衝、I 喝酒

> 註：`水滸：妖魔劫-(4.2)/` 為早期 C# 灰盒版，其啟動/活躍/恢復幀設計被本目錄 GDScript 版的 `data/action_frame_data.gd` 繼續採用；實際運行以本目錄為準。
