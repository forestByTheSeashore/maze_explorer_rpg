# HPBean.gd
extends Area2D

@export var heal_amount: int = 25 # 恢复的HP量，可在编辑器中调整

func _ready():
    body_entered.connect(_on_body_entered) # 连接信号

func _on_body_entered(body):
    if body.has_method("heal"): # 检查进入的物体是否有 heal 方法 (即是否是玩家)
        body.heal(heal_amount)
        queue_free() # HP豆被拾取后消失