extends SceneTree
# Draws the Maroon emblem: a black island silhouette against a maroon dusk,
# the Signal Beacon burning at the peak. Run:
#   godot --headless --script scripts/gen_icon.gd

func _init() -> void:
	var s := 512
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var sky_top := Color(0.09, 0.07, 0.14)
	var sky_mid := Color(0.35, 0.10, 0.16)     # maroon, of course
	var sky_low := Color(0.80, 0.38, 0.22)     # ember horizon
	var sea := Color(0.05, 0.05, 0.09)
	var silhouette := Color(0.03, 0.03, 0.05)
	var horizon := int(s * 0.62)

	for y in s:
		var c: Color
		if y < horizon:
			var t := float(y) / horizon
			c = sky_top.lerp(sky_mid, clampf(t * 1.4, 0, 1)).lerp(sky_low, maxf(0, t - 0.55) * 2.2)
		else:
			var t2 := float(y - horizon) / (s - horizon)
			c = sea.lerp(sky_low.darkened(0.6), maxf(0, 0.25 - t2))
		for x in s:
			img.set_pixel(x, y, c)

	# sun, half-set behind the island
	var sun_c := Color(1.0, 0.62, 0.30)
	for y in s:
		for x in s:
			var d := Vector2(x - 256, y - int(s * 0.60)).length()
			if d < 74.0 and y < horizon:
				img.set_pixel(x, y, sun_c)
			elif d < 92.0 and y < horizon:
				var p := img.get_pixel(x, y)
				img.set_pixel(x, y, p.lerp(sun_c, (92.0 - d) / 18.0 * 0.5))

	# island silhouette: two overlapping hills
	for x in s:
		var fx := float(x)
		var h1 := 120.0 * exp(-pow((fx - 210.0) / 130.0, 2.0))
		var h2 := 88.0 * exp(-pow((fx - 360.0) / 110.0, 2.0))
		var top := horizon - int(maxf(h1, h2))
		for y in range(top, int(s * 0.70)):
			img.set_pixel(x, y, silhouette)
	# pine silhouettes on the ridge
	for tree in [[150, 46, 26], [250, 60, 34], [318, 40, 22], [388, 34, 20]]:
		var tx: int = tree[0]
		var ridge := horizon
		for yy in range(0, horizon):
			if img.get_pixel(tx, yy) == silhouette:
				ridge = yy
				break
		var th: int = tree[1]
		for ty in th:
			var w := int(ty * float(tree[2]) / th * 0.5)
			for dx in range(-w, w + 1):
				var px := tx + dx
				var py: int = ridge - th + ty
				if px >= 0 and px < s and py >= 0 and py < s:
					img.set_pixel(px, py, silhouette)

	# the beacon at the main peak: pole, flame, upward beam
	var peak_x := 210
	var peak_y := horizon
	for yy in range(0, horizon):
		if img.get_pixel(peak_x, yy) == silhouette:
			peak_y = yy
			break
	var flame := Color(1.0, 0.78, 0.30)
	for yy in range(peak_y - 34, peak_y):
		for dx in range(-2, 3):
			img.set_pixel(peak_x + dx, yy, silhouette)
	for y in range(peak_y - 52, peak_y - 30):
		for x2 in range(peak_x - 7, peak_x + 8):
			if Vector2(x2 - peak_x, y - (peak_y - 41)).length() < 9.0:
				img.set_pixel(x2, y, flame)
	for y in range(0, peak_y - 48):
		var spread := 3.0 + (peak_y - 48 - y) * 0.10
		for dx in range(int(-spread), int(spread) + 1):
			var px := peak_x + dx
			if px >= 0 and px < s:
				var p := img.get_pixel(px, y)
				img.set_pixel(px, y, p.lerp(flame, 0.30))

	# sun & beacon reflections on the water
	for y in range(horizon + 4, s):
		if (y % 3) != 0:
			continue
		for dx in range(-30, 31):
			if absi(dx) % 2 == 0 and randf() > 0.35:
				var px := 256 + dx
				var p := img.get_pixel(px, y)
				img.set_pixel(px, y, p.lerp(sun_c, 0.25))

	img.save_png("res://icon.png")
	print("emblem written")
	quit()
