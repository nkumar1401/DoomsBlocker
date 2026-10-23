# Rule: Spec-Driven Development (SDD) Protocol

## Context
Applies to all tasks in DoomsBlocker.

## Guidelines
1. **Source of Truth**: `SPECIFICATIONS.md` is the project constitution.
2. **Regression Prevention**: Never modify core accessibility, lock overlay, or study zone logic without verifying against `test/spec_driver_test.dart`.
3. **Validation Command**:
   ```bash
   flutter test test/spec_driver_test.dart
   ```
4. **Agent Replaceability**: Keep all documentation, architecture diagrams, and constraints in repository markdown files so any agent (Antigravity, Cursor, Claude Code, Windsurf) can immediately understand and respect the codebase.
