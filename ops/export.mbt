///|
fn append_text(output : Array[Char], text : String) -> Unit {
  for character in text.to_array() {
    output.push(character)
  }
}

///|
fn csv_needs_quotes(chars : Array[Char]) -> Bool {
  if chars.is_empty() {
    return false
  }
  if chars[0] == ' ' ||
    chars[0] == '\t' ||
    chars[chars.length() - 1] == ' ' ||
    chars[chars.length() - 1] == '\t' {
    return true
  }
  for character in chars {
    if character == ',' ||
      character == '"' ||
      character == '\r' ||
      character == '\n' {
      return true
    }
  }
  false
}

///|
fn append_csv_value(output : Array[Char], value : String) -> Unit {
  let chars = value.to_array()
  let quoted = csv_needs_quotes(chars)
  if quoted {
    output.push('"')
  }
  for character in chars {
    if character == '"' {
      output.push('"')
      output.push('"')
    } else {
      output.push(character)
    }
  }
  if quoted {
    output.push('"')
  }
}

///|
pub fn export_csv(view : View) -> String {
  let output : Array[Char] = []
  for column_position in 0..<column_count(view) {
    if column_position > 0 {
      output.push(',')
    }
    let column = column_at(view, column_position).unwrap()
    append_csv_value(output, column.name)
  }
  output.push('\r')
  output.push('\n')
  for row_position in 0..<row_count(view) {
    for column_position in 0..<column_count(view) {
      if column_position > 0 {
        output.push(',')
      }
      append_csv_value(
        output,
        cell_to_string(cell_at(view, row_position, column_position).unwrap()),
      )
    }
    output.push('\r')
    output.push('\n')
  }
  String::from_array(output)
}

///|
fn append_json_string(output : Array[Char], value : String) -> Unit {
  let hex_digits = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  output.push('"')
  for character in value.to_array() {
    match character {
      '"' => {
        output.push('\\')
        output.push('"')
      }
      '\\' => {
        output.push('\\')
        output.push('\\')
      }
      '\n' => {
        output.push('\\')
        output.push('n')
      }
      '\r' => {
        output.push('\\')
        output.push('r')
      }
      '\t' => {
        output.push('\\')
        output.push('t')
      }
      '\u{08}' => {
        output.push('\\')
        output.push('b')
      }
      '\u{0c}' => {
        output.push('\\')
        output.push('f')
      }
      _ => {
        let codepoint = character.to_int()
        if codepoint < 32 {
          output.push('\\')
          output.push('u')
          output.push('0')
          output.push('0')
          output.push(hex_digits[codepoint / 16])
          output.push(hex_digits[codepoint % 16])
        } else {
          output.push(character)
        }
      }
    }
  }
  output.push('"')
}

///|
fn append_json_cell(output : Array[Char], cell : @table.Cell) -> Unit {
  match cell {
    @table.Cell::I(value) => append_text(output, "\{value}")
    @table.Cell::F(value) => {
      let text = "\{value}"
      let mut has_decimal_marker = false
      for character in text.to_array() {
        if character == '.' || character == 'e' || character == 'E' {
          has_decimal_marker = true
        }
      }
      append_text(output, text)
      if !has_decimal_marker {
        append_text(output, ".0")
      }
    }
    @table.Cell::B(value) =>
      append_text(output, if value { "true" } else { "false" })
    @table.Cell::D(value) => append_json_string(output, value)
    @table.Cell::S(value) => append_json_string(output, value)
    @table.Cell::Null => append_text(output, "null")
  }
}

///|
pub fn export_json(view : View) -> String {
  let output : Array[Char] = ['[']
  for row_position in 0..<row_count(view) {
    if row_position > 0 {
      output.push(',')
    }
    output.push('{')
    for column_position in 0..<column_count(view) {
      if column_position > 0 {
        output.push(',')
      }
      let column = column_at(view, column_position).unwrap()
      append_json_string(output, column.name)
      output.push(':')
      append_json_cell(
        output,
        cell_at(view, row_position, column_position).unwrap(),
      )
    }
    output.push('}')
  }
  output.push(']')
  String::from_array(output)
}
