class_name ElementalStatus
extends RefCounted
## Tracks the current elemental status on one target (A.2/A.3). Owner
## holds one instance, calls tick(delta) every physics frame.

signal status_applied(element: StringName, charge: int)
signal status_cleared(element: StringName)

const DECAY_SECONDS: float = 5.0  ## Mid-point of A.3's "~4-6s" window.

var element: StringName = Elements.NONE
var charge: int = 0
var _decay_timer: float = 0.0

func tick(delta: float) -> void:
	if element == Elements.NONE:
		return
	_decay_timer -= delta
	if _decay_timer <= 0.0:
		clear()

## Refresh only — never stacks (A.3's explicit fix). p_duration lets a
## specific reaction extend the decay window past the default 5s (used by
## Condensation, A.2) without needing a second timer system.
func apply(new_element: StringName, new_charge: int, p_duration: float = DECAY_SECONDS) -> void:
	element = new_element
	charge = new_charge
	_decay_timer = p_duration
	status_applied.emit(element, charge)

func clear() -> void:
	if element == Elements.NONE:
		return
	var cleared_element := element
	element = Elements.NONE
	charge = 0
	_decay_timer = 0.0
	status_cleared.emit(cleared_element)

func has_status() -> bool:
	return element != Elements.NONE
