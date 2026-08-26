class_name GameItems

# Everything craftable and its cost. Order = crafting menu order.
const RECIPES := {
	"string":     {"fiber": 2},
	"crude_axe":  {"branch": 1, "stone": 2, "string": 1},
	"crude_pick": {"branch": 1, "stone": 2, "string": 1},
	"spear":      {"branch": 2, "stone": 1, "string": 1},
	"stone_axe":  {"wood": 4, "stone": 6, "string": 2},
	"stone_pick": {"wood": 4, "stone": 6, "string": 2},
	"torch":      {"branch": 1, "fiber": 2},
	"campfire":   {"wood": 8, "stone": 4},
	"workbench":  {"wood": 12, "stone": 4},
	"totem":      {"wood": 20, "stone": 10},
	"forge":      {"stone": 20, "wood": 10},
	"beacon":     {"wood": 10, "iron_ore": 3, "string": 2, "ancient_lens": 1},
	# -------- clothing: fiber tier (craft anywhere)
	"fiber_cap":      {"fiber": 4, "string": 1},
	"fiber_tunic":    {"fiber": 8, "string": 2},
	"fiber_leggings": {"fiber": 6, "string": 2},
	"woven_pack":     {"fiber": 10, "string": 3},
	# -------- clothing: hide tier (craft anywhere)
	"hide_hood":  {"hide": 2, "string": 1},
	"hide_coat":  {"hide": 4, "string": 2},
	"hide_pants": {"hide": 3, "string": 2},
	"hide_pack":  {"hide": 4, "string": 3},
	# -------- forge-only (stand near a lit forge)
	"iron_bar":   {"iron_ore": 2, "wood": 2},
	"iron_axe":   {"iron_bar": 2, "branch": 1, "string": 1},
	"iron_pick":  {"iron_bar": 2, "branch": 1, "string": 1},
	"iron_spear": {"iron_bar": 2, "branch": 2, "string": 1},
	"iron_helm":  {"iron_bar": 2, "hide": 1},
	"iron_chest": {"iron_bar": 4, "hide": 2},
	"scale_helm":  {"leviathan_scale": 2, "hide": 1},
	"scale_chest": {"leviathan_scale": 3, "hide": 2},
	"raft":       {"wood": 20, "string": 4, "moonstone": 1},
	"hammer":     {"wood": 4, "stone": 2, "string": 1},
}

# Building pieces are placed straight from raw wood (Rust-style), not crafted.
# Snap to a 3 m grid; walls are 2.6 m tall. Requires a hammer.
const BUILD_PIECES := {
	"foundation": {"wood": 8},
	"floor":      {"wood": 6},
	"wall":       {"wood": 6},
	"half_wall":  {"wood": 3},
	"doorway":    {"wood": 5},
	"window":     {"wood": 5},
	"gable":      {"wood": 4},
	"roof":       {"wood": 6},
	"slope":      {"wood": 6},
	"hatched":    {"wood": 7},
	"door":       {"wood": 4},
	"shutter":    {"wood": 2},
}
const BCELL := 3.0
const BWALL_H := 2.6

const PLACEABLES := ["torch", "campfire", "workbench", "totem", "forge", "beacon"]
const MATERIALS := ["string", "iron_bar"]   # crafted items that go back into the inventory

# What you can make with cold hands and a flat rock. Everything else needs
# a station — the workbench for real carpentry, the forge for metal.
const HAND_RECIPES := ["string", "crude_axe", "crude_pick", "spear",
	"torch", "campfire", "hammer", "workbench"]
const FORGE_ONLY := ["iron_bar", "iron_axe", "iron_pick", "iron_spear",
	"iron_helm", "iron_chest", "scale_helm", "scale_chest"]

static func station_for(recipe: String) -> String:
	if recipe in FORGE_ONLY:
		return "forge"
	if recipe in HAND_RECIPES:
		return ""
	return "workbench"

# Only these live on the hotbar; placeables are held via right-click → Hold.
static func hotbar_eligible(item: String) -> bool:
	return TOOL_STATS.has(item) or item == "hammer" or item in FOODS or item == "torch"

const DESCRIPTIONS := {
	"wood": "Split from the island's pines. Builds, burns, feeds the totem.",
	"stone": "Loose or mined. The other half of everything.",
	"branch": "Deadfall. The handle of every first tool.",
	"fiber": "Pulled from dry grass. Twists into string.",
	"string": "Two fibers, twisted. Holds the world together.",
	"berries": "Safe to eat. Better in you than in a wolf.",
	"raw_meat": "Cook it. You know better.",
	"cooked_meat": "The good stuff. Fills you and heals a little.",
	"hide": "Skinned from a kill. Coats, packs, and armor backing.",
	"iron_ore": "Highland ore. The forge makes it honest.",
	"iron_bar": "Smelted and ready for real tools.",
	"moonstone": "It hums faintly. The reef, the raft, the monolith.",
	"leviathan_scale": "Proof. Also the island's best armor.",
	"torch": "Fire on a stick. Hold it, or plant it. The dark hates it.",
	"campfire": "Cooks meat. Marks home.",
	"workbench": "Real carpentry happens here. Place it, stand close, craft.",
	"totem": "Claims this ground. Feed it wood or the rot returns.",
	"forge": "Ore goes in. Iron comes out. Stand close to work it.",
	"beacon": "Needs the peak. Calls across the sea.",
	"journal": "The captain's last pages. Read them well.",
	"rusted_key": "Swallowed whole by a wolf. The Ruins are waiting.",
	"ancient_lens": "Focuses flame into signal. Iron, wood, and the peak.",
}

static func describe(item: String) -> String:
	if item in DESCRIPTIONS:
		return DESCRIPTIONS[item]
	if item in CLOTHES:
		var c: Dictionary = CLOTHES[item]
		if c.get("carry", 0) > 0:
			return "Worn on the %s. +%d carry." % [c["gear_slot"], c["carry"]]
		return "Worn on the %s. %d%% damage off." % [c["gear_slot"], int(c.get("armor", 0.0) * 100)]
	if TOOL_STATS.has(item):
		return "A tool. Bind it, hold it, use it."
	return ""

# Clothing: what you wear is what you get (slots borrowed from a fellow
# design doc, trimmed to four). armor = damage reduction; carry = extra
# capacity before weight slows you down.
const CLOTHES := {
	"fiber_cap":      {"gear_slot": "head",  "armor": 0.04, "tier": "fiber"},
	"fiber_tunic":    {"gear_slot": "torso", "armor": 0.08, "tier": "fiber"},
	"fiber_leggings": {"gear_slot": "legs",  "armor": 0.06, "tier": "fiber"},
	"woven_pack":     {"gear_slot": "back",  "armor": 0.0,  "carry": 40, "tier": "fiber"},
	"hide_hood":      {"gear_slot": "head",  "armor": 0.08, "tier": "hide"},
	"hide_coat":      {"gear_slot": "torso", "armor": 0.15, "tier": "hide"},
	"hide_pants":     {"gear_slot": "legs",  "armor": 0.11, "tier": "hide"},
	"hide_pack":      {"gear_slot": "back",  "armor": 0.0,  "carry": 90, "tier": "hide"},
	"iron_helm":      {"gear_slot": "head",  "armor": 0.12, "tier": "iron"},
	"iron_chest":     {"gear_slot": "torso", "armor": 0.22, "tier": "iron"},
	"scale_helm":     {"gear_slot": "head",  "armor": 0.16, "tier": "scale"},
	"scale_chest":    {"gear_slot": "torso", "armor": 0.30, "tier": "scale"},
}

# Material ladder, low -> high. Rarity vs power is a gradual slope, never
# exponential: full best-in-slot armor caps at 50% reduction (~2x survival),
# mirroring "top tier vs unarmoured is 3 hits, not 1".
const TIERS := ["fiber", "hide", "iron", "scale"]
const TIER_COLORS := {
	"fiber": Color(0.72, 0.72, 0.72),
	"hide":  Color(0.49, 0.76, 0.51),
	"iron":  Color(0.50, 0.70, 0.90),
	"scale": Color(0.90, 0.75, 0.48),
}
const ARMOR_CAP := 0.5

const NICE_NAMES := {
	"wood": "Wood", "stone": "Stone", "berries": "Berries",
	"branch": "Branch", "fiber": "Plant Fiber", "string": "String",
	"iron_ore": "Iron Ore",
	"raw_meat": "Raw Meat", "cooked_meat": "Cooked Meat",
	"crude_axe": "Crude Axe", "crude_pick": "Crude Pick",
	"stone_axe": "Stone Axe", "stone_pick": "Stone Pick",
	"spear": "Spear", "campfire": "Campfire", "wall": "Wall",
	"totem": "Claim Totem", "hand": "Hands",
	"journal": "Captain's Journal", "rusted_key": "Rusted Key",
	"ancient_lens": "Ancient Lens", "beacon": "Signal Beacon",
	"leviathan_scale": "Leviathan Scale",
	"hide": "Hide", "iron_bar": "Iron Bar", "forge": "Forge",
	"torch": "Torch", "moonstone": "Moonstone", "raft": "Raft",
	"hammer": "Hammer", "workbench": "Workbench",
	"foundation": "Foundation", "floor": "Floor",
	"half_wall": "Half Wall", "doorway": "Doorway", "window": "Window Wall",
	"gable": "Gable", "roof": "Roof", "slope": "Sloped Roof",
	"hatched": "Hatched Roof",
	"door": "Door", "shutter": "Shutters",
	"iron_axe": "Iron Axe", "iron_pick": "Iron Pick", "iron_spear": "Iron Spear",
	"fiber_cap": "Fiber Cap", "fiber_tunic": "Fiber Tunic",
	"fiber_leggings": "Fiber Leggings", "woven_pack": "Woven Pack",
	"hide_hood": "Hide Hood", "hide_coat": "Hide Coat",
	"hide_pants": "Hide Pants", "hide_pack": "Hide Pack",
	"iron_helm": "Iron Helm", "iron_chest": "Iron Chestplate",
	"scale_helm": "Scale Helm", "scale_chest": "Scale Chestplate",
}

# Harvest power per hit: chop (trees), mine (rocks/ore), and melee damage.
# Bare hands can only forage — they cannot fell a tree or crack a boulder.
const TOOL_STATS := {
	"hand":       {"chop": 0.0, "mine": 0.0, "dmg": 8.0},
	"crude_axe":  {"chop": 3.0, "mine": 0.0, "dmg": 14.0},
	"crude_pick": {"chop": 0.0, "mine": 3.0, "dmg": 12.0},
	"stone_axe":  {"chop": 5.0, "mine": 0.0, "dmg": 20.0},
	"stone_pick": {"chop": 0.0, "mine": 5.0, "dmg": 16.0},
	"spear":      {"chop": 0.0, "mine": 0.0, "dmg": 32.0},
	"iron_axe":   {"chop": 7.0, "mine": 0.0, "dmg": 28.0},
	"iron_pick":  {"chop": 0.0, "mine": 7.0, "dmg": 24.0},
	"iron_spear": {"chop": 0.0, "mine": 0.0, "dmg": 45.0},
}

# Resource nodes. "pickup" = hand-gatherable (any tool works, yields "count").
const RES_STATS := {
	"tree":   {"hp": 12.0, "item": "wood"},
	"rock":   {"hp": 15.0, "item": "stone"},
	"iron":   {"hp": 20.0, "item": "iron_ore"},
	"moonstone": {"hp": 25.0, "item": "moonstone"},
	"bush":   {"hp": 3.0,  "item": "berries", "pickup": true, "count": 2},
	"branch": {"hp": 1.0,  "item": "branch",  "pickup": true, "count": 1},
	"grass":  {"hp": 1.0,  "item": "fiber",   "pickup": true, "count": 2},
	"pebble": {"hp": 1.0,  "item": "stone",   "pickup": true, "count": 1},
}

const FOODS := {
	"berries":     {"hunger": 15.0, "hp": 0.0},
	"raw_meat":    {"hunger": 10.0, "hp": -5.0},
	"cooked_meat": {"hunger": 40.0, "hp": 10.0},
}

# ---------------------------------------------------------------- grid inventory

const STACK_MAX := {
	"wood": 50, "stone": 50, "fiber": 30, "branch": 20, "string": 30,
	"berries": 20, "raw_meat": 10, "cooked_meat": 10, "hide": 20,
	"iron_ore": 20, "iron_bar": 20, "leviathan_scale": 10, "moonstone": 5,
	"torch": 10, "campfire": 3, "wall": 5, "totem": 2, "forge": 2, "beacon": 2,
}

static func stack_max(item: String) -> int:
	return STACK_MAX.get(item, 1)

static func grid_size(item: String) -> Vector2i:
	if item in CLOTHES:
		return Vector2i(2, 2)
	if item == "branch":
		return Vector2i(1, 2)
	return Vector2i(1, 1)

const CATEGORY_COLORS := {
	"wood": Color(0.45, 0.32, 0.18), "branch": Color(0.42, 0.30, 0.17),
	"stone": Color(0.45, 0.45, 0.48), "iron_ore": Color(0.40, 0.34, 0.30),
	"iron_bar": Color(0.62, 0.65, 0.70), "moonstone": Color(0.45, 0.55, 0.75),
	"fiber": Color(0.62, 0.58, 0.30), "string": Color(0.70, 0.66, 0.50),
	"hide": Color(0.48, 0.34, 0.22), "leviathan_scale": Color(0.75, 0.62, 0.35),
	"berries": Color(0.60, 0.25, 0.30), "raw_meat": Color(0.62, 0.30, 0.28),
	"cooked_meat": Color(0.50, 0.32, 0.20),
	"torch": Color(0.70, 0.50, 0.25), "campfire": Color(0.60, 0.42, 0.22),
	"totem": Color(0.55, 0.40, 0.45), "forge": Color(0.40, 0.40, 0.42),
	"beacon": Color(0.65, 0.55, 0.30),
	"journal": Color(0.50, 0.42, 0.55), "rusted_key": Color(0.48, 0.36, 0.28),
	"ancient_lens": Color(0.42, 0.55, 0.60),
}

static func icon_color(item: String) -> Color:
	if item in CLOTHES:
		return TIER_COLORS[CLOTHES[item]["tier"]]
	return CATEGORY_COLORS.get(item, Color(0.4, 0.4, 0.45))

static func nice(n: String) -> String:
	return NICE_NAMES.get(n, n.capitalize())

static func cost_text(recipe: String) -> String:
	var parts: PackedStringArray = []
	for mat in RECIPES[recipe]:
		parts.append("%d %s" % [RECIPES[recipe][mat], nice(mat)])
	return ", ".join(parts)
