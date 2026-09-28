///|
pub(all) enum AppMode {
  Browse
  SearchInput
  FilterInput
  Help
} derive(Eq, Debug)

///|
pub(all) enum Key {
  Char(Char)
  Up
  Down
  Left
  Right
  PageUp
  PageDown
  Home
  End
  Enter
  Escape
  Backspace
} derive(Eq, Debug)

///|
pub struct AppState {
  original_view : @ops.View
  view : @ops.View
  cursor_row : Int
  cursor_column : Int
  first_row : Int
  mode : AppMode
  input : String
  message : String
  quit : Bool
  descending : Bool
}

///|
fn make_state(
  original_view : @ops.View,
  view : @ops.View,
  cursor_row : Int,
  cursor_column : Int,
  first_row : Int,
  mode : AppMode,
  input : String,
  message : String,
  quit : Bool,
  descending : Bool,
) -> AppState {
  {
    original_view,
    view,
    cursor_row,
    cursor_column,
    first_row,
    mode,
    input,
    message,
    quit,
    descending,
  }
}

///|
pub fn initial(view : @ops.View) -> AppState {
  make_state(view, view, 0, 0, 0, Browse, "", "", false, true)
}

///|
pub fn mode(state : AppState) -> AppMode {
  state.mode
}

///|
pub fn cursor_row(state : AppState) -> Int {
  state.cursor_row
}

///|
pub fn cursor_column(state : AppState) -> Int {
  state.cursor_column
}

///|
pub fn first_row(state : AppState) -> Int {
  state.first_row
}

///|
pub fn current_rows(state : AppState) -> Int {
  @ops.row_count(state.view)
}

///|
pub fn current_columns(state : AppState) -> Int {
  @ops.column_count(state.view)
}

///|
pub fn status_message(state : AppState) -> String {
  state.message
}

///|
pub fn should_quit(state : AppState) -> Bool {
  state.quit
}

///|
pub fn displayed_cell(
  state : AppState,
  row_position : Int,
  column_position : Int,
) -> String? {
  match @ops.cell_at(state.view, row_position, column_position) {
    Some(cell) => Some(@ops.cell_to_string(cell))
    None => None
  }
}

///|
fn clamp(value : Int, minimum : Int, maximum : Int) -> Int {
  let upper = if maximum < minimum { minimum } else { maximum }
  if value < minimum {
    minimum
  } else if value > upper {
    upper
  } else {
    value
  }
}

///|
fn adjusted_first_row(cursor : Int, first_row : Int, page_size : Int) -> Int {
  let safe_page_size = if page_size < 1 { 1 } else { page_size }
  if cursor < first_row {
    cursor
  } else if cursor >= first_row + safe_page_size {
    cursor - safe_page_size + 1
  } else {
    first_row
  }
}

///|
fn append_char(text : String, character : Char) -> String {
  let chars = text.to_array()
  chars.push(character)
  String::from_array(chars)
}

///|
fn remove_last_char(text : String) -> String {
  let chars = text.to_array()
  let _ = chars.pop()
  String::from_array(chars)
}

///|
fn search_mode(state : AppState, key : Key) -> AppState {
  match key {
    Escape =>
      make_state(
        state.original_view,
        state.view,
        state.cursor_row,
        state.cursor_column,
        state.first_row,
        Browse,
        "",
        "Search cancelled",
        false,
        state.descending,
      )
    Enter => {
      let view = @ops.search(state.view, state.input)
      make_state(
        state.original_view,
        view,
        0,
        clamp(state.cursor_column, 0, @ops.column_count(view) - 1),
        0,
        Browse,
        "",
        "Matched \{@ops.row_count(view)} rows",
        false,
        state.descending,
      )
    }
    Backspace =>
      make_state(
        state.original_view,
        state.view,
        state.cursor_row,
        state.cursor_column,
        state.first_row,
        SearchInput,
        remove_last_char(state.input),
        "",
        false,
        state.descending,
      )
    Char(character) =>
      make_state(
        state.original_view,
        state.view,
        state.cursor_row,
        state.cursor_column,
        state.first_row,
        SearchInput,
        append_char(state.input, character),
        "",
        false,
        state.descending,
      )
    _ => state
  }
}

///|
fn filter_mode(state : AppState) -> AppState {
  if state.input.is_empty() {
    return make_state(
      state.original_view,
      state.view,
      state.cursor_row,
      state.cursor_column,
      state.first_row,
      Browse,
      "",
      "Filter needs a value",
      false,
      state.descending,
    )
  }
  match @ops.column_at(state.view, state.cursor_column) {
    None =>
      make_state(
        state.original_view,
        state.view,
        state.cursor_row,
        state.cursor_column,
        state.first_row,
        Browse,
        "",
        "No column selected",
        false,
        state.descending,
      )
    Some(column) =>
      match
        @ops.filter(state.view, {
          column: column.name,
          op: @ops.FilterOp::Eq,
          value: state.input,
        }) {
        Ok(view) =>
          make_state(
            state.original_view,
            view,
            0,
            clamp(state.cursor_column, 0, @ops.column_count(view) - 1),
            0,
            Browse,
            "",
            "Matched \{@ops.row_count(view)} rows",
            false,
            state.descending,
          )
        Err(_) =>
          make_state(
            state.original_view,
            state.view,
            state.cursor_row,
            state.cursor_column,
            state.first_row,
            Browse,
            "",
            "Filter could not be applied",
            false,
            state.descending,
          )
      }
  }
}

///|
fn help_view() -> @ops.View {
  @ops.from_records(["Key", "Action"], [
    ["↑ / k", "Move up"],
    ["↓ / j", "Move down"],
    ["← / h", "Move left"],
    ["→ / l", "Move right"],
    ["PgUp / PgDn", "Move by page"],
    ["Home / End", "Jump to first or last row"],
    ["/", "Search visible cells"],
    ["f", "Filter selected column by equality"],
    ["s", "Toggle sort direction"],
    ["c", "Clear filters and search"],
    ["? / Esc", "Return to the table"],
    ["q", "Quit"],
  ]).unwrap()
}

///|
pub fn update(state : AppState, key : Key, page_size : Int) -> AppState {
  if state.quit {
    return state
  }
  match state.mode {
    SearchInput => search_mode(state, key)
    FilterInput =>
      match key {
        Escape =>
          make_state(
            state.original_view,
            state.view,
            state.cursor_row,
            state.cursor_column,
            state.first_row,
            Browse,
            "",
            "Filter cancelled",
            false,
            state.descending,
          )
        Enter => filter_mode(state)
        Backspace =>
          make_state(
            state.original_view,
            state.view,
            state.cursor_row,
            state.cursor_column,
            state.first_row,
            FilterInput,
            remove_last_char(state.input),
            "",
            false,
            state.descending,
          )
        Char(character) =>
          make_state(
            state.original_view,
            state.view,
            state.cursor_row,
            state.cursor_column,
            state.first_row,
            FilterInput,
            append_char(state.input, character),
            "",
            false,
            state.descending,
          )
        _ => state
      }
    Help =>
      match key {
        Escape | Char('?') =>
          make_state(
            state.original_view,
            state.view,
            state.cursor_row,
            state.cursor_column,
            state.first_row,
            Browse,
            "",
            "",
            false,
            state.descending,
          )
        _ => state
      }
    Browse => {
      let rows = @ops.row_count(state.view)
      let columns = @ops.column_count(state.view)
      let safe_page = if page_size < 1 { 1 } else { page_size }
      let mut next_row = state.cursor_row
      let mut next_column = state.cursor_column
      let mut next_first = state.first_row
      match key {
        Up | Char('k') => next_row = clamp(next_row - 1, 0, rows - 1)
        Down | Char('j') => next_row = clamp(next_row + 1, 0, rows - 1)
        Left | Char('h') => next_column = clamp(next_column - 1, 0, columns - 1)
        Right | Char('l') =>
          next_column = clamp(next_column + 1, 0, columns - 1)
        PageUp => next_row = clamp(next_row - safe_page, 0, rows - 1)
        PageDown => next_row = clamp(next_row + safe_page, 0, rows - 1)
        Home => {
          next_row = 0
          next_first = 0
        }
        End => next_row = clamp(rows - 1, 0, rows - 1)
        _ => ()
      }
      next_first = adjusted_first_row(next_row, next_first, safe_page)
      match key {
        Char('q') =>
          make_state(
            state.original_view,
            state.view,
            state.cursor_row,
            state.cursor_column,
            state.first_row,
            Browse,
            "",
            "",
            true,
            state.descending,
          )
        Char('/') =>
          make_state(
            state.original_view,
            state.view,
            state.cursor_row,
            state.cursor_column,
            state.first_row,
            SearchInput,
            "",
            "",
            false,
            state.descending,
          )
        Char('f') =>
          make_state(
            state.original_view,
            state.view,
            state.cursor_row,
            state.cursor_column,
            state.first_row,
            FilterInput,
            "",
            "",
            false,
            state.descending,
          )
        Char('?') =>
          make_state(
            state.original_view,
            state.view,
            state.cursor_row,
            state.cursor_column,
            state.first_row,
            Help,
            "",
            "",
            false,
            state.descending,
          )
        Char('c') =>
          make_state(
            state.original_view,
            state.original_view,
            0,
            0,
            0,
            Browse,
            "",
            "View reset",
            false,
            true,
          )
        Char('s') =>
          match @ops.column_at(state.view, state.cursor_column) {
            None =>
              make_state(
                state.original_view,
                state.view,
                next_row,
                next_column,
                next_first,
                Browse,
                "",
                "No column selected",
                false,
                state.descending,
              )
            Some(column) => {
              let descending = !state.descending
              match
                @ops.sort(state.view, [{ column: column.name, descending, }]) {
                Ok(view) =>
                  make_state(
                    state.original_view,
                    view,
                    0,
                    state.cursor_column,
                    0,
                    Browse,
                    "",
                    if descending {
                      "Sorted descending"
                    } else {
                      "Sorted ascending"
                    },
                    false,
                    descending,
                  )
                Err(_) => state
              }
            }
          }
        _ =>
          make_state(
            state.original_view,
            state.view,
            next_row,
            next_column,
            next_first,
            Browse,
            "",
            "",
            false,
            state.descending,
          )
      }
    }
  }
}

///|
pub fn draw(state : AppState, width : Int, height : Int) -> @render.Screen {
  let view = if state.mode == Help { help_view() } else { state.view }
  let first_row = if state.mode == Help { 0 } else { state.first_row }
  let cursor_row = if state.mode == Help { 0 } else { state.cursor_row }
  let cursor_column = if state.mode == Help { 0 } else { state.cursor_column }
  let status = match state.mode {
    SearchInput => Some("Search> \{state.input}  Enter apply  Esc cancel")
    FilterInput => Some("Filter> \{state.input}  Enter apply  Esc cancel")
    Browse => if state.message.is_empty() { None } else { Some(state.message) }
    Help => None
  }
  @render.render_with_status(
    view,
    width,
    height,
    { first_row, cursor_row, cursor_column, },
    status,
  )
}
