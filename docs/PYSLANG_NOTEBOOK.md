# PySlang Usage Notebook

This document records key findings and patterns for using the pyslang library.

## Statement Types and Their Attributes

PySlang has two types of AST nodes:
1. **Syntax objects** (uncompiled AST) - e.g., `ConditionalStatementSyntax`, `BlockStatementSyntax`
2. **Statement objects** (compiled AST) - accessed via `.kind` attribute with `StatementKind` enum

### Statement Kind Attributes

Different `StatementKind` types use different attributes to access their children:

| StatementKind | Child Attribute | Notes |
|---------------|-----------------|-------|
| `StatementKind.Block` | `.body` | Can be iterable or single statement |
| `StatementKind.List` | `.list` | **NOT `.body`!** Returns a Python list |
| `StatementKind.Timed` | `.stmt` | Single statement |
| `StatementKind.Conditional` | `.ifTrue`, `.ifFalse`, `.conditions` | `.conditions[0].expr` for condition |
| `StatementKind.Case` | `.items`, `.expr` | `.items` contains case items with `.stmt` |
| `StatementKind.ForLoop` | `.body`, `.init`, `.cond`, `.incr` | |
| `StatementKind.WhileLoop` | `.body`, `.cond` | |
| `StatementKind.DoWhileLoop` | `.body`, `.cond` | |
| `StatementKind.ImmediateAssertion` | `.cond`, `.ifTrue`, `.ifFalse` | Assertion statement |

### ProceduralBlockSymbol

`ProceduralBlockSymbol` represents `always`, `initial`, etc. blocks.

```python
# Access the body of a procedural block
proc_block.body  # Returns a Statement object

# Useful attributes
proc_block.name           # Block name (often empty string)
proc_block.kind           # SymbolKind
proc_block.procedureKind  # ProceduralBlockKind (Always, AlwaysComb, etc.)
proc_block.location       # Source location
```

### Checking Statement Types

```python
import pyslang as ps

# For compiled AST (Statement objects)
if hasattr(stmt, 'kind'):
    if stmt.kind == ps.StatementKind.Conditional:
        # Handle conditional
        pass
    elif stmt.kind == ps.StatementKind.List:
        # Use .list, not .body!
        for substmt in stmt.list:
            process(substmt)
    elif stmt.kind == ps.StatementKind.Block:
        # .body can be iterable or single
        if hasattr(stmt.body, '__iter__'):
            for substmt in stmt.body:
                process(substmt)
        else:
            process(stmt.body)

# For uncompiled AST (Syntax objects)
if isinstance(stmt, ps.ConditionalStatementSyntax):
    # Handle conditional syntax
    pass
```

## Common Pitfalls

### 1. StatementKind.List uses `.list`, not `.body`

```python
# WRONG
if stmt.kind == ps.StatementKind.List:
    for s in stmt.body:  # AttributeError!
        ...

# CORRECT
if stmt.kind == ps.StatementKind.List:
    for s in stmt.list:
        ...
```

### 2. Block body can be single statement or iterable

```python
# SAFE approach
if stmt.kind == ps.StatementKind.Block:
    body = stmt.body
    if hasattr(body, '__iter__') and not isinstance(body, str):
        for substmt in body:
            process(substmt)
    else:
        process(body)
```

### 3. ProceduralBlockSymbol.body returns Statement, not Syntax

When you access `ProceduralBlockSymbol.body`, you get a compiled Statement object, not a Syntax object. Check for `StatementKind` values, not Syntax types.

## Debugging PySlang Objects

```python
# Print all attributes of an object
print(f"Dir: {dir(obj)}")

# Check the kind
if hasattr(obj, 'kind'):
    print(f"Kind: {obj.kind}")

# For symbols
if hasattr(obj, 'name'):
    print(f"Name: {obj.name}")
```

## Example: Counting Conditionals

```python
def count_conditionals(items):
    count = 0

    if hasattr(items, 'kind'):
        kind = items.kind

        if kind == ps.StatementKind.Conditional:
            count += 1
            if hasattr(items, 'ifTrue'):
                count += count_conditionals(items.ifTrue)
            if hasattr(items, 'ifFalse') and items.ifFalse:
                count += count_conditionals(items.ifFalse)

        elif kind == ps.StatementKind.List:
            for substmt in items.list:
                count += count_conditionals(substmt)

        elif kind == ps.StatementKind.Block:
            body = items.body
            if hasattr(body, '__iter__') and not isinstance(body, str):
                for substmt in body:
                    count += count_conditionals(substmt)
            else:
                count += count_conditionals(body)

        elif kind == ps.StatementKind.Timed:
            if hasattr(items, 'stmt'):
                count += count_conditionals(items.stmt)

    return count
```

## Tracking Unique Branch Points

When counting branch points during symbolic execution, use source location offset as a stable unique identifier:

```python
# In ExecutionManager class
branch_points_seen = set()  # Track unique branch points

# When visiting a conditional
if hasattr(stmt, 'syntax') and stmt.syntax is not None:
    sr = stmt.syntax.sourceRange()
    branch_id = (m.curr_module, sr.start.offset if hasattr(sr.start, 'offset') else str(sr.start))
elif hasattr(stmt, 'sourceRange'):
    sr = stmt.sourceRange
    branch_id = (m.curr_module, sr.start.offset if hasattr(sr, 'start') and hasattr(sr.start, 'offset') else str(sr))
else:
    branch_id = (m.curr_module, str(stmt))

if branch_id not in m.branch_points_seen:
    m.branch_points_seen.add(branch_id)
    m.branch_count += 1
```

**Important:** Don't use `str(sourceRange)` directly - it includes the memory address which changes between calls!

## Version Notes

- PySlang 7.0.0 vs 9.x have some API differences
- For conditional statements: 7.0 uses `conditions[0].expr`
- Check for both `ifTrue`/`ifFalse` and `statement`/`elseClause` attributes

---

*Last updated: 2026-02-03*
*Based on debugging session for count_conditionals in LoopSE*
