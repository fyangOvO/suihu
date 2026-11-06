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
| 特殊技·打虎拳 | RB | U |
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
- [x] 輸入緩衝系統（12幀內方向輸入有效）

## V0.1.1 幀動畫毫秒管線（本輪重構，詳見 `../docs/07-動畫幀毫秒映射規格.md`）

- [x] 60fps 邏輯幀 × 30fps 視覺幀雙時鐘，幀↔毫秒統一換算（`data/action_frame_data.gd`）
- [x] 移除 sin 縮放/搖晃偽造，姿態由 `scripts/frame_animator.gd` 按毫秒序列播放
- [x] 命中判定改為啟動/活躍/恢復幀窗口；Light1→Light2→Light3 取消鏈由取消幀驅動
- [x] 格擋減傷 50%、受擊 12 幀硬直、Dash 無敵窗口、喝酒 48 幀，全部數據驅動
- [x] 素材唯讀盤點 `tools/normalize_assets.py`（源 90 檔：15 真 PNG / 75 JPEG 偽裝）
- [x] **V0.1.2 素材治理**：`tools/build_anim_frames.py` 以 rembg(u2net) 去背，90 張成品輸出 `assets/anim/clean/`（真 RGBA、統一 512×640、腳基線對齊、四角透明）；原始素材不動；播放器 `clean/` 優先、原始目錄兜底；`tools/check_clean_spec.py` 規格驗收全綠、`tools/verify_frame_links.py` 校驗無斷鏈
- [x] P0 姿態歸併入幀：Idle 4 / Walk 6 / Light1 4 / Light2 4 / Light3 7 / Heavy 5 / Block 2 / HurtStand 3
- [x] **實體 Area2D 判定盒（V0.1.3）**：HitBox(layer2)/HurtBox(layer4) 重疊取代 dx/dy 距離比較，活躍幀開盒、收招關盒；`tools/selftest_hitbox.gd` 無頭自測 Light1 命中扣血 40（800→760）
- [ ] 指令輸入 236/623/214、受身/浮空追打、牆族、蹲/空防分化
- [x] **V0.1.4 素材/時序收尾**：Light3 7 槽按蓄力→上升→頂點→滯空→空中拳→下落→起身重排；倒地/騰空分組縮放錨點（stand 71 / air 8 / ground 11，docs/07 §6.5）；高速技提速 Light3 40、Heavy·CmdTiger 45、AirLight·AirHeavy·CmdUp 50（docs/07 §6.6）；`tools/check_visual_fps.gd` 無頭斷言 PASS、邏輯窗口不變
- [x] **V0.1.5 統一造型第一批（高速/空中鏈路，暗黑頹廢定稿）**：以 idle 為身份母版 `image_edit` 保姿態重繪 6 幀（uppercut、jump-punch、jump、jump-down、jump-slash、launched），去冠、去念珠、不袒胸，暗沉青灰近墨＋磨損毛邊；`tools/build_redraw_frames.py` 去背分組縮放輸出 `assets/anim/redraw_clean/`，播放器 `ANIM_DIRS` 最高優先 `redraw_clean/`→`clean/`→原始目錄，缺圖自動回退、刪目錄即整體回退；`tools/check_redraw_spec.py` 6/6 PASS；斷鏈/帧率/命中無頭回歸全綠
- [x] **V0.1.6 統一造型覆蓋 1.0（46/46 唯一被引用幀，暗黑頹廢定稿）**：在第一批基礎上續完成 ground 2、待機/行走 9、C2 輕拳 8、C3 重拳突進 8、C4 防禦/受擊/覺醒 6、C5 飲酒/拔刀 6、jump-up 1；持刀技保留一把樸素中式單刀、徒手技空手、飲酒保酒具並壓暗；`tools/inventory_frames.py` 唯一 46＝已重繪 46、待處理 0；`check_redraw_spec.py` PASS、`verify_frame_links.py` 零斷鏈、主場景 headless RC=0 無錯；批次與精修台賬見 `tools/redraw_batches.md`
- [ ] 純美術精修（程序不可代勞，docs/07 §6.5、台賬 task17）：造型覆蓋已完成，剩目視微調——jump-down 張臂方向、draw-knife 腰鞘多餘刀、碎飄帶連通域清理＋暗色邊緣去灰、半身飲酒/拔刀幀錨點縮放與全身幀銜接、全套逐幀 diff 回調身份漂移；Sprite 腳位/縮放與最終暗色調待編輯器 2D 視圖目視（§6.4）；刀光/酒氣獨立圖層與補間級連貫中幀列為後續提升項

## 待實現

- [x] 酒氣滿自動拔刀（立繪切換：正常→覺醒版+金黃閃光）
- [x] 導入第一張美術素材（武松水墨立繪替換灰色方塊）
- [x] 導入舞台背景（景陽岡月夜山道概念圖）
- [x] 6張動作關鍵幀（直拳/上勾拳/掃堂腿/受擊/跳躍/拔刀）
- [x] 狀態機切換貼圖（不同動作顯示不同姿態）
- [x] 補充關鍵幀：走路A/B、重劈、喝酒
- [x] CPU AI（P2自動靠近+攻擊+防禦+喝酒）
- [ ] 覺醒演出（RT）
- [ ] 飛雲浦反擊（214+重，被打瞬間輸入反擊）
- [ ] 牆邊連段獎勵
- [ ] CPU 對手（先做最簡單的AI）

## 如何運行

1. 用 Godot **4.7.x** 打開 `D:\水滸g\game\project.godot`
2. 首次打開等待 `assets/anim` 素材導入完成
3. F5 運行；P1：A/D 移動、S 蹲、Space 跳、J 輕、K 重、L 格擋、Shift 衝、I 喝酒

> 註：`水滸：妖魔劫-(4.2)/` 為早期 C# 灰盒版，其啟動/活躍/恢復幀設計被本目錄 GDScript 版的 `data/action_frame_data.gd` 繼續採用；實際運行以本目錄為準。
