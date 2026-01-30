# Contributing to VisualGasic

We welcome contributions to VisualGasic! This document provides guidelines for contributing to the project.

## Table of Contents
1. [Getting Started](#getting-started)
2. [Development Setup](#development-setup)
3. [Coding Standards](#coding-standards)
4. [Testing Guidelines](#testing-guidelines)
5. [Documentation](#documentation)
6. [Pull Request Process](#pull-request-process)

## Getting Started

### Prerequisites
- Godot 4.5+ installed
- SCons build system (`pip install scons`)
- Git with submodules support
- Modern C++ compiler (GCC 9+, Clang 10+, MSVC 2019+)

### Development Environment Setup
```bash
# Clone the repository with submodules
git clone --recursive https://github.com/xgreenrx-star/VisualGasic.git
cd VisualGasic

# Build in debug mode for development
scons platform=linux target=template_debug dev=yes

# Run tests
scons test
```

## Development Setup

### Project Structure
```
src/
├── visual_gasic_*.h/.cpp    # Core language implementation
├── visual_gasic_repl.*      # Interactive REPL system
├── visual_gasic_gpu.*       # GPU computing features
├── visual_gasic_lsp.*       # Language server protocol
├── visual_gasic_debugger.*  # Advanced debugging tools
└── visual_gasic_ecs.*       # Entity component system
```

### Build Configuration
- **Debug builds**: Include full debugging info and assertions
- **Release builds**: Optimized for performance
- **Test builds**: Include test harness and coverage reporting

## Coding Standards

### C++ Style Guide
- **Indentation**: 4 spaces, no tabs
- **Naming**:
  - Classes: `PascalCase` (e.g., `VisualGasicParser`)
  - Functions/Methods: `snake_case` (e.g., `parse_expression`)
  - Variables: `snake_case` (e.g., `token_list`)
  - Constants: `UPPER_SNAKE_CASE` (e.g., `MAX_RECURSION_DEPTH`)
- **Headers**: Use include guards (`#ifndef`/`#define`/`#endif`)
- **Documentation**: Doxygen-style comments for public APIs

### Example Code Style
```cpp
/**
 * Parses a Visual Basic expression from tokens
 * @param tokens List of tokens to parse
 * @return Parsed expression node or nullptr on error
 */
ExpressionNode* VisualGasicParser::parse_expression(const Vector<Token>& tokens) {
    if (tokens.is_empty()) {
        return nullptr;
    }
    
    // Implementation here
    return result;
}
```

### VisualGasic Language Style
- **Keywords**: PascalCase (e.g., `Sub`, `Function`, `End`)
- **Variables**: camelCase or PascalCase (both supported)
- **Indentation**: 4 spaces recommended
- **Comments**: Use `'` for single-line comments

```vb
' Example VisualGasic code style
Function CalculateSum(Of T)(numbers As T()) As T
    Dim result As T = 0
    For Each num As T In numbers
        result += num
    Next
    Return result
End Function
```

## Testing Guidelines

### Test Categories
1. **Unit Tests**: Test individual functions and classes
2. **Integration Tests**: Test component interactions
3. **Language Tests**: Test VisualGasic language features
4. **Performance Tests**: Benchmark critical operations

### Running Tests
```bash
# Run all tests
scons test

# Run specific test category
scons test category=unit
scons test category=integration
scons test category=language

# Run with coverage reporting
scons test coverage=yes
```

### Writing Tests
```cpp
// tests/test_parser.cpp
#include "test_framework.h"
#include "../src/visual_gasic_parser.h"

TEST_CASE("Parser should handle basic expressions") {
    VisualGasicParser parser;
    Vector<Token> tokens = tokenize("x + y");
    
    ExpressionNode* result = parser.parse_expression(tokens);
    
    REQUIRE(result != nullptr);
    REQUIRE(result->type == EXPR_BINARY_OP);
    REQUIRE(result->op == "+");
}
```

## Documentation

### API Documentation
- Use Doxygen comments for all public APIs
- Include parameter descriptions and return values
- Provide usage examples for complex functions

### User Documentation
- Update relevant `.md` files in `docs/`
- Include code examples with explanations
- Test all examples to ensure they work

### Inline Comments
- Explain complex algorithms and business logic
- Document non-obvious design decisions
- Use TODO/FIXME comments for future improvements

## Pull Request Process

### Before Submitting
1. **Create a feature branch**: `git checkout -b feature/your-feature-name`
2. **Write tests**: Ensure new features have appropriate test coverage
3. **Update documentation**: Include relevant documentation updates
4. **Run tests locally**: Ensure all tests pass
5. **Check code style**: Run linting and formatting checks

### Pull Request Guidelines
1. **Clear title**: Describe what the PR does in one line
2. **Detailed description**: Explain the changes and motivation
3. **Breaking changes**: Clearly mark any breaking changes
4. **Testing**: Describe how you tested the changes
5. **Documentation**: List any documentation updates needed

### PR Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix (non-breaking change)
- [ ] New feature (non-breaking change)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work)
- [ ] Documentation update

## Testing
- [ ] Tests pass locally
- [ ] Added tests for new functionality
- [ ] Manual testing performed

## Documentation
- [ ] Documentation updated
- [ ] Examples added/updated
- [ ] API docs updated

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review of code completed
- [ ] Comments added for complex areas
- [ ] No new warnings introduced
```

### Review Process
1. **Automated checks**: CI/CD pipeline runs tests and style checks
2. **Code review**: Maintainers review code quality and design
3. **Testing**: Changes are tested on multiple platforms
4. **Approval**: PR approved by maintainers
5. **Merge**: Changes merged to main branch

## Advanced Contributions

### Adding New Language Features
1. **Design document**: Create RFC for significant changes
2. **AST updates**: Extend AST nodes if needed
3. **Parser changes**: Update parser to handle new syntax
4. **Runtime support**: Implement execution logic
5. **Tests and docs**: Comprehensive testing and documentation

### Performance Improvements
1. **Benchmarking**: Establish baseline performance
2. **Profiling**: Identify bottlenecks
3. **Implementation**: Make targeted improvements
4. **Validation**: Verify improvements with benchmarks
5. **Regression testing**: Ensure no performance regressions

### Integration Features
1. **API design**: Design clean, extensible APIs
2. **Error handling**: Robust error handling and recovery
3. **Documentation**: Comprehensive usage examples
4. **Platform testing**: Test on all supported platforms

## Getting Help

### Communication Channels
- **Issues**: GitHub Issues for bug reports and feature requests
- **Discussions**: GitHub Discussions for general questions
- **Discord**: Join our community Discord server
- **Email**: Contact maintainers directly for sensitive issues

### Resources
- [Godot GDExtension Documentation](https://docs.godotengine.org/en/stable/tutorials/scripting/gdextension/index.html)
- [VisualGasic Language Specification](docs/LANGUAGE_SPEC.md)
- [Architecture Overview](docs/ARCHITECTURE.md)

Thank you for contributing to VisualGasic! 🚀