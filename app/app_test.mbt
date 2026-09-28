///|
test "navigation clamps and scrolls with the cursor" {
  let view = @ops.from_records(["name"], [["Ada"], ["Lin"], ["Bo"]]).unwrap()
  let state = initial(view)
  let state = update(state, Key::Down, 2)
  assert_eq(cursor_row(state), 1)
  let state = update(state, Key::PageDown, 2)
  assert_eq(cursor_row(state), 2)
  assert_eq(first_row(state), 1)
  let state = update(state, Key::Down, 2)
  assert_eq(cursor_row(state), 2)
  let state = update(state, Key::Home, 2)
  assert_eq(cursor_row(state), 0)
  assert_eq(first_row(state), 0)
}

///|
test "search input filters the view and Escape cancels editing" {
  let view = @ops.from_records(["name", "city"], [
    ["Ada", "Paris"],
    ["Lin", "Tokyo"],
    ["Bo", "Osaka"],
  ]).unwrap()
  let state = update(initial(view), Key::Char('/'), 10)
  assert_eq(mode(state), AppMode::SearchInput)
  let state = update(state, Key::Char('T'), 10)
  let state = update(state, Key::Char('o'), 10)
  let state = update(state, Key::Char('k'), 10)
  let state = update(state, Key::Char('y'), 10)
  let state = update(state, Key::Char('o'), 10)
  let state = update(state, Key::Enter, 10)
  assert_eq(current_rows(state), 1)
  assert_eq(displayed_cell(state, 0, 1), Some("Tokyo"))
  let state = update(state, Key::Char('/'), 10)
  assert_eq(mode(state), AppMode::SearchInput)
  let state = update(state, Key::Escape, 10)
  assert_eq(mode(state), AppMode::Browse)
  assert_eq(current_rows(state), 1)
}

///|
test "filter applies equality to the selected column and clear resets data" {
  let view = @ops.from_records(["city", "age"], [
    ["Paris", "20"],
    ["Tokyo", "31"],
    ["Osaka", "20"],
  ]).unwrap()
  let state = update(initial(view), Key::Right, 10)
  let state = update(state, Key::Char('f'), 10)
  let state = update(state, Key::Char('2'), 10)
  let state = update(state, Key::Char('0'), 10)
  let state = update(state, Key::Enter, 10)
  assert_eq(current_rows(state), 2)
  let state = update(state, Key::Char('c'), 10)
  assert_eq(current_rows(state), 3)
}

///|
test "sort key toggles direction and help screen is renderable" {
  let view = @ops.from_records(["id"], [["3"], ["1"], ["2"]]).unwrap()
  let state = update(initial(view), Key::Char('s'), 10)
  assert_eq(displayed_cell(state, 0, 0), Some("1"))
  let state = update(state, Key::Char('s'), 10)
  assert_eq(displayed_cell(state, 0, 0), Some("3"))
  let help_state = update(state, Key::Char('?'), 10)
  assert_eq(mode(help_state), AppMode::Help)
  assert_eq(draw(help_state, 40, 8).lines.length(), 8)
  let quit_state = update(state, Key::Char('q'), 10)
  assert_eq(should_quit(quit_state), true)
}

///|
test "empty views keep cursor and scroll positions nonnegative" {
  let view = @ops.from_records(["name"], []).unwrap()
  let state = update(initial(view), Key::End, 5)
  assert_eq(cursor_row(state), 0)
  assert_eq(first_row(state), 0)
  assert_eq(current_rows(state), 0)
}
