extends Node2D
# MapSetup — spawns all map structures at runtime and bakes the NavigationPolygon.
# Attach to the TwistedTreeline scene root.

# MAP COORDINATE SYSTEM
# Total:     3200 x 2000 px
# Blue base: x: 0–350,    y: 0–2000
# Red base:  x: 2850–3200, y: 0–2000
# Top lane:  x: 0–3200,   y: 0–450
# Bot lane:  x: 0–3200,   y: 1550–2000
# Jungle:    x: 350–2850,  y: 450–1550
# Altar A:   (850,  750)  — blue-side jungle
# Altar B:   (2350, 750)  — red-side jungle
# Vilemaw:   (1600, 750)  — center jungle
# Fountain B: (120, 1000)
# Fountain R: (3080, 1000)

@export var tower_scene:       PackedScene = null
@export var nexus_scene:       PackedScene = null
@export var altar_scene:       PackedScene = null
@export var vilemaw_scene:     PackedScene = null
@export var health_pack_scene: PackedScene = null
@export var jungle_camp_scene: PackedScene = null
@export var nav_region:        NodePath = NodePath("../NavigationRegion2D")

# ---- Structure data ----
# [position, team, tower_type, lane]
const TOWERS := [
	# Blue top lane (left to right)
	[Vector2(600,   200),  1, "outer",     "top"],
	[Vector2(1200,  200),  1, "inner",     "top"],
	[Vector2(320,   200),  1, "inhibitor", "top"],
	# Blue bot lane
	[Vector2(600,  1800),  1, "outer",     "bot"],
	[Vector2(1200, 1800),  1, "inner",     "bot"],
	[Vector2(320,  1800),  1, "inhibitor", "bot"],
	# Blue nexus tower
	[Vector2(250,  1000),  1, "nexus",     "top"],
	# Red top lane (right to left)
	[Vector2(2600,  200),  2, "outer",     "top"],
	[Vector2(2000,  200),  2, "inner",     "top"],
	[Vector2(2880,  200),  2, "inhibitor", "top"],
	# Red bot lane
	[Vector2(2600, 1800),  2, "outer",     "bot"],
	[Vector2(2000, 1800),  2, "inner",     "bot"],
	[Vector2(2880, 1800),  2, "inhibitor", "bot"],
	# Red nexus tower
	[Vector2(2950, 1000),  2, "nexus",     "top"],
]

const NEXUSES := [
	[Vector2(175,  1000), 1],
	[Vector2(3025, 1000), 2],
]

const ALTARS := [
	[Vector2(850,  750), 0],
	[Vector2(2350, 750), 1],
]

const HEALTH_PACKS := [
	Vector2(1600, 1100),
	Vector2(900,  1100),
	Vector2(2300, 1100),
]

# [position, camp_type]
const JUNGLE_CAMPS := [
	[Vector2(600,  1100), "golems"],
	[Vector2(650,   650), "wraiths"],
	[Vector2(2600, 1100), "golems"],
	[Vector2(2550,  650), "wraiths"],
]

const VILEMAW_POS := Vector2(1600, 750)

const FOUNTAIN_BLUE := Vector2(120,  1000)
const FOUNTAIN_RED  := Vector2(3080, 1000)


func _ready() -> void:
	_spawn_towers()
	_spawn_nexuses()
	_spawn_altars()
	_spawn_vilemaw()
	_spawn_health_packs()
	_spawn_jungle_camps()
	_spawn_fountains()
	_build_navigation()
	_setup_wave_manager()


func _spawn_towers() -> void:
	if tower_scene == null:
		push_error("MapSetup: tower_scene not assigned")
		return
	for t in TOWERS:
		var node := tower_scene.instantiate()
		node.team       = t[1]
		node.tower_type = t[2]
		node.lane       = t[3]
		node.position   = t[0]
		# Color-code visually
		var sprite := node.get_node_or_null("Sprite2D")
		if sprite:
			sprite.color = Color(0.2, 0.4, 0.9) if t[1] == 1 else Color(0.9, 0.2, 0.2)
		add_child(node)


func _spawn_nexuses() -> void:
	if nexus_scene == null:
		push_error("MapSetup: nexus_scene not assigned")
		return
	for n in NEXUSES:
		var node := nexus_scene.instantiate()
		node.team     = n[1]
		node.position = n[0]
		var sprite := node.get_node_or_null("Sprite2D")
		if sprite:
			sprite.color = Color(0.1, 0.2, 0.8) if n[1] == 1 else Color(0.8, 0.1, 0.1)
		add_child(node)


func _spawn_altars() -> void:
	if altar_scene == null:
		push_error("MapSetup: altar_scene not assigned")
		return
	for a in ALTARS:
		var node := altar_scene.instantiate()
		node.altar_id = a[1]
		node.position = a[0]
		add_child(node)


func _spawn_vilemaw() -> void:
	if vilemaw_scene == null:
		push_error("MapSetup: vilemaw_scene not assigned")
		return
	var node := vilemaw_scene.instantiate()
	node.position = VILEMAW_POS
	add_child(node)


func _spawn_health_packs() -> void:
	if health_pack_scene == null:
		return
	for pos in HEALTH_PACKS:
		var node := health_pack_scene.instantiate()
		node.position = pos
		add_child(node)


func _spawn_jungle_camps() -> void:
	if jungle_camp_scene == null:
		return
	for c in JUNGLE_CAMPS:
		var node := jungle_camp_scene.instantiate()
		node.position  = c[0]
		node.camp_type = c[1]
		add_child(node)


func _spawn_fountains() -> void:
	var bf := Node2D.new()
	bf.name     = "BlueFountain"
	bf.position = FOUNTAIN_BLUE
	bf.add_to_group("fountain_team_1")
	add_child(bf)

	var rf := Node2D.new()
	rf.name     = "RedFountain"
	rf.position = FOUNTAIN_RED
	rf.add_to_group("fountain_team_2")
	add_child(rf)


func _build_navigation() -> void:
	var region: NavigationRegion2D = get_node_or_null(nav_region)
	if region == null:
		push_error("MapSetup: NavigationRegion2D not found at '%s'" % nav_region)
		return

	# Build a NavigationPolygon covering all walkable areas:
	# top lane + jungle + bot lane + both bases, connected as one polygon.
	# Shape: entire map rectangle minus the wall strips between jungle and lanes.
	# We use a simple union: one big outer polygon minus nothing (open map).
	# For MVP, the entire 3200x2000 area is walkable (walls are visual only).

	var nav_poly: NavigationPolygon = NavigationPolygon.new()

	# Outer walkable boundary (full map) — entire 3200x2000 area is walkable for MVP.
	# Directly set vertices + polygon indices to avoid the deprecated make_polygons_from_outlines().
	nav_poly.vertices = PackedVector2Array([
		Vector2(0,    0),
		Vector2(3200, 0),
		Vector2(3200, 2000),
		Vector2(0,    2000),
	])
	nav_poly.add_polygon(PackedInt32Array([0, 1, 2, 3]))

	region.navigation_polygon = nav_poly


func _setup_wave_manager() -> void:
	var wm: WaveManager = get_node_or_null("WaveManager")
	if wm == null:
		return
	wm.blue_top_waypoints = [
		Vector2(350, 200), Vector2(900, 200), Vector2(1600, 200),
		Vector2(2300, 200), Vector2(2600, 200), Vector2(2850, 200),
	]
	wm.blue_bot_waypoints = [
		Vector2(350, 1800), Vector2(900, 1800), Vector2(1600, 1800),
		Vector2(2300, 1800), Vector2(2600, 1800), Vector2(2850, 1800),
	]
	wm.red_top_waypoints = [
		Vector2(2850, 200), Vector2(2300, 200), Vector2(1600, 200),
		Vector2(900, 200), Vector2(600, 200), Vector2(350, 200),
	]
	wm.red_bot_waypoints = [
		Vector2(2850, 1800), Vector2(2300, 1800), Vector2(1600, 1800),
		Vector2(900, 1800), Vector2(600, 1800), Vector2(350, 1800),
	]
