# StatusBar.gd - 状态栏脚本
extends Control

@onready var hp_bar = $LeftSection/BarsContainer/HPContainer/HPBar
@onready var exp_bar = $LeftSection/BarsContainer/EXPContainer/EXPBar

func _ready():
	print("StatusBar initialized")

func update_hp(current_hp: int, max_hp: int):
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp

func update_exp(current_exp: int, max_exp: int):
	if exp_bar:
		exp_bar.max_value = max_exp
		exp_bar.value = current_exp 