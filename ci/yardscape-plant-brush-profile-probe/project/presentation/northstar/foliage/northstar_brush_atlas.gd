extends RefCounted
## Hand-authored broad foliage marks derived from the approved Northstar witness.
## The explicit lobe placements define four connected watercolor masses. Runtime
## work only rasterizes those fixed masks; it does not invent or randomize art.

const ID := "northstar-broad-mass-atlas/1"
const TILE_COUNT := 4
const TILE_SIZE := 96

# Vector4 stores center x/y followed by radius x/y. Each tile is deliberately
# asymmetric and connected, with small edge lobes rather than literal leaves.
const LOBES := [
	[
		Vector4(-.64,-.08,.34,.38), Vector4(-.43,.19,.42,.42),
		Vector4(-.13,-.08,.47,.43), Vector4(.14,.19,.45,.44),
		Vector4(.42,-.07,.43,.39), Vector4(.66,.11,.31,.34),
		Vector4(-.30,-.28,.38,.31), Vector4(.25,-.27,.42,.31)
	],
	[
		Vector4(-.62,.19,.31,.34), Vector4(-.43,-.12,.42,.40),
		Vector4(-.16,.25,.40,.43), Vector4(.06,-.10,.48,.45),
		Vector4(.33,.22,.41,.40), Vector4(.59,-.03,.35,.36),
		Vector4(-.18,-.34,.35,.28), Vector4(.38,-.30,.36,.29)
	],
	[
		Vector4(-.64,-.16,.31,.32), Vector4(-.48,.16,.39,.40),
		Vector4(-.18,-.02,.46,.46), Vector4(.04,.29,.39,.38),
		Vector4(.27,-.08,.46,.43), Vector4(.57,.17,.37,.37),
		Vector4(.65,-.19,.27,.29), Vector4(.02,-.35,.41,.28)
	],
	[
		Vector4(-.65,.05,.32,.36), Vector4(-.42,-.21,.39,.34),
		Vector4(-.25,.24,.40,.41), Vector4(.04,-.05,.48,.46),
		Vector4(.24,.30,.36,.35), Vector4(.42,-.19,.42,.36),
		Vector4(.66,.09,.30,.34), Vector4(.01,-.39,.34,.25)
	]
]

static func texture()->ImageTexture:
	var image:=Image.create(TILE_SIZE*TILE_COUNT,TILE_SIZE,false,Image.FORMAT_RGBA8)
	for tile in TILE_COUNT:
		for y in TILE_SIZE:
			for x in TILE_SIZE:
				var p:=Vector2(
					(float(x)+.5)/float(TILE_SIZE)*2.-1.,
					(float(y)+.5)/float(TILE_SIZE)*2.-1.
				)
				var alpha:=0.0
				var coverage:=0.0
				for lobe_index in LOBES[tile].size():
					var lobe:Vector4=LOBES[tile][lobe_index]
					var q:=(p-Vector2(lobe.x,lobe.y))/Vector2(lobe.z,lobe.w)
					var angle:=atan2(q.y,q.x)
					var radial:=q.length()
					var scallop:=1.0
					scallop+=.050*sin((4.0+float((tile+lobe_index)%3))*angle+float(tile)*.73+float(lobe_index)*1.17)
					scallop+=.018*cos(9.0*angle-float(lobe_index)*.61)
					var local:=clampf((scallop-radial)*17.0+.5,0.,1.)
					alpha=maxf(alpha,local)
					coverage+=smoothstep(.70,1.02,scallop-radial+.70)
				var wash:=.50
				wash+=.095*sin(p.x*2.7+p.y*.8+float(tile)*.91)
				wash+=.060*cos(p.y*3.2-p.x*.7-float(tile)*.57)
				wash-=clampf(coverage-1.25,0.,2.4)*.035
				var edge_pool:=1.0-smoothstep(.42,.84,alpha)
				wash-=edge_pool*.040
				image.set_pixel(tile*TILE_SIZE+x,y,Color(clampf(wash,.28,.72),0.,0.,alpha))
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)
