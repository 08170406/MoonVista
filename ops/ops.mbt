///|
pub(all) struct View {
  table : @table.Table
  row_indices : Array[Int]
  column_indices : Array[Int]
}

///|
pub(all) struct SortKey {
  column : String
  descending : Bool
}

///|
pub(all) enum OpsError {
  UnknownColumn(String)
} derive(Eq, Debug)

///|
priv struct ResolvedSortKey {
  column_index : Int
  descending : Bool
}

///|
pub fn from_table(table : @table.Table) -> View {
  let row_indices : Array[Int] = []
  let column_indices : Array[Int] = []
  for index in 0..<table.rows.length() {
    row_indices.push(index)
  }
  for index in 0..<table.columns.length() {
    column_indices.push(index)
  }
  { table, row_indices, column_indices, }
}

///|
fn find_column(table : @table.Table, name : String) -> Int? {
  for index, column in table.columns {
    if column.name == name {
      return Some(index)
    }
  }
  None
}

///|
fn compare_int(left : Int, right : Int) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn compare_double(left : Double, right : Double) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn compare_text(left : String, right : String) -> Int {
  let left_chars = left.to_array()
  let right_chars = right.to_array()
  let shared_length = if left_chars.length() < right_chars.length() {
    left_chars.length()
  } else {
    right_chars.length()
  }
  for index in 0..<shared_length {
    let left_codepoint = left_chars[index].to_int()
    let right_codepoint = right_chars[index].to_int()
    if left_codepoint < right_codepoint {
      return -1
    } else if left_codepoint > right_codepoint {
      return 1
    }
  }
  compare_int(left_chars.length(), right_chars.length())
}

///|
pub fn cell_to_string(cell : @table.Cell) -> String {
  match cell {
    @table.Cell::I(value) => "\{value}"
    @table.Cell::F(value) => "\{value}"
    @table.Cell::B(value) => "\{value}"
    @table.Cell::D(value) => value
    @table.Cell::S(value) => value
    @table.Cell::Null => ""
  }
}

///|
fn compare_non_null_cells(
  left : @table.Cell,
  right : @table.Cell,
  ctype : @table.ColType,
) -> Int {
  match (left, right, ctype) {
    (@table.Cell::I(left), @table.Cell::I(right), @table.ColType::Int) =>
      compare_int(left, right)
    (@table.Cell::F(left), @table.Cell::F(right), @table.ColType::Float) =>
      compare_double(left, right)
    (@table.Cell::B(left), @table.Cell::B(right), @table.ColType::Bool) =>
      compare_int(if left { 1 } else { 0 }, if right { 1 } else { 0 })
    (@table.Cell::D(left), @table.Cell::D(right), @table.ColType::Date) =>
      compare_text(left, right)
    (@table.Cell::S(left), @table.Cell::S(right), _) =>
      compare_text(left, right)
    _ => compare_text(cell_to_string(left), cell_to_string(right))
  }
}

///|
fn compare_rows(
  table : @table.Table,
  left_row : Int,
  right_row : Int,
  keys : Array[ResolvedSortKey],
) -> Int {
  for key in keys {
    let left_cell = table.rows[left_row][key.column_index]
    let right_cell = table.rows[right_row][key.column_index]
    let ordering = match (left_cell, right_cell) {
      (@table.Cell::Null, @table.Cell::Null) => 0
      (@table.Cell::Null, _) => 1
      (_, @table.Cell::Null) => -1
      _ => {
        let ctype = table.columns[key.column_index].ctype
        let result = compare_non_null_cells(left_cell, right_cell, ctype)
        if key.descending {
          -result
        } else {
          result
        }
      }
    }
    if ordering != 0 {
      return ordering
    }
  }
  0
}

///|
pub fn sort(view : View, keys : Array[SortKey]) -> Result[View, OpsError] {
  let resolved : Array[ResolvedSortKey] = []
  for key in keys {
    match find_column(view.table, key.column) {
      Some(column_index) =>
        resolved.push({ column_index, descending: key.descending, })
      None => return Err(UnknownColumn(key.column))
    }
  }
  let indexed_rows : Array[(Int, Int)] = []
  for position, row_index in view.row_indices {
    indexed_rows.push((row_index, position))
  }
  indexed_rows.sort_by(fn(left, right) {
    let ordering = compare_rows(view.table, left.0, right.0, resolved)
    if ordering == 0 {
      compare_int(left.1, right.1)
    } else {
      ordering
    }
  })
  let sorted_rows : Array[Int] = []
  for indexed_row in indexed_rows {
    sorted_rows.push(indexed_row.0)
  }
  Ok({
    table: view.table,
    row_indices: sorted_rows,
    column_indices: view.column_indices.copy(),
  })
}
