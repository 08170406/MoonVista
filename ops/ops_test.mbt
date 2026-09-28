///|
test "multi-key sort is stable for equal values" {
  let table = @table.from_records(["rank", "label", "id"], [
    ["2", "same", "first"],
    ["1", "other", "middle"],
    ["2", "same", "last"],
    ["2", "alpha", "before"],
  ]).unwrap()
  let result = sort(from_table(table), [
    { column: "rank", descending: false, },
    { column: "label", descending: false, },
  ]).unwrap()
  let first = result.table.rows[result.row_indices[0]][2]
  let second = result.table.rows[result.row_indices[1]][2]
  let third = result.table.rows[result.row_indices[2]][2]
  let fourth = result.table.rows[result.row_indices[3]][2]
  assert_eq(first, @table.Cell::S("middle"))
  assert_eq(second, @table.Cell::S("before"))
  assert_eq(third, @table.Cell::S("first"))
  assert_eq(fourth, @table.Cell::S("last"))
}

///|
test "descending numeric sort keeps null values last" {
  let table = @table.from_records(["value"], [["1"], [""], ["3"]]).unwrap()
  let result = sort(from_table(table), [{ column: "value", descending: true, }]).unwrap()
  assert_eq(result.row_indices, [2, 0, 1])
}

///|
test "sort reports unknown columns" {
  let table = @table.from_records(["value"], [["1"]]).unwrap()
  assert_eq(
    sort(from_table(table), [{ column: "missing", descending: false, }])
    is Err(_),
    true,
  )
}
