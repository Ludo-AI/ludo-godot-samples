class_name Card extends Control
## One card: the art in a TextureRect clipped to the frame's window, the frame on top, the ribbon tinted by type, labels.

const TINT := [Color(0.72, 0.17, 0.12), Color(0.17, 0.5, 0.27), Color(0.18, 0.36, 0.74)]
const ICON := ["res://art/i_attack.png", "res://art/i_block.png", "res://art/i_buff.png"]
const FONT := preload("res://art/Gelasio-Bold.ttf")

var data: CardData

func setup(d: CardData) -> Card:
	data = d
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	$ArtWindow/Art.texture = mip(d.art)
	$Frame.texture = mip($Frame.texture)
	$Cost.texture = mip($Cost.texture)
	$Ribbon/Title.text = d.title
	$Cost/Value.text = str(d.cost)
	$Text.text = d.text
	style($Ribbon/Title, 40, Color.WHITE, 10)
	style($Cost/Value, 70, Color.WHITE, 16)
	style($Text, 44, Color(0.1, 0.06, 0.03), 0)
	# r3 (founder note 1:31.0 "deal 7 damage cannot be read"): bigger rules text on its own solid parchment plate, so it reads at
	# hand size and when the exploded view lifts the Text layer off the card (it carries its plate with it)
	var pl := StyleBoxFlat.new(); pl.bg_color = Color(0.95, 0.89, 0.74); pl.set_corner_radius_all(12)
	pl.set_border_width_all(3); pl.border_color = Color(0.45, 0.3, 0.16); pl.content_margin_left = 10; pl.content_margin_right = 10
	$Text.add_theme_stylebox_override("normal", pl)
	$Text.add_theme_constant_override("line_spacing", -4)
	tint(d.kind)
	return self

func tint(kind: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = TINT[kind]
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(4)
	sb.border_color = Color(0.12, 0.07, 0.04)
	$Ribbon.add_theme_stylebox_override("panel", sb)
	$TypeIcon.texture = mip(load(ICON[kind]))

func style(l: Label, size: int, col: Color, outline: int) -> void:
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.03))
	l.add_theme_constant_override("outline_size", outline)

static func mip(tex: Texture2D) -> Texture2D:   # cards are drawn at a third of their size: mipmaps keep the art clean
	if tex == null or tex is ImageTexture: return tex
	var img := tex.get_image()
	img.decompress()
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
