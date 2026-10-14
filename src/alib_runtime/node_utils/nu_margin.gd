#! namespace ALibRuntime.NodeUtils class NUMarginContainer

const MARGIN_TOP = &"margin_top"
const MARGIN_BOTTOM = &"margin_bottom"
const MARGIN_LEFT = &"margin_left"
const MARGIN_RIGHT = &"margin_right"


const MARGIN_CONSTANTS = [MARGIN_TOP, MARGIN_BOTTOM, MARGIN_LEFT, MARGIN_RIGHT]

static func set_margins(margin_container:MarginContainer, val:int, top:=true, bottom:=true, left:=true, right:=true):
	if top:
		margin_container.add_theme_constant_override(MARGIN_TOP, val)
	if bottom:
		margin_container.add_theme_constant_override(MARGIN_BOTTOM, val)
	if left:
		margin_container.add_theme_constant_override(MARGIN_LEFT, val)
	if right:
		margin_container.add_theme_constant_override(MARGIN_RIGHT, val)
