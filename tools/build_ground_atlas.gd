extends SceneTree
## Assa os pisos das fichas (art/themes/theme_civN.tres) no atlas que o jogo carrega:
## art/themes/ground_atlas.res (Texture2DArray de cor com AO + Texture2DArray de relevo, 1024 px).
## Rode de novo sempre que mexer num piso. Precisa de janela (sem --headless): o Texture2DArray vive na GPU.
## Uso: godot_console --path . -s res://tools/build_ground_atlas.gd --quit
## ponytail: RGB8 sem compressão (~1,4 MB por fatia); no export Android trocar por ETC2/ASTC.

const SIZE := 1024
const OUT := "res://art/themes/ground_atlas.res"

var _albedo: Array[Image] = []
var _normal: Array[Image] = []


func _initialize() -> void:
	var atlas := GroundAtlas.new()
	var n := 1
	while ResourceLoader.exists("res://art/themes/theme_civ%d.tres" % n):
		var theme := load("res://art/themes/theme_civ%d.tres" % n) as PlanetTheme
		atlas.slice_of.append(_add(theme.ground_texture_file, theme.ground_ao_file, theme.ground_normal_file))
		atlas.dead_slice_of.append(_add(theme.dead_ground_texture_file, "", theme.dead_ground_normal_file))
		n += 1
	if _albedo.is_empty():   # nenhuma ficha tem textura: o array não pode ser vazio
		var gray := _solid(Color(0.5, 0.5, 0.5))
		var flat := _solid(Color(0.5, 0.5, 1.0))
		gray.generate_mipmaps()
		flat.generate_mipmaps()
		_albedo.append(gray)
		_normal.append(flat)
	atlas.albedo = Texture2DArray.new()
	atlas.albedo.create_from_images(_albedo)
	atlas.normal = Texture2DArray.new()
	atlas.normal.create_from_images(_normal)
	var err := ResourceSaver.save(atlas, OUT)
	print("atlas: %d fatia(s), slice_of=%s dead=%s -> %s (erro=%d)" % [_albedo.size(), atlas.slice_of, atlas.dead_slice_of, OUT, err])
	quit(0 if err == OK else 1)


## Acrescenta uma fatia (cor x AO + relevo) e devolve o índice dela; -1 se a ficha não tem textura.
func _add(tex_file: String, ao_file: String, normal_file: String) -> int:
	if tex_file == "":
		return -1
	var color := _load(tex_file)
	if ao_file != "":
		var ao := _load(ao_file)
		var c := color.get_data()
		var a := ao.get_data()
		for i in range(0, c.size(), 3):
			var k := a[i]   # AO é cinza: o canal R basta
			c[i] = c[i] * k / 255
			c[i + 1] = c[i + 1] * k / 255
			c[i + 2] = c[i + 2] * k / 255
		color = Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGB8, c)
	color.generate_mipmaps()
	_albedo.append(color)
	var normal := _load(normal_file) if normal_file != "" else _solid(Color(0.5, 0.5, 1.0))
	normal.generate_mipmaps(true)
	_normal.append(normal)
	return _albedo.size() - 1


func _load(path: String) -> Image:
	var img := Image.load_from_file(path)
	img.convert(Image.FORMAT_RGB8)
	img.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	return img


func _solid(color: Color) -> Image:
	var img := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGB8)
	img.fill(color)
	return img
