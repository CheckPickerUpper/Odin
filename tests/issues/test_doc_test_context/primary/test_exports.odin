#+test
package doc_test_primary

import "../dependency"
import "core:testing"

Test_Record :: struct #all_or_none {
	scratch: dependency.Scratch,
}

use_scratch :: proc(scratch: dependency.Scratch) -> dependency.Scratch {
	return scratch
}

@(test)
must_not_run :: proc(_: ^testing.T) {
	record := Test_Record{scratch = use_scratch(dependency.Scratch{value = 1})}
	_ = record
	when #config(DOC_TEST_DEPENDENCY_SIGNATURE, false) {
		dependency.imported_test_with_wrong_signature()
	}
	panic("documentation export ran a test")
}
