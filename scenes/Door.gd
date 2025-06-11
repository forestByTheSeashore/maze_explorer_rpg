# Door.gd
extends StaticBody2D

# -----------------------------------------------------------------------------
# Node References
# -----------------------------------------------------------------------------
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

# -----------------------------------------------------------------------------
# Export Variables: Define door type in editor (Important!)
# -----------------------------------------------------------------------------
enum DoorType { ENTRANCE, EXIT } # Door type enumeration
@export var type: DoorType = DoorType.ENTRANCE # Default is entrance door, can be changed in inspector
@export var requires_key: bool = false  # Whether a key is required
@export var required_key_type: String = "master_key"  # Type of key required
@export var consume_key_on_open: bool = true  # Whether to consume key when opening

# -----------------------------------------------------------------------------
# Door State Variables
# -----------------------------------------------------------------------------
var is_open: bool = false
var is_transitioning: bool = false # Prevent repeated triggers or animation interruption

# -----------------------------------------------------------------------------
# Signals
# -----------------------------------------------------------------------------
signal door_opened
signal door_closed

# -----------------------------------------------------------------------------
# _ready() Function
# -----------------------------------------------------------------------------
func _ready():
    # Debug: Check if nodes are correctly referenced
    if animated_sprite == null:
        push_error("Error: AnimatedSprite2D node not found for Door.gd!")
        return
    if collision_shape == null:
        push_error("Error: CollisionShape2D node not found for Door.gd!")
        return

    # Ensure AnimatedSprite2D animation_finished signal is connected only once
    if not animated_sprite.animation_finished.is_connected(on_animation_finished):
        animated_sprite.animation_finished.connect(on_animation_finished)

    # Set initial state based on door type (Important adjustment!)
    if type == DoorType.ENTRANCE:
        # Entrance door: Initially open (show last frame of open animation), no collision
        if animated_sprite.sprite_frames.has_animation("door_open"):
            animated_sprite.play("door_open")
            animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("door_open") - 1
            animated_sprite.stop() # Stop at the last frame of open animation
            #print("Entrance Door initialized to OPEN state.")
        else:
            push_error("Error: 'door_open' animation not found for Entrance Door!")
        
        is_open = true # Initial state is open
        collision_shape.disabled = true # No collision when open

    elif type == DoorType.EXIT:
        # Exit door: Initially closed (show last frame of close animation), has collision
        if animated_sprite.sprite_frames.has_animation("door_close"):
            animated_sprite.play("door_close")
            animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("door_close") - 1
            animated_sprite.stop() # Stop at the last frame of close animation
            #print("Exit Door initialized to CLOSED state.")
        else:
            push_error("Error: 'door_close' animation not found for Exit Door!")

        is_open = false # Initial state is closed
        collision_shape.disabled = false # Has collision when closed

    is_transitioning = false # Initially no animation playing

    # -----------------------------------------------------------------------------
    # Adjust Sprite and Collision Shape Alignment (Based on 18x32 pixel tiles, this part remains unchanged)
    # -----------------------------------------------------------------------------
    animated_sprite.offset = Vector2(-1, -16) 
    if collision_shape.shape == null or not (collision_shape.shape is RectangleShape2D):
        collision_shape.shape = RectangleShape2D.new()
    (collision_shape.shape as RectangleShape2D).extents = Vector2(9, 16)
    collision_shape.position = Vector2(8, 0)


# -----------------------------------------------------------------------------
# Public Function: Open Door (Behavior adjusted based on door type)
# -----------------------------------------------------------------------------
func open_door():
    if type == DoorType.ENTRANCE:
        # Entrance door should not execute open action, only close action
        # print("Entrance Door: open_door() called, but it only closes.")
        return 

    # Following is the exit door open logic
    if is_open or is_transitioning:
        # print("Exit Door: open_door() ignored (already open or transitioning).")
        return 
    
    is_transitioning = true
    if animated_sprite.sprite_frames.has_animation("door_open"):
        animated_sprite.play("door_open")
        # print("Exit Door: Playing 'door_open' animation.")
    else:
        push_error("Error: 'door_open' animation not found for Exit Door!")
        is_transitioning = false 

    collision_shape.disabled = true # Immediately disable collision when door opens

# -----------------------------------------------------------------------------
# Public Function: Close Door (Behavior adjusted based on door type)
# -----------------------------------------------------------------------------
func close_door():
    if type == DoorType.EXIT:
        # Exit door should not execute close action, only open action
        # print("Exit Door: close_door() called, but it only opens.")
        return 

    # Following is the entrance door close logic
    if not is_open or is_transitioning:
        # print("Entrance Door: close_door() ignored (already closed or transitioning).")
        return 
    
    is_transitioning = true
    if animated_sprite.sprite_frames.has_animation("door_close"):
        animated_sprite.play("door_close")
        # print("Entrance Door: Playing 'door_close' animation.")
    else:
        push_error("Error: 'door_close' animation not found for Entrance Door!")
        is_transitioning = false 

# -----------------------------------------------------------------------------
# Private Callback Function: Triggered when animation finishes playing
# -----------------------------------------------------------------------------
func on_animation_finished():
    is_transitioning = false 
    
    if animated_sprite.animation == "door_open":
        is_open = true
        animated_sprite.stop() 
        animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("door_open") - 1
        # print("Door (open animation finished).")
        door_opened.emit() 

    elif animated_sprite.animation == "door_close":
        is_open = false
        animated_sprite.stop()
        animated_sprite.frame = animated_sprite.sprite_frames.get_frame_count("door_close") - 1
        collision_shape.disabled = false # Re-enable collision after close animation completes
        # print("Door (close animation finished).")
        door_closed.emit() 


# -----------------------------------------------------------------------------
# Public Function: Interact (Execute only allowed actions based on door type)
# -----------------------------------------------------------------------------
# Modified interact() function
func interact():
    match type:
        DoorType.ENTRANCE:
            # Entrance door logic remains unchanged
            close_door()
        
        DoorType.EXIT:
            # Exit door needs to check for key
            if requires_key:
                _try_open_locked_door()
            else:
                open_door()


# New: Try to open a locked door
func _try_open_locked_door():
    # Find player
    var player = get_tree().get_first_node_in_group("player")
    if not player:
        print("Error: Player node not found")
        return
    
    # Check if player has required key
    if player.has_method("has_key") and player.has_key(required_key_type):
        print("Player has key, opening door...")
        
        # Show key usage notification
        var notification_manager = get_node_or_null("/root/NotificationManager")
        if notification_manager:
            notification_manager.notify_key_used(required_key_type)
        
        # Use key (if set to consume)
        if consume_key_on_open:
            if player.has_method("use_key"):
                player.use_key(required_key_type)
                print("Key has been used")
        
        # Open door
        open_door()
        
        # Show door opened notification
        if notification_manager:
            notification_manager.notify_door_opened()
        
    else:
        # Player doesn't have key
        print("This door is locked, requires", required_key_type, "to open")
        
        # Show door locked notification
        var notification_manager = get_node_or_null("/root/NotificationManager")
        if notification_manager:
            notification_manager.notify_key_required(required_key_type)
        
        _play_locked_door_feedback()

# New: Locked door feedback effects
func _play_locked_door_feedback():
    # Play locked door sound
    var audio_manager = get_node_or_null("/root/AudioManager")
    if audio_manager:
        audio_manager.play_door_locked_sound()
    
    # Play locked door sound or animation
    if animated_sprite:
        # Simple shake effect to indicate door is locked
        var original_position = animated_sprite.position
        var tween = create_tween()
        tween.tween_property(animated_sprite, "position:x", original_position.x + 2, 0.1)
        tween.tween_property(animated_sprite, "position:x", original_position.x - 2, 0.1)
        tween.tween_property(animated_sprite, "position:x", original_position.x, 0.1)