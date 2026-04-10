# Documentation Index

## Quick Links

### Getting Started
1. **First time?** Start with [ARCHITECTURE.md](ARCHITECTURE.md)
   - Understand system design, project structure, and workflows
   
2. **Want to use it?** Read [OPERATIONS.md](OPERATIONS.md)
   - Installation, configuration, running, troubleshooting

3. **Need to call functions?** Check [API.md](API.md)
   - Public function reference with examples

4. **Extending the code?** See [INTERNALS.md](INTERNALS.md)
   - Helper function reference and patterns

---

## Files Overview

### ARCHITECTURE.md
**Purpose:** System design and structure documentation

**Contents:**
- Project structure and philosophy
- Data model (2 device types explained)
- Workflow overview and operation flow
- Function organization (public vs internal)
- Configuration via environment variables
- Logging system and error handling
- Concurrency model (single-threaded)
- Security considerations
- Testing strategy
- Performance characteristics
- Future enhancements (Phase 3)

**Best for:**
- Understanding how the system works
- Making design decisions
- Planning extensions
- Security audit

### API.md
**Purpose:** Public function reference

**Contents:**
- 5 main functions fully documented:
  - `create_device_main`
  - `read_device_main`
  - `change_device_main`
  - `find_device_main`
  - `find_and_change_main`
  - `change_count_main`
- For each: signature, parameters, returns, behavior, examples
- Exit code reference (0, 1, 2)
- Device type specifications
- Error message format
- Common usage patterns
- Environment variables
- Backward compatibility guarantees

**Best for:**
- Calling the functions
- Understanding what they return
- Writing scripts that use the API
- Integrating with other tools

### OPERATIONS.md
**Purpose:** Deployment and operations guide

**Contents:**
- Installation & prerequisites
- Directory setup
- Running in interactive and non-interactive modes
- Configuration (env vars, persistent setup)
- Log management (viewing, rotation, clearing)
- 10 common issues with detailed solutions:
  - Command not found
  - Device not found
  - Invalid device ID
  - Permission denied
  - File not found
  - Concurrent access issues
  - Performance problems
  - Testing procedures
- Health checks and monitoring
- Performance tuning
- Backup & recovery
- Scheduling with cron
- Integration examples

**Best for:**
- Setting up the system
- Fixing problems
- Troubleshooting errors
- Operational questions
- Backup/restore
- Scaling and monitoring

### INTERNALS.md
**Purpose:** Internal function reference

**Contents:**
- 30+ helper functions documented
- Organized by category:
  - Logging helpers (7 functions)
  - Core helpers (2 functions)
  - Field parsing helpers (4 functions)
  - Device operation helpers (6 functions)
  - User input helpers (3 functions)
  - Utility functions
- For each: description, signature, parameters, returns, examples
- Function index table (quick reference)
- Common patterns for:
  - Error handling
  - Input validation
  - Field parsing
  - Device operations
- Modification guidelines for developers
- Naming conventions and standards

**Best for:**
- Understanding internal implementation
- Extending with new helpers
- Debugging helper functions
- Following best practices
- Learning the codebase

---

## When to Read What

### User trying to get started
1. OPERATIONS.md - Installation & setup
2. ARCHITECTURE.md - Understanding the system
3. API.md - How to use the functions

### Troubleshooting a problem
1. OPERATIONS.md - Check troubleshooting section
2. ARCHITECTURE.md - Understand the design context
3. Check logs: `tail -100 logs/device_manager.log`

### Writing a script that uses the API
1. API.md - Understand function signatures and examples
2. ARCHITECTURE.md - Understand workflows
3. OPERATIONS.md - Setup and configuration

### Extending or modifying the code
1. INTERNALS.md - Helper function reference
2. ARCHITECTURE.md - Design guidelines
3. Code comments in experimental.sh
4. Test files in tests/ for examples

### Deploying to production
1. OPERATIONS.md - Installation & configuration
2. ARCHITECTURE.md - Security and performance
3. OPERATIONS.md - Monitoring, backup, health checks

### Troubleshooting concurrent access
1. ARCHITECTURE.md - Concurrency section
2. OPERATIONS.md - "Concurrent runners corrupt files" section
3. Solution script provided in OPERATIONS.md

---

## Document Statistics

| Document | Size | Sections | Topics |
|----------|------|----------|--------|
| ARCHITECTURE.md | 12.5 KB | 16 | Design, workflows, functions, logging, security, testing |
| API.md | 12.0 KB | 12 | Public functions, types, examples, error codes |
| OPERATIONS.md | 13.4 KB | 12 | Setup, config, logs, troubleshooting, backup, monitoring |
| INTERNALS.md | 15.7 KB | 15 | 30+ helper functions, patterns, guidelines |
| **Total** | **53.6 KB** | **55+** | **Complete system documentation** |

---

## Navigation Tips

### Finding a function
1. API.md - For public functions (create, read, change, find, count)
2. INTERNALS.md - For helper functions (_helper_*, _generic_*)
3. Search by name in the appropriate document

### Understanding a workflow
1. ARCHITECTURE.md - See "Workflow Overview" section
2. OPERATIONS.md - See mode descriptions (interactive vs non-interactive)
3. API.md - See function examples

### Solving a problem
1. OPERATIONS.md - Troubleshooting section (indexed by problem)
2. ARCHITECTURE.md - Context on how the system works
3. Check logs, run tests, review code

### Following best practices
1. ARCHITECTURE.md - "Code Style" and "Development Guidelines"
2. INTERNALS.md - "Modification Guidelines"
3. Test files in tests/ - See working examples

---

## Related Files

- **experimental.sh** - Main library code
- **runner.sh** - Entry point script
- **tests/** - Test suite with 65+ test cases
- **PHASE_2_SUMMARY.md** - Phase 2 completion summary

---

## Version

**Current:** 1.1 (Phase 2 Complete)
- Phase 1: Stabilization & bug fixes
- Phase 2: Testing & documentation

**Last Updated:** 2026-04-10

---

## Questions?

1. **How do I use this?** → Read OPERATIONS.md, then API.md
2. **How does it work?** → Read ARCHITECTURE.md
3. **I found a bug** → Check OPERATIONS.md troubleshooting, then logs
4. **I want to extend it** → Read INTERNALS.md, then code comments
5. **It's not working** → OPERATIONS.md has 10+ scenarios with solutions
