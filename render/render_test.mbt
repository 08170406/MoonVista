///|
test "snapshot renders headers rows and status at the requested height" {
  let view = @ops.from_records(["name", "score"], [["Ada", "5"]]).unwrap()
  let screen = render(view, 40, 4, {
    first_row: 0,
    cursor_row: 0,
    cursor_column: 0,
  })
  assert_eq(screen.lines, [
    "| name | score |", "+------+-------+", "> Ada  | 5     |", "Rows 1-1/1 | Cols 2 | Cursor 1,1",
  ])
}

///|
test "narrow snapshots truncate headers and highlight the cursor cell" {
  let view = @ops.from_records(["name", "score"], [["Ada", "12345"]]).unwrap()
  let screen = render(view, 14, 4, {
    first_row: 0,
    cursor_row: 0,
    cursor_column: 1,
  })
  assert_eq(screen.lines, [
    "| name | sc… |", "+------+-----+", "> Ada  | 12… |", "Rows 1-1/1 | …",
  ])
}

///|
test "ANSI serialization clears the terminal and inverts the selected row" {
  let view = @ops.from_records(["name", "score"], [["Ada", "5"]]).unwrap()
  let screen = render(view, 40, 4, {
    first_row: 0,
    cursor_row: 0,
    cursor_column: 0,
  })
  assert_eq(
    to_ansi(screen),
    "\u{001b}[2J\u{001b}[H| name | score |\r\n+------+-------+\r\n" +
    "\u{001b}[7m> Ada  | 5     |\u{001b}[0m\r\nRows 1-1/1 | Cols 2 | Cursor 1,1",
  )
}
