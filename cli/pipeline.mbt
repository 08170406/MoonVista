///|
pub(all) struct CommandOutput {
  body : String
  stats_report : String
  output_path : String?
  is_export : Bool
}

///|
fn load_error_message(error : @loaders.LoadError) -> String {
  match error {
    @loaders.LoadError::EmptyInput => "input is empty"
    @loaders.LoadError::InvalidCsv(position) =>
      "invalid CSV near character \{position}"
    @loaders.LoadError::UnterminatedCsvQuote => "unterminated CSV quote"
    @loaders.LoadError::InvalidJson => "invalid JSON syntax"
    @loaders.LoadError::InvalidJsonShape =>
      "JSON must be an array of objects (or one object per JSONL line)"
    @loaders.LoadError::RaggedRow(row, expected, actual) =>
      "CSV row \{row} has \{actual} fields; expected \{expected}"
  }
}

///|
pub fn parse_input(
  path : String,
  content : String,
) -> Result[@table.Table, CliError] {
  let format = match detect_input_format(path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match format {
    InputFormat::Csv =>
      match @loaders.parse_csv(content) {
        Ok(table) => Ok(table)
        Err(error) => Err(InvalidInput(load_error_message(error)))
      }
    InputFormat::Json =>
      match @loaders.parse_json(content) {
        Ok(table) => Ok(table)
        Err(error) => Err(InvalidInput(load_error_message(error)))
      }
    InputFormat::JsonLines =>
      match @loaders.parse_jsonl(content) {
        Ok(table) => Ok(table)
        Err(error) => Err(InvalidInput(load_error_message(error)))
      }
  }
}

///|
pub fn load_table(path : String) -> Result[@table.Table, CliError] {
  let content = @fs.read_file_to_string(path) catch {
    @fs.IOError::IOError(_) => return Err(FileError(path))
  }
  parse_input(path, content)
}

///|
fn append_text(output : Array[Char], text : String) -> Unit {
  for character in text.to_array() {
    output.push(character)
  }
}

///|
fn make_stats_report(
  view : @ops.View,
  columns : Array[String],
) -> Result[String, CliError] {
  let output : Array[Char] = []
  for column in columns {
    let summary = match @ops.stats(view, column) {
      Ok(value) => value
      Err(@ops.OpsError::UnknownColumn(name)) => return Err(UnknownColumn(name))
    }
    let mean = match summary.mean {
      Some(value) => "\{value}"
      None => "n/a"
    }
    append_text(
      output,
      "Stats \{column}: count=\{summary.count}, nulls=\{summary.nulls}, unique=\{summary.unique}, min=\{summary.min.unwrap_or("n/a")}, max=\{summary.max.unwrap_or("n/a")}, mean=\{mean}\n",
    )
  }
  Ok(String::from_array(output))
}

///|
fn screen_text(view : @ops.View) -> String {
  let screen = @render.render(view, 120, 30, {
    first_row: 0,
    cursor_row: 0,
    cursor_column: 0,
  })
  let output : Array[Char] = []
  for line in screen.lines {
    append_text(output, line)
    output.push('\n')
  }
  String::from_array(output)
}

///|
pub fn execute_table(
  table : @table.Table,
  options : CliOptions,
) -> Result[CommandOutput, CliError] {
  let view = match apply_options(@ops.from_table(table), options) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let stats_report = match make_stats_report(view, options.stats_columns) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (body, is_export) = match options.export_format {
    ExportFormat::Screen => (screen_text(view), false)
    ExportFormat::Csv => (@ops.export_csv(view), true)
    ExportFormat::Json => (@ops.export_json(view), true)
  }
  Ok({ body, stats_report, output_path: options.output_path, is_export, })
}

///|
pub fn execute(options : CliOptions) -> Result[CommandOutput, CliError] {
  match options.output_path {
    Some(path) =>
      if @fs.path_exists(path) {
        return Err(OutputAlreadyExists(path))
      }
    None => ()
  }
  let path = match options.input_path {
    Some(value) => value
    None => return Err(MissingInput)
  }
  let table = match load_table(path) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  execute_table(table, options)
}

///|
pub fn usage() -> String {
  let lines = [
    "MoonVista — inspect CSV, JSON, and JSONL files", "", "Usage:", "  moon run cmd/main -- <file> [options]",
    "", "Options:", "  --sort <column> <asc|desc>      Sort by a column (repeatable)",
    "  --filter <column> <op> <value>  Filter rows (repeatable)", "  --stats <column>                Print column statistics (repeatable)",
    "  --export <csv|json>             Export the current view", "  --out <path>                    Write an export to a file",
    "  --repl                          Start the line-oriented workbench", "  -h, --help                      Show this help",
    "", "Filter operators: =, !=, contains, >, >=, <, <=, is-null, is-not-null",
    "", "REPL commands: up/down, left/right, page-up/page-down, search <text>,",
    "  filter <value>, sort, clear, help, quit", "", "Examples:", "  moon run cmd/main -- samples/customers.csv",
    "  moon run cmd/main -- samples/customers.csv --filter country = Japan --sort score desc",
    "  moon run cmd/main -- samples/customers.csv --export json --out filtered.json",
    "  moon run cmd/main -- samples/customers.csv --repl",
  ]
  let output : Array[Char] = []
  for line in lines {
    append_text(output, line)
    output.push('\n')
  }
  String::from_array(output)
}

///|
pub fn error_message(error : CliError) -> String {
  match error {
    MissingInput => "missing input file (try --help)"
    MissingValue(option) => "missing value after \{option}"
    MultipleInputs => "only one input file may be specified"
    UnknownOption(option) => "unknown option: \{option}"
    InvalidSortDirection(direction) =>
      "sort direction must be asc or desc, got \{direction}"
    InvalidFilterOperator(operator) =>
      "unsupported filter operator: \{operator}"
    InvalidExportFormat(format) =>
      "export format must be csv or json, got \{format}"
    OutputRequiresExport => "--out requires --export csv or --export json"
    UnsupportedInputFormat(path) =>
      "unsupported file extension for \{path}; use .csv, .json, or .jsonl"
    FileError(path) => "could not read input file: \{path}"
    InvalidInput(message) => "could not parse input: \{message}"
    UnknownColumn(name) => "unknown column: \{name}"
    StatsWithExportOnStdout =>
      "--stats with --export requires --out so the export stays valid"
    ReplWithExport => "--repl cannot be combined with --export"
    ReplWithStats => "run --stats separately before starting --repl"
    OutputAlreadyExists(path) => "refusing to overwrite existing file: \{path}"
  }
}
