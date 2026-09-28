///|
pub(all) enum LoadError {
  EmptyInput
  InvalidCsv(Int)
  UnterminatedCsvQuote
  InvalidJson
  InvalidJsonShape
  RaggedRow(Int, Int, Int)
} derive(Eq, Debug)

///|
fn csv_is_newline(value : Char) -> Bool {
  value == '\n' || value == '\r'
}

///|
fn finish_csv_field(field : Array[Char], row : Array[String]) -> Unit {
  row.push(String::from_array(field))
  field.truncate(0)
}

///|
fn finish_csv_row(
  field : Array[Char],
  row : Array[String],
  rows : Array[Array[String]],
) -> Unit {
  finish_csv_field(field, row)
  rows.push(row)
}

///|
fn blank_csv_row(row : Array[String]) -> Bool {
  for field in row {
    if !field.trim().is_empty() {
      return false
    }
  }
  true
}

///|
fn csv_rows(input : String) -> Result[Array[Array[String]], LoadError] {
  let chars = input.to_array()
  let mut index = 0
  if chars.length() > 0 && chars[0].to_int() == 65279 {
    index = 1
  }
  let field : Array[Char] = []
  let mut row : Array[String] = []
  let rows : Array[Array[String]] = []
  let mut quoted = false
  let mut after_quote = false
  let mut record_open = false
  while index < chars.length() {
    let current = chars[index]
    if quoted {
      if current == '"' {
        if index + 1 < chars.length() && chars[index + 1] == '"' {
          field.push('"')
          index = index + 2
        } else {
          quoted = false
          after_quote = true
          index = index + 1
        }
      } else {
        field.push(current)
        index = index + 1
      }
    } else if after_quote {
      if current == ',' {
        finish_csv_field(field, row)
        after_quote = false
        record_open = true
        index = index + 1
      } else if csv_is_newline(current) {
        finish_csv_row(field, row, rows)
        row = []
        after_quote = false
        record_open = false
        if current == '\r' &&
          index + 1 < chars.length() &&
          chars[index + 1] == '\n' {
          index = index + 2
        } else {
          index = index + 1
        }
      } else if current == ' ' || current == '\t' {
        index = index + 1
      } else {
        return Err(InvalidCsv(index + 1))
      }
    } else if current == ',' {
      finish_csv_field(field, row)
      record_open = true
      index = index + 1
    } else if csv_is_newline(current) {
      finish_csv_row(field, row, rows)
      row = []
      record_open = false
      if current == '\r' &&
        index + 1 < chars.length() &&
        chars[index + 1] == '\n' {
        index = index + 2
      } else {
        index = index + 1
      }
    } else if current == '"' {
      if field.length() == 0 {
        quoted = true
        record_open = true
        index = index + 1
      } else {
        return Err(InvalidCsv(index + 1))
      }
    } else {
      field.push(current)
      record_open = true
      index = index + 1
    }
  }
  if quoted {
    return Err(UnterminatedCsvQuote)
  }
  if record_open || field.length() > 0 || row.length() > 0 || after_quote {
    finish_csv_row(field, row, rows)
  }
  while rows.length() > 1 && blank_csv_row(rows[rows.length() - 1]) {
    let _ = rows.pop()
  }
  if rows.is_empty() {
    Err(EmptyInput)
  } else {
    Ok(rows)
  }
}

///|
fn table_from_csv_rows(
  rows : Array[Array[String]],
) -> Result[@table.Table, LoadError] {
  if rows.length() == 0 || blank_csv_row(rows[0]) {
    return Err(EmptyInput)
  }
  let headers = rows[0]
  let records : Array[Array[String]] = []
  for index in 1..<rows.length() {
    records.push(rows[index])
  }
  match @table.from_records(headers, records) {
    Ok(table) => Ok(table)
    Err(@table.TableError::TooManyFields(row, expected, actual)) =>
      Err(RaggedRow(row, expected, actual))
  }
}

///|
pub fn parse_csv(input : String) -> Result[@table.Table, LoadError] {
  match csv_rows(input) {
    Ok(rows) => table_from_csv_rows(rows)
    Err(error) => Err(error)
  }
}

///|
fn json_value_to_text(value : Json) -> String {
  match value {
    Json::String(text) => text
    Json::Null => ""
    _ => value.stringify()
  }
}

///|
fn collect_json_headers(objects : Array[Map[String, Json]]) -> Array[String] {
  let headers : Array[String] = []
  for object in objects {
    object.each(fn(key, _) {
      let mut exists = false
      for header in headers {
        if header == key {
          exists = true
        }
      }
      if !exists {
        headers.push(key)
      }
    })
  }
  headers.sort()
  let ascending_headers : Array[String] = []
  for index in 0..<headers.length() {
    ascending_headers.push(headers[headers.length() - index - 1])
  }
  ascending_headers
}

///|
fn table_from_json_objects(
  objects : Array[Map[String, Json]],
) -> Result[@table.Table, LoadError] {
  if objects.is_empty() {
    return Err(EmptyInput)
  }
  let headers = collect_json_headers(objects)
  if headers.is_empty() {
    return Err(InvalidJsonShape)
  }
  let records : Array[Array[String]] = []
  for object in objects {
    let row : Array[String] = []
    for header in headers {
      match object.get(header) {
        Some(value) => row.push(json_value_to_text(value))
        None => row.push("")
      }
    }
    records.push(row)
  }
  match @table.from_records(headers, records) {
    Ok(table) => Ok(table)
    Err(_) => Err(InvalidJsonShape)
  }
}

///|
fn parse_json_value(source : StringView) -> Result[Json, LoadError] {
  Ok(@json.parse(source)) catch {
    _ => Err(InvalidJson)
  }
}

///|
fn decode_json_object(
  source : StringView,
) -> Result[Map[String, Json], LoadError] {
  match parse_json_value(source) {
    Ok(Json::Object(object)) => Ok(object)
    Ok(_) => Err(InvalidJsonShape)
    Err(error) => Err(error)
  }
}

///|
pub fn parse_json(input : String) -> Result[@table.Table, LoadError] {
  match parse_json_value(input) {
    Ok(Json::Array(values)) => {
      let objects : Array[Map[String, Json]] = []
      for value in values {
        match value {
          Json::Object(object) => objects.push(object)
          _ => return Err(InvalidJsonShape)
        }
      }
      table_from_json_objects(objects)
    }
    Ok(_) => Err(InvalidJsonShape)
    Err(error) => Err(error)
  }
}

///|
pub fn parse_jsonl(input : String) -> Result[@table.Table, LoadError] {
  let chars = input.to_array()
  let line : Array[Char] = []
  let objects : Array[Map[String, Json]] = []
  for current in chars {
    if current == '\n' {
      let text = String::from_array(line).trim()
      if !text.is_empty() {
        match decode_json_object(text) {
          Ok(object) => objects.push(object)
          Err(error) => return Err(error)
        }
      }
      line.truncate(0)
    } else {
      line.push(current)
    }
  }
  let final_text = String::from_array(line).trim()
  if !final_text.is_empty() {
    match decode_json_object(final_text) {
      Ok(object) => objects.push(object)
      Err(error) => return Err(error)
    }
  }
  table_from_json_objects(objects)
}
