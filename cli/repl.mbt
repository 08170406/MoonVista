///|
pub fn initial_repl_state(
  options : CliOptions,
) -> Result[@app.AppState, CliError] {
  let path = match options.input_path {
    Some(value) => value
    None => return Err(MissingInput)
  }
  let table = match load_table(path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let view = match apply_options(@ops.from_table(table), options) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok(@app.initial(view))
}

///|
pub fn repl_frame(state : @app.AppState) -> String {
  let screen = @app.draw(state, 100, 16)
  let output : Array[Char] = []
  for line in screen.lines {
    append_text(output, line)
    output.push('\n')
  }
  String::from_array(output)
}

///|
fn starts_with_text(value : String, prefix : String) -> Bool {
  let value_chars = value.to_array()
  let prefix_chars = prefix.to_array()
  if value_chars.length() < prefix_chars.length() {
    return false
  }
  for index in 0..<prefix_chars.length() {
    if value_chars[index] != prefix_chars[index] {
      return false
    }
  }
  true
}

///|
fn text_after(value : String, prefix : String) -> String {
  let value_chars = value.to_array()
  let prefix_length = prefix.to_array().length()
  let result : Array[Char] = []
  for index in prefix_length..<value_chars.length() {
    result.push(value_chars[index])
  }
  String::from_array(result)
}

///|
fn apply_text_command(
  state : @app.AppState,
  text : String,
  first_key : Char,
  page_size : Int,
) -> @app.AppState {
  let mut next = @app.update(state, @app.Key::Char(first_key), page_size)
  for character in text.to_array() {
    next = @app.update(next, @app.Key::Char(character), page_size)
  }
  @app.update(next, @app.Key::Enter, page_size)
}

///|
pub fn apply_repl_command(
  state : @app.AppState,
  command : String,
  page_size : Int,
) -> @app.AppState {
  let command = command.trim().to_owned()
  if starts_with_text(command, "search ") {
    apply_text_command(state, text_after(command, "search "), '/', page_size)
  } else if starts_with_text(command, "filter ") {
    apply_text_command(state, text_after(command, "filter "), 'f', page_size)
  } else {
    match command {
      "up" | "k" => @app.update(state, @app.Key::Up, page_size)
      "down" | "j" => @app.update(state, @app.Key::Down, page_size)
      "left" | "h" => @app.update(state, @app.Key::Left, page_size)
      "right" | "l" => @app.update(state, @app.Key::Right, page_size)
      "page-up" => @app.update(state, @app.Key::PageUp, page_size)
      "page-down" => @app.update(state, @app.Key::PageDown, page_size)
      "home" => @app.update(state, @app.Key::Home, page_size)
      "end" => @app.update(state, @app.Key::End, page_size)
      "sort" | "s" => @app.update(state, @app.Key::Char('s'), page_size)
      "clear" | "c" => @app.update(state, @app.Key::Char('c'), page_size)
      "help" | "?" => @app.update(state, @app.Key::Char('?'), page_size)
      "quit" | "q" => @app.update(state, @app.Key::Char('q'), page_size)
      "escape" => @app.update(state, @app.Key::Escape, page_size)
      _ => state
    }
  }
}
