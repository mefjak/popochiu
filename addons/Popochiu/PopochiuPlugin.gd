tool
extends EditorPlugin

# TODO: Que este directorio se pueda seleccionar cuando se instala el plugin por
#		primera vez
const BASE_DIR := 'res://popochiu'
const MAIN_DOCK_PATH := 'res://addons/Popochiu/Editor/MainDock/PopochiuDock.tscn'
const EMPTY_DOCK_PATH := 'res://addons/Popochiu/Editor/MainDock/EmptyDock.tscn'
const UTILS_SNGL = 'res://addons/Popochiu/Engine/Others/Utils.gd'
const CURSOR_SNGL = 'res://addons/Popochiu/Engine/Cursor/Cursor.tscn'
const POPOCHIU_SNGL = 'res://addons/Popochiu/Engine/Popochiu.tscn'
const ICHARACTER_SNGL = 'res://addons/Popochiu/Engine/Interfaces/ICharacter.gd'
const IINVENTORY_SNGL = 'res://addons/Popochiu/Engine/Interfaces/IInventory.gd'
const IDIALOG_SNGL = 'res://addons/Popochiu/Engine/Interfaces/IDialog.gd'
const IGRAPHIC_INTERFACE_SNGL = 'res://addons/Popochiu/Engine/Interfaces/IGraphicInterface.gd'
const GLOBALS_SNGL = 'res://popochiu/Globals.gd'
const GLOBALS_SRC = 'res://addons/Popochiu/Engine/Others/Globals.gd'
const GRAPHIC_INTERFACE_SRC = 'res://addons/Popochiu/Engine/Objects/GraphicInterface/'
const TRANSITION_LAYER_SRC = 'res://addons/Popochiu/Engine/Objects/TransitionLayer/'

var main_dock: Panel

var _editor_interface := get_editor_interface()
var _editor_file_system := _editor_interface.get_resource_filesystem()
var _directory := Directory.new()
var _is_first_install := false
var _input_actions := preload('res://addons/Popochiu/Engine/Others/InputActions.gd')


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos de Godot ░░░░
func _init() -> void:
	# Gracias Dialogic
	if Engine.editor_hint:
		# Verificar si existe la carpeta donde irán los elementos del juego.
		# Si no, crear carpetas, mover archivos y actualizar Popochiu.tscn.
		_init_file_structure()
	
	# Cargar los singleton para acceder directamente a objetos de Popochiu
	add_autoload_singleton('Utils', UTILS_SNGL)
	add_autoload_singleton('Cursor', CURSOR_SNGL)
	add_autoload_singleton('E', POPOCHIU_SNGL)
	add_autoload_singleton('C', ICHARACTER_SNGL)
	add_autoload_singleton('I', IINVENTORY_SNGL)
	add_autoload_singleton('D', IDIALOG_SNGL)
	add_autoload_singleton('G', IGRAPHIC_INTERFACE_SNGL)
	add_autoload_singleton('Globals', GLOBALS_SNGL)


func _enter_tree() -> void:
	if not _is_first_install:
		prints('::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::')

		main_dock = preload(MAIN_DOCK_PATH).instance()
		main_dock.ei = _editor_interface
		main_dock.fs = _editor_file_system

		add_control_to_dock(DOCK_SLOT_RIGHT_BL, main_dock)
		connect('scene_changed', main_dock, 'scene_changed')
		
		# Llenar las listas de habitaciones, personajes, objetos de inventario
		# y árboles de diálogo.
		yield(get_tree().create_timer(1.0), 'timeout')
		main_dock.fill_data()
		main_dock.grab_focus()


func _exit_tree() -> void:
	if not _is_first_install:
		remove_autoload_singleton('Utils')
		remove_autoload_singleton('Cursor')
		remove_autoload_singleton('E')
		remove_autoload_singleton('C')
		remove_autoload_singleton('I')
		remove_autoload_singleton('D')
		remove_autoload_singleton('G')
		remove_autoload_singleton('Globals')

		remove_control_from_docks(main_dock)


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos virtuales ░░░░
func enable_plugin() -> void:
	_create_input_actions()
	
	# Mostrar la ventana de diálogo para pedirle a la desarrolladora que reinicie
	# el motor.
	var ad := AcceptDialog.new()
	ad.window_title = 'El reiniciador'
	ad.dialog_text = 'Toca que reinicie el motor pa que funcione el Popochiu.'
	_editor_interface.get_base_control().add_child(ad)
	ad.popup_centered()


func disable_plugin() -> void:
	_remove_input_actions()


# ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ métodos privados ░░░░
func _init_file_structure() -> void:
	var directory := Directory.new()
	
	if not directory.dir_exists(BASE_DIR):
		prints('-------------------------------------', 'Creando lo inicial!!!')

		for d in _get_directories().values():
			if not directory.dir_exists(d):
				directory.make_dir_recursive(d)

		directory.copy(GLOBALS_SRC, GLOBALS_SNGL)
#		directory.rename(GRAPHIC_INTERFACE_SRC, BASE_DIR + '/GraphicInterface')
#		directory.rename(TRANSITION_LAYER_SRC, BASE_DIR + '/TransitionLayer')
		
		_editor_file_system.scan()
		
		_is_first_install = true


func _get_directories() -> Dictionary:
	return {
		BASE = BASE_DIR,
		ROOMS = BASE_DIR + '/Rooms',
		CHARACTERS = BASE_DIR + '/Characters',
		INVENTORY_ITEMS = BASE_DIR + '/InventoryItems',
		DIALOGS = BASE_DIR + '/Dialogs',
	}


func _create_input_actions() -> void:
	# Registrar los Input de interact, look y skip
	# Gracias QuentinCaffeino :) ()
	for d in _input_actions.ACTIONS:
		var setting_name = 'input/' + d.name
		
		if not ProjectSettings.has_setting(setting_name):
			var event: InputEvent
			
			if d.has('button'):
				event = InputEventMouseButton.new()
				event.button_index = d.button
			elif d.has('key'):
				event = InputEventKey.new()
				event.scancode = d.key
			
			ProjectSettings.set_setting(
				setting_name,
				{
					deadzone = float(d.deadzone if d.has('deadzone') else 0.5),
					events = [event]
				}
			)

	var result = ProjectSettings.save()
	assert(result == OK, 'Failed to save project settings')


func _remove_input_actions() -> void:
	for d in _input_actions.ACTIONS:
		var setting_name = 'input/' + d.name
		
		if ProjectSettings.has_setting(setting_name):
			ProjectSettings.clear(setting_name)
	
	var result = ProjectSettings.save()
	assert(result == OK, 'Failed to save project settings')