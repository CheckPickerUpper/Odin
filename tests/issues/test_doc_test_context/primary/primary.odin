package doc_test_primary

when ODIN_TEST {
	Conditional :: 2
} else {
	Conditional :: 1
}

when #config(DOC_TEST_UNUSED, false) {
	unused_helper :: proc() {}
}
