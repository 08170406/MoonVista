///|
pub(all) enum ColType {
  Int
  Float
  Bool
  Date
  Str
  Empty
} derive(Eq, Debug)

///|
pub(all) struct Column {
  name : String
  ctype : ColType
  nulls : Int
  confidence : Double
}

///|
pub(all) enum Cell {
  I(Int)
  F(Double)
  B(Bool)
  D(String)
  S(String)
  Null
} derive(Eq, Debug)

///|
pub(all) struct Table {
  columns : Array[Column]
  rows : Array[Array[Cell]]
}

///|
pub(all) enum TableError {
  TooManyFields(Int, Int, Int)
}

///|
fn is_integer(value : String) -> Bool {
  try {
    let _ = @string.parse_int(value.trim())
    true
  } catch {
    _ => false
  }
}

///|
fn is_number(value : String) -> Bool {
  try {
    let _ = @string.parse_double(value.trim())
    true
  } catch {
    _ => false
  }
}

///|
fn is_boolean(value : String) -> Bool {
  value.trim() == "true" || value.trim() == "false"
}

///|
fn digit_at(chars : Array[Char], index : Int) -> Int? {
  if index < 0 || index >= chars.length() {
    None
  } else {
    let value = chars[index].to_int()
    if value >= 48 && value <= 57 {
      Some(value - 48)
    } else {
      None
    }
  }
}

///|
fn is_date(value : String) -> Bool {
  let chars = value.trim().to_array()
  if chars.length() != 10 || chars[4] != '-' || chars[7] != '-' {
    false
  } else {
    match
      (
        digit_at(chars, 0),
        digit_at(chars, 1),
        digit_at(chars, 2),
        digit_at(chars, 3),
        digit_at(chars, 5),
        digit_at(chars, 6),
        digit_at(chars, 8),
        digit_at(chars, 9),
      ) {
      (
        Some(y0),
        Some(y1),
        Some(y2),
        Some(y3),
        Some(m0),
        Some(m1),
        Some(d0),
        Some(d1),
      ) => {
        let year = y0 * 1000 + y1 * 100 + y2 * 10 + y3
        let month = m0 * 10 + m1
        let day = d0 * 10 + d1
        let leap = year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
        let days = match month {
          2 => if leap { 29 } else { 28 }
          4 | 6 | 9 | 11 => 30
          1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
          _ => 0
        }
        year > 0 && day > 0 && day <= days
      }
      _ => false
    }
  }
}

///|
fn infer_type_and_confidence(samples : Array[String]) -> (ColType, Double) {
  let values : Array[String] = []
  for sample in samples {
    let trimmed = sample.trim()
    if !trimmed.is_empty() {
      values.push("\{trimmed}")
    }
  }
  if values.is_empty() {
    (Empty, 1.0)
  } else {
    let mut all_integer = true
    let mut all_number = true
    let mut all_boolean = true
    let mut all_date = true
    let mut number_count = 0
    let mut boolean_count = 0
    let mut date_count = 0
    let mut string_count = 0
    for value in values {
      let integer = is_integer(value)
      let number = is_number(value)
      let boolean = is_boolean(value)
      let date = is_date(value)
      all_integer = all_integer && integer
      all_number = all_number && number
      all_boolean = all_boolean && boolean
      all_date = all_date && date
      if number {
        number_count = number_count + 1
      } else if boolean {
        boolean_count = boolean_count + 1
      } else if date {
        date_count = date_count + 1
      } else {
        string_count = string_count + 1
      }
    }
    if all_integer {
      (Int, 1.0)
    } else if all_number {
      (Float, 1.0)
    } else if all_boolean {
      (Bool, 1.0)
    } else if all_date {
      (Date, 1.0)
    } else {
      let best = max_int(
        max_int(number_count, boolean_count),
        max_int(date_count, string_count),
      )
      (Str, best.to_double() / values.length().to_double())
    }
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
pub fn infer_type(samples : Array[String]) -> ColType {
  infer_type_and_confidence(samples).0
}

///|
fn cell_from_string(value : String, ctype : ColType) -> Cell {
  let trimmed = value.trim()
  if trimmed.is_empty() {
    Null
  } else {
    let text = "\{trimmed}"
    match ctype {
      Int => I(@string.parse_int(trimmed)) catch { _ => S(text) }
      Float => F(@string.parse_double(trimmed)) catch { _ => S(text) }
      Bool => B(text == "true")
      Date => D(text)
      Str => S(text)
      Empty => Null
    }
  }
}

///|
pub fn from_records(
  headers : Array[String],
  records : Array[Array[String]],
) -> Result[Table, TableError] {
  let columns : Array[Column] = []
  for column_index in 0..<headers.length() {
    let samples : Array[String] = []
    let mut nulls = 0
    for row in records {
      if column_index >= row.length() || row[column_index].trim().is_empty() {
        nulls = nulls + 1
      } else {
        samples.push(row[column_index])
      }
    }
    let (ctype, confidence) = infer_type_and_confidence(samples)
    columns.push({ name: headers[column_index], ctype, nulls, confidence, })
  }
  let rows : Array[Array[Cell]] = []
  for row_index, record in records {
    if record.length() > headers.length() {
      return Err(
        TooManyFields(row_index + 1, headers.length(), record.length()),
      )
    }
    let row : Array[Cell] = []
    for column_index in 0..<headers.length() {
      if column_index >= record.length() {
        row.push(Null)
      } else {
        row.push(
          cell_from_string(record[column_index], columns[column_index].ctype),
        )
      }
    }
    rows.push(row)
  }
  Ok({ columns, rows, })
}
