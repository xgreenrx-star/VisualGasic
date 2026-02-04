# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.1.x   | :white_check_mark: |
| 2.0.x   | :white_check_mark: |
| 1.5.x   | :x:                |
| < 1.5   | :x:                |

## Reporting a Vulnerability

We take security vulnerabilities seriously. If you discover a security issue, please report it responsibly.

### How to Report

1. **Do NOT** open a public GitHub issue for security vulnerabilities
2. Email the maintainers directly at: **security@visualgasic.dev** (or create a private security advisory on GitHub)
3. Include as much detail as possible:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

### What to Expect

- **Acknowledgment**: We will acknowledge receipt within 48 hours
- **Assessment**: We will assess the vulnerability within 7 days
- **Resolution**: Critical vulnerabilities will be patched within 14 days
- **Disclosure**: We will coordinate disclosure timing with you

### Scope

The following are in scope for security reports:

- **Visual Gasic Core** (`src/` directory)
- **GDExtension Plugin** (`addons/visual_gasic/`)
- **Parser and Compiler** security issues
- **Memory safety** issues in C++ code
- **Code injection** vulnerabilities

### Out of Scope

- Issues in third-party dependencies (godot-cpp)
- Issues in example code that don't affect the core
- Denial of service through malformed input (we accept this as a limitation)

## Security Best Practices

When using Visual Gasic in your projects:

1. **Validate User Input**: Always sanitize external data before using in scripts
2. **File Operations**: Be cautious with file paths from untrusted sources
3. **Keep Updated**: Use the latest version with security patches
4. **Review External Code**: Audit third-party .vg files before running

## Hall of Fame

We thank the following individuals for responsibly disclosing security issues:

- *Your name could be here!*

---

Thank you for helping keep Visual Gasic secure!
