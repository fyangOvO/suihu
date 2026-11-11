extends RefCounted
## 動畫與戰鬥幀資料表（數據驅動，程序與美術共用同一份真相）
##
## 兩套時鐘（對齊 docs/06-設計稿-美術與動畫規格.md §1、§3）：
##   邏輯層 LOGIC_FPS = 60：判定、取消、硬直、無敵幀全部以邏輯幀為準，1 邏輯幀 = 16.667ms
##   視覺層 VISUAL_FPS = 30：角色姿態序列幀，1 視覺幀 = 33.333ms（可逐動作覆蓋）
##
## 每個動作 spec 欄位：
##   loop        true=循環姿態（Idle/Walk/Block…），false=一次性動作（攻擊/受擊/演出）
##   logic       {startup, active, recovery} 60fps 邏輯幀；一次性動作總幀 = 三者相加
##   damage      命中傷害（0 = 無攻擊判定）
##   cancel_frame 可取消到下一招的第一個邏輯幀；-1 = 不可取消
##   hit_range   命中判定水平距離（px）
##   knockback   命中擊退水平速度；knock_up > 0 時給予浮空垂直速度
##   invuln      {start,end} 邏輯幀區間無敵（可選）
##   visual      {fps, frames:[檔名…]} 姿態序列，檔名對應 res://assets/anim/<檔名>.png
##               序列中不存在 / 格式無法解碼的圖會被播放器自動跳過，不會報錯中斷

const LOGIC_FPS: int = 60
const LOGIC_FRAME_MS: float = 1000.0 / 60.0
const VISUAL_FPS: int = 30
const VISUAL_FRAME_MS: float = 1000.0 / 30.0

const SPECS: Dictionary = {
	# ---------- Base Layer 底層姿態（循環，由輸入與物理驅動切換） ----------
	"Idle": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["idle.png", "idle-front.png", "idle-side.png", "fighter-stance.png"]},
		"note": "目標 4 視覺幀循環 2.4s（06 §2.1 #01）；現僅 1 張關鍵姿態"
	},
	"Walk": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["walk-a.png", "walk-b.png", "walk-mid.png", "walk-c.png", "walk-d.png", "walk-b.png"]},
		"note": "目標 6 視覺幀循環 0.45s（06 §2.1 #02）；現 walk-a/b 兩姿態"
	},
	"Crouch": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["crouch.png"]},
		"note": "蹲姿/蹲防共用（06 §4 偷懶點 #8）"
	},
	"AirUp": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["jump-up.png", "jump.png"]},
		"note": "空中上升姿態（06 §2.1 #06）"
	},
	"AirDown": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["jump-down.png", "jump.png"]},
		"note": "空中下降姿態（06 §2.1 #07）"
	},
	"Land": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 15},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["wakeup.png"]},
		"note": "落地硬直 0.25s ≈ 15 幀（06 §2.1 #09）"
	},
	"Dash": {
		"loop": false,
		"logic": {"startup": 4, "active": 6, "recovery": 8},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"invuln": {"start": 4, "end": 10},
		"visual": {"fps": 30, "frames": ["dash.png"]},
		"note": "前衝 18 幀=300ms，無敵第 4~9 幀（06 §3.4）"
	},

	# ---------- Action Layer 通常攻擊（一次性；幀數對齊 06 §3.1 / 03 §4.1） ----------
	"Light1": {
		"loop": false,
		"logic": {"startup": 6, "active": 4, "recovery": 12},
		"damage": 40, "cancel_frame": 8, "hit_range": 150.0, "knockback": 180.0,
		"visual": {"fps": 30, "frames": ["punch-start.png", "punch.png", "combo-punch.png", "punch-end.png"]},
		"note": "站輕一 22 幀=366.7ms；第 8 幀後可取消（06 §3.1）"
	},
	"Light2": {
		"loop": false,
		"logic": {"startup": 5, "active": 4, "recovery": 12},
		"damage": 45, "cancel_frame": 7, "hit_range": 150.0, "knockback": 200.0,
		"visual": {"fps": 30, "frames": ["punch-left.png", "punch.png", "double-palm.png", "punch-end.png"]},
		"note": "站輕二 21 幀=350ms；第 7 幀後可取消"
	},
	"Light3": {
		"loop": false,
		"logic": {"startup": 9, "active": 5, "recovery": 22},
		"damage": 70, "cancel_frame": -1, "hit_range": 160.0, "knockback": 240.0, "knock_up": 220.0,
		"visual": {"fps": 40, "frames": ["uppercut-start.png", "rising-punch.png", "uppercut.png", "jump-up.png", "jump-punch.png", "jump-down.png", "wakeup.png"]},
		"note": "站輕三 36 邏輯幀=600ms，擊退浮空；命中後可 LB 衝取消；視覺 7 槽按蓄力→上升→頂點→滯空→空中拳→下落→撐地起身時序重排，40fps；造型跨幀差異(束髮/袒胸/念珠/冠帽)仍屬美術統一項，見 docs/07 §4.3"
	},
	"Heavy": {
		"loop": false,
		"logic": {"startup": 12, "active": 4, "recovery": 24},
		"damage": 90, "cancel_frame": 16, "hit_range": 170.0, "knockback": 260.0,
		"visual": {"fps": 45, "frames": ["heavy-start.png", "heavyslash.png", "elbow.png", "headbutt.png", "heavy-end.png"]},
		"note": "站重 40 幀=666.7ms；命中第 16 幀後可取消指令技；揮擊視覺 45fps 快切，邏輯窗口不變"
	},
	"CrouchLight": {
		"loop": false,
		"logic": {"startup": 5, "active": 3, "recovery": 10},
		"damage": 30, "cancel_frame": 6, "hit_range": 130.0, "knockback": 140.0,
		"visual": {"fps": 30, "frames": ["crouch-punch.png"]},
		"note": "蹲刺 18 幀=300ms（06 §3.1）"
	},
	"AirLight": {
		"loop": false,
		"logic": {"startup": 5, "active": 4, "recovery": 6},
		"damage": 50, "cancel_frame": -1, "hit_range": 140.0, "knockback": 160.0,
		"visual": {"fps": 50, "frames": ["jump-punch.png"]},
		"note": "空輕；命中後落地取消（06 §3.2）；空中技 50fps"
	},
	"AirHeavy": {
		"loop": false,
		"logic": {"startup": 8, "active": 4, "recovery": 6},
		"damage": 70, "cancel_frame": -1, "hit_range": 140.0, "knockback": 180.0,
		"visual": {"fps": 50, "frames": ["jump-slash.png"]},
		"note": "空重對空主力（06 §3.2）；空中技 50fps"
	},

	# ---------- 防禦 / 反應層 ----------
	"Block": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["block.png", "knife-guard.png"]},
		"note": "站格擋循環姿態（防中按重可反擊）；不可被普通攻擊造成硬直"
	},
	"CrouchBlock": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["crouch.png"]},
		"note": "蹲防（下+防）：僅受 35% 傷害、擊退最小；防中按重可反擊；不可造成硬直"
	},
	"AirBlock": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["jump-down.png"]},
		"note": "空防（空中按住防）：受 40% 傷害且不浮空；隨下落落地解除"
	},
	"HurtStand": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 12},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["hurt-back.png", "hurt.png", "hurt-head.png"]},
		"note": "站受擊 0.2s=12 幀（06 §2.1 #12）；Reaction 層最高優先級"
	},
	"Stun": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 30},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 20, "frames": ["hurt.png", "hurt-back.png"]},
		"note": "Boss 咆哮正面 30 幀硬直（docs/10 BOS-08）；只由 Boss 施加"
	},
	"StunShort": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 15},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 20, "frames": ["hurt.png", "hurt-back.png"]},
		"note": "Boss 咆哮背對 15 幀硬直（docs/10 BOS-08）"
	},
	"HurtAir": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 18},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["launched.png", "hurt.png"]},
		"note": "空受擊 0.3s=18 幀，落地轉 Knockdown（06 §2.1 #13）"
	},
	"Knockdown": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 36},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["knockdown.png"]},
		"note": "倒地 0.6s=36 幀；倒地中按跳可受身（06 §2.1 #14）"
	},
	"WallStick": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 30},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["hurt.png"]},
		"note": "牆族：被擊退且背已貼牆＝額外傷害＋黏牆 30 幀（01 §牆族），結束彈回轉 HurtAir 可再追打"
	},
	"WakeUp": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 18},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["wakeup.png"]},
		"note": "起身 0.3s=18 幀（06 §2.4 #39）"
	},

	# ---------- 資源 / 演出 ----------
	"Drink": {
		"loop": false,
		"logic": {"startup": 12, "active": 0, "recovery": 36},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["drink-prep.png", "drink-tilt.png", "drink.png", "drink-finish.png"]},
		"note": "喝酒 48 幀=800ms；前 12 幀不可取消，酒氣+30（06 §3.5）"
	},
	"DrawKnife": {
		"loop": false,
		"logic": {"startup": 15, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["draw-knife.png", "drawknife.png"]},
		"note": "拔刀 15 幀前搖不可攻擊（06 §3.5 / 03 §4.1）"
	},

	# ---------- 指令技 / 覺醒（數據先就位，輸入接線後續迭代） ----------
	"AwakenIdle": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 30, "frames": ["draw-knife.png"]},
		"note": "滿酒氣待機立繪：拔刀覺醒姿態，僅替換視覺，不進入狀態機、不影響判定"
	},
	"CmdTiger": {
		"loop": false,
		"logic": {"startup": 10, "active": 6, "recovery": 22},
		"damage": 110, "cancel_frame": -1, "hit_range": 220.0, "knockback": 320.0,
		"visual": {"fps": 45, "frames": ["punch.png"]},
		"note": "打虎拳 236+重（↓↘→），38 幀=633ms（06 §3.3）；指令技 45fps"
	},
	"CmdUp": {
		"loop": false,
		"logic": {"startup": 12, "active": 8, "recovery": 28},
		"damage": 130, "cancel_frame": -1, "hit_range": 150.0, "knockback": 120.0, "knock_up": 360.0,
		"visual": {"fps": 50, "frames": ["uppercut.png"]},
		"note": "鴛鴦樓昇斬 623+重（→↓↘），對空浮空（06 §3.3）；浮空技 50fps"
	},
	"CmdDrunk": {
		"loop": false,
		"logic": {"startup": 8, "active": 5, "recovery": 20},
		"damage": 70, "cancel_frame": -1, "hit_range": 260.0, "knockback": 100.0,
		"invuln": {"start": 8, "end": 18},
		"visual": {"fps": 30, "frames": ["fighter-stance.png"]},
		"note": "醉打蔣門神 RB，穿身無敵 10 幀，CD 4s（06 §3.3）"
	},
	"Counter": {
		"loop": false,
		"logic": {"startup": 6, "active": 4, "recovery": 14},
		"damage": 120, "cancel_frame": -1, "hit_range": 190.0, "knockback": 160.0,
		"knock_up": 260.0,
		"invuln": {"start": 0, "end": 6},
		"visual": {"fps": 30, "frames": ["punch-start.png", "punch.png"]},
		"note": "飞云浦反击：214（↓↙←）+重、站/蹲防中按重、或HurtStand前4帧按重触发；前6帧招架无敌，命中120浮空"
	},
	"Super": {
		"loop": false,
		"logic": {"startup": 24, "active": 60, "recovery": 24},
		"damage": 320, "cancel_frame": -1, "hit_range": 260.0, "knockback": 200.0,
		"invuln": {"start": 0, "end": 108},
		"visual": {"fps": 30, "frames": ["awaken.png"]},
		"note": "覺醒必殺 RT/O：酒氣滿100觸發、全程無敵、active窗口320傷害、結束清氣；金黄modulate演出（06 §3.5）"
	},

	# ---------- 吊睛小虎（精英，docs/04 §3） ----------
	# 幀名落在 assets/anim/tiger/，由 Tiger.tscn 的 anim_dir 指定目錄；血量 350 在場景上設定
	"TigerIdle": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 6, "frames": ["idle.png"]},
		"note": "小虎站立警戒；單姿態先夠用，後續可擴呼吸幀"
	},
	"TigerWalk": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 10, "frames": ["walk-1.png", "walk-2.png"]},
		"note": "小虎四足行走兩幀循環 0.2s，接近玩家時壓迫感來源"
	},
	"TigerCrouch": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 8, "frames": ["crouch.png"]},
		"note": "小虎壓低蓄力，前撲前的預備姿態"
	},
	"TigerPounce": {
		"loop": false,
		"logic": {"startup": 16, "active": 6, "recovery": 16},
		"damage": 90, "cancel_frame": -1, "hit_range": 190.0, "knockback": 260.0,
		"visual": {"fps": 18, "frames": ["crouch.png", "pounce.png"]},
		"note": "前撲（可格擋）38 幀=633ms；啟動 16 幀給玩家架招窗口，命中擊退 260"
	},
	"TigerTail": {
		"loop": false,
		"logic": {"startup": 12, "active": 6, "recovery": 18},
		"damage": 80, "cancel_frame": -1, "hit_range": 170.0, "knockback": 220.0,
		"low": true,
		"visual": {"fps": 20, "frames": ["tail.png", "crouch.png"]},
		"note": "尾掃（低姿，需跳過）36 幀=600ms；低判定，站防可擋、蹲防擋不住"
	},
	"TigerPounceChain": {
		"loop": false,
		"logic": {"startup": 18, "active": 8, "recovery": 22},
		"damage": 110, "cancel_frame": -1, "hit_range": 200.0, "knockback": 280.0,
		"multi_hit": [
			{"frame": 18, "damage": 35, "unblockable": false},
			{"frame": 28, "damage": 40, "unblockable": true},
			{"frame": 38, "damage": 35, "unblockable": true},
		],
		"visual": {"fps": 22, "frames": ["crouch.png", "pounce.png", "leap.png"]},
		"note": "三連撲（撲—撤—再撲）48 幀=800ms；18/28/38 三段 35/40/35，第二段起不可格擋"
	},
	"TigerCross": {
		"loop": false,
		"logic": {"startup": 14, "active": 4, "recovery": 20},
		"damage": 70, "cancel_frame": -1, "hit_range": 150.0, "knockback": 200.0,
		"visual": {"fps": 22, "frames": ["leap.png", "pounce.png"]},
		"note": "越頂 cross-up 38 幀=633ms；跳過玩家頭頂換邊，落地後接後跳拉距"
	},
	"TigerHurt": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 14},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 20, "frames": ["hurt.png", "hurt-2.png"]},
		"note": "小虎站受擊 14 幀；架招成功後改用 TigerHurtLong 38 幀（弱點）"
	},
	"TigerHurtLong": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 38},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 20, "frames": ["hurt.png", "hurt-2.png"]},
		"note": "架招成功後的小虎長硬直 38 幀=633ms；不參與搶招，走完回 TigerIdle"
	},
	"TigerKnockdown": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 30},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 20, "frames": ["knockdown.png"]},
		"note": "小虎倒地 30 幀；空中追打（Air Juggle）主要窗口"
	},
	"TigerWakeUp": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 16},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 20, "frames": ["hurt-2.png", "idle.png"]},
		"note": "小虎起身 16 幀，起身後才會恢復攻擊"
	},

	# ---------- 景陽岡猛虎 Boss（docs/10-BOS-01 招式表凍結） ----------
	# 幀名落在 assets/anim/boss/，由 Boss.tscn 的 anim_dir 指定；血量 1200 在場景上設定
	"BossIdle": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 6, "frames": ["boss-idle.png"]},
		"note": "猛虎站立警戒；呼吸可後續補幀"
	},
	"BossWalk": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 10, "frames": ["boss-walk-1.png", "boss-walk-2.png"]},
		"note": "四足行走兩幀循環，Boss 走速 160"
	},
	"BossCrouch": {
		"loop": true,
		"logic": {"startup": 0, "active": 0, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 8, "frames": ["boss-crouch.png"]},
		"note": "低伏蓄勢；保留狀態枚舉，目前由撲擊起手借用"
	},
	"BossHurt": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 24},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 20, "frames": ["boss-hurt.png"]},
		"note": "削韌 320 破防硬直 24 幀；霸體時不進此狀態"
	},
	"BossKnockdown": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 60},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 20, "frames": ["boss-knockdown.png"]},
		"note": "倒地 60 幀；腹部 ×2 弱點僅此窗口開啟"
	},
	"BossDeath": {
		"loop": false,
		"logic": {"startup": 0, "active": 0, "recovery": 90},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"visual": {"fps": 12, "frames": ["boss-knockdown.png", "boss-pant.png"]},
		"note": "死亡演出 90 幀；BOS-10 接管倒地→騎背→水潭→黑霧→字幕"
	},
	"BossPhase": {
		"loop": false,
		"logic": {"startup": 0, "active": 72, "recovery": 0},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"invuln": {"start": 0, "end": 72},
		"visual": {"fps": 20, "frames": ["boss-roar.png"]},
		"note": "66%/33% 轉場 1.2s（72 幀）無敵、無攻擊判定；轉場後才切階段"
	},

	# --- P1 撲 ---
	"BossPounce": {
		"loop": false,
		"logic": {"startup": 48, "active": 10, "recovery": 24},
		"damage": 200, "cancel_frame": -1, "hit_range": 300.0, "knockback": 320.0, "knock_up": 120.0,
		"unblockable": true,
		"hitbox": {"shape": "rect", "size": [300, 150], "offset": [150, -100]},
		"cooldown": 3.0, "vx": 240.0, "vx_window": 58,
		"visual": {"fps": 18, "frames": ["boss-crouch.png", "boss-pounce-1.png", "boss-pounce-2.png", "boss-pounce-3.png", "boss-pounce-4.png", "boss-pounce-5.png"]},
		"note": "餓虎撲食 82 幀；不可格擋，P1 權重 45、冷卻 3.0s"
	},
	"BossTail": {
		"loop": false,
		"logic": {"startup": 18, "active": 8, "recovery": 22},
		"damage": 140, "cancel_frame": -1, "hit_range": 260.0, "knockback": 180.0, "knock_up": 60.0,
		"hitbox": {"shape": "rect", "size": [260, 100], "offset": [110, -70]},
		"cooldown": 1.8,
		"visual": {"fps": 20, "frames": ["boss-tail-1.png", "boss-crouch.png"]},
		"note": "剪尾 48 幀；可站防、可蹲防，P1 權重 35、P2 權重 30"
	},
	# --- P2 掀 ---
	"BossRearUp": {
		"loop": false,
		"logic": {"startup": 26, "active": 10, "recovery": 30},
		"damage": 220, "cancel_frame": -1, "hit_range": 280.0, "knockback": 260.0, "knock_up": 360.0,
		"hitbox": {"shape": "rect", "size": [280, 180], "offset": [130, -120]},
		"guard_ratio": 0.25, "guard_push": 220.0,
		"cooldown": 3.2,
		"visual": {"fps": 20, "frames": ["boss-rear-up.png", "boss-claw-1.png", "boss-claw-2.png"]},
		"note": "爪子掀天 66 幀；可擋但只減 25% 且推遠 220，命中浮空 360"
	},
	"BossRoar": {
		"loop": false,
		"logic": {"startup": 18, "active": 12, "recovery": 20},
		"damage": 0, "cancel_frame": -1, "hit_range": 300.0, "knockback": 0.0,
		"hitbox": {"shape": "circle", "radius": 300, "offset": [0, -90]},
		"stun_frames": 30, "back_turn_frames": 15,
		"cooldown": 6.0,
		"visual": {"fps": 20, "frames": ["boss-roar.png", "boss-rear-up.png"]},
		"note": "咆哮 50 幀；半徑 300 內 30 幀硬直，背對減半 15 幀，0 傷害"
	},
	"BossSummon": {
		"loop": false,
		"logic": {"startup": 20, "active": 30, "recovery": 20},
		"damage": 0, "cancel_frame": -1, "hit_range": 0.0, "knockback": 0.0,
		"summon": 2,
		"cooldown": 12.0,
		"visual": {"fps": 20, "frames": ["boss-summon.png", "boss-recover.png"]},
		"note": "召小虎 70 幀；場上上限 2，P2 權重 15、冷卻 12s"
	},
	# --- P3 剪 ---
	"BossIronTail": {
		"loop": false,
		"logic": {"startup": 24, "active": 10, "recovery": 26},
		"damage": 180, "cancel_frame": -1, "hit_range": 340.0, "knockback": 240.0, "knock_up": 80.0,
		"unblockable": true, "low": true,
		"hitbox": {"shape": "rect", "size": [340, 90], "offset": [170, -55]},
		"cooldown": 2.4,
		"visual": {"fps": 20, "frames": ["boss-iron-tail-1.png", "boss-iron-tail-2.png", "boss-iron-tail-3.png"]},
		"note": "鐵尾 60 幀；低判定＋不可格擋，必須跳；P3 權重 40"
	},
	"BossDeathPounce": {
		"loop": false,
		"logic": {"startup": 30, "active": 8, "recovery": 60},
		"damage": 800, "cancel_frame": -1, "hit_range": 320.0, "knockback": 400.0, "knock_up": 200.0,
		"unblockable": true, "once_per_phase": true,
		"hitbox": {"shape": "rect", "size": [320, 180], "offset": [160, -90]},
		"cooldown": 8.0, "vx": 260.0, "vx_window": 38,
		"visual": {"fps": 20, "frames": ["boss-death-pounce-1.png", "boss-death-pounce-2.png", "boss-pounce-4.png", "boss-pant.png"]},
		"note": "絕命撲 98 幀；800 傷、不可格擋，每階段 1 次，P3 權重 20"
	},
	"BossPounceP3": {
		"loop": false,
		"logic": {"startup": 36, "active": 10, "recovery": 30},
		"damage": 240, "cancel_frame": -1, "hit_range": 320.0, "knockback": 360.0, "knock_up": 140.0,
		"unblockable": true,
		"hitbox": {"shape": "rect", "size": [320, 150], "offset": [160, -100]},
		"cooldown": 3.2, "vx": 240.0, "vx_window": 46,
		"visual": {"fps": 18, "frames": ["boss-death-pounce-1.png", "boss-death-pounce-2.png", "boss-pounce-4.png"]},
		"note": "P3 撲擊 76 幀；240 傷、不可格擋，P3 權重 25"
	},
	"BossRearUpP3": {
		"loop": false,
		"logic": {"startup": 30, "active": 10, "recovery": 36},
		"damage": 260, "cancel_frame": -1, "hit_range": 300.0, "knockback": 280.0, "knock_up": 380.0,
		"hitbox": {"shape": "rect", "size": [300, 190], "offset": [140, -120]},
		"guard_ratio": 0.20, "guard_push": 240.0,
		"cooldown": 3.5,
		"visual": {"fps": 20, "frames": ["boss-rear-up.png", "boss-claw-1.png", "boss-claw-2.png"]},
		"note": "P3 掀天 76 幀；260 傷、可擋 20%／推 240，P3 權重 15"
	},
}

## 取得動作 spec；未知動作回退 Idle，保證播放層永不為空
static func spec(action: String) -> Dictionary:
	return SPECS.get(action, SPECS["Idle"])

static func total_frames(spec: Dictionary) -> int:
	var lg: Dictionary = spec.get("logic", {})
	return int(lg.get("startup", 0)) + int(lg.get("active", 0)) + int(lg.get("recovery", 0))

static func frames_to_ms(frame: int) -> float:
	return float(frame) * LOGIC_FRAME_MS

static func ms_to_frames(ms: float) -> int:
	return int(round(ms / LOGIC_FRAME_MS))

## 是否處於命中判定活躍窗口（邏輯幀）
static func is_active_frame(spec: Dictionary, frame: int) -> bool:
	var lg: Dictionary = spec.get("logic", {})
	var s: int = int(lg.get("startup", 0))
	var a: int = int(lg.get("active", 0))
	return a > 0 and frame >= s and frame < s + a

## 是否處於無敵幀區間
static func is_invulnerable(spec: Dictionary, frame: int) -> bool:
	var inv: Dictionary = spec.get("invuln", {})
	if inv.is_empty():
		return false
	return frame >= int(inv.get("start", -1)) and frame < int(inv.get("end", -1))

## 視覺幀間隔（ms），預設 30fps
static func visual_frame_ms(spec: Dictionary) -> float:
	var vis: Dictionary = spec.get("visual", {})
	var fps: int = int(vis.get("fps", VISUAL_FPS))
	return 1000.0 / float(maxi(fps, 1))
