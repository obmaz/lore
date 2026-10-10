import '../models/party_member.dart';
import 'lore_source_memory.dart';
import 'lore_window_io.dart';

/// The window may close if its game screen is disposed during PressAnyKey.
abstract interface class LoreTalkIo implements LoreWindowIo {
  bool get isOpen;
}

/// LORETALK.PAS:640-704: the complete Water Field lord case on etc[15].
/// Mutations run in source order, independently of JSON/ScriptOutcome batches.
class LoreWaterLord {
  LoreWaterLord._();

  static Future<void> run({
    required List<PartyMember> party,
    required LorePartyEtc etc,
    required LoreTalkIo io,
  }) async {
    io.clear(); // talkmode starts with Clear.
    final stage = etc.read(15);
    switch (stage) {
      case 0:
        io.print(7, ' 여기는 WATER FIELD 라는 성이오.  이곳이 당');
        io.print(7, '신이 마지막으로 거칠 우리편의 성이오.');
        io.print(7, ' 차원의 틈을 통해 Necromancer가 내려 오던날');
        io.print(7, '이 대륙은 거의 전부가 바다로 가라않았소. 하');
        io.print(7, '지만  그때에 살아 남은 사람들은 아직 가라않');
        io.print(7, '지 않은 이곳에 찾아와서 이 성을 건립했소.그');
        io.print(7, '리고는  공이 컸던 나를 왕으로 추대했던 것이');
        io.print(7, '오.');
        io.print(7, ' 당신도 생각하고 있다시피 이 대륙은 거의 물');
        io.print(7, '로 덮혀있소.  하지만 이곳처럼 물이 차지않은');
        io.print(7, '두곳에 Necromancer 는 이미 이 대륙의 지배를');
        io.print(7, '위한 동굴을 만들었소. 그 두곳의 적들은 여타');
        io.print(7, '의 대륙과는 비교가 안될 정도의  거대한 적들');
        io.print(7, '이 많이 있소.');
        io.print(7, ' 우리로서는 더 이상 손을 쓸수가 없소.  이곳');
        io.print(7, '사람들의 마지막 희망인  이 곳이 적들에게 점');
        io.print(7, '령된다면 WIVERN 동굴로 이어지는 워터 게이트');
        io.print(7, '를 통해 다른 대륙도 하나둘씩  점령되어 갈것');
        io.print(7, '이오.');
        io.print(7, ''); // talk('') also prints its blank line.
      case 1:
        io.print(7, ' 먼저,  여기서 남서쪽의 어느 섬에 있는 동굴');
        io.print(7, '인 NOTICE에 가서 보스인 Hidra를 물리쳐 주십');
        io.print(7, '시오.');
      case 2:
        io.print(7, 'Hidra를 물리치다니 ... 대단한 능력이오.');
        io.print(11, '[ EXP + 150000 ]');
        io.print(7, '');
        _award(party, 150000);
        io.print(7, '이제는 소문으로만 듣던 당신들의 능력을 믿을');
        io.print(7, '수 있겠소.');
      case 3:
        io.print(7, ' 이번에는  대륙의 동쪽에 있는 LOCKUP 동굴속');
        io.print(7, '의 Huge Dragon을 물리쳐 주시오.');
      case 4:
        io.print(7, '역시 위대한 영웅이오 !!');
        io.print(11, '[ EXP + 300000 ]');
        io.print(7, '');
        _award(party, 300000);
        io.print(7, '여기에 Swamp Key 가 있소.');
      case 5:
        io.print(7, ' Swamp Key 는 GAIA TERRA 의 스왐프 게이트를');
        io.print(7, '여는데 사용되오.  거기서 늪의 대륙으로 가시');
        io.print(7, '오. 늪의 대륙은 완전한 적들의 소굴이므로 매');
        io.print(7, '우 주의하시오.');
      default:
        return; // Pascal case has no else; byte values 6..255 do nothing.
    }
    await io.pressAnyKey();
    if (!io.isOpen) return; // Screen lifetime, not a game-rule branch.
    if (stage == 0 || stage == 2 || stage == 4) {
      etc[15] = etc.read(15) + 1;
    }
  }

  static void _award(List<PartyMember> party, int amount) {
    for (final member in party.take(6)) {
      if (member.name.isNotEmpty) {
        member.experience = LorePascal.longint(member.experience + amount);
      }
    }
  }
}
