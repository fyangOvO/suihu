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
- [ ] 純美術精修（程序不可代勞，docs/07 §6.5、台賬 task17）：造型覆蓋已完成，剩目視微調——jump-down 張臂方向、draw-knife 腰鞘多餘刀、碎飄帶連通域清理＋暗色邊緣去灰、半身飲酒/拔刀幀錨點縮放與全身幀銜接、全套逐幀 diff 回調身份漂移；Sprite 腳位/縮放與最終暗色調待編輯器 2D 視圖目視（§6.4）；刀光/酒氣獨立圖層與補間級連貫中幀列為後續提升項
- [x] **V0.1.7 玩法補全（`tools/selftest_gameplay.gd` 18 項斷言 PASS）**：覺醒必殺 Super 滿酒氣按 O(RT) 觸發、全程無敵、active 窗口 320 傷害、金黃 modulate 脈衝演出、結束清氣；飛雲浦反擊 Counter（站/蹲防中或受擊前 4 邏輯幀按重，前 6 幀招架無敵、命中 120 浮空；完整 214 方向序列緩衝留待後續）；防禦分化＝站防 50%／蹲防 CrouchBlock 35% 小退卻／空防 AirBlock 40% 且不浮空；順帶修復「無敵招式攻擊盒被誤關閉、Super/醉打打不中」的耦合問題；回歸 selftest_hitbox、check_visual_fps、主場景 headless 全綠
- [x] **V0.1.8 P1 酒氣條 HUD（`tools/selftest_hud.gd` 7 項斷言 PASS）**：MainRigged 場景於 P1 血條下新增 P1Wine 進度條（0–100）與滿氣提示 Label，主邏輯每幀同步 wine_gauge；滿 100 時氣條轉金黃高亮、顯示「覺醒可發（O / RT）」，Super 結束清氣後自動回落；P2 為占位 AI 不繪氣條；補上此前文檔已列但代碼缺失的酒氣條；回歸 gameplay／hitbox／fps／headless 全綠
- [x] **V0.1.9 飛雲浦反擊完整指令技 214（`tools/selftest_gameplay.gd` 23 項斷言 PASS）**：新增相對朝向方向歷史緩衝窗口（18 邏輯幀），識別方向序列並按重觸發 Counter；與既有簡化觸發（站/蹲防中按重、受擊前 4 幀按重）並存，出手即清空緩衝；本次只接入 214，236/623 方向緩衝尚未實現（現 CmdTiger/CmdUp 仍為按鍵直觸）；回歸 hitbox／fps／hud／主場景 headless 全綠
- [x] **V0.2.0 指令技完整方向緩衝 236/623（`tools/selftest_gameplay.gd` 46 項斷言 PASS）**：方向記錄重做為數字小鍵盤語義（5 中／2 下／1 下後／3 下前／4 後／6 前／7 上後／8 上／9 上前，皆相對朝向），`_has_cmd` 通用順序匹配（允許中間夾中立或其他方向），派生 214 ↓↙←、236 ↓↘→、623 →↓↘；重鍵分派優先級 214>623>236 → Counter／CmdUp／CmdTiger，出手即清空緩衝；同步修正 V0.1.9 中 214 的錯誤序列（後→下→前 改為 下→下後→後）；自測新增物理接線斷言（落地後 236+重真的切 CmdTiger、623+重切 CmdUp、214+重切 Counter、無指令+重切 Heavy、236+輕不誤觸）；滿氣待機新增 AwakenIdle 拔刀立繪（draw-knife）＋柔和金輝呼吸，進入戰鬥狀態即回落正常幀，Super 仍使用 awaken
- [x] **V0.2.1 覺醒過場演出（`tools/selftest_cinematic.gd` 21 項斷言 PASS）**：MainRigged 新增 BattleCam(960,540) 與 Cinematic 層（Dim 暗角／Slash 金色刀光／Flash 定格白閃）；P1 進入 Super 即啟動 2.0s 時間軸——0–0.30s 推鏡（zoom→1.20 並追隨 P1、暗角→0.55）、0.28–0.55s 刀光橫掃＋白閃定格、1.30–2.00s 全部復位；演出期間 P2 定格外，離開 Super 或超時即中斷復位；HUD 屬獨立 CanvasLayer 不受鏡頭影響；回歸 gameplay／hud／hitbox／fps／主場景 headless 全綠
- [x] **V0.2.2 醉打蔣門神接入（`tools/selftest_gameplay.gd` 59 項斷言 PASS）**：`CmdDrunk` 補上輸入路徑（P1 的 `p1_special`＝RB／U），4s 冷卻（`_tick_cooldowns` 逐幀遞減，冷卻中按鍵無效）、起手＋活躍段（邏輯幀 1–13）以 360 速度前衝、8–18 幀無敵、穿身以 `add_collision_exception_with(opponent)` 只忽略對手身體碰撞（地面／牆仍保留，離開狀態即恢復例外）；並將 `CmdDrunk` 補入 `ATTACKS`，否則攻擊盒不會開啟（與 V0.1.7 修過的「無敵招式打不中」屬同一類耦合）；自測新增 13 項（觸發、冷卻封鎖／遞減／歸零、傷害 70、總 33 幀、active 8–12、invuln 僅 8–17、攻擊盒歸類、穿身例外增減）

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
