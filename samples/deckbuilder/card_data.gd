class_name CardData extends Resource
## One card's numbers. A new card is a new .tres file, not new code.

enum Kind { ATTACK, SKILL, POWER }

@export var title: String
@export var kind: Kind
@export var cost := 1
@export var damage := 0
@export var block := 0
@export var draw := 0
@export var weak := 0
@export var all_enemies := false
@export_multiline var text: String
@export var art: Texture2D
