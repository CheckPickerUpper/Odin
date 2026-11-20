package doc_test_primary

when ODIN_TEST {
	Conditional :: 2
} else {
	Conditional :: 1
}

when #config(DOC_TEST_UNUSED, false) {
	unused_helper :: proc() {}
}

when #config(DOC_TEST_TYPE_ERROR, false) {
	invalid_value: int = "not an integer"
}

when #config(DOC_TEST_UNUSED_LOCAL, false) {
	use_local :: proc(value: $T) {
		unused_local := value
	}

	main :: proc() {
		use_local(1)
	}
}
