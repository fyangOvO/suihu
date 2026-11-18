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
- [x] 首次啟動引導（顯示模式／主音量／手柄死區，確認後不再彈）
- [x] 手柄死區生效（移動類比軸可調，按鍵動作不受影響）

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
  - 已知留白：SCN-01 在 V0.3.3 已补三镜演出；SCN-02 已接老虎伥鬼实体战；SCN-06 倒影、BOS-10 虎屍／黑霧畫面仍待 SC-06。

- [x] **V0.3.1 老虎伥鬼六帧素材（`tools/check_corpse_ghost_spec.py` 6/6 PASS）**：
  - 母图 `docs/preview/corpse-ghost-pose-sheet-src.png`（六格：站立／走 A／走 B／木棍直戳／木棍下砸／受击后仰）。
  - 成品 `assets/anim/corpse_ghost/{idle,walk-a,walk-b,thrust,smash,hurt}.png`，`tools/build_corpse_ghost_frames.py` 由母图可重复重建；全部 512×640 RGBA、四角透明、脚底基线 611–612。
  - 拆帧对照 `docs/preview/corpse-ghost-frames.png`；六格人物身份、破旧短褐、青灰尸脸、腰间木牌与木棍保持一致。

- [x] **V0.3.2 SCN-02 老虎伥鬼实体战（`tools/selftest_corpse_ghost.gd` 49 项 PASS；全量 13 个自测 RC=0）**：
  - **`scenes/CorpseGhost.tscn`**：从 `RiggedFighter.tscn` 派生，`max_hp=180`、`anim_dir=res://assets/anim/corpse_ghost/`、`start_state=CorpseIdle`、`ai_profile=corpse_ghost`、`drop_chance=0.1`。
  - **`data/action_frame_data.gd` 新增伥鬼专属状态**：`CorpseIdle`／`CorpseWalk`／`CorpseBlock`／`CorpseLight`（木棍直戳 65 伤、启动 8 帧、24 帧）／`CorpseHeavy`（木棍下砸 130 伤、启动 15 帧、43 帧）／`CorpseDash`（前冲棍击 65 伤、`vx=280`）／`CorpseHurt`／`CorpseHurtAir`／`CorpseDeath`。所有状态只引用伥鬼六帧，不再回退 `redraw_clean/` 的武松素材。
  - **`scripts/rigged_fighter.gd`**：新增 `_is_corpse()` 分支与 `_ai_apply_corpse()`，复用既有 `ai_plan()` 的距离／架招／低血／冷却决策，但把 `light`／`heavy`／`dash_attack`／`block`／`rock` 映射到伥鬼专属状态；`_decide_corpse_free_state()` 只允许站防／拖步／站立，不蹲防、不跳跃。`CorpseBlock` 走站防减伤 50%，受击固定 `CorpseHurt`，死亡固定 `CorpseDeath`；墙族弹回改走 `CorpseHurtAir`，避免切到武松的 `HurtAir`。
  - **`scripts/chapters/scn_02_trail.gd`**：SCN-02 覆写 `opponent_scene_path()` 接 `CorpseGhost.tscn`；B2 先播 D-04 再写 B3，B3 直接把伥鬼放到 x=1120 开战；2.2／5.2／8.2s 三条 HUD 教学提示（不再用 9.6s 计时器自动过关）；只有伥鬼青煙散完才 `mark_clear("B3")` 并 `_finish_to("B4", 1.6, "山道通了。")`。
  - **流程断言同步**：`tools/selftest_flow.gd` 的 SCN-02 分支从「no opponent」改为「CorpseGhost 180hp + profile」；现 56 项全 PASS。
  - 离屏验收 `docs/preview/flow-scn02-corpse.png`：山道背景、双侧血条、P2「老虎伥鬼」、伥鬼实机帧与教学横幅同时可见。

- [x] **V0.3.3 SCN-01 酒肆三镜演出（`tools/selftest_inn_cutscene.gd` 26 项 PASS；全量 14 个自测 RC=0）**：
  - **`scripts/chapters/scn_01_inn.gd` 全文重写**：不新增素材，酒肆布景全部程序化——`InnBack`（墙／地板／梁柱／窗／后架）、`InnFront`（前桌／三酒碗／酒壶／油灯／店家剪影／尾影）、`InnCanvasModulate`；武松饮酒复用现有 `Drink` 四帧（`drink-prep`／`drink-tilt`／`drink`／`drink-finish`，48 逻辑帧）。
  - **第一镜·喝酒**：B1 三段对话结束后 `_begin_inn_cutscene()`；`Visual` 位置 0.45s 由 `(0,-160)` 下移到 `(0,-108)` 模拟落座，P1 物理关闭、面向店家；三碗各 0.82s 播 `InnDrink1/2/3`，每碗结束 0.25s 淡出，第三碗后进灯灭。无新增战斗、无 HP 结算。
  - **第二镜·灯灭**：0.55s 并行 tween 把 `PointLight2D.energy`／径向光晕 `modulate:a`／火苗 `modulate:a` 归零，`CanvasModulate` 压到 `Color(0.27,0.26,0.24)`；顶部接「燈滅了。店家的影子，多了一條尾巴。」
  - **第三镜·尾影**：`TailRoot` 从店家剪影右后侧 0.30s `TRANS_BACK` 弹出、0.35s 停留、0.25s 淡出（总 0.9s），`Line2D` 宽 32＋四控制点锥形收尾；尾影收掉后 `_finish_to("B2", 0.7, "")` 出门。
  - **自测**：`tools/selftest_inn_cutscene.gd` 26 项——布景节点、三碗数量、落座下移、P1 物理冻结、第一碗淡出、灯灭三参数归零、CanvasModulate 压暗、尾影出现、三碗全空、B1 clear→B2。
  - **离屏验收**：`docs/preview/flow-scn01-drink.png`（油灯暖光、三碗酒、武松举碗）与 `flow-scn01-tail.png`（灯灭冷灰、剪影＋尾影＋金色横幅）。工具 `tools/capture_scn01_cutscene.gd` 用 `SubViewport(1920×1080)`＋条件触发双帧，`16×16` 窗口移出屏幕，无可见窗口。

- [x] **V0.3.4 UI 觀感基線（字體＋HUD＋主菜單＋對話框；全量 14 個自測 RC=0）**：
  - **字體入庫**：`assets/fonts/MaShanZheng-Regular.ttf`（馬善政毛筆楷書，OFL）作標題／人名／橫幅；`assets/fonts/LXGWWenKaiLite-Regular.ttf`（霞鶩文楷 Lite，OFL）作正文與按鈕；許可證隨字體放在 `assets/fonts/OFL-*.txt`。`project.godot` 增 `gui/theme/custom_font`，全局先吃正文楷體。
  - **統一 UI 樣式**：新增 `scripts/ui/ui_style.gd`，集中暗墨底／殘金線／朱砂血條／紙色文字與 `StyleBoxFlat` 面板、血條、按鈕三態；場景不再各自硬寫一套色值。
  - **HUD 重排**：左上改「名札」面板——毛筆「武松」＋細血條＋酒氣條＋「酒」字；右上 P2 同結構；中央「酒肆」標題加短金線；提示與戰利品移到左下，不再堆在頭頂；橫幅改為暗墨長條＋上下金線，避免大字裸浮。
  - **主菜單重排**：左欄大標題＋朱砂「劫」印＋豎金線；按鈕改窄金邊、左對齊、hover 朱砂填充；底部加場景路徑小字，移開原本正中的大灰塊。
  - **對話框改版**：加朱砂豎印、上下金線與更寬的正文區，發言人用毛筆字，正文用文楷，提示右下弱化。
  - **參考站取捨**：爱给网 `game2d/lib/` 的素材以日系 RPG Maker 為主，直接搬會撞本作暗黑水墨調性；本批只借鑒其「九宮格面板／血條框／按鈕三態」的結構，UI 仍自繪，未下載其角色圖入庫。
  - **離屏驗收**：`docs/preview/flow-main-menu.png` 與 `flow-scn01-dialogue.png` 已重出；SCN-01 喝酒／尾影兩張同步帶新 HUD。

- [x] **V0.3.5 UI 殼層與觀感細節第一批（16 項殼層自測 PASS、全量回歸 fails=0）**：
  - **暫停／設置／死亡重開／章末結算**：新增 `scripts/ui/game_shell.gd`（CanvasLayer 30、`PROCESS_MODE_ALWAYS`），Esc 呼出暫停；死亡不再自動回檢查點，改由玩家選「重試本段／回山神廟／回主菜單」；SCN-06 的 B9 結尾由 9 秒 credits 改成章末結算面板。
  - **Boss 條**：`stage_base` 偵測 `_boss_boot` 後隱藏 P2 面板，改用 960×84 的 Boss 條（名札、一／二／三階段、1200 HP、三格刻度與末端高光）。
  - **觀感層**：`ui_style.gd` 新增 `add_paper`（256 噪聲紙紋）、`add_corner_marks`（四角 L 金線）、`add_nine_patch`（程序生成 32×32 九宮格框）；主菜單、HUD 名札、對話框、Boss 條與殼層面板都吃到紙紋／角線，按鈕加菱形 `MenuMark`。
  - **驗收**：`tools/selftest_ui_shell.gd` 16 項 PASS；新增 `tools/capture_ui_shell.gd` 產 `ui-pause.png`／`ui-settings.png`／`ui-death.png`／`ui-summary.png`／`ui-boss.png`，五張 `err=0`。已知 960×540 下採樣後四角金線偏細，留待下一輪提高對比或改局部預覽。

- [x] **V0.3.6 內容三段：SCN-03 亂林霧、SCN-04 山神廟、SCN-06 水潭倒影（三支新自測 PASS、FLOW fails=0）**：
  - **SCN-03 亂林**：`scn_03_forest.gd` 在背景下加三層 alpha 漸變霧帶（遠／中／近，各自速度與透明度）＋六根樹幹／六團枝冠剪影；霧貼圖用 `FastNoiseLite` 逐像素寫 `Image`，避免 `NoiseTexture2D` 平鋪成方塊；`_tick_stage` 推視差並在 `FOG_TRAVEL` 回收。
  - **SCN-04 山神廟**：`scn_04_temple.gd` 程序化搭建廟內地面、後牆、立柱、廟門、供桌、香爐、雙燭焰光、山神像（金片眼、殘金冠、垂帶）；B4 問路結束後山神像眨眼一次（`_blink_once`，只觸發一次），同時保留存檔與上山流程。
  - **SCN-06 水潭**：`scn_06_pool.gd` 加水面月影／月影寬帶、水岸蘆葦、星點與右岸石台虎屍剪影（含虎斑與冷邊），水下加虎屍倒影；B9 對話結束後留 1.4 秒空鏡再進章末結算，讓倒影與虎屍真的被看見。
  - **驗收**：`tools/selftest_scn03_forest.gd` 14 項、`tools/selftest_scn04_temple.gd` 10 項、`tools/selftest_scn06_pool.gd` 10 項全部 PASS；新增 `capture_scn03.gd`／`capture_scn04.gd`／`capture_scn06.gd`，三張 `err=0`；`selftest_flow` 仍 `fails=0`。
- [x] **V0.3.7 內容觀感返工：分叉樹、廟內暖光、虎屍脊線與腿部（三支自測仍 PASS、FLOW fails=0）**：
  - **SCN-03**：`_add_trunks` 改為每棵樹一組 `Tree`／`Trunk`／`Root`／四條 `Branch`，樹幹下粗上細、根部抓地；樹冠改成四團不規則葉簇，不再是一整排黑塊。
  - **SCN-04**：新增徑向 `GradientTexture2D` 暖光（`_add_glow`＋`BLEND_MODE_ADD`），兩支燭移到山神像外側；供桌、地面、香爐與神像臉面各有暖光，後牆／地面／神像改成暖石灰，燭火不再只是一塊均勻色斑。
  - **SCN-06**：虎屍加 `TigerSpine` 脊線、`TigerBelly` 腹線、`TigerHaunch` 胯線、耳朵／吻部／閉眼，四條腿重畫成帶膝節與腳掌的多邊形，石台加接觸陰影。
  - **驗收**：`selftest_scn03_forest`／`selftest_scn04_temple`／`selftest_scn06_pool` 全 PASS；`selftest_flow` `fails=0`；三張截圖已重出。
- [x] **V0.3.8 戰鬥層驗收：SCN-02 真打自測＋Boss Visual 對齊受擊盒**：
  - **SCN-02 不再秒殺**：新增 `tools/selftest_scn02_fight.gd`，不呼叫 `take_damage`；用 `Input.action_press("p1_light")` 模擬玩家每 24 幀出輕擊、伥鬼起手時按 `p1_block` 防禦，讓 AI 與玩家都走完整狀態機。7 項斷言全 PASS：AI 會接近並出 `CorpseLight`／`CorpseHeavy`／`CorpseDash`、會打到玩家、玩家輕擊能扣血、伥鬼在 767 幀內被打死、B3 寫完成並排隊 B4。
  - **Boss 尺寸對齊**：實測 `boss-idle.png`（768×768）可視 bbox 300×460、基線 y=720；`Boss.tscn` 的 `Visual` 由繼承的 0.55／-185 改為 `scale 0.72`／`position (0,-242)`，可視高約 331px、腳底落回原點，明顯蓋過 110×240 的 `Collision`／`HurtShape`，不再出現「老虎比受擊盒小」。
  - **自測擴充**：`selftest_boss.gd` 新增 4 項（碰撞盒 110×240、Visual 0.72、腳底 ±2px、可視高 ≥ 240×1.15），Boss 自測 `fails=0`；`selftest_corpse_ghost` RC=0、`selftest_flow` `fails=0`。
  - **截圖**：`docs/preview/boss-preview.png` 與 `flow-scn05-ridge.png` 已重出，崗頂老虎現在比玩家高半個頭、與 Boss 條比例正常。
- [x] **V0.3.9 SCN-05 三階段實戰：Boss 後撤死循環修正＋入場真打自測（`selftest_scn05_boss_fight` 11 項全 PASS、`selftest_boss` fails=0）**：
  - **Boss AI 兩處修正**：`boss_plan` 的 P1 分支把 `dist > 520` 的 `approach` 提到 `retreat` 之前，避免玩家拉遠時仍一路後退；`_boss_apply` 的 `retreat` 改為**只在下令瞬間**承諾一次 `boss_retreat_t`，不再每幀刷新，終結「退到右牆後仍持續 BossWalk 朝牆外走」的死循環。
  - **SCN-05 入場實戰**：新增 `tools/selftest_scn05_boss_fight.gd`，從 B7 真實實例化 `SCN_05_Ridge.tscn`，用 `Input.action_press` 模擬玩家：Boss 冷卻窗口貼到 135–150 打 `Light1→2→3` 連段；冷卻結束前 0.8s 退到 350–370；不可格擋撲擊用醉打無敵／Dash 穿過；第一輪先吃一次撲擊驗證 Boss 傷害窗口。不在外部改血量。
  - **結果**：`frames=1799 p1_hp=493 p1_min=493 boss_hp=0 boss_min=0 attacks=8 phase=3`；Boss 實際走完 P1→P2→P3、死亡演出、B7 clear 並排隊 B8。
  - **回歸**：`selftest_boss` 既有 39+4 項 `fails=0`，兩處 AI 修正未破壞招式、尺寸與階段斷言。
- [x] **V0.3.10 S09 線性全流程一輪到底：酒肆→山道→山神廟→亂林→崗頂→水潭（`selftest_full_run` 10 項 PASS、約 3.8–4.0k 幀、零死亡）**：
  - **新自測**：`tools/selftest_full_run.gd` 從 B1 酒肆起跑，對話自動翻頁；山道伥鬼、亂林小虎、崗頂 Boss 全部用 `Input.action_press` 真打，不呼叫 `take_damage`、不改血量。
  - **路線**：實際順序 SCN-01 → SCN-02 → SCN-04 → SCN-03 → SCN-05 → SCN-06，對應 B1→B9；B4 山神廟先存檔再進 B5 亂林。
  - **結果**：兩跑 3775／3991 幀（約 63–66 秒）、`deaths=0`、`beat=B9`、B1–B9 全 clear、B4 檢查點已寫入、章末結算面板已顯示；伥鬼／小虎／Boss 三場皆由玩家實際打死。
  - **回歸**：`selftest_scn05_boss_fight` 仍為 11 項 PASS（`frames=1799 boss_hp=0 phase=3`），全流程沒有新軟鎖。
- [x] **V0.3.11 S09.1 失敗重開閉環：死亡面板 → 重試本段／回山神廟（`selftest_restart_flow` 15 項 PASS）**：
  - **無檢查點路徑**：B3 山道死亡後死亡面板出現、`DeathCheckpoint` 正確禁用；按「重試本段」重載 SCN-02，保持 B3、玩家 800 血且可操作，shell 關閉。
  - **有檢查點路徑**：B4 山神廟存檔後進 B5，於 SCN-03 死亡；`DeathCheckpoint` 啟用，按「回山神廟」真的讀檔回 SCN-04 B4，恢復存檔血量、解除暫停並回到可玩狀態。
  - **結果**：`RESTART_FLOW_SELFTEST result=PASS fails=[] frames=397 beat=B4 dialogue_calls=8`；死亡後兩條重開路徑都不軟鎖。
- [x] **V0.3.12 S10 UI 焦點可達性＋顯示設置持久化（`selftest_ui_focus_settings` 34 項 PASS）**：
  - **主菜單真修復**：`MainMenu.tscn` 根節點原本漏掛 `main_menu.gd`，按鈕與焦點邏輯不會生效；現已補回 `script = ExtResource("1_menu")`，新局／續玩／離開與鍵盤手柄焦點都接回。
  - **焦點鏈**：暫停 4 鍵、設置 2 鍵、死亡 2／3 鍵（依檢查點動態跳過禁用）、結算 2 鍵都建立上／下／左／右／next／prev 環；面板開啟即抓第一顆，設定頁按取消回暫停，暫停頁取消回遊戲。
  - **暫停鍵**：新增 `ui_pause`（Esc＋手柄 Start），`stage_base` 與 `GameShell` 共用，避免手柄 Start 被當成喝酒，也避免設定頁按 Esc 被搶回暫停首頁；對話演出期間也可暫停。
  - **設定持久化**：新增 `scripts/ui/user_settings.gd`，以 `user://settings.cfg` 保存顯示模式；主菜單啟動時套用，切換即時寫入；檔案損壞或非法值回退視窗模式，下一次保存可自動修復。
  - **結果**：`UI_FOCUS_SETTINGS_SELFTEST result=PASS fails=[] frames=5`；`selftest_ui_shell` 16 項、`selftest_flow` 56 項、`selftest_restart_flow` 15 項仍全 PASS。
- [x] **V0.3.13 S11 END-01 結局名單（`selftest_end_credits` 11 項 PASS）**：
  - **流程**：B9 對話後進章末結算；結算頁按「回到主菜單」先進黑幕製作名單，名單縱向滾動 20 秒，可按「跳過名單」或 Esc／手柄 A 立即返回主菜單。
  - **觀感**：黑底＋紙紋＋四角金線，標題與段落用殘金／宣紙色，右下留「跳過名單」；名單內容只列實際存在的工作項，不編造人名或音頻職位。
  - **結果**：`END_CREDITS_SELFTEST result=PASS fails=[] frames=6`；UI 焦點與殼層回歸仍 PASS。
- [x] **V0.3.14 S11 Boss 條／教學提示觀感統一（`selftest_tutorial_hint` 8 項＋`selftest_ui_shell` 21 項 PASS）**：
  - **Boss 條**：面板改成與 Banner 同軸的 960×92，x=480，和 P1 面板留 16px；Boss 名 30px、`虎威` 小籤、右側階段名與三顆階段菱形、右側血量文字；血條 912×16，左右各內縮 24，沿用 8 段 HUD 的白線／端帽／分段刻度語言。
  - **Banner／教學**：Banner 移到 y=176，與 Boss 面板留 20px；寬高同為 960×64。教學提示多帶 `教學` 小籤，正文避開標籤區並降為 28px；一般劇情 Banner 不帶籤、維持居中 30px。SCN-02 三條教學提示改用此格式。
  - **驗收**：`TUTORIAL_HINT_SELFTEST result=PASS fails=[] frames=5`；`UI_SHELL_SELFTEST` 21 項、`HUD_SELFTEST`、`SELFTEST BOSS`、`FLOW_SELFTEST` 全 PASS。更新 `docs/preview/ui-boss.png`、`flow-scn05-ridge.png`，新增 `flow-scn02-tutorial.png`。
- [x] **V0.3.15 SCN-03 亂林三層霧（`SCN03_FOREST_SELFTEST` 19 項 PASS）**：
  - **深度順序**：遠霧先掛在樹幹後方，中霧在樹冠之後，近霧最後蓋到林影上；遠→近移動速度 18／46／92，避免三層同速糊成一片。
  - **分層帶**：遠霧 y=108、高 260、冷灰藍；中霧 y=390、高 230、灰綠；近霧 y=720、高 200、偏亮灰綠；alpha 0.46／0.38／0.32，各自獨立噪聲，寬 2600 避免循環接縫。
  - **驗收**：`SCN03_FOREST_SELFTEST result=PASS fails=[]`；新增「遠霧在樹後／近霧在樹前／三層高低與速度遞增／三張紋理互異」5 項。更新 `docs/preview/scn03-forest.png`。
- [x] **V0.3.16 SCN-04 山神廟暖光與眨眼彩蛋（`SCN04_TEMPLE_SELFTEST` 15 項 PASS）**：
  - **暖光**：兩支燭各補一層外圈光暈與地面光池；供桌補正面暖光；山神像背後加暖色輪廓光，整體牆面再加一層低強度暖洗光。燭芯、香爐與山神臉部仍是局部光，不把整間廟照亮。
  - **臉部層次**：山神臉補眉骨、鼻樑、鼻側陰影與眼窩；金片眼睛加 `pivot_offset`，眨眼從眼窩中心向上下合攏，不再只縮左上角。
  - **眨眼**：由 `_tick_stage` 以 0.10s 閉眼、0.16s 睜眼確定性推進；B4 對話結束後只觸發一次，1.8s 後進 B5。
  - **驗收**：`SCN04_TEMPLE_SELFTEST result=PASS fails=[]`；新增眼窩、眉骨／鼻樑、暖光暈、眨眼中段與睜眼回位 5 項。更新 `docs/preview/scn04-temple.png`，新增 `docs/preview/scn04-blink.png`。
- [x] **V0.3.17 SCN-06 水潭倒影與虎屍剪影（`SCN06_POOL_SELFTEST` 24 項 PASS）**：
  - **玩家倒影**：B8 先在潭邊水面留一個發暗的人形倒影；字幕推進 0.75s 後以一道水面冷光切換成披直裰的白虎倒影（含虎頭、耳朵、四腿、舉爪、虎斑與尾），B9「下山」保留白虎倒影作結。
  - **虎屍剪影**：虎身壓暗到近黑，補冷灰背脊、頭部邊光、虎斑與腿部層次；水面倒影改成可讀的壓扁虎形，加上四道水下波紋，避免 960×540 只看見一團暗影。
  - **水面**：加深水色，補 `WaterSurface`／`WaterDeep` 上下水帶與月影外圈微光；月影條帶略提 alpha、寬度，讓黑水仍有上下層次。
  - **驗收**：`SCN06_POOL_SELFTEST result=PASS fails=[]`（24 項）；`FLOW_SELFTEST fails=0`；`selftest_full_run` 重跑 `result=PASS fails=[] frames=3900 deaths=0 beat=B9`。更新 `docs/preview/scn06-pool.png`。
- [x] **V0.3.18 UI 殼層結算頁間距收尾（`UI_SHELL_SELFTEST` 23 項 PASS）**：
  - **章末結算**：`SummaryNew`／`SummaryMenu` 上移 24px，和底下 `SummaryHint` 留出 30px，按鈕不再貼住提示文字；`SummaryStats` 與按鈕之間仍保留 10px。
  - **設置標題**：`SettingsTitle` 的陰影降為 1px、去外描邊，避免 960×540 下「設置」字邊發糊像重影。
  - **防回歸**：`selftest_ui_shell` 新增「設置頁標題只出現一次」與「結算提示與按鈕至少留 16px」2 項，23 項全 PASS。
  - **截圖**：重出 `docs/preview/ui-summary.png`、`ui-settings.png`、`ui-pause.png`、`ui-death.png`、`ui-boss.png`、`flow-main-menu.png`。
- [x] **V0.3.19 SCN-01 三碗酒／燈滅尾影觀感（`INN_SELFTEST` 30 項 PASS）**：
  - **三碗酒**：碗身高 24px、補碗腹、碗沿、酒面與暖色反光，三碗間距 86px；960×540 下不再只剩三條亮邊。
  - **尾影**：`TailLine` 改為 44px 寬暗褐錐形、`TailRim` 6px 暖邊；補 `ShopkeeperRim` 3px 剪影輪廓，尾巴從店家背後伸出，不再像浮在牆上的發光彎鉤。
  - **驗收**：`INN_SELFTEST fails=[]`（30 項）；`FLOW_SELFTEST fails=0`；`FULL_RUN_SELFTEST result=PASS fails=[] frames=3775 deaths=0 beat=B9`。重出 `docs/preview/flow-scn01-drink.png`、`flow-scn01-tail.png`。
- [x] **V0.3.20 SCN-02 伥鬼剪影與教學聚焦（`SCN02_FIGHT_SELFTEST` 12 項 PASS）**：
  - **伥鬼存在感**：`CORPSE_VISUAL_SCALE=0.68`、`CORPSE_VISUAL_Y=-198` 把 P2 放大並保持腳底貼地；新增 `GhostPresence`（腳影、高低冷霧、左右煙絲、入場霧爆散），碰撞盒不變。
  - **教學連結**：新增 `TutorialFocus` 四角金框＋頂部菱形，跟隨 P2 並緩慢呼吸；三段教學期間顯示，第 10.8 秒或伥鬼死亡後隱藏。
  - **截圖**：`tools/capture_scn02.gd` 重寫，先凍住入場站位拍 `flow-scn02-corpse.png`，再觸發第一段教學拍 `flow-scn02-tutorial.png`。
  - **驗收**：`SCN02_FIGHT_SELFTEST result=PASS fails=[] frames=767`；`FLOW_SELFTEST fails=0`；`TUTORIAL_HINT_SELFTEST PASS`；`FULL_RUN_SELFTEST result=PASS fails=[] frames=3901 deaths=0 beat=B9`。
- [x] **V0.3.21 UI 殼層收尾：四頁面板九宮格、按鈕圖標、Boss／P2 對齊（`UI_SHELL_SELFTEST` 45 項 PASS）**：
  - **面板**：`add_nine_patch` 改為 `PRESET_FULL_RECT` 跟隨父節點尺寸，不再只在建立時取一次 `parent.size`；暫停／設置／死亡／結算四頁都掛九宮格，紙紋降到 0.045、四角金線加粗到 2px。
  - **按鈕**：`menu_button_styles` 增加可選 `icon_kind`，殼層按鈕左側改畫程序化小圖標（繼續／設置／主菜單／離開／顯示／返回／重試／山神廟／重新開始／跳過），文字起點同步內縮到 52px；主菜單仍保留既有菱形 `MenuMark`。
  - **頁面內容**：暫停、設置、死亡補標題下金線；設置頁補「畫面」小節；結算頁 `SummaryRule` 從空 Label 改成真正的 1px 金線。
  - **Boss／P2**：`BossHPText` 右端內縮 24px，階段 pip 改為 14px 間距並與 HP 文字留 5px 空隙；P2 面板由 430×112 改為 430×128，補 `P2Rule`，與 P1 同高、同寬、同頂邊、左右 34px 對稱。
  - **截圖**：`capture_ui_shell.gd` 在拍 Boss 條前把 beat 設到 B7，避免 SCN-05 在 B6 亮相時 Boss 仍借用基礎人形貼圖；`ui-boss.png` 已重出為乾淨的虎與 Boss 條。
  - **驗收**：`UI_SHELL_SELFTEST result=PASS`（45 項）；`HUD_SELFTEST result=PASS`；`FLOW_SELFTEST fails=0`；重出 `ui-pause.png`、`ui-settings.png`、`ui-death.png`、`ui-summary.png`、`ui-boss.png`、`flow-scn02-corpse.png`、`flow-scn02-tutorial.png`。
- [x] **V0.3.22 SCN-03 亂林分叉與三層霧打碎（`SCN03_FOREST_SELFTEST` 22 項 PASS）**：
  - **樹幹分叉**：六棵樹依近／中／遠景分開，主幹在 `y=-420` 附近長出左、右主枝與中央主梢，每枝再遞迴分二級枝；枝條用帶彎度的六點多邊形收尖，枝端接葉簇，樹幹補單側樹皮亮邊與三段根盤。
  - **霧層**：遠／中／近三層改成 `768×160` 雙噪聲貼圖，低頻雲團疊高頻細節，手動 smoothstep 打出可穿過的洞，上下緣用 `sin(πt)` 包絡收邊；層高、位移速度與 alpha 仍分開。
  - **貼地霧團**：新增 `Mist90/720/1370/1680` 四團徑向漸變，打斷 `FogNear` 的整條水平帶；三層霧再加極慢上下浮動，避免像固定橫幅。
  - **驗收**：`SCN03_FOREST_SELFTEST result=PASS fails=[]`（22 項，新增分叉、枝端葉簇、貼地霧團）；`FLOW_SELFTEST fails=0`；重出 `docs/preview/scn03-forest.png`。
- [x] **V0.3.23 SCN-03 月光穿霧與樹隙光柱（`SCN03_FOREST_SELFTEST` 27 項 PASS）**：
  - **月光光暈**：月亮下方加 `MoonGlowWide`／`MoonGlowCore` 兩層徑向漸變加法光暈，外圈大而淡、內核小而亮，讓月光先滲進遠霧再被樹枝切碎。
  - **樹隙光柱**：`MoonShaftVolume` 一層極淡體積底光，加 A/B/C/D 四束窄光柱；光柱由 `256×512` 程序錐形貼圖生成，頂端收尖、底端展開、沿長度遞減 alpha 並混少量噪聲，材質用 `CanvasItemMaterial.BLEND_MODE_ADD`。
  - **遮擋關係**：節點順序為 `FogFar → MoonGlow → MoonShaft → Tree → FogMid → FogNear`；樹幹遮出樹隙，中近霧再把光柱壓柔，避免變成浮在林影上的舞台燈。
  - **驗收**：`SCN03_FOREST_SELFTEST result=PASS fails=[]`（27 項，新增月光光暈、四束光柱、加法材質、光柱在樹幹後方與中近霧後方）；`FLOW_SELFTEST fails=0`；重出 `docs/preview/scn03-forest.png`。
- [x] **V0.3.24 SCN-04 山神廟暖光與眨眼彩蛋補完（`SCN04_TEMPLE_SELFTEST` 28 項 PASS）**：
  - **香爐與供桌**：供桌中段補 `Censer`／`CenserRim`／`CenserFootL/R`，三炷香從爐口插出；另加前層 `AltarFront`／`CenserFront`，讓桌面、香爐與香壓在神像下擺前面；供桌前緣加 `AltarGoldEdge` 金線，桌面不再是一塊空紅布。
  - **暖光層**：燭光分成焰心、近光圈、外圈與地面光池四層，並加入 `AltarFrontWarm`、`IdolFaceWarm`、`IdolWarm`、`IdolRobeWarm`、`CenserFrontGlow`；燭焰與燭光以 `sin` 微幅閃爍，暖光不再是靜止的均勻色斑。
  - **山神像**：補肩、前襟、腰帶、手與 `IdolCheekL/R`、`IdolMouth`、`IdolForeheadMark`、`IdolEyeGlowL/R`、`IdolRimL/R` 與 `IdolCrownEdge`；臉部底灰提亮，暖光集中在額頭與鼻樑，眼窩保留金片眼輝光；後牆補砌石線與廟門框，避免大面積平塗。
  - **眨眼彩蛋**：`_blink_once()` 後眼窩輝光隨眼瞼開合從 base×0.38 回到 base；`BlinkSpark` 在 0.10s 閉眼時達到金色微閃，睜眼後歸零；`capture_scn04.gd` 現在同時輸出 `scn04-temple.png` 與 `scn04-blink.png`。
  - **驗收**：`SCN04_TEMPLE_SELFTEST result=PASS fails=[]`（28 項，新增香爐、前層供桌、暖光層、神像衣褶、牆面砌石、眼窩輝光、金閃、燭火閃爍節點）；`FLOW_SELFTEST fails=0`；重出 `docs/preview/scn04-temple.png` 與 `docs/preview/scn04-blink.png`。
- [x] **V0.3.25 SCN-06 水潭虎屍層次與倒影重讀（`SCN06_POOL_SELFTEST` 31 項 PASS）**：
  - **虎屍剪影**：虎身與頭部分色，補 `TigerBlood`／`TigerBloodPool` 石台血跡、`TigerRib0..3` 肋線、`TigerNose`／`TigerFang278/288`／`TigerWhisker*` 面部細節，四腿重新分色並加 `TigerToe*`；960×540 下不再只是一團暗塊。
  - **水中虎影**：`TigerReflection` 由 `scale.y=-0.42` 改 `-0.52`，補 `RLeg*`／`RPaw*`／`RMuzzle`／`RStripe0..2`，水線下能讀出四腿與頭部缺口；倒影整體加冷色 modulate，避免和岸上虎屍脫節。
  - **月影與遠岸**：月影從整齊七層改成九條帶橫向偏移的碎月，水面不再像漏斗；新增 `FarRidge` 遠岸嶺線與 `PoolMist` 水線薄霧，讓大面積黑空有前後景。
  - **玩家倒影**：`PoolReflection` 加冷色 modulate，白虎倒影補 `WhiteTigerUnderbelly` 與 `WhiteTigerHeadRim`，壓低過亮的水面白塊。
  - **驗收**：`SCN06_POOL_SELFTEST result=PASS fails=[]`（31 項，新增虎腿、肋線血跡、面部、倒影腿、白虎頭緣、遠岸薄霧）；`FLOW_SELFTEST fails=0`；重出 `docs/preview/scn06-pool.png`。
- [x] **V0.3.26 SCN-06 水潭只調色與提亮（`SCN06_POOL_SELFTEST` 31 項 PASS）**：
  - **虎屍提亮**：`TigerBody`／`TigerHead`／`TigerTail`、四腿與腳掌整體上調，`TigerBody` 由近黑褐抬到 `(0.125,0.112,0.092,0.99)`，頭部抬到 `(0.175,0.155,0.125,0.99)`，和石台剪影拉開；趾節、膝線同步提亮。
  - **虎屍細節**：血跡與血泊、四條肋線、虎斑、背脊冷邊、頭頂冷邊、脊線、腹線、胯線、耳、吻部、鼻頭、獠牙、鬍鬚、閉眼全部提高明度與 alpha，960×540 下能讀出頭、脊、四腿，不再只是暗塊。
  - **白虎倒影下調**：`WhiteTigerBody`／`Head`／`Ear`／`Tail`／`Leg`／`Paw`／`Rim`／`HeadRim`／`Fang`／`Eye` 與 `PoolReflection.root.modulate` 全部壓低，白虎倒影回到水面冷灰，不再像亮白貼片。
  - **水中虎影微調**：`TigerReflection` 本體、頭、腿、掌、吻部、脊線、頭緣與虎斑略提，保持水下比岸上更暗的層級。
  - **邊界**：只改顏色與 alpha，未新增節點、未改幾何、未移動位置。
  - **驗收**：`SCN06_POOL_SELFTEST result=PASS fails=[]`（31 項）；`FLOW_SELFTEST fails=0`；重出 `docs/preview/scn06-pool.png`。
- [x] **V0.3.27 SCN-06 水面呼吸與倒影微動（`SCN06_POOL_SELFTEST` 34 項 PASS）**：
  - **水面呼吸**：`WaterSurface` 與 `WaterDeep` 的 `modulate.a` 以極慢正弦微微起伏，水線不再是一條死線；月影九條碎光沿用既有節點，繼續做縮放與 alpha 呼吸。
  - **水霧漂移**：`PoolMist` 以 `960 ± 9px` 極慢橫向漂移，alpha 同步微動，讓岸與水接縫有空氣感。
  - **倒影微動**：`TigerReflection` 與 `PoolReflection` 的 `modulate.a` 各自以不同相位微動，虎影與白虎倒影不會同步呼吸。
  - **邊界**：只動既有節點的 alpha 與 `PoolMist.position.x`，未新增節點、未改幾何、未改倒影位置或 scale。
  - **驗收**：`SCN06_POOL_SELFTEST result=PASS fails=[]`（34 項，新增水面 alpha、水霧位移、虎影 alpha 三項微動檢查）；`FLOW_SELFTEST fails=0`；重出 `docs/preview/scn06-pool.png`。
- [x] **V0.3.28 戰鬥熱路徑節點與規格快取（效能優化，25 套自測 RC=0）**：
  - **節點快取**：`rigged_fighter` 在 `_ready` 一次取好 `Visual`／`HitBox`／`AttackShape`／`HurtBox`／`Collision`／`Fx`，物理幀內不再逐幀解析 `NodePath`；`fighter_fx` 同樣快取 `SlashCore`／`SlashHalo`／`Aura`／`DrunkVapor`。
  - **規格快取**：敵人 `_spec()` 的複製字典按狀態快取，`is_player1` 變更時清空（自測會在 `_ready` 後改身分），命中與每幀播放不再重建字典。
  - **HUD 增量更新**：`stage_base` 血條只寫變動值、血量文字只寫變動整數、Boss 階段名與菱形只在階段切換時重繪；血條 overlay 子節點一次取好。
  - **雜項**：對話框整句快取；`coin_pickup` 移除每幀多餘 `queue_redraw()`（本地繪製內容靜態，位移由節點座標負責）。
  - **邊界**：只動節點查找、字典複製與 UI 寫入時機，未改任何玩法數值、判定盒、動畫時序或顏色。
  - **驗收**：25 套 `tools/selftest_*.gd` 全部 RC=0／`fails=0`；主場景 `--quit-after 240` RC=0 且無 ERROR。
- [x] **V0.3.29 音頻總線與設置頁四項音量（AUD-02 核心，`selftest_audio` 58 項 PASS）**：
  - **`AudioManager` autoload**：Master／BGM／SFX／Voice 四總線（缺則建立、全部送 Master）；8 路 SFX 池輪替；BGM 雙播放器交叉淡入淡出；對話 ducking −6dB；Voice 單軌；`register_stream()` 可注入佔位串流。
  - **缺素材容錯**：`res://assets/audio/{sfx,bgm,voice}/` 不存在時 `play_*` 一律回傳 `false`、不報錯；未匯入的 `.wav` 以 `AudioStreamWAV.load_from_file()` 執行時回退，素材到位只補檔案即可。
  - **`GameAudio` 靜態入口**：所有腳本透過 `/root/AudioManager` 發聲；`--script` 自測或單場景預覽沒有 autoload 時安全 no-op，設置寫入仍走 `UserSettings`。
  - **設置持久化**：`user://settings.cfg` 的 `[audio]` 段保存 master／bgm／sfx／voice（0–1，越界或非數值回預設）；與 `[display]` 共存，互不覆蓋。
  - **設置頁**：新增「音量」區四列滑桿（主音量／背景音樂／音效／語音）＋即時數值 Label＋金線軌道／菱形握把；焦點鏈 `顯示 → 主音量 → 背景音樂 → 音效 → 語音 → 返回`，進入頁面同步存檔值。
  - **驗收**：`AUDIO_SELFTEST result=PASS fails=[]`（58 項：總線、預設值、夾取與靜音、非法值回退、SFX 池不增長、BGM 切換與淡入淡出、ducking −6dB、Voice、GameAudio no-op）；`UI_FOCUS_SETTINGS_SELFTEST result=PASS`（43 項）；`UI_SHELL_SELFTEST result=PASS`；主場景 240 幀 RC=0。
- [x] **V0.3.30 場景與戰鬥音頻調用點（AUD-03 先行，`selftest_audio` 62 項 PASS）**：
  - **戰鬥**：起手刀風（輕／重兩檔、依招式名固定音高）、命中（傷害 ≥100 走重擊）、格擋／架招、受擊、牆族黏牆、死亡（Boss 覆寫為長虎吼）。
  - **敵人與場景**：小虎前撲／三連撲／越頂／尾掃、伥鬼輕重起手、Boss 撲擊／掀身／尾掃／咆哮／階段切換／召小虎；石頭擲出／落地碎裂、掉落物拾取（碎銀／木牌分開）、酒肆三碗酒／燈滅／尾影；`BossDeathCine` 進場淡出 BGM。
  - **對話**：開始時 BGM ducking −6dB、關閉還原；每 3 字打一次低音量打字音；劇情行可帶 `voice` 欄位觸發語音軌。
  - **BGM**：主菜單 `bgm_menu`；SCN-01～06 以 `bgm_track()` 分別請求 `bgm_inn／trail／forest／temple／ridge／pool`，切場景自動交叉淡入。
  - **UI**：殼層按鈕與主菜單游標移動／確認音；所有調用點在缺素材時安全無聲。
  - **驗收**：`AUDIO_SELFTEST result=PASS fails=[]`（62 項，新增對話 ducking 調用點與主菜單 BGM 場景調用點）；26 套自測 RC=0；主場景 240 幀 RC=0 且無 ERROR。

- [x] **V0.3.31 存檔備份與損壞回退（FLOW-03，`tools/selftest_save.gd` 54 項 PASS）**：
  - **原子寫入收斂**：`save_checkpoint()` 統一走 `_write_atomic()`（先寫 `.tmp` 再 rename，rename 不支援覆蓋時退回直寫），主檔與備份共用同一條寫入路徑；任一步失敗都回填 `last_checkpoint_error` 並發 `checkpoint_failed`。
  - **覆蓋前備份**：存檔前先讀現有主檔，只有「讀得懂」才寫 `checkpoint.json.bak`——壞檔不會把上一份好檔蓋掉；首次存檔不產生備份。
  - **損壞回退**：`load_checkpoint()` 先讀主檔，解析失敗或主檔遺失時自動改讀備份，並把備份內容回寫成新主檔完成修復；`last_load_source` 記錄 `primary／backup`，`last_load_recovered` 標記是否走過救援。
  - **四態狀態**：新增 `checkpoint_state()` → `none／ok／backup／corrupt`；主菜單據此顯示「檢查點：山神廟／存檔損壞，已備份／存檔損壞，請開新局／尚無檢查點」，`has_checkpoint()` 只在 `ok`、`backup` 兩態為真。
  - **容錯**：`_parse_text()` 驗證節拍存在、`flags`／`loot` 必為字典；`_safe_int()` 接受 int／float／bool／數字字串；HP `clampi(…,1,800)`；未知掉落鍵保留、缺鍵補 0。
  - **清理**：`clear_checkpoint()` 一併清掉主檔、備份與兩份 `.tmp`，避免殘檔被下一次讀取誤判。
  - **驗收**：`SAVE_SELFTEST result=PASS fails=0 checks=54`（基本讀寫、備份、主檔損壞回退、雙壞拒絕、主檔遺失由備份續玩、非法節拍、型別容錯）；28 套自測 RC=0；主場景 240 幀 RC=0 且無 ERROR。

- [x] **V0.3.32 首次啟動引導與手柄死區（TUT-02，`tools/selftest_onboard.gd` 48 項 PASS）**：
  - **初次進山頁**：主菜單在「沒有 settings.cfg 或 `[meta] onboarded` 未設」時先彈引導頁，擋住常規按鈕；三項為顯示模式（視窗／全屏切換）、主音量（0–100）、手柄死區（0–100，預設 30）；確認後寫檔並標記 `[meta] onboarded=true`，之後不再出現。
  - **手柄死區真生效**：`UserSettings.apply_deadzone()` 對 `p1_left/right/up/down`、`p2_left/right/up/down` 呼叫 `InputMap.action_set_deadzone`；按鍵動作（輕／重／擋／跳／衝／必殺）維持工程預設 0.5，不被滑桿影響。滑桿 0–100 映射 0.00–1.00，寫入 `[input] movement_deadzone`。
  - **設置頁同步**：暫停 → 設置新增「手柄」分區與死區滑桿，焦點鏈改為 `顯示 → 主音量 → 背景音樂 → 音效 → 語音 → 手柄死區 → 返回暫停`；面板加高到 640，四項音量與死區都會在進入頁面時同步存檔值。
  - **容錯**：設定檔損壞或死區值非數值／越界時回預設 0.30 並重新引導一次；主音量、顯示模式沿用 `UserSettings` 既有校驗。
  - **共用樣式**：滑桿軌道／菱形握把抽到 `ui_style.gd`（`style_slider`／`diamond_texture`），設置頁與引導頁同一套外觀。
  - **驗收**：`ONBOARD_SELFTEST result=PASS fails=[] checks=48`；`UI_FOCUS_SETTINGS_SELFTEST result=PASS`（43 項，含新增死區鏈路）；全量 31 套自測 RC=0；主場景 240 幀 RC=0 且無 ERROR。

- [x] **V0.3.33 石頭與青煙物件池（OPT-04 第一批，`tools/selftest_pool.gd` 46 項 PASS）**：
  - **通用池**：新增 `scripts/object_pool.gd`，`acquire(key, factory, target_parent)` 先取回收桶、沒有才新建；`release(key, node)` 摘下節點、隱藏並掛回池下，單 key 閒置上限 3，超額直接釋放；`stats()` 回報 created／reused／released／dropped／live。池節點 `PROCESS_MODE_DISABLED`，回收期間不跑邏輯。
  - **掛載位置**：章節舞台在 `_build_world()` 最前面建 `ObjectPool`；試煉場 `MainRigged` 在 `_ready()` 同樣掛一格；找不到池的場合（單獨實例化敵人測試）石頭仍照舊 `new`，行為不變。
  - **石頭**：`_ai_spawn_rock()` 改走池；命中／落地／超時三處 `queue_free()` 換成 `_despawn()` 歸還；`setup()` 先 `pool_reset()`（位置、旋轉、速度、目標、age、damage 歸零）再設參數；投擲音效從 `_ready()` 移進 `setup()`（池化後 `_ready` 只跑一次，否則重用的石頭沒聲音）；刪掉 `_physics_process` 的逐幀 `queue_redraw()`，靜態多邊形只畫一次。
  - **青煙**：`SpriteFrames` 改靜態快取，六張 512×640 全場只 `add_frame` 一次；每具敵人固定一格 `DeathMist`，死亡時重播、收起時 `stop()`＋隱藏，不再每次死亡新建再 `queue_free`。
  - **驗收**：`POOL_SELFTEST result=PASS fails=[] checks=46`（20 次循環 created 仍為 1、5 個同時歸還只留 3 個、石頭落地歸還而非刪除、無池退回 `queue_free`、青煙跨實例共用同一份 SpriteFrames）；全量 32 套自測 RC=0；`selftest_full_run` 3972 幀 0 死亡；主場景 240 幀 RC=0 且無 ERROR。

- [x] **V0.3.34 拾取物併入物件池（OPT-04 第二批，`selftest_pool` 擴充至 62 項 PASS）**：
  - **生成／回收**：`_spawn_drop()` 的碎銀與木牌改走 `_acquire_pickup()`（池 key `pickup`），沒有池時照舊直接 `new`；`_collect()` 的 `queue_free()` 換成 `_despawn()` 歸還。
  - **重用重畫**：`setup()` 先 `pool_reset()` 並補一次 `queue_redraw()`——碎銀與木牌是兩套程序繪製，池化後 `_ready` 只跑一次，不補重畫會出現「撿完碎銀、下次掉出木牌卻是銀塊外觀」的錯誤。
  - **既有斷言不受影響**：`selftest_death` 仍 `drops_left=0`、碎銀與小虎爪計數照舊；池內節點掛在 `ObjectPool` 下，不會被測試用 `main.get_children()` 的 `_pickups()` 誤數。
  - **驗收**：`POOL_SELFTEST result=PASS fails=[] checks=62`（拾取物回收進池、身分切換、浮動計時歸零、無池退回都逐項斷言）；全量 32 套自測 RC=0；`selftest_full_run` 3919 幀 0 死亡；主場景 240 幀 RC=0 且無 ERROR。

- [x] **V0.3.35 場景非同步預載（OPT-04 第三批，對應「切場景 <3s」，`tools/selftest_preload.gd` 24 項 PASS）**：
  - **預載器**：新增 `scripts/scene_preloader.gd`（`extends RefCounted`、全靜態、不加 autoload）：`request` 去重、`poll` 推進、`ready_scene`／`take` 取用、`State { NONE, LOADING, READY, FAILED }`，FAILED 允許重試；`stats()` 給 requested／ready／failed／in_flight／load_ms。
  - **接線**：`chapter_manager.goto_beat()`／`goto_checkpoint()` 走 `_switch_scene(path)`，已備好就 `change_scene_to_packed`，否則退回 `change_scene_to_file`；`stage_base._deferred_start()` 依下一拍預載下一場景（同場景跳過）；主菜單預載第一幕並用它進場；試煉場預載主菜單、結算切場亦走預載結果。
  - **收尾**：主菜單／舞台／試煉場的 `_exit_tree()` 都呼叫 `PRELOADER.settle_pending()`，把仍在載的請求收乾。漏這一步，行程退出時引擎會報 `1 ObjectDB instance was leaked`（線程請求懸空，不是資源沒放）。
  - **無頭取捨**：`force_headless`（預設 false）讓自測／CI 不自動預載，避免每套測試退出都掛一條線程；`selftest_preload` 自己開旗標驗真實線程路徑，視窗模式接線照常。
  - **數據**：六章節冷載 `SCENE_COST worst_load=70ms`（SCN-03 最慢 82–88ms、SCN-06 53–61ms、SCN-05 28–38ms），預載後取用 0ms，對 3000ms 預算留足餘量。
  - **驗收**：`PRELOAD_SELFTEST result=PASS fails=[] checks=24`；全量 33 套自測 RC=0（`selftest_preload`／`onboard`／`ui_shell`／`ui_focus_settings`／`death`／`flow` err=0／leak=0）；`selftest_full_run` 3901 幀 0 死亡 B9；主場景 240 幀 RC=0 無 ERROR。

- [x] **V0.3.36 目標機帧率記錄與回歸噪音收斂（OPT-04 收尾）**：
  - **帧率記錄（本機即 Intel UHD 730 目標配置）**：Godot 4.7.2、1920×1080、Vulkan Forward+，`--disable-vsync`＋`--print-fps`，視窗啟動後用 `SetWindowPos` 移到螢幕外（-4000,-3000），全程無可見窗口。離屏渲染上限：主菜單 240–276、酒肆 175–267、山道 188–268、亂林 214–265、山神廟 378–392、崗頂 290–345 fps；有桌面合成時：主菜單 86–88、酒肆 89–100，其餘撞 144Hz 上限。最差一檔（酒肆 89fps）對 ≥55fps 目標仍有 60% 餘量。
  - **玩法自測乾淨**：`rigged_fighter._wall_on_side()` 開頭補 `if not is_inside_tree(): return false`——`selftest_gameplay` 曾在未入樹的假人上呼叫 `take_damage`，`test_move` 噴 `Condition "!is_inside_tree()" is true`；現在該套 err=0。
  - **Boss 戰偶發死亡收斂**：`selftest_full_run` 的 Boss 驅動改成狀態機閃避表——咆哮半徑內先撤、命中窗口衝刺離場；階段轉場先退；Boss 殘血（≤90）無視小虎先收頭；召喚小虎只在出招時格擋；玩家低血（≤480）切遠距風箏、只吃收招窗口。週期性輸入全部改用場景內幀計數，不受開場載入差一幀影響。連跑 5 次 `deaths=0`、全部 B1–B9 clear；未動任何血量與 Boss 數值。
  - **驗收**：`selftest_gameplay`／`wall`／`wall_stage`／`ai`／`tiger`／`boss`／`corpse_ghost`／`fx`／`scn02_fight`／`scn05_boss_fight`／`scn03_forest` 全 PASS、err=0；`selftest_full_run` 5/5 PASS。

- [x] **V0.3.37 打擊感：命中停頓＋鏡頭震屏／微推（M5 OPT-01）**：
  - **命中停頓（只凍邏輯）**：`rigged_fighter` 新增 `_hitstop`；命中當下攻方與受方各凍結 4／8／12 個邏輯幀（輕／重／覺醒，單下 ≥100 傷害視同重招）。停頓期間不推進狀態機、`_frame`、物理與冷卻，但仍讀輸入並同步刀光／酒氣特效，停完自然變成幾幀的輸入緩衝。
  - **鏡頭**：新增 `scripts/camera_fx.gd`（trauma 平方衰減 0.8s、位移上限 12×9px、2% 微推 0.1s 回彈），章節舞台以 `hit_landed` 信號接線。背景剛好 1920×1080，故震屏期間自動補 1.5% 過掃，位移不會露出背景邊緣；切換關閉時立即回基準。
  - **開關**：`[display] camera_fx`（預設開），暫停頁新增「鏡頭效果」按鈕，與顯示切換併排；鏡頭層每 0.5s 重讀設置，切換即時生效。
  - **自測**：新增 `tools/selftest_feel.gd`（27 項）——幀數映射、雙方同步凍結、`_frame` 停頓期不推進、停完續走、鏡頭位移／衰減／過掃／關閉重置、設置持久化與壞型別回退。
  - **連帶調整**：`selftest_tiger` 三連撲窗口放寬（三段各帶 4 幀停頓，48→約 60 幀），改用「執行期間曾達到的已判定段數」斷言；`selftest_boss` 的頭／腹倍率段改為先歸零狀態再出招、手動召虎前清停頓；`selftest_scn05_boss_fight` 出手節奏由全域 `n % 24` 改本地間隔計數（停頓會讓取模相位漂移，導致出手機會被錯過），超時上限 2400→3000。
  - **驗收**：全量 30 套自測 PASS；`selftest_scn05_boss_fight` 2363 幀擊殺（Boss 三階段、player hp 545 未死）；`selftest_full_run` 3957 幀 deaths=0 B9；主場景 240 幀 RC=0、0 ERROR、0 泄漏。

- [x] **V0.3.38 手感層：架招白閃＋慢放、輸入緩衝、受身（M5 OPT-02）**：
  - **架招回饋**：攻擊中／防禦中按重成功轉入飛雲浦反擊（Counter）時，角色像素用 shader 混白 5 幀（`assets/shaders/white_flash.gdshader`，單一 uniform，不新增節點），同時把 `Engine.time_scale` 壓到 0.4 撐 150ms。用 `Time.get_ticks_msec` 計時，避免被慢放的 delta 二次拖長；無頭預設不啟用，避免拖慢既有自測。
  - **開關**：`[display] parry_fx`（預設開），暫停頁新增「打擊特效」按鈕（顯示／打擊特效／鏡頭效果三鍵同排）；慢放層每 0.5s 重讀設置，關掉立即還原倍率。
  - **輸入緩衝**：攻擊鍵 6 幀、方向與指令 18 幀。早按的輕／重不再白按——出招尾段按下的鍵會在取消窗口或恢復第一幀自動兌現；AI 的決策按鍵也在同一條 `_capture_presses()` 收進緩衝（否則 AI 永遠接不上招）。
  - **受身**：倒地（Knockdown）中按跳立刻起身上 WakeUp，前 6 幀完全無敵；不按照舊躺 36 幀可被追打，仍保留「受身失敗不無解」的代價差。
  - **自測**：`selftest_feel` 擴到 50 項（新增架招信號／白閃 uniform、慢放 0.4x／150ms／reset／關閉不觸發、緩衝衰減與消耗、真實早按接 Light2、受身無敵擋傷、不按受身照樣掉血）；`selftest_ui_focus_settings` 新增打擊特效按鈕焦點與持久化。離屏截圖 `docs/preview/parry-flash-on.png`／`parry-flash-off.png` 驗證白閃實際渲染（閃時全白剪影、6 幀後復原）。
  - **連帶調整**：`selftest_gameplay` 的指令技用例改走 `_atk_buf_*` 緩衝欄位（原本直接塞 `_heavy_pressed`，現在按鍵要經緩衝才會兌現）。
  - **驗收**：全量 30 套自測 PASS；`selftest_scn05_boss_fight` 2363 幀擊殺（p1_hp 545、Boss 三階段）；`selftest_full_run` 3949 幀 deaths=0 B9；主場景 240 幀 RC=0、0 ERROR、0 泄漏；兩套離屏截圖 RC=0、無 shader 編譯錯誤。

- [x] **V0.3.39 相機：lookahead、邊界 clamp、Boss 拉遠、階段微推（M5 OPT-03）**：
  - **取景前提**：世界與背景都只有 1920×1080。1.0 取景時相機水平可動半徑是 0，任何 lookahead 都會露背景邊；把背景放大會連帶拖歪 SCN-03 掛在 Background 下的樹幹／霧帶。故基準取景統一收到 **1.15**（可視寬 1670，左右各留 125px），換得 ±120 平移，背景與所有子節點原樣不動。
  - **Lookahead**：`camera_fx` 新增 `_follow`（建相機時直接接 `p1`）。目標 =（玩家 x − 960）× 0.25＋朝向 20px，夾在 ±120；用 8/s 的 lerp 追平，不會硬切。
  - **邊界 clamp**：每幀用「目前 zoom（含過掃）」算視野，把機位夾在世界內；視野比世界大時直接置中，Boss 拉遠時也不會出現黑邊。
  - **Boss 拉遠 10%**：`stage_base` 新增 `camera_zoom_mul()`，SCN-05 回 `1.0/1.1`，實測 1.15→1.045。
  - **階段微推 0.3s**：HUD 偵測到 Boss 由一階換二／三階時呼叫 `phase_push()`，0.3s 正弦推近 5% 再收回（開場第一次不算）。
  - **水潭固定機位**：SCN-06 覆寫 `camera_lookahead_enabled()=false`，機位鎖 960，對稱倒影構圖不被推歪。
  - **自測**：新增 `tools/selftest_camera.gd`（26 項）——中線歸零、朝向 20px 提前量、左右各夾 ±120、機位不越界、Boss 1.045 與較窄的平移量、階段微推峰值與收乾、水潭鎖死、關掉設置全歸位、三個舞台的覆寫值。新增 `tools/capture_camera_framing.gd` 離屏驗圖（主窗 1×1 移屏外）。
  - **驗收**：全量 32 套自測 PASS（含新增 camera）；`selftest_scn05_boss_fight` 2363 幀、p1_hp 545；`selftest_full_run` 3779 幀 deaths=0 B9；離屏截圖 4 張 err=0，最左／最右機位 840／1054（120px 全用滿也未露邊）。



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
