// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "08170406/moonvista"

version = "0.1.0"

readme = "README.md"

repository = "https://github.com/08170406/MoonVista"

license = "Apache-2.0"

keywords = [ "moonbit", "terminal", "csv", "json", "data" ]

preferred_target = "native"

description = "A MoonBit terminal workbench for exploring CSV, JSON, and JSONL data."

import {
  "moonbitlang/x@0.5.5",
}
