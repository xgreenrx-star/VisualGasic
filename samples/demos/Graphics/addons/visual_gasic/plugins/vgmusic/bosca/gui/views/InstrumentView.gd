###################################################
# Part of Bosca Ceoil Blue                        #
# Copyright (c) 2025 Yuri Sizov and contributors  #
# Provided under MIT                              #
###################################################

@tool
extends MarginContainer

@onready var _instrument_dock: ItemDock = %InstrumentDock


func _ready() -> void:
	if not false:
		Controller.help_manager.reference_node(HelpManager.StepNodeRef.INSTRUMENT_EDITOR_VIEW, get_global_rect)
		Controller.help_manager.reference_node(HelpManager.StepNodeRef.INSTRUMENT_EDITOR_DOCK, _instrument_dock.get_global_rect_with_delete_area)
