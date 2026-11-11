extends RefCounted
## 1.0 線性章節的敘事資料：B1–B9 節拍、D-01–D-10 台詞、場景路由。
## 所有台詞單句 ≤ 40 字、每拍 ≤ 3 行（docs/09 §4.4）。

const D: Dictionary = {
	"D-01": "客官，一個人？後面跟著那隻東西，不是我看不見，是它不想讓你看見。",
	"D-02": "我眼裡只有酒和路。",
	"D-03": "三碗不過岡——不是酒烈，是岡上的東西不喜歡醉漢。",
	"D-04": "景陽岡沒有虎。虎在你身上。",
	"D-05": "回頭，還是上去？",
	"D-06": "我這一生，沒回過頭。",
	"D-07": "那虎氣性自洩了。",
	"D-08": "你也是被放出來的。",
	"D-09": "景陽岡沒有虎了。但武松的影子，從此是四隻。",
	"D-10": "下山。",
}

const SCENE_PATHS: Dictionary = {
	"SCN-01": "res://scenes/chapters/SCN_01_Inn.tscn",
	"SCN-02": "res://scenes/chapters/SCN_02_Trail.tscn",
	"SCN-03": "res://scenes/chapters/SCN_03_Forest.tscn",
	"SCN-04": "res://scenes/chapters/SCN_04_Temple.tscn",
	"SCN-05": "res://scenes/chapters/SCN_05_Ridge.tscn",
	"SCN-06": "res://scenes/chapters/SCN_06_Pool.tscn",
}

const BEATS: Dictionary = {
	"B1": {
		"scene": "SCN-01", "title": "酒肆", "next": "B2",
		"lines": [
			{"speaker": "酒肆老闆", "text": D["D-01"]},
			{"speaker": "武松", "text": D["D-02"]},
			{"speaker": "酒肆老闆", "text": D["D-03"]},
		],
	},
	"B2": {
		"scene": "SCN-02", "title": "酒肆外", "next": "B3",
		"lines": [
			{"speaker": "旁白", "text": D["D-04"]},
		],
	},
	"B3": {
		"scene": "SCN-02", "title": "山道", "next": "B4",
		"lines": [],
	},
	"B4": {
		"scene": "SCN-04", "title": "山神廟", "next": "B5",
		"lines": [
			{"speaker": "山神", "text": D["D-05"]},
			{"speaker": "武松", "text": D["D-06"]},
		],
	},
	"B5": {
		"scene": "SCN-03", "title": "亂林", "next": "B6",
		"lines": [],
	},
	"B6": {
		"scene": "SCN-05", "title": "崗頂", "next": "B7",
		"lines": [],
	},
	"B7": {
		"scene": "SCN-05", "title": "崗頂", "next": "B8",
		"lines": [],
	},
	"B8": {
		"scene": "SCN-06", "title": "水潭", "next": "B9",
		"lines": [
			{"speaker": "水潭字幕", "text": D["D-08"]},
			{"speaker": "結語", "text": D["D-09"]},
		],
	},
	"B9": {
		"scene": "SCN-06", "title": "結語", "next": "",
		"lines": [
			{"speaker": "武松", "text": D["D-10"]},
		],
	},
}

const ORDER: Array[String] = ["B1", "B2", "B3", "B4", "B5", "B6", "B7", "B8", "B9"]

static func beat(id: String) -> Dictionary:
	return BEATS.get(id, {})

static func lines(id: String) -> Array:
	return beat(id).get("lines", [])

static func next_id(id: String) -> String:
	return String(beat(id).get("next", ""))

static func scene_path(id: String) -> String:
	var scene_id: String = String(beat(id).get("scene", ""))
	return String(SCENE_PATHS.get(scene_id, ""))

static func first_beat() -> String:
	return ORDER[0]

static func validate() -> Array[String]:
	var errors: Array[String] = []
	for i in range(ORDER.size()):
		var id: String = ORDER[i]
		if beat(id).is_empty():
			errors.append("%s missing" % id)
			continue
		if i < ORDER.size() - 1 and next_id(id) != ORDER[i + 1]:
			errors.append("%s next=%s expected %s" % [id, next_id(id), ORDER[i + 1]])
		if i == ORDER.size() - 1 and next_id(id) != "":
			errors.append("%s should be terminal" % id)
		var scene_path: String = scene_path(id)
		if scene_path == "" or not ResourceLoader.exists(scene_path):
			errors.append("%s scene missing: %s" % [id, scene_path])
		var l: Array = lines(id)
		if l.size() > 3:
			errors.append("%s has %d lines (>3)" % [id, l.size()])
		for line in l:
			var text: String = String(line.get("text", ""))
			if text.length() > 40:
				errors.append("%s line too long (%d)" % [id, text.length()])
			if String(line.get("speaker", "")) == "":
				errors.append("%s line without speaker" % id)
	return errors
