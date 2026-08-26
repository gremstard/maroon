extends SceneTree
# One-off: draws the app icon (an island under a maroon sun). Run:
#   godot --headless --script scripts/gen_icon.gd

func _init() -> void:
	var s := 256
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var sea := Color(0.10, 0.32, 0.45)
	var sea_deep := Color(0.07, 0.22, 0.34)
	var sand := Color(0.78, 0.71, 0.50)
	var grass := Color(0.30, 0.52, 0.26)
	var grass_dark := Color(0.24, 0.42, 0.21)
	var sun := Color(0.55, 0.15, 0.20)   # maroon, naturally
	var isle := Vector2(118, 158)
	for y in s:
		for x in s:
			var p := Vector2(x, y)
			var c := sea.lerp(sea_deep, float(y) / s)
			var d := p.distance_to(isle)
			var wobble := sin(x * 0.11) * 6.0 + cos(y * 0.13) * 5.0
			if d + wobble < 78.0:
				c = sand
			if d + wobble < 64.0:
				c = grass if (x + y) % 7 != 0 else grass_dark
			var sd := p.distance_to(Vector2(196, 52))
			if sd < 30.0:
				c = sun
			elif sd < 34.0:
				c = c.lerp(sun, 0.35)
			img.set_pixel(x, y, c)
	# a few pine triangles
	for tree in [Vector2(100, 128), Vector2(132, 142), Vector2(114, 156)]:
		for ty in 26:
			var w := int(ty * 0.55)
			for tx in range(-w, w + 1):
				var px := int(tree.x) + tx
				var py := int(tree.y) - 26 + ty
				if px >= 0 and px < s and py >= 0 and py < s:
					img.set_pixel(px, py, Color(0.13, 0.32, 0.17))
	img.save_png("res://icon.png")
	print("icon written")
	quit()
