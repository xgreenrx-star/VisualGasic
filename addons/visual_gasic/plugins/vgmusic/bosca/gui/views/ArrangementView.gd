###################################################
# Part of Bosca Ceoil Blue                        #
# Copyright (c) 2025 Yuri Sizov and contributors  #
# Provided under MIT                              #
###################################################

@tool
extends MarginContainer


func _ready() -> void:
	if not false:
		Controller.help_manager.reference_node(HelpManager.StepNodeRef.ARRANGEMENT_EDITOR_VIEW, get_global_rect)
