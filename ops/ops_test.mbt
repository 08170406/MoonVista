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

///|
test "numeric and equality filters return an independent row view" {
  let table = @table.from_records(["team", "score"], [
    ["red", "7"],
    ["blue", "3"],
    ["red", "9"],
  ]).unwrap()
  let original = from_table(table)
  let selected = filter(original, {
    column: "score",
    op: FilterOp::Ge,
    value: "7",
  }).unwrap()
  assert_eq(selected.row_indices, [0, 2])
  assert_eq(original.row_indices, [0, 1, 2])
  let red = filter(selected, { column: "team", op: FilterOp::Eq, value: "red", }).unwrap()
  assert_eq(red.row_indices, [0, 2])
}

///|
test "contains and null predicates handle text and missing values" {
  let table = @table.from_records(["name", "note"], [
    ["Ada", "MoonBit rocks"],
    ["Lin", ""],
    ["Bo", "MoonVista"],
  ]).unwrap()
  let view = from_table(table)
  let contains = filter(view, {
    column: "note",
    op: FilterOp::Contains,
    value: "Moon",
  }).unwrap()
  assert_eq(contains.row_indices, [0, 2])
  let missing = filter(view, {
    column: "note",
    op: FilterOp::IsNull,
    value: "",
  }).unwrap()
  assert_eq(missing.row_indices, [1])
}

///|
test "filters reject unknown columns and keep nulls out of comparisons" {
  let table = @table.from_records(["value"], [[""], ["3"]]).unwrap()
  let view = from_table(table)
  assert_eq(
    filter(view, { column: "value", op: FilterOp::Gt, value: "1", }).unwrap().row_indices,
    [1],
  )
  assert_eq(
    filter(view, { column: "missing", op: FilterOp::Eq, value: "x", }) is Err(_),
    true,
  )
}

///|
test "projection preserves requested order and source table" {
  let table = @table.from_records(["id", "name", "city"], [
    ["1", "Ada", "Paris"],
    ["2", "Lin", "Tokyo"],
  ]).unwrap()
  let original = from_table(table)
  let projected = project(original, ["city", "id"]).unwrap()
  assert_eq(projected.column_indices, [2, 0])
  assert_eq(projected.row_indices, [0, 1])
  assert_eq(original.column_indices, [0, 1, 2])
}

///|
test "hide columns removes only the requested visible fields" {
  let table = @table.from_records(["id", "name", "city"], [
    ["1", "Ada", "Paris"],
  ]).unwrap()
  let hidden = hide_columns(from_table(table), ["name"]).unwrap()
  assert_eq(hidden.column_indices, [0, 2])
}

///|
test "search matches visible cells and empty query keeps the view" {
  let table = @table.from_records(["name", "city"], [
    ["Ada", "Paris"],
    ["Lin", "Tokyo"],
    ["Bo", "Parma"],
  ]).unwrap()
  let view = from_table(table)
  assert_eq(search(view, "Par").row_indices, [0, 2])
  assert_eq(search(view, "").row_indices, [0, 1, 2])
  let projected = project(view, ["name"]).unwrap()
  assert_eq(search(projected, "Tokyo").row_indices, [])
}

///|
test "view accessors use display positions and reject out of bounds" {
  let table = @table.from_records(["name"], [["Ada"]]).unwrap()
  let view = from_table(table)
  assert_eq(row_count(view), 1)
  assert_eq(column_count(view), 1)
  assert_eq(source_row_index(view, 0), Some(0))
  assert_eq(source_row_index(view, 1), None)
  assert_eq(column_at(view, 0).unwrap().name, "name")
  assert_eq(cell_at(view, 0, 0), Some(@table.Cell::S("Ada")))
}
