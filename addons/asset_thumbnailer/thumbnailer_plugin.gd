@tool
extends EditorPlugin

const PANEL_SCENE := "res://addons/asset_thumbnailer/thumbnailer_panel.tscn"
const DEFAULT_OUTPUT := "res://addons/asset_thumbnailer/generated_icons"

var dock: Control
var viewport: SubViewport
var world_root: Node3D
var camera: Camera3D
var key_light: DirectionalLight3D
var fill_light: DirectionalLight3D

var current_instance: Node3D = null
var current_paths: Array[String] = []
var current_index := -1

var preview_zoom := 1.0
var preview_rotation := 0.0
var preview_tilt := -15.0
var preview_yaw := 25.0

var _updating_controls := false


func _enter_tree() -> void:
	dock = load(PANEL_SCENE).instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

	(dock.get_node("%AddFilesButton") as Button).pressed.connect(_on_add_file_pressed)
	(dock.get_node("%AddFolderButton") as Button).pressed.connect(_on_add_folder_pressed)
	(dock.get_node("%ClearBtn") as Button).pressed.connect(_on_clear_pressed)

	(dock.get_node("%PreviousBtn") as Button).pressed.connect(_on_previous_pressed)
	(dock.get_node("%ExportBtn") as Button).pressed.connect(_on_export_pressed)
	(dock.get_node("%NextBtn") as Button).pressed.connect(_on_next_pressed)

	(dock.get_node("%AssetList") as ItemList).item_selected.connect(_on_asset_selected)
	_setup_viewport()
	_setup_ui()

func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
	if is_instance_valid(viewport):
		viewport.queue_free()

func _setup_viewport() -> void:
	viewport = SubViewport.new()
	viewport.name = "ThumbnailViewport"
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.world_3d = World3D.new()
	viewport.world_3d.environment = Environment.new()

	world_root = Node3D.new()
	viewport.add_child(world_root)

	camera = Camera3D.new()
	camera.current = true
	camera.fov = 45.0
	camera.near = 0.01
	camera.far = 1000.0
	world_root.add_child(camera)

	key_light = DirectionalLight3D.new()
	key_light.light_energy = 2.0
	key_light.rotation_degrees = Vector3(-45, -35, 0)
	world_root.add_child(key_light)

	fill_light = DirectionalLight3D.new()
	fill_light.light_energy = 0.75
	fill_light.rotation_degrees = Vector3(35, 145, 0)
	world_root.add_child(fill_light)
	add_child(viewport)

func _setup_ui() -> void:
	var size_option := dock.get_node("%PresetSize") as OptionButton
	if size_option.item_count == 0:
		size_option.add_item("64")
		size_option.add_item("128")
		size_option.add_item("256")
		size_option.add_item("512")
		size_option.select(2)

	var cam_option := dock.get_node("%CameraMode") as OptionButton
	if cam_option.item_count == 0:
		cam_option.add_item("Perspective")
		cam_option.add_item("Orthographic")
		cam_option.select(0)

	(dock.get_node("%TransparentBg") as CheckBox).button_pressed = true
	(dock.get_node("%OutputPath") as LineEdit).text = DEFAULT_OUTPUT
	
	(dock.get_node("%PresetSize") as OptionButton).item_selected.connect(func(_i):
		_refresh_preview()
	)
	(dock.get_node("%CameraMode") as OptionButton).item_selected.connect(func(i):
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL if i == 1 else Camera3D.PROJECTION_PERSPECTIVE
		_refresh_preview()
	)
	(dock.get_node("%TransparentBg") as CheckBox).toggled.connect(func(v):
		viewport.transparent_bg = v
		_refresh_preview()
	)
	(dock.get_node("%BackgroundColor") as ColorPickerButton).color_changed.connect(func(_c):
		_refresh_preview()
	)
	(dock.get_node("%InfoLabel") as Label).visible = false
	(dock.get_node("%ItemListContainer") as VBoxContainer).visible = false
	
	var zoom_slider := dock.get_node("%ZoomSlider") as HSlider
	zoom_slider.min_value = 0.5
	zoom_slider.max_value = 5.0
	zoom_slider.step = 0.05
	zoom_slider.value = preview_zoom
	zoom_slider.value_changed.connect(_on_zoom_changed)
	
	var zoom_value := dock.get_node("%ZoomValue") as SpinBox
	zoom_value.min_value = 50
	zoom_value.max_value = 500
	zoom_value.step = 5
	zoom_value.value = preview_zoom * 100.0
	zoom_value.value_changed.connect(func(v):
		if _updating_controls:
			return
		preview_zoom = v / 100.0
		_sync_controls()
		_refresh_preview() )

	var rotate_slider := dock.get_node("%RotateSlider") as HSlider
	rotate_slider.min_value = -180
	rotate_slider.max_value = 180
	rotate_slider.step = 1
	rotate_slider.value = preview_rotation
	rotate_slider.value_changed.connect(_on_rotate_changed)

	var rotate_value := dock.get_node("%RotateValue") as SpinBox
	rotate_value.min_value = -180
	rotate_value.max_value = 180
	rotate_value.step = 1
	rotate_value.value = preview_rotation
	rotate_value.value_changed.connect(func(v):
		if _updating_controls:
			return
		preview_rotation = v
		_sync_controls()
		_refresh_preview()
	)

	var tilt_slider := dock.get_node("%TiltSlider") as HSlider
	tilt_slider.min_value = -89
	tilt_slider.max_value = 89
	tilt_slider.step = 1
	tilt_slider.value = preview_tilt
	tilt_slider.value_changed.connect(_on_tilt_changed)

	var tilt_value := dock.get_node("%TiltValue") as SpinBox
	tilt_value.min_value = -89
	tilt_value.max_value = 89
	tilt_value.step = 1
	tilt_value.value = preview_tilt
	tilt_value.value_changed.connect(func(v):
		if _updating_controls:
			return
		preview_tilt = v
		_sync_controls()
		_refresh_preview()
	)

	var yaw_slider := dock.get_node("%YawSlider") as HSlider
	yaw_slider.min_value = -180
	yaw_slider.max_value = 180
	yaw_slider.step = 1
	yaw_slider.value = preview_yaw
	yaw_slider.value_changed.connect(_on_yaw_changed)

	var yaw_value := dock.get_node("%YawValue") as SpinBox
	yaw_value.min_value = -180
	yaw_value.max_value = 180
	yaw_value.step = 1
	yaw_value.value = preview_yaw
	yaw_value.value_changed.connect(func(v):
		if _updating_controls:
			return
		preview_yaw = v
		_sync_controls()
		_refresh_preview()
	)

	var preview := dock.get_node("%PreviewImage") as TextureRect
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	var asset_list := dock.get_node("%AssetList") as ItemList
	asset_list.select_mode = ItemList.SELECT_SINGLE
	asset_list.allow_reselect = true
	_update_slider_labels()
	_update_item_counter()
	_update_navigation_buttons()

func _update_slider_labels() -> void:
	_updating_controls = true
	(dock.get_node("%ZoomValue") as SpinBox).value = preview_zoom * 100.0
	(dock.get_node("%TiltValue") as SpinBox).value = preview_tilt
	(dock.get_node("%YawValue") as SpinBox).value = preview_yaw
	(dock.get_node("%RotateValue") as SpinBox).value = preview_rotation
	_updating_controls = false

func _update_item_counter() -> void:
	if current_paths.is_empty():
		(dock.get_node("%ItemCounter") as Label).text = "0 / 0"
	else:
		(dock.get_node("%ItemCounter") as Label).text = "%d / %d" % [
			current_index + 1,
			current_paths.size()
		]

func _update_navigation_buttons() -> void:
	(dock.get_node("%PreviousBtn") as Button).disabled = current_index <= 0
	(dock.get_node("%NextBtn") as Button).disabled = current_index >= current_paths.size() - 1

func _sync_controls() -> void:
	_updating_controls = true
	(dock.get_node("%ZoomSlider") as HSlider).value = preview_zoom
	(dock.get_node("%ZoomValue") as SpinBox).value = preview_zoom * 100.0
	(dock.get_node("%RotateSlider") as HSlider).value = preview_rotation
	(dock.get_node("%RotateValue") as SpinBox).value = preview_rotation
	(dock.get_node("%TiltSlider") as HSlider).value = preview_tilt
	(dock.get_node("%TiltValue") as SpinBox).value = preview_tilt
	(dock.get_node("%YawSlider") as HSlider).value = preview_yaw
	(dock.get_node("%YawValue") as SpinBox).value = preview_yaw
	_updating_controls = false

func _normalize_instance_scale(instance: Node3D) -> void:
	var bounds := _get_combined_aabb(instance)
	var largest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest <= 0.0001:
		return
	var target_size := 2.0
	var scale_factor := target_size / largest
	instance.scale *= scale_factor

func _center_instance(instance: Node3D) -> void:
	var bounds := _get_combined_aabb(instance)
	var center := bounds.position + bounds.size * 0.5
	instance.global_position -= center
	
func _refresh_preview() -> void:
	if current_instance == null:
		return
	current_instance.rotation_degrees.y = preview_rotation
	# Viewport size
	var size_option := dock.get_node("%PresetSize") as OptionButton
	if size_option.selected >= 0:
		var size := int(size_option.get_item_text(size_option.selected))
		viewport.size = Vector2i(size, size)
	# Transparency toggle
	var transparent := (dock.get_node("%TransparentBg") as CheckBox).button_pressed
	var bg_picker := dock.get_node("%BackgroundColor") as ColorPickerButton
	var env := viewport.world_3d.environment
	if transparent:
		env.background_mode = Environment.BG_CLEAR_COLOR
	else:
		env.background_mode = Environment.BG_COLOR
		env.background_color = bg_picker.color
	var cam_option := dock.get_node("%CameraMode") as OptionButton
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if cam_option.selected == 1 else Camera3D.PROJECTION_PERSPECTIVE
	var bounds := _get_combined_aabb(current_instance)
	_position_camera(bounds)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_draw()
	_update_preview()
	
	
func _on_add_file_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray([
		"*.tscn ; Scene",
		"*.scn ; Binary Scene",
		"*.glb ; GLB",
		"*.gltf ; GLTF",
		"*.fbx ; FBX",
		"*.blend ; Blender",
		"*.mesh ; Mesh"
	])
	dialog.file_selected.connect(_on_file_selected)
	dock.add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func _on_add_folder_pressed() -> void:
	var dialog := FileDialog.new()
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.dir_selected.connect(_on_folder_selected)
	dock.add_child(dialog)
	dialog.popup_centered_ratio(0.7)

func _on_clear_pressed() -> void:
	(dock.get_node("%AssetList") as ItemList).clear()
	current_paths.clear()
	current_index = -1
	if current_instance:
		current_instance.queue_free()
		current_instance = null
	(dock.get_node("%PreviewImage") as TextureRect).texture = null
	(dock.get_node("%ItemListContainer") as Control).visible = false
	_update_item_counter()
	_update_navigation_buttons()

func _on_file_selected(path: String) -> void:
	var list := dock.get_node("%AssetList") as ItemList
	list.clear()
	list.add_item(path)
	current_paths = [path]
	(dock.get_node("%ItemListContainer") as Control).visible = false
	current_index = 0
	list.select(0)
	_load_preview(path)
	_update_item_counter()
	_update_navigation_buttons()

func _on_folder_selected(folder: String) -> void:
	var list := dock.get_node("%AssetList") as ItemList
	list.clear()
	current_paths.clear()
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var file_name := dir.get_next()
		if file_name == "":
			break
		if dir.current_is_dir():
			continue
		var lower := file_name.to_lower()
		if lower.ends_with(".tscn") \
		or lower.ends_with(".scn") \
		or lower.ends_with(".glb") \
		or lower.ends_with(".gltf") \
		or lower.ends_with(".fbx") \
		or lower.ends_with(".blend") \
		or lower.ends_with(".mesh"):
			var path := folder.path_join(file_name)
			current_paths.append(path)
			list.add_item(path)
	dir.list_dir_end()
	(dock.get_node("%ItemListContainer") as Control).visible = current_paths.size() > 1
	if not current_paths.is_empty():
		current_index = 0
		list.select(0)
		_load_preview(current_paths[0])
	
	_update_item_counter()
	_update_navigation_buttons()

func _on_asset_selected(index: int) -> void:
	print("asset select")
	current_index = index
	_update_item_counter()
	_update_navigation_buttons()
	var path := current_paths[index]
	_load_preview(path)

func _load_preview(path: String) -> void:
	print("Load preview")
	if current_instance:
		current_instance.queue_free()
		current_instance = null
		get_tree().process_frame
	preview_zoom = 1.0
	preview_rotation = 0.0
	preview_tilt = -15.0
	preview_yaw = 0.0

	_sync_controls()
	var resource := ResourceLoader.load(path)
	if resource == null:
		push_error("Failed to load resource: %s" % path)
		return
	if resource is PackedScene:
		var packed := resource as PackedScene
		var node := packed.instantiate()
		if node is Node3D:
			current_instance = node as Node3D
	elif resource is Mesh:
		var mesh_instance := MeshInstance3D.new()
		mesh_instance.mesh = resource as Mesh
		current_instance = mesh_instance
	if current_instance == null:
		push_error("Resource is not a Node3D or Mesh: %s" % path)
		return
	world_root.add_child(current_instance)
	current_instance.transform = Transform3D.IDENTITY
	_normalize_instance_scale(current_instance) 
	_center_instance(current_instance)
	current_instance.rotation_degrees.y = preview_rotation
	var size_option := dock.get_node("%PresetSize") as OptionButton
	if size_option.selected == -1 and size_option.item_count > 0:
		size_option.select(0)
	var selected_size := 256
	if size_option.selected >= 0:
		selected_size = int(size_option.get_item_text(size_option.selected))
		viewport.size = Vector2i(selected_size, selected_size)
	
	viewport.transparent_bg = (dock.get_node("%TransparentBg") as CheckBox).button_pressed
	var cam_option := dock.get_node("%CameraMode") as OptionButton
	if cam_option.selected == -1 and cam_option.item_count > 0:
		cam_option.select(0)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if cam_option.selected == 1 else Camera3D.PROJECTION_PERSPECTIVE
	var bounds := _get_combined_aabb(current_instance)
	_position_camera(bounds)
	
	await RenderingServer.frame_post_draw
	_refresh_preview()	

func _update_preview() -> void:
	var texture := viewport.get_texture()
	if texture == null:
		return
	var image := texture.get_image()
	var tex := ImageTexture.create_from_image(image)
	(dock.get_node("%PreviewImage") as TextureRect).texture = tex
	dock.queue_redraw()

func _show_info(text: String, is_error := false) -> void:
	var label := dock.get_node("%InfoLabel") as Label
	label.text = text
	label.visible = true
	label.modulate = Color(1, 0.4, 0.4) if is_error else Color(0.4, 1, 0.4)
	var id := Time.get_ticks_msec()
	label.set_meta("info_id", id)
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		if label.get_meta("info_id") == id:
			label.visible = false
	)

func _on_zoom_changed(value: float) -> void:
	if _updating_controls:
		return
	preview_zoom = value
	_sync_controls()
	_refresh_preview()

func _on_rotate_changed(value: float) -> void:
	if _updating_controls:
		return
	preview_rotation = value
	_sync_controls()
	_refresh_preview()

func _on_tilt_changed(value: float) -> void:
	if _updating_controls:
		return
	preview_tilt = value
	_sync_controls()
	_refresh_preview()

func _on_yaw_changed(value: float) -> void:
	if _updating_controls:
		return
	preview_yaw = value
	_sync_controls()
	_refresh_preview()

func _on_previous_pressed() -> void:
	if current_index <= 0:
		return
	current_index -= 1
	var list := dock.get_node("%AssetList") as ItemList
	list.deselect_all()
	list.select(current_index)
	_update_item_counter()
	_update_navigation_buttons()
	_load_preview(current_paths[current_index])

func _on_next_pressed() -> void:
	if current_index >= current_paths.size() - 1:
		return
	current_index += 1
	var list := dock.get_node("%AssetList") as ItemList
	list.deselect_all()
	list.select(current_index)
	_update_item_counter()
	_update_navigation_buttons()
	_load_preview(current_paths[current_index])


func _on_export_pressed() -> void:
	if current_instance == null or current_index < 0:
		return
	var output_path := (dock.get_node("%OutputPath") as LineEdit).text.strip_edges()
	if output_path.is_empty():
		output_path = DEFAULT_OUTPUT
	if not DirAccess.dir_exists_absolute(output_path):
		DirAccess.make_dir_recursive_absolute(output_path)
	RenderingServer.force_draw()
	var image := viewport.get_texture().get_image()
	var current_path := current_paths[current_index]
	var name_input := (dock.get_node("%FileNameInput") as LineEdit).text.strip_edges()
	var file_name := name_input if name_input != "" else current_path.get_file().get_basename()
	var save_path := output_path.path_join(file_name + ".png")
	
	var err := image.save_png(save_path)
	if err == OK:
		print("Saved: ", save_path)
		_show_info("✅ Exported: " + save_path.get_file())
		if current_index < current_paths.size() - 1:
			current_index += 1
			var list := dock.get_node("%AssetList") as ItemList
			list.deselect_all()
			list.select(current_index)
			_update_item_counter()
			_update_navigation_buttons()
			_load_preview(current_paths[current_index])
	else:
		_show_info("❌ Failed to export", true)
		push_error("Failed to save: %s" % save_path)


func _position_camera(bounds: AABB) -> void:
	var center := bounds.position + bounds.size * 0.5
	var largest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if largest < 0.01:
		largest = 1.0
	var distance: float
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		camera.size = largest * 1.3 / preview_zoom
		distance = largest * 2.2 / preview_zoom
	else:
		distance = (largest * 0.5) / tan(deg_to_rad(camera.fov) * 0.5)
		distance *= 1.4 / preview_zoom
	var tilt_rad := deg_to_rad(preview_tilt)
	camera.position = center + Vector3( 0.0, -sin(tilt_rad) * distance, cos(tilt_rad) * distance )
	camera.look_at(center, Vector3.UP)
	camera.rotation.z = deg_to_rad(preview_yaw)


func _get_combined_aabb(root: Node) -> AABB:
	var combined := AABB()
	var has_bounds := false
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var current := stack.pop_back()
		if current is MeshInstance3D:
			var mesh_instance := current as MeshInstance3D
			if mesh_instance.mesh:
				var aabb := mesh_instance.get_aabb()
				var transform := mesh_instance.global_transform
				var corners := [
					transform * aabb.position,
					transform * (aabb.position + Vector3(aabb.size.x, 0, 0)),
					transform * (aabb.position + Vector3(0, aabb.size.y, 0)),
					transform * (aabb.position + Vector3(0, 0, aabb.size.z)),
					transform * (aabb.position + Vector3(aabb.size.x, aabb.size.y, 0)),
					transform * (aabb.position + Vector3(aabb.size.x, 0, aabb.size.z)),
					transform * (aabb.position + Vector3(0, aabb.size.y, aabb.size.z)),
					transform * (aabb.position + aabb.size)
				]
				for point in corners:
					if not has_bounds:
						combined = AABB(point, Vector3.ZERO)
						has_bounds = true
					else:
						combined = combined.expand(point)
		for child in current.get_children():
			if child is Node:
				stack.append(child)
	if not has_bounds:
		combined = AABB(Vector3(-0.5, -0.5, -0.5), Vector3.ONE)
	return combined
