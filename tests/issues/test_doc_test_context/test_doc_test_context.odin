package test_doc_test_context

import "core:fmt"
import "core:io"
import "core:encoding/cbor"
import "core:encoding/json"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"
import "base:runtime"
import doc "core:odin/doc-format"
import tool "core:odin/tool-format"

@(private="file")
Export_Context :: enum {
	Production,
	Test,
}

@(private="file")
Expected_Document :: struct #all_or_none {
	path:           string,
	target:         string,
	export_context: Export_Context,
}

@(private="file")
read_file :: proc(t: ^testing.T, path: string) -> []u8 {
	bytes, read_error := os.read_entire_file(path, context.temp_allocator)
	switch failure in read_error {
	case nil:
		return bytes
	case os.General_Error, os.Platform_Error, runtime.Allocator_Error, io.Error:
		testing.fail_now(t, fmt.tprintf("cannot read %s: %v", path, failure))
	}
	unreachable()
}

@(private="file")
find_package :: proc(t: ^testing.T, header: ^doc.Header, name: string) -> doc.Pkg {
	for documentation_package in doc.from_array(header, header.pkgs) {
		if doc.from_string(header, documentation_package.name) == name {
			return documentation_package
		}
	}

	testing.fail_now(t, fmt.tprintf("package %q is missing", name))
}

@(private="file")
find_entity :: proc(t: ^testing.T, header: ^doc.Header, documentation_package: doc.Pkg, name: string) -> doc.Entity {
	entities := doc.from_array(header, header.entities)
	for entry in doc.from_array(header, documentation_package.entries) {
		if doc.from_string(header, entry.name) == name {
			return entities[entry.entity]
		}
	}

	testing.fail_now(t, fmt.tprintf("entity %q is missing from package %q", name, doc.from_string(header, documentation_package.name)))
}

@(private="file")
find_exported_file :: proc(t: ^testing.T, semantics: tool.Semantics, name: string) -> tool.Exported_File {
	for exported_file in semantics.exported {
		if filepath.base(semantics.files[exported_file.file]) == name {
			return exported_file
		}
	}

	testing.fail_now(t, fmt.tprintf("semantic export for %q is missing", name))
}

@(test)
test_documentation_uses_test_context :: proc(t: ^testing.T) {
	host_target := strings.to_lower(ODIN_OS_STRING, context.temp_allocator)
	documents := [?]Expected_Document{
		{path = "production.odin-doc", target = host_target, export_context = .Production},
		{path = "primary.odin-doc", target = host_target, export_context = .Test},
		{path = "test_windows.odin-doc", target = "windows", export_context = .Test},
		{path = "test_darwin.odin-doc", target = "darwin", export_context = .Test},
		{path = "test_unused.odin-doc", target = host_target, export_context = .Test},
	}
	source := string(read_file(t, "../test_doc_test_context/primary/primary.odin"))
	test_offset := strings.index(source, "Conditional :: 2")
	production_offset := strings.index(source, "Conditional :: 1")
	testing.expect(t, test_offset >= 0 && production_offset >= 0)

	for document in documents {
		bytes := read_file(t, document.path)
		header, decode_error := doc.read_from_bytes(bytes)
		switch decode_error {
		case .None:
		case .Header_Too_Small, .Invalid_Magic, .Data_Too_Small, .Invalid_Version:
			testing.fail_now(t, fmt.tprintf("cannot decode %s: %v", document.path, decode_error))
		}
		semantic_path := fmt.tprintf("%s.cbor", strings.trim_suffix(document.path, ".odin-doc"))
		semantics := tool.Semantics{}
		switch failure in tool.unmarshal_semantics(read_file(t, semantic_path), &semantics, context.temp_allocator) {
		case nil:
		case tool.Semantics_Error, json.Unmarshal_Error, cbor.Unmarshal_Error:
			testing.fail_now(t, fmt.tprintf("cannot decode %s: %v", semantic_path, failure))
		}
		primary_semantics := find_exported_file(t, semantics, "primary.odin")
		inactive_test := false
		inactive_production := false
		for pair in 0..<len(primary_semantics.inactive)/2 {
			from := int(primary_semantics.inactive[2*pair])
			to := int(primary_semantics.inactive[2*pair+1])
			inactive_test ||= from <= test_offset && test_offset < to
			inactive_production ||= from <= production_offset && production_offset < to
		}

		primary := find_package(t, header, "doc_test_primary")
		conditional := find_entity(t, header, primary, "Conditional")
		selected_target := find_entity(t, header, primary, "Selected_Target")
		testing.expect_value(t, doc.from_string(header, selected_target.init_string), fmt.tprintf("%q", document.target))

		expected_files := []string{"primary.odin", fmt.tprintf("platform_%s.odin", document.target)}
		switch document.export_context {
		case .Production:
			testing.expect_value(t, doc.from_string(header, conditional.init_string), "1")
			testing.expect(t, inactive_test && !inactive_production)
			for documentation_package in doc.from_array(header, header.pkgs) {
				testing.expect(t, doc.from_string(header, documentation_package.name) != "dependency")
			}
			for entry in doc.from_array(header, primary.entries) {
				name := doc.from_string(header, entry.name)
				testing.expect(t, name != "Test_Record" && name != "use_scratch" && name != "must_not_run")
			}
		case .Test:
			testing.expect_value(t, doc.from_string(header, conditional.init_string), "2")
			testing.expect(t, !inactive_test && inactive_production)
			find_exported_file(t, semantics, "scratch_test.odin")
			expected_files = []string{"primary.odin", fmt.tprintf("platform_%s.odin", document.target), "test_exports.odin"}
			dependency := find_package(t, header, "dependency")
			scratch := find_entity(t, header, dependency, "Scratch")
			record := find_entity(t, header, primary, "Test_Record")
			procedure := find_entity(t, header, primary, "use_scratch")
			find_entity(t, header, primary, "must_not_run")
			files := doc.from_array(header, header.files)
			testing.expect_value(t, filepath.base(doc.from_string(header, files[scratch.pos.file].name)), "scratch_test.odin")

			types := doc.from_array(header, header.types)
			entities := doc.from_array(header, header.entities)
			record_types := doc.from_array(header, types[record.type].types)
			if !testing.expect_value(t, len(record_types), 1) {
				continue
			}
			record_fields := doc.from_array(header, types[record_types[0]].entities)
			if testing.expect_value(t, len(record_fields), 1) {
				testing.expect_value(t, entities[record_fields[0]].type, scratch.type)
			}

			procedure_types := doc.from_array(header, types[procedure.type].types)
			if !testing.expect_value(t, len(procedure_types), 2) {
				continue
			}
			for procedure_type in procedure_types {
				parameters := doc.from_array(header, types[procedure_type].entities)
				if testing.expect_value(t, len(parameters), 1) {
					testing.expect_value(t, entities[parameters[0]].type, scratch.type)
				}
			}
		}

		files := doc.from_array(header, header.files)
		primary_files := doc.from_array(header, primary.files)
		testing.expect_value(t, len(primary_files), len(expected_files))
		for expected_file in expected_files {
			found := false
			for file_index in primary_files {
				if filepath.base(doc.from_string(header, files[file_index].name)) == expected_file {
					found = true
				}
			}
			testing.expectf(t, found, "%s is missing from %s", expected_file, document.path)
		}
	}
}
