# UIManager.gd - 游戏UI总管理器
extends CanvasLayer

@onready var inventory_panel: Control = $InventoryPanel

func _ready():
    add_to_group("ui_manager")

func toggle_inventory():
    if inventory_panel:
        inventory_panel.toggle_visibility()

func _input(event):
    # ESC键关闭背包
    if event.is_action_pressed("ui_cancel") and inventory_panel and inventory_panel.visible:
        inventory_panel.hide_inventory()
        get_viewport().set_input_as_handled()