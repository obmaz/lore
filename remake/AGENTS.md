# LORE port direction

- This project is self-contained. Do not read, import, synchronize or depend
  on files in another project. Work on main and preserve unrelated user changes.
- Development boundaries and completion gates: `docs/porting/direct_port_strategy.md`.
- Validation commands: `docs/README.md`.
- Modernize mobile presentation, input, dialogue flow and battle command
  preparation while preserving explicit source replay adapters. Numeric rules,
  saves and RNG remain source-owned unless a concrete gameplay change requires otherwise.
- Keep Pascal control flow, early exits, expression types, array bounds/indices,
  byte values, random-call order and map mutation order. Port complete procedures
  or closed source branches, including choice/battle continuations.
- Keep source tile codes and map identities separate from visual assets. Pascal
  `map[x,y]` is one-based; the Flutter grid is `grid[y-1][x-1]`. Do not transpose
  map/save payloads or replace raw `etc` bytes with named Boolean flags.
- Reuse existing source-backed code, native widgets, resources, reducers, audio
  adapters and regression fixtures. JSON may store resources and saves, but executable JSON event rules and
  JSON/legacy fallback are removed. Historical rule/parser fixtures live only
  in test tooling and are not runtime parity evidence.
- Give each migrated event one runtime owner. Do not run JSON/legacy fallback
  for an event already owned by a direct procedure, even when it returns no event.
- Record unknown compiler overflow/range-check behavior and intentional changes.
  Passing tests or having a procedure wrapper does not prove a complete port.
- Before committing behavior changes, run relevant source replay tests, the full
  Flutter test suite and `flutter analyze`; refresh/check the contract ledger and
  source memory review index if their inputs changed. Build the release web target
  when changing shared numeric/storage code used by the web runtime.
