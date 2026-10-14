const BUILT_IN_VARIANTS: Dictionary = {
	# Primitives & Core Types
	"Nil": true,
	"bool": true,
	"int": true,
	"float": true,
	"String": true,
	"void": true, # Valid for return types
	
	# Vector Types
	"Vector2": true,
	"Vector2i": true,
	"Vector3": true,
	"Vector3i": true,
	"Vector4": true,
	"Vector4i": true,
	
	# Matrix & Transform Types
	"Transform2D": true,
	"Projection": true,
	"Basis": true,
	"Transform3D": true,
	"Quaternion": true,
	
	# Geometry Types
	"Rect2": true,
	"Rect2i": true,
	"Plane": true,
	"AABB": true,
	
	# Miscellaneous Core Types
	"Color": true,
	"StringName": true,
	"NodePath": true,
	"RID": true,
	
	# Core Objects
	"Object": true,
	"Callable": true,
	"Signal": true,
	"Dictionary": true,
	"Array": true,
	
	# Packed Arrays
	"PackedByteArray": true,
	"PackedInt32Array": true,
	"PackedInt64Array": true,
	"PackedFloat32Array": true,
	"PackedFloat64Array": true,
	"PackedStringArray": true,
	"PackedVector2Array": true,
	"PackedVector3Array": true,
	"PackedColorArray": true,
	"PackedVector4Array": true,
	}

## Return boolean if string is built in type.
static func check_type(type:String):
	if BUILT_IN_VARIANTS.has(type):
		return true
	return false
