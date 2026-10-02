# LORE port direction

- Follow the sole plan, `docs/porting/direct_port_strategy.md`. The active goal
  is a source-faithful LORE port with modern map rendering, UI, input and audio.
  New game rules are direct Dart ports of the original Pascal procedures.
- Keep Pascal control flow, early exits, expression types, array bounds/indices,
  byte values, random-call order and map mutation order. Port complete procedures
  or closed source branches, including choice/battle continuations.
- Keep source tile codes and map identities separate from visual assets. Pascal
  `map[x,y]` is one-based; the Flutter grid is `grid[y-1][x-1]`. Do not transpose
  map/save payloads or replace raw `etc` bytes with named Boolean flags.
- Reuse existing source-backed code, native widgets, resources, reducers, audio
  adapters and regression fixtures. Existing JSON data and not-yet-migrated
  event rules may remain during transition; new game rules belong in Dart.
- Give each migrated event one runtime owner. Do not run JSON/legacy fallback
  for an event already owned by a direct procedure, even when it returns no event.
- Record unknown compiler overflow/range-check behavior and intentional changes.
  Passing tests or having a procedure wrapper does not prove a complete port.
- Before committing behavior changes, run relevant source replay tests, the full
  Flutter test suite and `flutter analyze`; refresh/check the contract ledger and
  source memory review index if their inputs changed. Build the release web target
  when changing shared numeric/storage code used by the web runtime.
