///|
test "CSV handles comma and escaped quote fields" {
  let table = parse_csv("name,note\nAda,\"hello, \"\"MoonBit\"\"\"").unwrap()
  match table.rows[0][1] {
    @table.Cell::S(value) => assert_eq(value, "hello, \"MoonBit\"")
    _ => assert_eq(1, 0)
  }
}

///|
test "CSV supports multiline quoted values and CRLF" {
  let table = parse_csv("name,note\r\nAda,\"line one\r\nline two\"\r\n").unwrap()
  match table.rows[0][1] {
    @table.Cell::S(value) => assert_eq(value, "line one\r\nline two")
    _ => assert_eq(1, 0)
  }
}

///|
test "CSV strips a UTF-8 BOM and ignores terminal blank lines" {
  let table = parse_csv("\u{FEFF}name,value\nAda,1\n\n").unwrap()
  assert_eq(table.columns.length(), 2)
  assert_eq(table.rows.length(), 1)
}

///|
test "CSV pads short records and rejects wide records" {
  let padded = parse_csv("name,value\nAda\n").unwrap()
  assert_eq(padded.rows.length(), 1)
  match padded.rows[0][1] {
    @table.Cell::Null => ()
    _ => assert_eq(1, 0)
  }
  assert_eq(parse_csv("a\n1,2") is Err(_), true)
}

///|
test "JSON object arrays create deterministic columns" {
  let table = parse_json(
    "[{\"z\":1,\"name\":\"Ada\"},{\"name\":\"Lin\",\"z\":2}]",
  ).unwrap()
  assert_eq(table.columns[0].name, "name")
  assert_eq(table.columns[1].name, "z")
  assert_eq(table.rows.length(), 2)
}

///|
test "JSONL skips blank lines and loads objects" {
  let table = parse_jsonl(
    "{\"name\":\"Ada\",\"ok\":true}\n\n{\"name\":\"Lin\",\"ok\":false}\n",
  ).unwrap()
  assert_eq(table.rows.length(), 2)
  assert_eq(table.columns.length(), 2)
}

///|
test "invalid JSON shapes and unterminated CSV quotes are reported" {
  assert_eq(parse_json("{\"name\":\"Ada\"}") is Err(_), true)
  assert_eq(parse_jsonl("[1,2]") is Err(_), true)
  assert_eq(parse_csv("name,note\nAda,\"unterminated") is Err(_), true)
}
