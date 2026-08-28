extends Area3D

signal scored(team: int)
@export_enum("蓝方:0", "黄方:1") var scoring_team := 0
var locked := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if locked or not body is DroneBody:
		return
	locked = true
	scored.emit(scoring_team)
	await get_tree().create_timer(1.2).timeout
	locked = false
