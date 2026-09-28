///|
pub(all) struct RenderOptions {
  first_row : Int
  cursor_row : Int
  cursor_column : Int
}

///|
pub(all) struct Screen {
  width : Int
  height : Int
  lines : Array[String]
  selected_line : Int?
}

///|
fn min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn text_length(value : String) -> Int {
  value.to_array().length()
}

///|
fn truncate_text(value : String, width : Int) -> String {
  if width <= 0 {
    ""
  } else {
    let chars = value.to_array()
    if chars.length() <= width {
      value
    } else if width == 1 {
      "…"
    } else {
      let clipped : Array[Char] = []
      for index in 0..<(width - 1) {
        clipped.push(chars[index])
      }
      clipped.push('…')
      String::from_array(clipped)
    }
  }
}

///|
fn padded_text(value : String, width : Int) -> String {
  let clipped = truncate_text(value, width)
  let chars = clipped.to_array()
  let output : Array[Char] = []
  for character in chars {
    output.push(character)
  }
  while output.length() < width {
    output.push(' ')
  }
  String::from_array(output)
}

///|
fn column_widths(view : @ops.View, screen_width : Int) -> Array[Int] {
  let widths : Array[Int] = []
  for column_position in 0..<@ops.column_count(view) {
    let column = @ops.column_at(view, column_position).unwrap()
    let mut width = min_int(32, max_int(1, text_length(column.name)))
    for row_position in 0..<@ops.row_count(view) {
      let cell = @ops.cell_at(view, row_position, column_position).unwrap()
      width = max_int(
        width,
        min_int(32, text_length(@ops.cell_to_string(cell))),
      )
    }
    widths.push(width)
  }
  let columns = widths.length()
  if columns == 0 {
    return widths
  }
  let overhead = columns * 3 + 1
  let available = max_int(columns, screen_width - overhead)
  let mut extra = available - columns
  let fitted : Array[Int] = []
  for width in widths {
    let added = min_int(width - 1, extra)
    fitted.push(1 + added)
    extra = extra - added
  }
  fitted
}

///|
fn render_header(view : @ops.View, widths : Array[Int]) -> String {
  let line : Array[Char] = ['|']
  for column_position in 0..<@ops.column_count(view) {
    line.push(' ')
    let column = @ops.column_at(view, column_position).unwrap()
    for
      character in padded_text(column.name, widths[column_position]).to_array() {
      line.push(character)
    }
    line.push(' ')
    line.push('|')
  }
  String::from_array(line)
}

///|
fn render_divider(widths : Array[Int]) -> String {
  let line : Array[Char] = ['+']
  for width in widths {
    for _ in 0..<(width + 2) {
      line.push('-')
    }
    line.push('+')
  }
  String::from_array(line)
}

///|
fn render_row(
  view : @ops.View,
  row_position : Int,
  widths : Array[Int],
  selected : Bool,
) -> String {
  let line : Array[Char] = [if selected { '>' } else { '|' }]
  for column_position in 0..<@ops.column_count(view) {
    line.push(' ')
    let cell = @ops.cell_at(view, row_position, column_position).unwrap()
    for
      character in padded_text(
        @ops.cell_to_string(cell),
        widths[column_position],
      ).to_array() {
      line.push(character)
    }
    line.push(' ')
    line.push('|')
  }
  String::from_array(line)
}

///|
fn render_status(
  view : @ops.View,
  first_row : Int,
  visible_rows : Int,
  cursor_row : Int,
  cursor_column : Int,
) -> String {
  let total = @ops.row_count(view)
  let first = if total == 0 { 0 } else { first_row + 1 }
  let last = first_row + visible_rows
  "Rows \{first}-\{last}/\{total} | Cols \{@ops.column_count(view)} | Cursor \{cursor_row + 1},\{cursor_column + 1}"
}

///|
pub fn render(
  view : @ops.View,
  width : Int,
  height : Int,
  options : RenderOptions,
) -> Screen {
  render_with_status(view, width, height, options, None)
}

///|
pub fn render_with_status(
  view : @ops.View,
  width : Int,
  height : Int,
  options : RenderOptions,
  status_override : String?,
) -> Screen {
  let safe_width = max_int(0, width)
  let safe_height = max_int(0, height)
  let first_row = min_int(@ops.row_count(view), max_int(0, options.first_row))
  let widths = column_widths(view, safe_width)
  let lines : Array[String] = []
  let mut selected_line : Int? = None
  let mut visible_rows = 0
  if safe_height == 1 {
    let status = match status_override {
      Some(value) => value
      None =>
        render_status(
          view,
          first_row,
          0,
          options.cursor_row,
          options.cursor_column,
        )
    }
    lines.push(truncate_text(status, safe_width))
  } else if safe_height >= 2 {
    lines.push(render_header(view, widths))
    lines.push(render_divider(widths))
    let capacity = max_int(0, safe_height - 3)
    visible_rows = min_int(capacity, @ops.row_count(view) - first_row)
    for offset in 0..<visible_rows {
      let row_position = first_row + offset
      let selected = row_position == options.cursor_row
      if selected {
        selected_line = Some(lines.length())
      }
      lines.push(render_row(view, row_position, widths, selected))
    }
    if safe_height >= 3 {
      let status = match status_override {
        Some(value) => value
        None =>
          render_status(
            view,
            first_row,
            visible_rows,
            options.cursor_row,
            options.cursor_column,
          )
      }
      lines.push(truncate_text(status, safe_width))
    }
  }
  while lines.length() < safe_height {
    lines.push("")
  }
  if lines.length() > safe_height {
    lines.truncate(safe_height)
  }
  { width: safe_width, height: safe_height, lines, selected_line, }
}

///|
pub fn to_ansi(screen : Screen) -> String {
  let output : Array[Char] = []
  for character in "\u{001b}[2J\u{001b}[H".to_array() {
    output.push(character)
  }
  for line_index, line in screen.lines {
    if screen.selected_line == Some(line_index) {
      for character in "\u{001b}[7m".to_array() {
        output.push(character)
      }
    }
    for character in line.to_array() {
      output.push(character)
    }
    if screen.selected_line == Some(line_index) {
      for character in "\u{001b}[0m".to_array() {
        output.push(character)
      }
    }
    if line_index + 1 < screen.lines.length() {
      output.push('\r')
      output.push('\n')
    }
  }
  String::from_array(output)
}
