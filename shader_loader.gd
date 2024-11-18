extends Control

@export_file("*.glsl") var shader_file: String
@export_range(128, 4096, 1, "exp") var dimension: int = 512
@export_range(0.016, 2.0) var update_interval: float = 0.03

var rd: RenderingDevice
var shader_rid: RID
var current_state_rid: RID
var next_state_rid: RID
var uniform_set: RID
var pipeline: RID
var texture_rect: TextureRect
var speed_slider: HSlider
var fps_label: Label
var play_button: Button
var time_since_last_update: float = 0.0
var simulation_running: bool = true
var current_image: Image
var brush_size: int = 1
var cell_size: int = 4
var is_drawing: bool = false
var is_erasing: bool = false
var display_dimension: int = 512
var fps_counter_label: Label
var frame_time: float = 0.0
var frame_count: int = 0
var unlimited_fps: bool = false
var fps_update_interval: float = 0.5
var simulation_speed: float = 10.0

func _ready() -> void:
	setup_ui()
	init_gpu()
	init_game()
	set_process(true)
	set_process_input(true)
	get_tree().get_root().size_changed.connect(_on_cell_size_changed.bind(cell_size)) 
	_on_speed_changed(30)

func setup_ui() -> void:
	var vbox := VBoxContainer.new()
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	var controls := HBoxContainer.new()
	vbox.add_child(controls)
	play_button = Button.new()
	controls.add_child(play_button)
	play_button.text = "Pause"
	play_button.custom_minimum_size.x = 100
	play_button.pressed.connect(_on_play_button_pressed)
	var speed_label := Label.new()
	controls.add_child(speed_label)
	speed_label.text = "Speed:"
	speed_slider = HSlider.new()
	controls.add_child(speed_slider)
	speed_slider.custom_minimum_size.x = 200
	speed_slider.min_value = 1
	speed_slider.max_value = 90
	speed_slider.value = 30
	speed_slider.value_changed.connect(_on_speed_changed)
	fps_label = Label.new()
	controls.add_child(fps_label)
	fps_label.text = "30 FPS"
	var reset_button := Button.new()
	controls.add_child(reset_button)
	reset_button.text = "Reset"
	reset_button.custom_minimum_size.x = 100
	reset_button.pressed.connect(_on_reset_pressed)
	var brush_label := Label.new()
	controls.add_child(brush_label)
	brush_label.text = "Brush Size:"
	var brush_slider := HSlider.new()
	controls.add_child(brush_slider)
	brush_slider.custom_minimum_size.x = 100
	brush_slider.min_value = 1
	brush_slider.max_value = 50
	brush_slider.value = brush_size
	brush_slider.value_changed.connect(func(value): brush_size = int(value))
	var cell_label := Label.new()
	controls.add_child(cell_label)
	cell_label.text = "Cell Size:"
	var cell_slider := HSlider.new()
	controls.add_child(cell_slider)
	cell_slider.custom_minimum_size.x = 100
	cell_slider.min_value = 1
	cell_slider.max_value = 10
	cell_slider.value = cell_size
	cell_slider.value_changed.connect(_on_cell_size_changed)
	texture_rect = TextureRect.new()
	vbox.add_child(texture_rect)
	texture_rect.custom_minimum_size = Vector2(display_dimension, display_dimension)
	texture_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texture_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.gui_input.connect(_on_texture_gui_input)
	var fps_container := HBoxContainer.new()
	controls.add_child(fps_container)
	fps_counter_label = Label.new()
	fps_container.add_child(fps_counter_label)
	fps_counter_label.text = "FPS: 0"
	var unlimited_checkbox := CheckBox.new()
	fps_container.add_child(unlimited_checkbox)
	unlimited_checkbox.text = "Unlimited FPS"
	unlimited_checkbox.pressed.connect(func(): 
		unlimited_fps = unlimited_checkbox.button_pressed
		if unlimited_fps:
			Engine.max_fps = 0
		else:
			Engine.max_fps = int(simulation_speed)
		)

func _on_cell_size_changed(value: float) -> void:
	cell_size = int(value)
	var screen_size = get_viewport().get_visible_rect().size
	display_dimension = mini(screen_size.x, screen_size.y)
	texture_rect.custom_minimum_size = Vector2(display_dimension, display_dimension)
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func update_display() -> void:
	if current_image:
		texture_rect.texture = ImageTexture.create_from_image(current_image)
		texture_rect.custom_minimum_size = Vector2(dimension * cell_size, dimension * cell_size)

func _on_texture_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			is_drawing = event.pressed
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_erasing = event.pressed
	elif event is InputEventMouseMotion and (is_drawing or is_erasing):
		var tex_size = texture_rect.size
		var local_pos = event.position
		var tex_scale = Vector2(dimension, dimension) / tex_size
		var pixel_pos = local_pos * tex_scale
		draw_at_position(pixel_pos, is_erasing)

func draw_at_position(pos: Vector2, erase: bool = false) -> void:
	if not current_image:
		current_image = Image.create_from_data(dimension, dimension, false, Image.FORMAT_RGBA8, 
			rd.texture_get_data(current_state_rid, 0))
	for y in range(-brush_size, brush_size + 1):
		for x in range(-brush_size, brush_size + 1):
			var draw_pos = Vector2i(pos) + Vector2i(x, y)
			if draw_pos.x >= 0 and draw_pos.x < dimension and draw_pos.y >= 0 and draw_pos.y < dimension:
				if x * x + y * y <= brush_size * brush_size:
					if erase:
						current_image.set_pixelv(draw_pos, Color(0, 0, 0, 0))
					else:
						current_image.set_pixelv(draw_pos, Color(0, 0.5, 1, 1))
	rd.texture_update(current_state_rid, 0, current_image.get_data())
	update_display()

func _on_play_button_pressed() -> void:
	simulation_running = !simulation_running
	play_button.text = "Pause" if simulation_running else "Play"
	
func _on_speed_changed(value: float) -> void:
	simulation_speed = value
	update_interval = 1.0 / value if !unlimited_fps else 0.0
	fps_label.text = "%d FPS" % value
	if !unlimited_fps:
		Engine.max_fps = int(value)

func _on_reset_pressed() -> void:
	init_game(true)

func init_gpu() -> void:
	rd = RenderingServer.create_local_rendering_device()
	if rd == null:
		push_error("Couldn't create local RenderingDevice")
		return
	shader_rid = load_shader(rd, shader_file)
	var format := RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM  # Changed from R8_UNORM
	format.width = dimension
	format.height = dimension
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
					   RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
					   RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	current_state_rid = rd.texture_create(format, RDTextureView.new())
	next_state_rid = rd.texture_create(format, RDTextureView.new())
	var current_uniform := RDUniform.new()
	current_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	current_uniform.binding = 0
	current_uniform.add_id(current_state_rid)
	var next_uniform := RDUniform.new()
	next_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	next_uniform.binding = 1
	next_uniform.add_id(next_state_rid)
	uniform_set = rd.uniform_set_create([current_uniform, next_uniform], shader_rid, 0)
	pipeline = rd.compute_pipeline_create(shader_rid)

func init_game(empty: bool = false) -> void:
	var initial_state := PackedByteArray()
	initial_state.resize(dimension * dimension * 4)
	
	if empty:
		initial_state.fill(0)
	else:
		# Random initialization
		for i in range(0, initial_state.size(), 4):
			if randf() < 0.3:
				initial_state[i] = 0
				initial_state[i+1] = 128
				initial_state[i+2] = 255
				initial_state[i+3] = 255
			else:
				initial_state[i] = 0
				initial_state[i+1] = 0
				initial_state[i+2] = 0
				initial_state[i+3] = 0
	
	rd.texture_update(current_state_rid, 0, initial_state)
	current_image = null

func _process(delta: float) -> void:
	# FPS counter logic
	frame_time += delta
	frame_count += 1
	
	if frame_time >= fps_update_interval:
		var fps = frame_count / frame_time
		fps_counter_label.text = "FPS: %d" % fps
		frame_time = 0.0
		frame_count = 0
	
	# Game logic
	if !simulation_running:
		return
		
	if unlimited_fps:
		update_simulation(delta)  # Run every frame when unlimited
	else:
		time_since_last_update += delta
		if time_since_last_update >= update_interval:
			time_since_last_update = 0.0
			update_simulation(delta)

func update_simulation(_delta: float) -> void:
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, dimension / 8, dimension / 8, 1)
	rd.compute_list_end()
	rd.submit()
	rd.sync()
	var output_bytes := rd.texture_get_data(next_state_rid, 0)
	var result_image := Image.create_from_data(dimension, dimension, false, Image.FORMAT_RGBA8, output_bytes)
	current_image = result_image
	update_display()
	var temp_rid := current_state_rid
	current_state_rid = next_state_rid
	next_state_rid = temp_rid
	var current_uniform := RDUniform.new()
	current_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	current_uniform.binding = 0
	current_uniform.add_id(current_state_rid)
	var next_uniform := RDUniform.new()
	next_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	next_uniform.binding = 1
	next_uniform.add_id(next_state_rid)
	uniform_set = rd.uniform_set_create([current_uniform, next_uniform], shader_rid, 0)
	
func load_shader(p_rd: RenderingDevice, path: String) -> RID:
	var shader_file_data: RDShaderFile = load(path)
	var shader_spirv: RDShaderSPIRV = shader_file_data.get_spirv()
	return p_rd.shader_create_from_spirv(shader_spirv)

func _exit_tree() -> void:
	if rd == null:
		return
	rd.free_rid(pipeline)
	rd.free_rid(uniform_set)
	rd.free_rid(current_state_rid)
	rd.free_rid(next_state_rid)
	rd.free_rid(shader_rid)
	rd.free()
