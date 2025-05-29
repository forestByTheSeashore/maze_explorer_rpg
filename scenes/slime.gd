# RedSlime.gd
extends CharacterBody2D

@export var attack_power: int = 10     # 红色史莱姆的攻击力
@export var experience_drop: int = 15  # 击败后掉落的经验值
@export var health: int = 1            # 史莱姆生命值（简化版本，通常为1）

@onready var damage_zone: Area2D = $DamageZone # 假设你有 DamageZone Area2D
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D # 添加动画精灵引用

var can_deal_damage: bool = true # 用于控制伤害频率
var is_dead: bool = false       # 防止重复死亡处理

func _ready():
    add_to_group("enemies") # 将史莱姆添加到 "enemies" 组，方便玩家检测
    
    # 检查并连接DamageZone信号
    if damage_zone: 
        damage_zone.body_entered.connect(_on_DamageZone_body_entered)
    
    # 初始化动画
    if animated_sprite:
        # 检查是否有idle动画
        if animated_sprite.sprite_frames and animated_sprite.sprite_frames.has_animation("idle"):
            animated_sprite.play("idle")
        else:
            push_error("Warning: 'idle' animation not found for " + name)
    else:
        push_error("Error: AnimatedSprite2D node not found for " + name)

func _process(_delta):
    # 确保史莱姆始终播放idle动画（如果没有其他动画正在播放且未死亡）
    if not is_dead and animated_sprite and not animated_sprite.is_playing():
        if animated_sprite.sprite_frames.has_animation("idle"):
            animated_sprite.play("idle")

# 新的统一接口：接收玩家攻击
func receive_player_attack(player_attack_power: int) -> int:
    if is_dead:
        return 0
    
    # 根据GDD规则: "攻击力高于敌人即视为击败"
    if player_attack_power > self.attack_power:
        print(name, " 被玩家击败！玩家攻击力: ", player_attack_power, " > 史莱姆攻击力: ", attack_power)
        defeated()
        return player_attack_power  # 返回造成的伤害值
    else:
        # 如果玩家攻击力不高于敌人攻击力，根据GDD规则，敌人不会被击败
        print("玩家攻击力 (", player_attack_power, ") 不足以击败史莱姆 (", self.attack_power, ")")
        
        # 播放受击效果（如果有hurt动画）
        _on_hit_by_player()
        return 0  # 没有造成有效伤害

# 新增：受击时的反应（与敌人系统统一）
func _on_hit_by_player():
    # 播放受击效果
    play_hurt_animation()
    
    # 可以添加受击音效、闪烁效果等
    print(name, " 被玩家击中，但未被击败")
    
    # 示例：短暂闪烁效果
    if animated_sprite:
        var original_modulate = animated_sprite.modulate
        animated_sprite.modulate = Color.RED
        await get_tree().create_timer(0.1).timeout
        if animated_sprite:  # 确保节点仍然存在
            animated_sprite.modulate = original_modulate

# 保留原有方法作为兼容接口（标记为已弃用）
func receive_hit_from_player(player_total_attack_power: int):
    push_warning("receive_hit_from_player() is deprecated, use receive_player_attack() instead")
    receive_player_attack(player_total_attack_power)

# 通用伤害接口（与其他敌人统一）
func take_damage(amount: int, source_attack_power: int = 0):
    if is_dead:
        return
        
    health -= amount
    print(name, " 受到 ", amount, " 点伤害, 剩余HP: ", health)
    
    if health <= 0:
        defeated()
    else:
        _on_hit_by_player()

func defeated():
    if is_dead:
        return
        
    is_dead = true
    print(name + " 被击败了!")
    
    # 停止伤害检测
    can_deal_damage = false
    if damage_zone:
        damage_zone.monitoring = false
    
    # 播放死亡动画（如果有）
    await play_death_animation()
    
    # 通知玩家获得经验
    var player_node = get_tree().get_first_node_in_group("player")
    if player_node and player_node.has_method("gain_experience"):
        player_node.gain_experience(experience_drop)
        print("玩家获得经验: ", experience_drop)

    queue_free() # 敌人消失

# 播放受击动画
func play_hurt_animation():
    if not animated_sprite:
        return
        
    if animated_sprite.sprite_frames.has_animation("hurt"):
        animated_sprite.play("hurt")
        # 受击动画结束后返回idle
        await animated_sprite.animation_finished
        if not is_dead and animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
            animated_sprite.play("idle")

# 播放死亡动画
func play_death_animation():
    if not animated_sprite:
        return
        
    if animated_sprite.sprite_frames.has_animation("death"):
        animated_sprite.play("death")
        # 等待死亡动画播放完成
        await animated_sprite.animation_finished
    else:
        # 如果没有死亡动画，等待一小段时间作为死亡延迟
        await get_tree().create_timer(0.2).timeout

# --- 史莱姆对玩家造成伤害 (接触伤害) ---
func _on_DamageZone_body_entered(body):
    if is_dead or not can_deal_damage:
        return
        
    if body.is_in_group("player"): # 确保是玩家
        if body.has_method("take_damage"):
            print(name + " 对玩家造成伤害!")
            body.take_damage(attack_power)
            
            # 播放攻击动画（如果有）
            play_attack_animation()

            # 实现一个简单的伤害冷却，防止持续接触时瞬间多次伤害
            can_deal_damage = false
            await get_tree().create_timer(1.0).timeout # 1秒内不再造成伤害
            if not is_dead:  # 确保史莱姆还活着
                can_deal_damage = true

# 播放攻击动画
func play_attack_animation():
    if not animated_sprite or is_dead:
        return
        
    if animated_sprite.sprite_frames.has_animation("attack"):
        animated_sprite.play("attack")
        # 攻击动画结束后返回idle
        await animated_sprite.animation_finished
        if not is_dead and animated_sprite and animated_sprite.sprite_frames.has_animation("idle"):
            animated_sprite.play("idle")