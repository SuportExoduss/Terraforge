class_name GroundAtlas
extends Resource
## Atlas dos pisos (E00), gerado por tools/build_ground_atlas.gd. Só entram civilizações que têm
## textura: slice_of[i] diz qual fatia é o chão da civilização i+1 (-1 = sem textura, cor chapada).

@export var albedo: Texture2DArray     # cor com o AO já assado
@export var normal: Texture2DArray     # relevo (mesmas fatias do albedo)
@export var slice_of := PackedInt32Array()
@export var dead_slice_of := PackedInt32Array()   # Death Biome (DD-122), idem
