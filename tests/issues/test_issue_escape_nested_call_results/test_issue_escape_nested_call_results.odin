// The escape analysis compares each fact a call's results gain with all those before it, and here they double with each
// call to 2^20, so without a limit on them `odin check` does not finish
package test_issues

Pair :: struct($T: typeid) {
	a, b: T,
}

pair :: proc(x: $T) -> Pair(T) {
	return {a = x, b = x}
}

nest :: proc(s: string) {
	_ = pair(pair(pair(pair(pair(pair(pair(pair(pair(pair(pair(pair(pair(pair(pair(pair(pair(pair(pair(pair(s))))))))))))))))))))
}
