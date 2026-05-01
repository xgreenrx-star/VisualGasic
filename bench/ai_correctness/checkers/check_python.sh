#!/bin/bash
# Parse-check a Python file. Exit 0 = parses OK.
set -e
python3 -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$1"
