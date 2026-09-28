///|
/// Runs the table state machine through a simple line-oriented terminal REPL.
fn run_repl(options : @cli.CliOptions) -> Unit {
  match @cli.initial_repl_state(options) {
    Err(error) => {
      println("Error: \{@cli.error_message(error)}")
      @sys.exit(1)
    }
    Ok(initial) => {
      let mut state = initial
      while !@app.should_quit(state) {
        println(@cli.repl_frame(state))
        println("moonvista> type help for commands, q to quit")
        match @terminal.read_stdin_line() {
          @terminal.StdinLine::Line(command) =>
            state = @cli.apply_repl_command(state, command, 12)
          @terminal.StdinLine::TooLong =>
            println("Input line is longer than 4095 bytes; discarded")
          @terminal.StdinLine::EndOfInput =>
            state = @cli.apply_repl_command(state, "quit", 12)
        }
      }
    }
  }
}

///|
/// Command line entry point. All file I/O stays at this boundary; the data
/// model, transformations, and rendering remain in MoonBit library packages.
fn main {
  let full_args = @env.args()
  let args = if full_args.is_empty() { [] } else { full_args[1:].to_owned() }
  match @cli.parse_args(args) {
    Err(error) => {
      println("Error: \{@cli.error_message(error)}")
      println(@cli.usage())
      @sys.exit(2)
    }
    Ok(options) =>
      if options.help {
        println(@cli.usage())
      } else if options.repl {
        run_repl(options)
      } else {
        match @cli.execute(options) {
          Err(error) => {
            println("Error: \{@cli.error_message(error)}")
            @sys.exit(1)
          }
          Ok(result) => {
            if !result.stats_report.is_empty() {
              println(result.stats_report)
            }
            match result.output_path {
              Some(path) =>
                match @terminal.write_export_file(path, result.body) {
                  0 => println("Wrote export to \{path}")
                  1 => {
                    println(
                      "Error: refusing to overwrite existing file: \{path}",
                    )
                    @sys.exit(1)
                  }
                  _ => {
                    println("Error: could not write export file \{path}")
                    @sys.exit(1)
                  }
                }
              None => println(result.body)
            }
          }
        }
      }
  }
}
