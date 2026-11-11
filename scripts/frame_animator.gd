extends Sprite2D
## 毫秒驅動的姿態序列播放器（掛在角色 Visual 節點上）
##
## 與舊版差異：不再用 sin() 讓單張圖縮放/搖晃冒充動作；
## 而是依 spec.visual.fps 換算「每視覺幀多少毫秒」，按累計毫秒選取序列幀。
## 序列中缺圖 / 格式無法解碼的素材自動跳過，整個播放鏈路不會中斷。
##
## 職責邊界：只負責「現在顯示哪一張姿態圖」；
## 朝向翻轉、縮放、物理位移、判定窗口由 rigged_fighter.gd 負責。

const DATA := preload("res://data/action_frame_data.gd")
## 素材查找順序（高優先 → 兜底，缺圖自動下一層，整條鏈路不中斷）：
## 1) redraw_clean/：統一造型重繪成品（暗黑頹廢，tools/build_redraw_frames.py 產出，僅覆蓋已重繪幀）
## 2) clean/：去背透明統一畫布成品（tools/build_anim_frames.py 產出）
## 3) anim/ 根目錄：原始素材（含偽裝 JPEG，解碼失敗會被下一層跳過）
## 移除 redraw_clean/ 目錄或其條目即整體回退到舊成品，原始素材永不覆蓋。
const ANIM_DIRS: Array = ["res://assets/anim/redraw_clean/", "res://assets/anim/clean/", "res://assets/anim/"]
## 實際查找順序；敵人可透過 set_search_dirs 把自己的目錄插到最前面
var search_dirs: Array = ANIM_DIRS.duplicate()

var _cache: Dictionary = {}
var _action: String = ""
var _frames: Array = []          # 已成功解析的 Texture2D 序列
var _loop: bool = false
var _frame_ms: float = 33.333
var _elapsed_ms: float = 0.0
var _idx: int = -1
var finished: bool = false        # 一次性動作是否播完最後一幀

## 每幀呼叫；action 變更時自動重入新動作，否則只推進時鐘
## （命名避開 CanvasItem 原生 show()，避免覆寫衝突）
func play_action(action: String, spec: Dictionary, delta: float) -> void:
	if action != _action:
		_enter(action, spec)
	tick(delta)

## 設定素材查找目錄（敵人把自己的 anim 目錄放最前，找不到再回退到武松那三層）
func set_search_dirs(dirs: Array) -> void:
	search_dirs = dirs.duplicate()
	_cache.clear()

func _enter(action: String, spec: Dictionary) -> void:
	_action = action
	_loop = bool(spec.get("loop", false))
	_frame_ms = DATA.visual_frame_ms(spec)
	_elapsed_ms = 0.0
	_idx = -1
	finished = false
	_frames.clear()
	var vis: Dictionary = spec.get("visual", {})
	for file in vis.get("frames", []):
		var tex: Texture2D = _resolve(str(file))
		if tex != null:
			_frames.append(tex)

func tick(delta: float) -> void:
	if _frames.is_empty():
		return
	_elapsed_ms += delta * 1000.0
	var size: int = _frames.size()
	var new_idx: int = int(_elapsed_ms / _frame_ms)
	if _loop:
		new_idx = posmod(new_idx, size)
	elif new_idx >= size:
		new_idx = size - 1
		finished = true
	if new_idx != _idx:
		_idx = new_idx
		texture = _frames[_idx]

func get_elapsed_ms() -> float:
	return _elapsed_ms

func get_action() -> String:
	return _action

## 載入素材：先查已導入資源（clean 成品優先 → 原始 anim/）；
## 再用 Image 直接解碼磁碟檔（headless 或尚未導入時）；全部失敗回傳 null 並跳過該幀
func _resolve(file: String) -> Texture2D:
	if _cache.has(file):
		return _cache[file]
	var tex: Texture2D = null
	for dir in search_dirs:
		var rpath: String = dir + file
		if ResourceLoader.exists(rpath):
			tex = load(rpath) as Texture2D
			if tex != null:
				break
	if tex == null:
		for dir in search_dirs:
			var gpath: String = ProjectSettings.globalize_path(dir + file)
			var img := Image.new()
			if img.load(gpath) == OK:
				var it := ImageTexture.new()
				it.set_image(img)
				tex = it
				break
	_cache[file] = tex
	return tex
