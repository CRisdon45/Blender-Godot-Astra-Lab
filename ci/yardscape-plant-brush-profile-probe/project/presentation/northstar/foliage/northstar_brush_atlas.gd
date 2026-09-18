extends RefCounted
## Hand-authored broad foliage marks derived from the approved Northstar witness.
## The explicit lobe placements define four connected watercolor masses. Runtime
## work only rasterizes those fixed masks; it does not invent or randomize art.

const ID := "northstar-broad-mass-atlas/2"
const TILE_COUNT := 4
const TILE_SIZE := 96

# Vector4 stores center x/y followed by radius x/y. Each tile is deliberately
# asymmetric and connected, with small edge lobes rather than literal leaves.
const LOBES := [
	[
		Vector4(-.02,-.01,.70,.67), Vector4(-.51,.03,.43,.45),
		Vector4(-.20,.42,.46,.39), Vector4(.34,.38,.44,.39),
		Vector4(.52,-.05,.43,.44), Vector4(.14,-.42,.48,.37)
	],
	[
		Vector4(-.04,.02,.69,.66), Vector4(-.50,-.17,.42,.40),
		Vector4(-.35,.35,.42,.40), Vector4(.14,.47,.45,.35),
		Vector4(.49,.17,.43,.42), Vector4(.30,-.38,.48,.38)
	],
	[
		Vector4(.01,-.04,.72,.65), Vector4(-.53,.10,.41,.43),
		Vector4(-.24,.45,.44,.36), Vector4(.29,.40,.47,.39),
		Vector4(.53,-.12,.41,.42), Vector4(-.12,-.45,.48,.35)
	],
	[
		Vector4(.03,.03,.68,.69), Vector4(-.50,-.04,.43,.44),
		Vector4(-.33,.40,.40,.37), Vector4(.21,.46,.46,.36),
		Vector4(.52,.02,.42,.45), Vector4(.18,-.44,.46,.37)
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
