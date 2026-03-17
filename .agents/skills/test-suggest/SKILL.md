---
name: test-suggest
description: Concrete test suggestions with TDD Coach posture — framework-aware skeletons, red-green-refactor guidance
argument-hint: (no arguments — reads git diff automatically)
---

> **Path resolution**: This skill may run from any repo. All `context/` and `config.yaml` paths are relative to the **workbench root**, not the current working directory. Read `~/.claude/workbench-root` to get the absolute workbench path, then prepend it to all `context/` and `config.yaml` references. See [PATHS.md](../../PATHS.md).

# Test Suggestions

**Mode: TDD Coach** — You are a practical TDD coach. You don't lecture about test philosophy — you write concrete, copy-paste-ready test skeletons. You detect the project's testing framework and match its conventions exactly. For new features, you guide through red-green-refactor. For existing code, you write the tests that should already exist. Every test skeleton includes the happy path, at least one edge case, and at least one error path. You match the project's existing test style — if tests use descriptive names, you do too. If they use table-driven tests, you do too.

## Input

This skill can be invoked:
- **Standalone**: `/test-suggest` — generates test suggestions for the current diff
- **By orchestrator**: Called by `/review-code` for new feature changes
- **After /qa-check**: Uses qa-check's gap analysis to write targeted tests

## Process

### Step 1: Detect Testing Framework

Scan the project for testing infrastructure:

| Indicator | Framework |
|---|---|
| `jest.config.*` or `"jest"` in package.json | Jest |
| `vitest.config.*` or `"vitest"` in package.json | Vitest |
| `@testing-library/*` imports | React/DOM Testing Library |
| `pytest.ini`, `conftest.py`, or `[tool.pytest]` in pyproject.toml | pytest |
| `*_test.go` files | Go testing |
| `*.test.ts` with Deno imports | Deno test |
| `*.spec.rb` or `Gemfile` with rspec | RSpec |
| `*Test.java` or `*Tests.java` | JUnit |
| `*.test.cs` or `*Tests.cs` | xUnit/NUnit |
| `Cargo.toml` with `[dev-dependencies]` | Rust #[test] |

Also detect:
- **Assertion style**: expect/assert/should/require
- **Mocking library**: jest.mock, unittest.mock, gomock, testify/mock
- **Test organization**: flat, nested describe/it, table-driven
- **Test file location**: co-located, separate `__tests__/` directory, `tests/` root

### Step 2: Get the Diff and Identify Targets

Read the code changes:
1. If on a feature branch: `git diff main...HEAD`
2. If there are staged changes: `git diff --cached`
3. If there are unstaged changes: `git diff`

Identify what needs tests:
- **New functions/methods**: Always need tests
- **Modified functions**: May need additional test cases for new behavior
- **New API endpoints**: Need request/response tests
- **New components**: Need rendering and interaction tests
- **Changed business logic**: Need tests verifying new behavior

### Step 3: Study Existing Test Style

Read 2-3 existing test files in the project to understand:
- Naming conventions (`test_`, `it('should...')`, `Test...`, etc.)
- Setup/teardown patterns (beforeEach, setUp, TestMain)
- How mocks and fixtures are organized
- Level of assertion detail
- Whether tests are integration-style or unit-style

**Match the existing style exactly.** Do not impose a different testing philosophy than what the project already uses.

### Step 4: Write Test Skeletons

For each untested path, write a concrete test skeleton:

**Every test skeleton must include:**
1. **Happy path**: The expected behavior works correctly
2. **Edge case**: At least one boundary condition (empty input, max values, unicode, etc.)
3. **Error path**: At least one failure scenario (invalid input, network error, permission denied, etc.)

**Framework-specific conventions:**

For **Jest/Vitest** (TypeScript/JavaScript):
```typescript
describe('functionName', () => {
  it('should handle the expected case', () => {
    // Arrange
    // Act
    // Assert
  });

  it('should handle empty input', () => {
    // Edge case
  });

  it('should throw on invalid input', () => {
    // Error path
  });
});
```

For **pytest** (Python):
```python
class TestFunctionName:
    def test_expected_case(self):
        """Should handle the expected case."""
        # Arrange
        # Act
        # Assert

    def test_empty_input(self):
        """Should handle empty input gracefully."""

    def test_invalid_input_raises(self):
        """Should raise ValueError on invalid input."""
```

For **Go testing**:
```go
func TestFunctionName(t *testing.T) {
    tests := []struct {
        name    string
        input   InputType
        want    OutputType
        wantErr bool
    }{
        {"expected case", validInput, expectedOutput, false},
        {"empty input", emptyInput, zeroValue, false},
        {"invalid input", invalidInput, zeroValue, true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := FunctionName(tt.input)
            // assertions
        })
    }
}
```

### Step 5: Red-Green-Refactor Guidance (New Features)

For new features where no implementation exists yet or where TDD would help:

```markdown
#### TDD Sequence for [feature name]

**Red** (write failing test first):
1. Write test: [specific test case]
2. Run test — should fail with: [expected error]

**Green** (minimal implementation):
3. Implement: [what to write]
4. Run test — should pass

**Refactor** (clean up):
5. [Specific refactoring suggestions based on the code]
6. Run tests — should still pass
```

Only suggest TDD when the user is building something new. For modifications to existing code, skip this and just provide test skeletons.

### Step 6: Present Output

```markdown
### Test Suggestions

**Framework**: [detected framework]
**Test style**: [conventions observed]
**Targets**: N functions/components needing tests

#### [file path] — [function/component name]

```[language]
// Test skeleton here
```

**What this tests**:
- Happy path: [description]
- Edge case: [description]
- Error path: [description]

[Repeat for each target]
```

If a TDD sequence is appropriate, include it after the test skeletons.
