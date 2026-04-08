#!/usr/bin/env python3
"""Test script to check how PySlang parses assertions in or1200_assertions.sv"""

import sys
import pyslang as ps

def traverse_statements(stmt, depth=0, max_depth=10):
    """Recursively traverse statements and print their kinds."""
    indent = "  " * depth

    if stmt is None or depth > max_depth:
        return

    # Handle iterable
    if hasattr(stmt, '__iter__') and not isinstance(stmt, str):
        for i, s in enumerate(stmt):
            if i < 3:  # Only show first 3
                traverse_statements(s, depth, max_depth)
            elif i == 3:
                print(f"{indent}... ({len(list(stmt)) - 3} more)")
                break
        return

    # Check if it's a Statement with a kind
    if hasattr(stmt, 'kind'):
        print(f"{indent}Statement kind: {stmt.kind}")

        # Check for assertion kinds
        if stmt.kind == ps.StatementKind.ImmediateAssertion:
            print(f"{indent}  -> Found ImmediateAssertion!")
            if hasattr(stmt, 'cond'):
                print(f"{indent}     Condition: {stmt.cond}")
            if hasattr(stmt, 'expr'):
                print(f"{indent}     Expression: {stmt.expr}")

        # Check for Conditional - might be an assert
        if stmt.kind == ps.StatementKind.Conditional:
            print(f"{indent}  -> Conditional statement")
            # Check attributes
            attrs = [a for a in dir(stmt) if not a.startswith('_')]
            print(f"{indent}     Attributes: {attrs[:10]}")

            # Check if it's an assertion check
            if hasattr(stmt, 'check'):
                print(f"{indent}     check attribute: {stmt.check}")
                print(f"{indent}     check type: {type(stmt.check)}")
                if hasattr(stmt.check, 'kind'):
                    print(f"{indent}     check.kind: {stmt.check.kind}")

            # Check conditions
            if hasattr(stmt, 'conditions'):
                print(f"{indent}     conditions: {stmt.conditions}")
                if stmt.conditions:
                    for i, cond in enumerate(stmt.conditions):
                        print(f"{indent}     condition[{i}]: {cond}")
                        if hasattr(cond, 'expr'):
                            print(f"{indent}       expr: {cond.expr}")

        # Traverse nested statements
        if stmt.kind == ps.StatementKind.Block:
            if hasattr(stmt, 'body'):
                traverse_statements(stmt.body, depth + 1, max_depth)
        elif stmt.kind == ps.StatementKind.List:
            if hasattr(stmt, 'list'):
                traverse_statements(stmt.list, depth + 1, max_depth)
        elif stmt.kind == ps.StatementKind.Timed:
            if hasattr(stmt, 'stmt'):
                traverse_statements(stmt.stmt, depth + 1, max_depth)
        elif stmt.kind == ps.StatementKind.Conditional:
            if hasattr(stmt, 'ifTrue'):
                print(f"{indent}  Traversing ifTrue branch...")
                traverse_statements(stmt.ifTrue, depth + 1, max_depth)
            if hasattr(stmt, 'ifFalse') and stmt.ifFalse:
                print(f"{indent}  Traversing ifFalse branch...")
                traverse_statements(stmt.ifFalse, depth + 1, max_depth)

def main():
    # Parse the assertions file
    driver = ps.Driver()
    driver.addStandardArgs()

    # Add the file
    driver.sourceLoader.addFiles('designs/benchmarks/or1200/buggy-or1200/or1200_assertions.sv')
    driver.processOptions()

    if not driver.parseAllSources():
        print("Parse failed")
        sys.exit(1)

    comp = driver.createCompilation()

    # Get top instances
    modules = list(comp.getRoot().topInstances)

    print(f"Found {len(modules)} top-level module(s)")

    for mod in modules:
        print(f"\nModule: {mod.name}")

        # Iterate through members
        count = 0
        for member in mod.body:
            if member.kind == ps.SymbolKind.ProceduralBlock:
                count += 1
                print(f"\n  ProceduralBlock #{count}: {member.name}")
                print(f"    Body kind: {member.body.kind}")

                # Traverse the body
                traverse_statements(member.body, 2)

                if count >= 5:
                    break

        print(f"\n  Total ProceduralBlocks: {count}")

if __name__ == '__main__':
    main()
