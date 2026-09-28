///|
pub struct View {
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
pub(all) enum FilterOp {
  Eq
  Ne
  Contains
  Gt
  Ge
  Lt
  Le
  IsNull
  IsNotNull
} derive(Eq, Debug)

///|
pub(all) struct Filter {
  column : String
  op : FilterOp
  value : String
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

///|
fn contains_text(text : String, needle : String) -> Bool {
  let text_chars = text.to_array()
  let needle_chars = needle.to_array()
  if needle_chars.is_empty() {
    return true
  }
  if needle_chars.length() > text_chars.length() {
    return false
  }
  for start in 0..<(text_chars.length() - needle_chars.length() + 1) {
    let mut matches = true
    for offset in 0..<needle_chars.length() {
      if text_chars[start + offset] != needle_chars[offset] {
        matches = false
      }
    }
    if matches {
      return true
    }
  }
  false
}

///|
fn compare_cell_to_literal(
  cell : @table.Cell,
  literal : String,
  ctype : @table.ColType,
) -> Int? {
  match (cell, ctype) {
    (@table.Cell::Null, _) => None
    (@table.Cell::I(value), @table.ColType::Int) =>
      Some(compare_int(value, @string.parse_int(literal.trim()))) catch {
        _ => None
      }
    (@table.Cell::F(value), @table.ColType::Float) =>
      Some(compare_double(value, @string.parse_double(literal.trim()))) catch {
        _ => None
      }
    (@table.Cell::B(value), @table.ColType::Bool) =>
      if literal == "true" {
        Some(compare_int(if value { 1 } else { 0 }, 1))
      } else if literal == "false" {
        Some(compare_int(if value { 1 } else { 0 }, 0))
      } else {
        None
      }
    (@table.Cell::D(value), @table.ColType::Date) =>
      Some(compare_text(value, literal))
    (@table.Cell::S(value), _) => Some(compare_text(value, literal))
    _ => Some(compare_text(cell_to_string(cell), literal))
  }
}

///|
fn filter_matches(
  cell : @table.Cell,
  ctype : @table.ColType,
  condition : Filter,
) -> Bool {
  match condition.op {
    IsNull =>
      match cell {
        @table.Cell::Null => true
        _ => false
      }
    IsNotNull =>
      match cell {
        @table.Cell::Null => false
        _ => true
      }
    Contains =>
      match cell {
        @table.Cell::Null => false
        _ => contains_text(cell_to_string(cell), condition.value)
      }
    Eq => compare_cell_to_literal(cell, condition.value, ctype) == Some(0)
    Ne => compare_cell_to_literal(cell, condition.value, ctype) != Some(0)
    Gt =>
      match compare_cell_to_literal(cell, condition.value, ctype) {
        Some(ordering) => ordering > 0
        None => false
      }
    Ge =>
      match compare_cell_to_literal(cell, condition.value, ctype) {
        Some(ordering) => ordering >= 0
        None => false
      }
    Lt =>
      match compare_cell_to_literal(cell, condition.value, ctype) {
        Some(ordering) => ordering < 0
        None => false
      }
    Le =>
      match compare_cell_to_literal(cell, condition.value, ctype) {
        Some(ordering) => ordering <= 0
        None => false
      }
  }
}

///|
pub fn filter(view : View, condition : Filter) -> Result[View, OpsError] {
  match find_column(view.table, condition.column) {
    None => Err(UnknownColumn(condition.column))
    Some(column_index) => {
      let column = view.table.columns[column_index]
      let rows : Array[Int] = []
      for row_index in view.row_indices {
        if filter_matches(
            view.table.rows[row_index][column_index],
            column.ctype,
            condition,
          ) {
          rows.push(row_index)
        }
      }
      Ok({
        table: view.table,
        row_indices: rows,
        column_indices: view.column_indices.copy(),
      })
    }
  }
}

///|
pub fn project(view : View, columns : Array[String]) -> Result[View, OpsError] {
  let selected : Array[Int] = []
  for name in columns {
    match find_column(view.table, name) {
      None => return Err(UnknownColumn(name))
      Some(column_index) => {
        let mut is_visible = false
        for selected_index in selected {
          if selected_index == column_index {
            is_visible = true
          }
        }
        if !is_visible {
          selected.push(column_index)
        }
      }
    }
  }
  Ok({
    table: view.table,
    row_indices: view.row_indices.copy(),
    column_indices: selected,
  })
}

///|
pub fn hide_columns(
  view : View,
  columns : Array[String],
) -> Result[View, OpsError] {
  for name in columns {
    if find_column(view.table, name) is None {
      return Err(UnknownColumn(name))
    }
  }
  let selected : Array[Int] = []
  for column_index in view.column_indices {
    let mut is_hidden = false
    for name in columns {
      if view.table.columns[column_index].name == name {
        is_hidden = true
      }
    }
    if !is_hidden {
      selected.push(column_index)
    }
  }
  Ok({
    table: view.table,
    row_indices: view.row_indices.copy(),
    column_indices: selected,
  })
}

///|
pub fn search(view : View, query : String) -> View {
  let rows : Array[Int] = []
  if query.is_empty() {
    for row_index in view.row_indices {
      rows.push(row_index)
    }
  } else {
    for row_index in view.row_indices {
      let mut matches = false
      for column_index in view.column_indices {
        let cell = view.table.rows[row_index][column_index]
        if contains_text(cell_to_string(cell), query) {
          matches = true
        }
      }
      if matches {
        rows.push(row_index)
      }
    }
  }
  {
    table: view.table,
    row_indices: rows,
    column_indices: view.column_indices.copy(),
  }
}

///|
pub fn row_count(view : View) -> Int {
  view.row_indices.length()
}

///|
pub fn column_count(view : View) -> Int {
  view.column_indices.length()
}

///|
pub fn source_row_index(view : View, row_position : Int) -> Int? {
  if row_position < 0 || row_position >= view.row_indices.length() {
    None
  } else {
    Some(view.row_indices[row_position])
  }
}

///|
pub fn column_at(view : View, column_position : Int) -> @table.Column? {
  if column_position < 0 || column_position >= view.column_indices.length() {
    None
  } else {
    Some(view.table.columns[view.column_indices[column_position]])
  }
}

///|
pub fn cell_at(
  view : View,
  row_position : Int,
  column_position : Int,
) -> @table.Cell? {
  if row_position < 0 ||
    row_position >= view.row_indices.length() ||
    column_position < 0 ||
    column_position >= view.column_indices.length() {
    None
  } else {
    Some(
      view.table.rows[view.row_indices[row_position]][view.column_indices[column_position]],
    )
  }
}
