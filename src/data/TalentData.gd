class_name TalentData
extends RefCounted

enum Rank {
	F,
	D,
	C,
	B,
	A,
	S,
	SSS
}

const RANK_NAMES = {
	Rank.F: "F",
	Rank.D: "D",
	Rank.C: "C",
	Rank.B: "B",
	Rank.A: "A",
	Rank.S: "S",
	Rank.SSS: "SSS"
}

const RANK_COLORS = {
	Rank.F: Color(0.7, 0.7, 0.7),        # Grey
	Rank.D: Color(0.3, 0.85, 0.3),       # Green
	Rank.C: Color(0.2, 0.6, 1.0),        # Cyan/Blue
	Rank.B: Color(0.7, 0.3, 0.95),       # Purple
	Rank.A: Color(1.0, 0.35, 0.35),      # Red/Orange
	Rank.S: Color(1.0, 0.85, 0.1),       # Gold
	Rank.SSS: Color(0.4, 1.0, 0.9)       # Prismatic Rainbow
}

# Accurate probabilities from specification:
# F 45%, D 25%, C 15%, B 8%, A 4.5%, S 2%, SSS 0.5%
const RANK_WEIGHTS = [
	{ "rank": Rank.F,   "weight": 45.0 },
	{ "rank": Rank.D,   "weight": 25.0 },
	{ "rank": Rank.C,   "weight": 15.0 },
	{ "rank": Rank.B,   "weight": 8.0 },
	{ "rank": Rank.A,   "weight": 4.5 },
	{ "rank": Rank.S,   "weight": 2.0 },
	{ "rank": Rank.SSS, "weight": 0.5 }
]

const TALENT_CATALOG = {
	Rank.SSS: [
		{
			"id": "sss_immortal",
			"name": "Bất Diệt Thần Thể",
			"desc": "Máu tối đa +100%, Sát thương +50%, Tự hồi 3 HP/giây, Giảm 30% sát thương từ quái vật.",
			"hp_mult": 2.0,
			"dmg_mult": 1.5,
			"regen": 3.0,
			"dmg_reduction": 0.30,
			"gather_mult": 1.5,
			"speed_mult": 1.2
		},
		{
			"id": "sss_primordial_overlord",
			"name": "Hoang Cổ Bá Chủ",
			"desc": "Sát thương +100%, Công trình base +200% máu, Toàn bộ quái vật giảm 25% giáp khi đối mặt.",
			"hp_mult": 1.5,
			"dmg_mult": 2.0,
			"regen": 1.0,
			"dmg_reduction": 0.20,
			"gather_mult": 2.0,
			"speed_mult": 1.15
		}
	],
	Rank.S: [
		{
			"id": "s_sword_domain",
			"name": "Đại Đạo Kiếm Thể",
			"desc": "Sát thương kiếm +80%, Tốc độ đánh +30%, 50% tỉ lệ chém chí mạng nhân đôi sát thương.",
			"hp_mult": 1.2,
			"dmg_mult": 1.8,
			"regen": 0.5,
			"dmg_reduction": 0.15,
			"gather_mult": 1.0,
			"speed_mult": 1.1
		},
		{
			"id": "s_phoenix_rebirth",
			"name": "Niết Bàn Thần Huyết",
			"desc": "Tự hồi 2 HP/giây, Miễn nhiễm hoàn toàn với bỏng và giá lạnh băng tuyết.",
			"hp_mult": 1.4,
			"dmg_mult": 1.2,
			"regen": 2.0,
			"dmg_reduction": 0.15,
			"gather_mult": 1.0,
			"speed_mult": 1.05
		}
	],
	Rank.A: [
		{
			"id": "a_wood_spirit",
			"name": "Linh Mộc Dục Hỏa",
			"desc": "Thu hoạch gỗ x2, Xây dựng giảm 50% chi phí gỗ, Giữ thân nhiệt ổn định không bị lạnh.",
			"hp_mult": 1.1,
			"dmg_mult": 1.1,
			"regen": 0.0,
			"dmg_reduction": 0.05,
			"gather_mult": 2.0,
			"speed_mult": 1.05
		},
		{
			"id": "a_beast_blood",
			"name": "Thú Huyết Cuồng Nộ",
			"desc": "Khi máu dưới 40%, Sát thương tăng +60% và Tốc độ di chuyển tăng +30%.",
			"hp_mult": 1.2,
			"dmg_mult": 1.35,
			"regen": 0.0,
			"dmg_reduction": 0.1,
			"gather_mult": 1.0,
			"speed_mult": 1.15
		}
	],
	Rank.B: [
		{
			"id": "b_earth_lord",
			"name": "Thần Lực Thổ Bá",
			"desc": "Thu hoạch đá và quặng x2, Công trình tường và cửa căn cứ tăng +100% máu.",
			"hp_mult": 1.1,
			"dmg_mult": 1.15,
			"regen": 0.0,
			"dmg_reduction": 0.1,
			"gather_mult": 1.5,
			"speed_mult": 1.0
		},
		{
			"id": "b_iron_skin",
			"name": "Thiết Bì Thể Phách",
			"desc": "Máu tối đa +30%, Giảm 15% sát thương nhận từ mọi đòn tấn công của dã thú.",
			"hp_mult": 1.3,
			"dmg_mult": 1.0,
			"regen": 0.0,
			"dmg_reduction": 0.15,
			"gather_mult": 1.0,
			"speed_mult": 1.0
		}
	],
	Rank.C: [
		{
			"id": "c_wind_walker",
			"name": "Thần Hành Phong Bộ",
			"desc": "Tốc độ di chuyển +35%, Giảm 50% thể lực tiêu hao khi chạy nhanh.",
			"hp_mult": 1.0,
			"dmg_mult": 1.0,
			"regen": 0.0,
			"dmg_reduction": 0.0,
			"gather_mult": 1.0,
			"speed_mult": 1.35
		},
		{
			"id": "c_hunter_eye",
			"name": "Ưng Nhãn Thợ Săn",
			"desc": "Tầm quan sát rộng hơn 25%, Sát thương lên dã thú hoang dã +25%.",
			"hp_mult": 1.0,
			"dmg_mult": 1.25,
			"regen": 0.0,
			"dmg_reduction": 0.0,
			"gather_mult": 1.2,
			"speed_mult": 1.05
		}
	],
	Rank.D: [
		{
			"id": "d_survivalist",
			"name": "Dã Ngoại Sinh Tồn",
			"desc": "Thể lực tối đa +30%, Giảm 30% tốc độ suy giảm thân nhiệt khi trời rét ban đêm.",
			"hp_mult": 1.05,
			"dmg_mult": 1.05,
			"regen": 0.0,
			"dmg_reduction": 0.05,
			"gather_mult": 1.1,
			"speed_mult": 1.05
		},
		{
			"id": "d_herbalist",
			"name": "Thảo Mộc Nhập Môn",
			"desc": "Khi tiêu thụ thịt rừng và thảo dược, lượng hồi máu tăng +50%.",
			"hp_mult": 1.1,
			"dmg_mult": 1.0,
			"regen": 0.2,
			"dmg_reduction": 0.0,
			"gather_mult": 1.15,
			"speed_mult": 1.0
		}
	],
	Rank.F: [
		{
			"id": "f_hardworking",
			"name": "Cần Cù Bù Thông Minh",
			"desc": "Tốc độ chặt cây và đào đá +15%, Nhận thêm +1 nguyên liệu mỗi lần thu hoạch.",
			"hp_mult": 1.0,
			"dmg_mult": 1.0,
			"regen": 0.0,
			"dmg_reduction": 0.0,
			"gather_mult": 1.15,
			"speed_mult": 1.0
		},
		{
			"id": "f_strong_back",
			"name": "Thân Thể Khỏe Khoắn",
			"desc": "Máu tối đa +10%, Có thể mang vác thêm tài nguyên.",
			"hp_mult": 1.1,
			"dmg_mult": 1.0,
			"regen": 0.0,
			"dmg_reduction": 0.0,
			"gather_mult": 1.05,
			"speed_mult": 1.0
		}
	]
}

static func roll_rank() -> Rank:
	return _rank_from_roll(randf() * 100.0)

static func roll_rank_with(rng: RandomNumberGenerator) -> Rank:
	return _rank_from_roll(rng.randf() * 100.0)

static func _rank_from_roll(roll: float) -> Rank:
	var acc = 0.0
	for entry in RANK_WEIGHTS:
		acc += entry.weight
		if roll < acc:
			return entry.rank
	return Rank.F

static func roll_talent() -> Dictionary:
	var rank = roll_rank()
	var candidates = TALENT_CATALOG[rank]
	var choice = candidates[randi() % candidates.size()].duplicate(true)
	choice["rank"] = rank
	choice["rank_str"] = RANK_NAMES[rank]
	choice["color_hex"] = RANK_COLORS[rank].to_html()
	return choice
