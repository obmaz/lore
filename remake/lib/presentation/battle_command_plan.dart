/// UI preparation order is independent of LoreBattle's execution order.
/// Commands still execute in source party order, with no extra random calls.
class BattleCommandPlan {
  final Set<int> _prepared = {};

  bool isPrepared(int index) => _prepared.contains(index);
  void prepare(int index) => _prepared.add(index);
  void reset() => _prepared.clear();
  int? nextPending(Iterable<int> eligible) {
    for (final index in eligible) {
      if (!isPrepared(index)) return index;
    }
    return null;
  }

  int preparedCount(Iterable<int> eligible) =>
      eligible.where(isPrepared).length;
}
