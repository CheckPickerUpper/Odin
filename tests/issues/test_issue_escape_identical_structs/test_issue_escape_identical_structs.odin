// What a specialization writes to a field reaches every caller whose struct is identical to the one it was made for,
// such as the same anonymous struct written in each caller, so both warnings are kept
package test_issues

clear_other :: proc(s: ^$T) {
	s.other = nil
}

first :: proc() -> struct{pointer: ^int, other: ^int} {
	x: int
	s: struct{pointer: ^int, other: ^int}
	s.pointer = &x
	clear_other(&s)
	// The checker finishes this body before checking the nested caller, so the specialization has a fixed source location.
	second :: proc() -> struct{pointer: ^int, other: ^int} {
		y: int
		value: struct{pointer: ^int, other: ^int}
		value.pointer = &y
		clear_other(&value)
		return value
	}
	_ = second()
	return s
}
