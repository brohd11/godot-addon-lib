const UVersion = EditorNodeRef.UVersion

static func add_to_favorites():
	var minor = _get_minor_version()
	if minor <= 7:
		return 4

static func remove_from_favorites():
	var minor = _get_minor_version()
	if minor <= 7:
		return 5

static func rename():
	var minor = _get_minor_version()
	if minor <= 7:
		return 10

static func expand_folder():
	var minor = _get_minor_version()
	if minor <= 7:
		return 0

static func expand_hierarchy():
	var minor = _get_minor_version()
	if minor <= 7:
		return 21

static func collapse_hierarchy():
	var minor = _get_minor_version()
	if minor <= 7:
		return 22

static func reimport():
	var minor = _get_minor_version()
	if minor <= 7:
		return 13


static func _get_minor_version():
	return UVersion.get_minor_version()
