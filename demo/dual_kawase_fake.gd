extends Node

var _comp : RID
var _eff : RID

func apply_to_viewport(viewport: Node) -> void:
	print("DualKawaseFake: apply_to_viewport called")
	_comp = RenderingServer.compositor_create()
	_eff = RenderingServer.compositor_effect_create()
	# set the effect on the compositor and enable it
	RenderingServer.compositor_set_compositor_effects(_comp, [_eff])
	RenderingServer.compositor_effect_set_enabled(_eff, true)
	print("DualKawaseFake: compositor/eff created")

func free_compositor() -> void:
	if _eff and _eff != RID():
		RenderingServer.free_rid(_eff)
		_eff = RID()
	if _comp and _comp != RID():
		RenderingServer.free_rid(_comp)
		_comp = RID()
	print("DualKawaseFake: freed compositor/eff")

func _exit_tree() -> void:
	free_compositor()