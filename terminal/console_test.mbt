///|
test "exclusive writer refuses to replace an existing file" {
  let path = "_build/moonvista-exclusive-write-test.txt"
  if @fs.path_exists(path) {
    @fs.remove_file(path) catch {
      @fs.IOError::IOError(_) => ()
    }
  }
  let first_status = write_export_file(path, "original")
  let second_status = write_export_file(path, "replacement")
  let saved_content = @fs.read_file_to_string(path)
  @fs.remove_file(path)
  assert_eq(first_status, 0)
  assert_eq(second_status, 1)
  assert_eq(saved_content, "original")
}
