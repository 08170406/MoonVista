///|
pub(all) enum ExportFormat {
  Screen
  Csv
  Json
} derive(Eq, Debug)

///|
pub(all) enum InputFormat {
  Csv
  Json
  JsonLines
} derive(Eq, Debug)

///|
pub(all) struct CliOptions {
  input_path : String?
  sorts : Array[@ops.SortKey]
  filters : Array[@ops.Filter]
  stats_columns : Array[String]
  export_format : ExportFormat
  output_path : String?
  help : Bool
  repl : Bool
}

///|
pub(all) enum CliError {
  MissingInput
  MissingValue(String)
  MultipleInputs
  UnknownOption(String)
  InvalidSortDirection(String)
  InvalidFilterOperator(String)
  InvalidExportFormat(String)
  OutputRequiresExport
  UnsupportedInputFormat(String)
  FileError(String)
  InvalidInput(String)
  UnknownColumn(String)
  StatsWithExportOnStdout
  ReplWithExport
  ReplWithStats
  OutputAlreadyExists(String)
} derive(Eq, Debug)

///|
fn empty_options() -> CliOptions {
  {
    input_path: None,
    sorts: [],
    filters: [],
    stats_columns: [],
    export_format: ExportFormat::Screen,
    output_path: None,
    help: false,
    repl: false,
  }
}

///|
fn looks_like_option(value : String) -> Bool {
  let chars = value.to_array()
  chars.length() >= 2 && chars[0] == '-' && chars[1] == '-'
}

///|
fn parse_filter_operator(value : String) -> @ops.FilterOp? {
  match value {
    "=" | "==" => Some(@ops.FilterOp::Eq)
    "!=" => Some(@ops.FilterOp::Ne)
    "contains" => Some(@ops.FilterOp::Contains)
    ">" => Some(@ops.FilterOp::Gt)
    ">=" => Some(@ops.FilterOp::Ge)
    "<" => Some(@ops.FilterOp::Lt)
    "<=" => Some(@ops.FilterOp::Le)
    "is-null" => Some(@ops.FilterOp::IsNull)
    "is-not-null" => Some(@ops.FilterOp::IsNotNull)
    _ => None
  }
}

///|
pub fn parse_args(args : Array[String]) -> Result[CliOptions, CliError] {
  let sorts : Array[@ops.SortKey] = []
  let filters : Array[@ops.Filter] = []
  let stats_columns : Array[String] = []
  let mut export_format = ExportFormat::Screen
  let mut input_path : String? = None
  let mut output_path : String? = None
  let mut repl = false
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    match argument {
      "--help" | "-h" => return Ok({ ..empty_options(), help: true, })
      "--repl" => {
        repl = true
        index = index + 1
      }
      "--sort" => {
        if index + 2 >= args.length() {
          return Err(MissingValue("--sort"))
        }
        let column = args[index + 1]
        let direction = args[index + 2]
        let descending = match direction {
          "asc" => false
          "desc" => true
          _ => return Err(InvalidSortDirection(direction))
        }
        sorts.push({ column, descending, })
        index = index + 3
      }
      "--filter" => {
        if index + 2 >= args.length() {
          return Err(MissingValue("--filter"))
        }
        let column = args[index + 1]
        let operator_text = args[index + 2]
        let operator = match parse_filter_operator(operator_text) {
          Some(value) => value
          None => return Err(InvalidFilterOperator(operator_text))
        }
        let (value, consumed) = match operator {
          @ops.FilterOp::IsNull | @ops.FilterOp::IsNotNull => ("", 3)
          _ => {
            if index + 3 >= args.length() {
              return Err(MissingValue("--filter"))
            }
            (args[index + 3], 4)
          }
        }
        filters.push({ column, op: operator, value, })
        index = index + consumed
      }
      "--stats" => {
        if index + 1 >= args.length() {
          return Err(MissingValue("--stats"))
        }
        stats_columns.push(args[index + 1])
        index = index + 2
      }
      "--export" => {
        if index + 1 >= args.length() {
          return Err(MissingValue("--export"))
        }
        export_format = match args[index + 1] {
          "csv" => ExportFormat::Csv
          "json" => ExportFormat::Json
          value => return Err(InvalidExportFormat(value))
        }
        index = index + 2
      }
      "--out" => {
        if index + 1 >= args.length() {
          return Err(MissingValue("--out"))
        }
        if output_path is Some(_) {
          return Err(UnknownOption("--out specified more than once"))
        }
        output_path = Some(args[index + 1])
        index = index + 2
      }
      _ => {
        if looks_like_option(argument) {
          return Err(UnknownOption(argument))
        }
        if input_path is Some(_) {
          return Err(MultipleInputs)
        }
        input_path = Some(argument)
        index = index + 1
      }
    }
  }
  if input_path is None {
    return Err(MissingInput)
  }
  if output_path is Some(_) && export_format == ExportFormat::Screen {
    return Err(OutputRequiresExport)
  }
  if !stats_columns.is_empty() &&
    export_format != ExportFormat::Screen &&
    output_path is None {
    return Err(StatsWithExportOnStdout)
  }
  if repl && export_format != ExportFormat::Screen {
    return Err(ReplWithExport)
  }
  if repl && !stats_columns.is_empty() {
    return Err(ReplWithStats)
  }
  Ok({
    input_path,
    sorts,
    filters,
    stats_columns,
    export_format,
    output_path,
    help: false,
    repl,
  })
}

///|
pub fn apply_options(
  initial_view : @ops.View,
  options : CliOptions,
) -> Result[@ops.View, CliError] {
  let mut view = initial_view
  for condition in options.filters {
    match @ops.filter(view, condition) {
      Ok(filtered) => view = filtered
      Err(@ops.OpsError::UnknownColumn(name)) => return Err(UnknownColumn(name))
    }
  }
  if !options.sorts.is_empty() {
    match @ops.sort(view, options.sorts) {
      Ok(sorted) => view = sorted
      Err(@ops.OpsError::UnknownColumn(name)) => return Err(UnknownColumn(name))
    }
  }
  Ok(view)
}

///|
fn has_suffix(value : String, suffix : String) -> Bool {
  let value_chars = value.to_array()
  let suffix_chars = suffix.to_array()
  if suffix_chars.length() > value_chars.length() {
    return false
  }
  let offset = value_chars.length() - suffix_chars.length()
  for index in 0..<suffix_chars.length() {
    if value_chars[offset + index] != suffix_chars[index] {
      return false
    }
  }
  true
}

///|
pub fn detect_input_format(path : String) -> Result[InputFormat, CliError] {
  if has_suffix(path, ".csv") {
    Ok(InputFormat::Csv)
  } else if has_suffix(path, ".json") {
    Ok(InputFormat::Json)
  } else if has_suffix(path, ".jsonl") {
    Ok(InputFormat::JsonLines)
  } else {
    Err(UnsupportedInputFormat(path))
  }
}
