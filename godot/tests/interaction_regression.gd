extends SceneTree
var game: Node3D
var checks: Dictionary = {}
var output := ""
func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--evidence-dir="): output=arg.trim_prefix("--evidence-dir=")
    if output.is_empty(): quit(2); return
    run.call_deferred()
func tick(count: int) -> void:
    for i in count: await physics_frame
    await process_frame
func run() -> void:
    game=load("res://main.tscn").instantiate()
    root.add_child(game)
    await tick(5)
    game.start_expedition()
    game._set_phase("exploring")
    game.rover.set_driving_enabled(false)
    game.rover.set_camera_mode("first_person")
    game.world.set_process(false)
    var center: Vector3=game.world.signal_origin()
    var position := Vector3(center.x,game.world.height_at(center.x,center.z+12.0)+0.05,center.z+12.0)
    game.rover.global_position=position
    game.rover.heading=0.0
    game.rover.rotation=Vector3.ZERO
    var organism: Node3D=game.world._ecology_nodes[0]
    var original := organism.global_position
    organism.global_position=position+Vector3(0,0.1,-4.0)
    await tick(3)
    game.interact()
    checks.ecology_near_signal_cannot_bypass_contact_range=game.phase=="exploring" and game.transmit_count==0 and game.observed_ecology.size()==1
    game.contact.reset()
    game.transmit_count=0
    game.observed_ecology.clear()
    game._set_phase("exploring")
    var wall := StaticBody3D.new()
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size=Vector3(5,5,0.5)
    shape.shape=box
    wall.add_child(shape)
    root.add_child(wall)
    wall.position=position+Vector3(0,1.5,-2.0)
    await tick(3)
    game.interact()
    checks.occluded_targets_do_not_scan_or_transmit=game.transmit_count==0 and game.observed_ecology.is_empty()
    wall.queue_free()
    await tick(3)
    organism.global_position=original
    game.world.set_process(true)
    game.start_expedition()
    await tick(12)
    game.pause_expedition()
    var clock: float=game.world._world_time
    var before: Vector3=organism.position
    await tick(25)
    checks.pause_freezes_ecology=game.world._world_time==clock and organism.position.is_equal_approx(before)
    game.resume_expedition()
    await tick(10)
    checks.resume_animates_ecology=game.world._world_time>clock
    game.world.observe_ecology(organism.global_position)
    game.reset_expedition()
    checks.reset_clears_all_observations=game.world._observed_regions.is_empty() and game.observed_ecology.is_empty()
    checks.audio_layers_loaded=game.audio._players.size()==6
    game.audio.set_drive(4.0)
    checks.audio_uses_new_cruise_speed=is_equal_approx(game.audio._drive,0.5)
    var ok: bool=true
    for value in checks.values():
        if not value: ok=false
    DirAccess.make_dir_recursive_absolute(output)
    var f:=FileAccess.open(output.path_join("interaction.json"),FileAccess.WRITE)
    var result: Dictionary={"passed":ok,"checks":checks,"kind":"native_adversarial_fixture_not_full_journey"}
    f.store_string(JSON.stringify(result,"  "));f.close()
    print("INTERACTION_REGRESSION "+JSON.stringify(result))
    game.queue_free()
    await create_timer(0.4).timeout
    quit(0 if ok else 1)
