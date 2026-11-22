#+test
package dependency

Scratch :: struct #all_or_none {
	value: int,
}

when #config(DOC_TEST_DEPENDENCY_SIGNATURE, false) {
	@(test)
	imported_test_with_wrong_signature :: proc() {}
}
