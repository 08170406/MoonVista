///|
test "integer columns infer Int" {
  assert_eq(infer_type(["12", "-4", "0"]), ColType::Int)
}

///|
test "mixed whole and decimal numbers infer Float" {
  assert_eq(infer_type(["12", "4.5", "-0.25"]), ColType::Float)
}

///|
test "boolean columns infer Bool" {
  assert_eq(infer_type(["true", "false"]), ColType::Bool)
}

///|
test "ISO calendar dates infer Date" {
  assert_eq(infer_type(["2024-02-29", "2026-09-28"]), ColType::Date)
  assert_eq(infer_type(["2023-02-29", "2024-13-01"]), ColType::Str)
}

///|
test "mixed semantic values remain strings" {
  assert_eq(infer_type(["12", "twelve"]), ColType::Str)
}

///|
test "empty columns infer Empty" {
  assert_eq(infer_type(["", "  "]), ColType::Empty)
}

///|
test "table records type confidence and pads missing cells as Null" {
  let table = from_records(["name", "value"], [
    ["alpha", "1"],
    ["beta", "word"],
    ["gamma"],
  ]).unwrap()
  assert_eq(table.columns[1].ctype, ColType::Str)
  assert_eq(table.columns[1].confidence, 0.5)
  assert_eq(table.columns[1].nulls, 1)
  match table.rows[2][1] {
    Cell::Null => ()
    _ => assert_eq(1, 0)
  }
}

///|
test "table rejects records wider than the header" {
  assert_eq(from_records(["one"], [["1", "extra"]]) is Ok(_), false)
}
