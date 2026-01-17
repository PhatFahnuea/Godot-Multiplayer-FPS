extends CharacterBody3D

signal health_changed(health_value)

@onready var camera = $Camera3D
@onready var anim_player = $Soldier/AnimationPlayer
@onready var raycast = $Camera3D/RayCast3D


var health = 3
var is_dead = false
var is_wave_playing = false
const SPEED = 10.0
const JUMP_VELOCITY = 10.0

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 20.0

func _enter_tree():
	set_multiplayer_authority(str(name).to_int())

func _ready():
	if not is_multiplayer_authority(): return
	anim_player.play("CharacterArmature|Idle_Gun_Pointing")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	if is_dead == false:
		if Input.is_action_just_pressed("shoot") \
				and anim_player.current_animation != "shoot":
			play_shoot_effects.rpc()
			if raycast.is_colliding():
				var hit_player = raycast.get_collider()
				hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())

func play_wave_animation() -> void:
	is_wave_playing = false


func _physics_process(delta):
	if is_dead == false:
		if is_wave_playing == false:
			is_wave_playing = false
			if not is_multiplayer_authority(): return
			# Add the gravity.
			if not is_on_floor():
				velocity.y -= gravity * delta

	# Handle Jump.
			if Input.is_action_just_pressed("ui_accept") and is_on_floor():
				velocity.y = JUMP_VELOCITY

		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
			var input_dir = Input.get_vector("left", "right", "up", "down")
			var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			if direction:
				velocity.x = direction.x * SPEED
				velocity.z = direction.z * SPEED
				if anim_player.current_animation != "Run_Shoot":
					$Run.play()
					anim_player.play("CharacterArmature|Run_Shoot")
					rpc("sync_animation", "CharacterArmature|Run_Shoot")
					rpc("sync_sound", true)  # Play the sound for all peers

			else:
				velocity.x = move_toward(velocity.x, 0, SPEED)
				velocity.z = move_toward(velocity.z, 0, SPEED)
				if anim_player.current_animation != "Idle_Gun_Pointing":
					$Run.stop()
					rpc("sync_sound", false)  # Stop the sound for all peers
					anim_player.play("CharacterArmature|Idle_Gun_Pointing")
					rpc("sync_animation", "CharacterArmature|Idle_Gun_Pointing")

			move_and_slide()


@rpc("any_peer")
func sync_animation(animation_name: String):
	anim_player.play(animation_name)


@rpc("any_peer")
func sync_sound(play: bool):
	if play:
		if not $Run.is_playing():
			$Run.play()
	else:
		if $Run.is_playing():
			$Run.stop()
			
func setName(s):
	$Label3D.text = s
		
		
@rpc("call_local")
func play_shoot_effects():
	if is_dead == false:
		anim_player.stop()
		anim_player.play("CharacterArmature|Gun_Shoot")
		$Gun.play()


@rpc("any_peer")
func receive_damage():
	if is_dead:     
		return
	health -= 1 
	health_changed.emit(health)
	if health <= 0:        
		is_dead = true  
		hide()
		handle_death() 
		rpc("player_died")  # Notify all peers that this player has died


@rpc("any_peer")
func player_died():    
	if is_dead:        
		return      
	handle_death()  # Call handle_death to play the death animation

func handle_death():
	if anim_player.current_animation != "CharacterArmature|Death":       
		anim_player.play("CharacterArmature|Death")
		rpc("sync_animation", "CharacterArmature|Death")   
	anim_player.connect("animation_finished", Callable(self, "_on_death_animation_finished"))

func _on_death_animation_finished(anim_name):   
	if anim_name == "CharacterArmature|Death":
		# Schedule respawn after 3 seconds        
		get_tree().create_timer(10.0).connect("timeout", Callable(self, "_respawn"))


func _respawn() -> void:
	health = 3    
	position = Vector3.ZERO  # Reset position  
	show()  # Show player
	is_dead = false    
	anim_player.play("CharacterArmature|Idle_Gun_Pointing")    
	health_changed.emit(health)



func _on_animation_player_animation_finished(anim_name):
	if is_dead == false:
		if anim_name == "CharacterArmature|Wave":
			is_wave_playing = false
			
	
		if anim_name == "shoot":
			anim_player.play("CharacterArmature|Idle_Gun_Pointing")
			$Gun.stop()
