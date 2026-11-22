package test_internal

import "core:testing"

Empty :: struct {}
Value :: struct { expression: rawptr, frame: ^Frame, slot: int }
Site :: struct { call: rawptr, frame: ^Frame }
Invoke :: struct { site: Site }
Operation :: union #no_nil { Empty, Invoke }
Key :: struct { value: Value, projection: ^Projection, operation: Operation }
Origin :: union #no_nil { Empty, ^Demand }
Demand :: struct { key: Key, origin: Origin }
Projection :: union #no_nil { Empty, Step }
Step :: struct { value: i128, tail: ^Projection }
Package :: struct { index: ^Type_Index }
Type_Index :: struct { programs: []^Program }
Program :: struct { demands: map[Key]^Demand }
Frame :: struct { pkg: ^Package }

clone :: proc(key: Key, origin: Origin) -> ^Demand {
	return new_clone(Demand{key = key, origin = origin})
}
@(test)
recursive_union_layout_keeps_aggregate_fields :: proc(t: ^testing.T) {
	frame := Frame{}
	value := Value{frame = &frame}
	cloned := clone(Key{value = value, operation = Invoke{site = Site{frame = &frame}}}, Empty{})
	testing.expect_value(t, cloned.key.value.frame, &frame)
	testing.expect_value(t, cloned.key.operation.(Invoke).site.frame, &frame)
	testing.expect_value(t, uintptr(&cloned.origin) - uintptr(cloned), uintptr(offset_of(Demand, origin)))
	free(cloned)
}
