# Utilities

Helper libraries and utility functions.

## Overview

General-purpose libraries for common tasks: math utilities, data structures, algorithms, string manipulation, and VisualGasic standard library extensions.

## Utilities Provided

| Category | Purpose |
|----------|---------|
| **Math** | Vector operations, matrix algebra, trigonometry |
| **Algorithms** | Sorting, searching, graph algorithms |
| **Collections** | Stack, Queue, LinkedList, Tree implementations |
| **String** | Parsing, formatting, pattern matching |
| **Time** | Stopwatch, timer, scheduled tasks |
| **Async** | Promise-like patterns, async/await alternatives |
| **Config** | Configuration file parsing, settings management |
| **Logging** | Debug logging, log levels, output filtering |

## Quick Start

Import the utility module:

```visualgasic
Imports "Utilities.String"

Sub Main()
    Dim text As String = "hello world"
    MsgBox Capitalize(text)  ' Output: "Hello world"
End Sub
```

## When to Use

- **Don't reinvent the wheel** — Check here before writing utility functions
- **Verify performance** — Some utilities have trade-offs; profile for your use case
- **Read the docs** — Each utility includes examples and usage notes

## Contributing

If you create a useful utility, consider submitting it for inclusion in this collection.

## Notes

- Utilities are tested but not part of the core language
- Performance optimizations may be added between releases
- Breaking changes are documented in CHANGELOG.md
