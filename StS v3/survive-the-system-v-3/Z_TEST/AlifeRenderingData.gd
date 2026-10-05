class_name AlifeRenderingData
extends RefCounted

const TEX_W := 1024
var tex_h := 0
var data := PackedFloat32Array()
var img: Image
var tex: ImageTexture
const MIN_CAP := 16 * TEX_W

func capacity() -> int:
	return data.size() / 4

func resize(requested: int) -> void:
	requested = maxi(requested, MIN_CAP)   # never smaller than the minimum
	var new_h := ceili(float(requested) / TEX_W)
	var new_cap := new_h * TEX_W
	var old_cap := capacity()
	if new_cap <= old_cap:
		return
	tex_h = new_h
	var pad := PackedFloat32Array()
	pad.resize((new_cap - old_cap) * 4)
	pad.fill(0.0)
	data.append_array(pad)
	img = Image.create_from_data(TEX_W, tex_h, false, Image.FORMAT_RGBAF, data.to_byte_array())
	if tex == null:
		tex = ImageTexture.create_from_image(img)
	else:
		tex.set_image(img)            # same resource: every material using it updates

func upload() -> void:
	#print(data[0])
	#print(data.size())
	img.set_data(TEX_W, tex_h, false, Image.FORMAT_RGBAF, data.to_byte_array())
	tex.update(img)
