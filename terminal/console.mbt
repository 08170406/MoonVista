///|
pub enum StdinLine {
  EndOfInput
  TooLong
  Line(String)
}

///|
#cfg(platform="windows")
priv struct NativePath(String)

///|
#cfg(not(platform="windows"))
priv struct NativePath(Bytes)

///|
#cfg(platform="windows")
fn NativePath::from_string(path : String) -> NativePath {
  NativePath(path)
}

///|
#cfg(not(platform="windows"))
fn NativePath::from_string(path : String) -> NativePath {
  NativePath(@unicode.to_utf8_bytes(path) + Bytes::make(1, 0))
}

///|
#borrow(buffer)
extern "C" fn console_read_line_ffi(buffer : Bytes, capacity : Int) -> Int = "moonvista_console_read_line"

///|
#borrow(path, content)
extern "C" fn console_write_new_file_ffi(
  path : NativePath,
  content : Bytes,
  length : Int,
) -> Int = "moonvista_console_write_new_file"

///|
pub fn read_stdin_line() -> StdinLine {
  let buffer = Bytes::make(4096, 0)
  let length = console_read_line_ffi(buffer, 4096)
  if length == -1 {
    EndOfInput
  } else if length == -2 {
    TooLong
  } else {
    let bytes : Array[Byte] = []
    for index in 0..<length {
      bytes.push(buffer[index])
    }
    Line(@unicode.to_utf8_string(Bytes::from_array(bytes[:])))
  }
}

///|
/// Creates a file without replacing an existing destination.
/// Returns 0 on success, 1 when the path already exists, and -1 on I/O error.
pub fn write_export_file(path : String, content : String) -> Int {
  if @fs.path_exists(path) {
    1
  } else {
    let bytes = @unicode.to_utf8_bytes(content)
    console_write_new_file_ffi(
      NativePath::from_string(path),
      bytes,
      bytes.length(),
    )
  }
}
