// ignore_for_file: prefer_interpolation_to_compose_strings
import '../data/lore_script.dart';
import '../models/party_member.dart';
import 'lore_source_memory.dart';
import 'lore_source_coordinates.dart';
import 'lore_talk_procedures.dart';
import 'lore_water_lord.dart';

abstract interface class LoreTalkModeIo implements LoreTalkIo {
  void setTile(int x, int y, int tile);
  void refresh();
  void cprint(
    int color,
    int highlight,
    String before,
    String word,
    String after,
  );
  void message(int color, String text);
  Future<void> recruit(LoreScript procedure);
  Future<String> challengeKey();
}

/// Direct port of LORETALK.PAS:talkmode. No JSON rule lookup or named flag
/// substitution. Each wait, raw byte case and mutation stays in source order.
class LoreTalkMode {
  static Future<void> run({
    required int mapId,
    required int targetX,
    required int targetY,
    required int x,
    required int y,
    required List<PartyMember> party,
    required LorePartyEtc etc,
    required int Function(int) roll,
    required LoreTalkModeIo io,
  }) async {
    var s = '';
    var c = '';
    final m = ['', '', ''];
    bool at(int ax, int ay) =>
        LoreSourceCoordinates.at(x, y, targetX - x, targetY - y, ax, ay);
    io.clear();
    switch (mapId) {
      case 6:
        {
          if (at(9, 64)) {
            io.print(7, " 당신이 모험을 시작한다면, 많은 괴물들을 만날 것이오.");
            s = " 무엇보다도, Serpent 와 Insects 와 Python 은";
            io.print(7, s + " 맹독이 있으니 주의 하시기 바라오.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(72, 73)) {
            io.print(7, "Orc 는 가장 하급 괴물이오.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(51, 72)) {
            if ((etc.read(50) & 16) == 0) {
              io.print(7, " 당신이  Necromancer에 진정으로  대항하고자");
              io.print(7, "한다면, 이 성의 바로위에 있는 피라밋에 가보");
              io.print(7, "도록하시오. 그 곳은 Necromancer와 동시에 바");
              io.cprint(7, 11, "다에서 떠오른 ", "또다른 지식의 성전", "이기 때문이");
              io.print(7, "오.  당신이 어느 수준이 되어 그 곳에 들어간");
              io.print(7, "다면  진정한 이 세계의 진실을 알수 있을것이");
              io.print(7, "오.");
              await io.pressAnyKey();
              if (!io.isOpen) return;
              etc[50] = (etc.read(50) | 16);
            } else {
              io.print(7, " `MENACE' 속에는 Dwarf, Giant, Wolf, Python");
              io.print(7, "같은 괴물들이 살고 있소.");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            }
          }
          if (at(58, 74)) {
            s = " 나의 부모님은 Python 의 독에 의해 돌아 가셨습니다.";
            io.print(7, s + " Python 은 정말 위험한 존재입니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(63, 27)) {
            io.print(7, " 단지 Lord Ahn 만이 능력 상으로 Necromancer 에게 도전할 수 있습니다.");
            s = " 하지만 Lord Ahn 자신이 대립을 싫어해서, 현재는";
            io.print(7, s + " Necromancer 에게 대항할 자가 없습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(90, 82)) {
            io.print(7, " 우리는 Ancient Evil을 배척하고 Lord Ahn님을 받들어야 합니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(94, 68)) {
            io.print(7, " 우리는 MENACE 의 동쪽에 있는 나무로부터 많은 식량을 얻은적이 있습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(19, 53)) {
            io.print(10, " 이 세계의 창시자는 안 영기님 이시며, 그는 위대한 프로그래머 입니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(13, 27) || at(18, 27)) {
            s = (party.first.sex == Gender.male ? '남성' : '여성');
            io.print(7, " 어서 오십시오. 여기는 LORE 주점입니다.");
            if (roll(2) == 0) {
              io.print(7, " 거기 " + s + "분 어서 오십시오.");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            } else {
              io.print(7, " 위스키에서 칵테일까지 마음껏 선택하십시오.");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            }
          }
          if (at(21, 33)) {
            io.print(7, "...");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(10, 30)) {
            io.print(7, "요새 무덤쪽에서 유령이 떠돈다던데...");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(13, 32)) {
            io.print(7, "하하하, 자네도 한번 마셔보게나.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(15, 35)) {
            io.print(7, " 이제 Lord Ahn의 시대도 끝나가는가 ? 그까짓");
            io.print(7, "Necromancer라는 작자에게 쩔쩔 매는 꼴이라니");
            io.print(7, "...  차라리 내가 나가서 그 놈과 싸우는게 났");
            io.print(7, "겠다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(18, 33)) {
            io.print(7, " 당신은 Skeleton 족의 한명이 우리와 함께 생");
            io.print(7, "활하려 한다는 것에 대해서 어떻게 생각하십니");
            io.print(7, "까 ?  저는 그 말을 들었을때 너무 혐오스러웠");
            io.print(7, "습니다. 어서 빨리 그 살아있는 뼈다귀를 여기");
            io.print(7, "서 쫒아냈으면 좋겠습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(21, 36)) {
            io.print(7, " ... 끄~~윽 ... ...");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(18, 38)) {
            io.print(7, " 이보게 자네, 내말 좀 들어 보게나.  나의 친");
            io.print(7, "구들은 이제 이 세상에 없다네. 그들은 너무나");
            io.print(7, "도 용감하고 믿음직스런 친구들이었는데... 내");
            io.print(7, "가 다리를 다쳐 병원에 있을 동안 그들은 모두");
            io.print(7, "이 대륙의 평화를 위해 LORE 특공대에 지원 했");
            io.print(7, "다네.  하지만 그들은 아무도 다시는 돌아오지");
            io.print(7, "못했어.  그런 그들에게 이렇게 살아있는 나로");
            io.print(7, "서는 미안할 뿐이네  그래서 술로 나날을 보내");
            io.print(7, "고 있지. 죄책감을 잊기위해서 말이지...");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(72, 78)) {
            io.print(7, " 물러나십시오.  여기는 용사의 유골들을 안치");
            io.print(7, "해 놓은 곳입니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(63, 76) && ((etc.read(50) & 1) == 0)) {
            io.print(7, " 당신이  한 유골 앞에 섰을때  이상한 느낌과");
            io.print(7, "함께 먼곳으로 부터 어떤 소리가 들려왔다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(13, " 안녕하시오. 대담한 용사여.");
            io.print(13, " 당신이 나의 잠을 깨웠소 ?  나는 고대에 이");
            io.print(13, "곳을 지키다가 죽어간 기사 Jr. Antares 라고");
            io.print(13, "하오.  저의 아버지는 Red Antares 라고 불리");
            io.print(13, "웠던 최강의 마법사였소.  그는 말년에  어떤");
            io.print(13, "동굴로 은신을 한 후 아무에게도 모습을 나타");
            io.print(13, "내지 않았소.  하지만 당신의 운명은 나의 아");
            io.print(13, "버지를 만나야만하는 운명이라는 것을 알수있");
            io.print(13, "소.  반드시 나의 아버지를 만나서 당신이 알");
            io.print(13, "지 못했던 새로운 능력들을 배우시오. 그리고");
            io.print(13, "나의 아버지를 당신의 동행으로 참가시키도록");
            io.print(13, "하시오. 물론 좀 어렵겠지만 ...");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(13, " 아참,  그리고 내가 죽기전에 여기에 뭔가를");
            io.print(13, "여기에 숨겨 두었는데  당신에게 도움이 될지");
            io.print(13, "모르겠소. 그럼, 나는 다시 오랜 잠으로 들어");
            io.print(13, "가야 겠소.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            for (var i = 79; i <= 81; i++) {
              io.setTile(62, i, 44);
            }
            io.setTile(62, 82, 0);
            io.setTile(62, 83, 14);
            io.refresh();
            etc[50] = (etc.read(50) | 1);
          }
          if (at(24, 50)) {
            io.print(7, " 힘내게, " + party.first.name);
            io.print(7, " 자네라면 충분히 Necromancer를 무찌를수 있");
            io.print(7, "을 걸세. 자네만 믿겠네.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(24, 54)) {
            io.print(7, " 위의 저 친구로부터  당신 얘기 많이 들었습");
            io.print(7, "니다. 저는 우리성에서 당신같은 용감한 사람");
            io.print(7, "이 있다는걸 자랑스럽게 생각합니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(13, 55)) {
            io.print(7, " 만약, 당신들이  그 일을 해내기가 어렵다고");
            io.print(7, "생각되시면 LASTDITCH 성에서  성문을 지키고");
            io.print(7, "있는 Polaris란 청년을 일행에 참가시켜 주십");
            io.print(7, "시오.  분명 그 사람이라면 쾌히 승락할 겁니");
            io.print(7, "다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(50, 11)) {
            io.print(7, " 이 안에 갇혀있는 사람들에게는 일체 면회가");
            io.print(7, "허용되지 않습니다. 나가 주십시오.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(53, 11)) {
            io.print(7, " 여기는 Lord Ahn의 체제에 대해서 깊은 반감");
            io.print(7, "을 가지고 있는 자들을 수용하고 있습니다.");
            io.print(7, " 아마 그들은 죽기전에는 이곳을 나올수 없을");
            io.print(7, "겁니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(41, 10)) {
            io.print(7, " 나는 이곳의 기사로서  이 세계의 모든 대륙");
            io.print(7, "을 탐험하고 돌아왔었습니다. 내가 마지막 대");
            io.print(7, "륙을 돌았을때  나는 새로운 존재를 발견했습");
            io.print(7, "니다. 그는 바로 예전까지도 Lord Ahn과 대립");
            io.print(7, "하던 Ancient Evil이라는 존재였습니다. 지금");
            io.print(7, "우리의 성에서는 철저하게 배격하도록 어릴때");
            io.print(7, "부터 가르침 받아온 그 Ancient Evil이었습니");
            io.print(7, "다.  하지만 그곳에서 본 그는 우리가 알고있");
            io.print(7, "는 그와는 전혀 다른 인간미를 가진  말 그대");
            io.print(7, "로  신과같은 존재였습니다.  내가 그의 신앙");
            io.print(7, "아래 있는 어느 도시를 돌면서 내가 느낀것은");
            io.print(7, "정말 Lord Ahn에게서는 찾아볼수가 없는 그런");
            io.print(7, "자애와 따뜻한 정이었습니다.  그리고 여태껏");
            io.print(7, "내가 알고 있는 그에 대한 지식이  정말 잘못");
            io.print(7, "되었다는 것과  이런 사실을 다른 사람에게도");
            io.print(7, "알려주고 싶다는 이유로  그의 사상을 퍼뜨리");
            io.print(7, "다 이렇게 잡히게 된것입니다.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(7, " 하지만 더욱 이상한것은 Lord Ahn 자신도 그");
            io.print(7, "에 대한 사실을 인정하면서도  왜 우리에게는");
            io.print(7, "그를 배격하도록만 교육시키는 가를  알고 싶");
            io.print(7, "을뿐입니다. Lord Ahn께서는 나를 이해한다고");
            io.print(7, "하셨지만 사회 혼란을 방지하기 위해 나를 이");
            io.print(7, "렇게 밖에 할수 없다고 말씀하시더군요. 그리");
            io.print(7, "이것은 선을 대표하는 자기로서는 이 방법 밖");
            io.print(7, "에는 없다고 하시더군요.");
            io.print(7, " 하지만 Lord Ahn의 마음은 사실 이렇지 않다");
            io.print(7, "는걸 알수 있었습니다.  Ancient Evil의 말로");
            io.print(7, "는 사실 서로가 매우 절친한 관계임을 알수가");
            io.print(7, "있었기 때문입니다.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(40, 15)) {
            await io.recruit(LoreTalkProcedures.madJoeRecruit);
            if (!io.isOpen) return;
          }
          if (at(63, 10)) {
            io.print(7, " 안녕하시오. 나는 한때 이 곳의 유명한 도둑");
            io.print(7, "이었던 사람이오.  결국 그 때문에 나는 잡혀");
            io.print(7, "서 평생 여기에 있게 되었지만...");
            io.cprint(7, 11, " 그건 그렇고, 내가 LORE 성의 보물인 ", "황금의", "");
            io.cprint(7, 11, "", "방패", "를 훔쳐 달아나다. 그만 그것을 MENACE라");
            io.print(7, "는 금광에 숨겨 놓은채 잡혀 버리고 말았소.");
            io.print(7, "나는 이제 그것을 가져봤자 쓸때도 없으니 차");
            io.print(7, "라리 당신이 그걸 가지시오. 가만있자...  어");
            io.print(7, "디였더라...  그래 ! MENACE의 가운데쯤에 벽");
            io.print(7, "으로 사방이 둘러 싸여진 곳이었는데..  당신");
            io.print(7, "들이라면  지금 여기에 들어온것과 같은 방법");
            io.print(7, "으로 들어가서 방패를 찾을수 있을것이오. 행");
            io.print(7, "운을 빌겠소.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(60, 15)) {
            io.print(7, " 당신들에게 경고해 두겠는데 건너편 방에 있");
            io.print(7, "는 Joe는 오랜 수감생활 끝에 미쳐 버리고 말");
            io.print(7, "았소.  그의 말에 속아서 당신네 일행에 참가");
            io.print(7, "시키는 그런 실수는 하지마시오.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(42, 78) || at(42, 80)) {
            if (((etc.read(50) & 8)) == 0) {
              io.print(7, " Lord Ahn 님의 명령에 의해서 당신들에게 한");
              io.print(7, "가지의 무기를 드리겠습니다.  들어가셔서 무");
              io.print(7, "기를 선택해 주십시오.");
            } else {
              io.print(7, " 여기서 가져가신 무기를 잘 사용하셔서 세계");
              io.print(7, "의 적인 Necromancer를 무찔러 주십시오.");
            }
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(51, 14)) {
            io.print(7, "MENACE 에는 금덩이가 많다던데...");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(83, 27)) {
            io.print(7, "MENACE 는 한때 금광이었습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(87, 73) || at(91, 65)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(8, 71) || at(14, 69) || at(14, 73)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(87, 14) || at(86, 12)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(21, 12) || at(25, 13)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(50, 51) || at(52, 51)) {
            if ((etc.read(30) & 1) == 1) {
              io.print(7, "행운을 빌겠소 !!!");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            } else if (etc.read(10) < 3) {
              io.print(7, "저희 성주님을 만나 보십시오.");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            } else {
              io.print(10, "당신은 이 게임 세계에 도전하고 싶습니까 ?");
              io.print(10, "(Y/n)");
              c = await io.challengeKey();
              if (!io.isOpen) return;
              // Extended keyboard scan handled by input adapter.
              if (c.toUpperCase() == "Y") {
                io.setTile(49, 52, 47);
                io.setTile(50, 52, 44);
                io.setTile(51, 52, 44);
                io.setTile(52, 52, 44);
                io.setTile(53, 52, 47);
                io.setTile(49, 53, 47);
                io.setTile(50, 53, 44);
                io.setTile(51, 53, 44);
                io.setTile(52, 53, 44);
                io.setTile(53, 53, 45);
                io.print(7, "");
                io.print(7, "예.");
                io.print(7, "");
                io.print(7, "이제부터 당신은 진정한 이 세계에 발을 디디게 되는 것입니다.");
                await io.pressAnyKey();
                if (!io.isOpen) return;
                etc[30] = (etc.read(30) | 1);
                io.refresh();
              } else {
                io.print(7, "");
                io.print(7, "아니오.");
                io.print(7, "");
                io.print(7, "다시 생각 해보십시오.");
                await io.pressAnyKey();
                if (!io.isOpen) return;
              }
            }
          }
          if (at(51, 87)) {
            if ((etc.read(30) & 2) == 0) {
              for (var i = 49; i <= 53; i++) {
                io.setTile(i, 88, 44);
              }
              io.print(7, "난 당신을 믿소, " + party.first.name + ".");
              await io.pressAnyKey();
              if (!io.isOpen) return;
              etc[30] = (etc.read(30) | 2);
              io.refresh();
            } else {
              io.print(7, "힘내시오, " + party.first.name + ".");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            }
          }
          if (((x >= 48 && x <= 54)) && ((y >= 31 && y <= 37))) {
            if (etc.read(10) == 0) {
              io.print(7, "저희 성주님을 만나십시오.");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            } else {
              io.print(7, "당신이 성공하기를 빕니다.");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            }
          }
          if (at(51, 28)) {
            switch (etc.read(10)) {
              case 0:
                {
                  io.cprint(7, 11, " 나는 ", "Lord Ahn", " 이오.");
                  io.print(7, " 이제부터 당신은  이 게임에서 새로운 인물로");
                  io.print(7, "서 생을 시작하게 될것이오. 그럼 나의 이야기");
                  io.print(7, "를 시작하겠소.");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                  etc[10] = etc.read(10) + 1;
                }
              case 1:
                {
                  io.print(7, " 이 세계는 내가 통치하는 동안에는 무척 평화");
                  io.print(7, "로운 세상이 진행되어 왔었소.  그러나 그것은");
                  io.print(7, "한 운명의 장난으로 무참히 깨어져 버렸소.");
                  io.print(7, " 한날, 대기의 공간이 진동하며 난데없는 푸른");
                  io.print(7, "번개가 대륙들 중의 하나를 강타했소.  공간은");
                  io.print(7, "휘어지고 시간은 진동하며  이 세계를 공포 속");
                  io.print(7, "으로 몰고 갔소.  그 번개의 위력으로 그 불운");
                  io.print(7, "한 대륙은  황폐화된 용암 대지로 변하고 말았");
                  io.print(7, "고, 다른 하나의 대륙은 충돌시의 진동에 의해");
                  io.print(7, "바다 깊이 가라앉아 버렸소.");
                  io.print(7, " 그런 일이 있은 한참 후에,  이상하게도 용암");
                  io.print(7, "대지의 대륙으로부터 강한 생명의 기운이 발산");
                  io.print(7, "되기 시작 했소.  그래서, 우리들은 그 원인을");
                  io.print(7, "알아보기 위해 'LORE 특공대'를 조직하기로 합");
                  io.print(7, "의를 하고 이곳에 있는 거의 모든 용사들을 모");
                  io.print(7, "아서 용암 대지로 변한 그 대륙으로 급히 그들");
                  io.print(7, "을 파견하였지만 여태껏 아무 소식도 듣지못했");
                  io.print(7, "소. 그들이 생존해 있는지 조차도 말이오.");
                  io.print(7, " 이런 저런 방법을 통하여 그들의 생사를 알아");
                  io.cprint(7, 11, "려던중 우연히 우리들은 '", "Necromancer", "'라고 불");
                  io.print(7, "리우는  용암 대지속의  새로운 세력의 존재를");
                  io.print(7, "알아내었고,  그때의 그들은 이미 막강한 세력");
                  io.print(7, "으로 성장해가고 있는중 이었소.  그때의 번개");
                  io.print(7, "는 그가 이 공간으로 이동하는 수단이었소. 즉");
                  io.print(7, "그는 이 공간의 인물이 아닌 다른 차원을 가진");
                  io.print(7, "공간에서 왔던 것이오.");
                  io.print(7, " 그는 현재 이 세계의 반을  그의 세력권 안에");
                  io.print(7, "넣고 있소. 여기서 당신의 궁극적인 임무는 바");
                  io.cprint(7, 11, "로 '", "Necromancer 의 야심을 봉쇄 시키는 것", "'이");
                  io.print(7, "라는 걸 명심해 두시오.");
                  io.print(7, "");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                  etc[10] = etc.read(10) + 1;
                }
              case 2:
                {
                  io.print(7, " Necromancer 의 영향력은 이미 LORE 대륙까지");
                  io.print(7, "도달해있소.  또한 그들은 이 대륙의 남서쪽에");
                  io.print(7, "'MENACE' 라고 불리우는 지하 동굴을 얼마전에");
                  io.print(7, "구축했소.  그래서, 그 동굴의 존재 때문에 우");
                  io.print(7, "리들은 그에게 위협을 당하게 되었던 것이오.");
                  io.print(7, " 하지만, LORE 특공대가 이 대륙을 떠난후로는");
                  io.print(7, "그 일당들에게 대적할 용사는  이미  남아있지");
                  io.print(7, "않았소. 그래서 부탁하건데, 그 동굴을 중심부");
                  io.print(7, "까지 탐사해 주시오.");
                  io.print(7, " 나는 당신들에게 Necromancer에 대한 일을 맡");
                  io.print(7, "기고 싶지만, 아직은 당신들의  확실한 능력을");
                  io.print(7, "모르는 상태이지요.  그래서 이 일은 당신들의");
                  io.print(7, "잠재력을 증명해 주는 좋은 기회가 될것이오.");
                  io.print(7, " 만약 당신들이 무기가 필요하다면 무기고에서");
                  io.print(7, "약간의 무기를 가져가도록 허락하겠소.");
                  io.print(7, "");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                  etc[10] = etc.read(10) + 1;
                }
              case 3:
                {
                  io.cprint(7, 11, " 대륙의 남서쪽에 있는 `", "MENACE", "'를 탐사해 주시오.");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                }
              case 4:
                {
                  io.print(7, "당신들의 성공을 축하하오 !!");
                  io.print(11, "[EXP + 1000]");
                  for (var i = 1; i <= 6 && i <= party.length; i++) {
                    if (party[i - 1].name != "") {
                      party[i - 1].experience = LorePascal.longint(
                        party[i - 1].experience + 1000,
                      );
                    }
                  }
                  etc[10] = etc.read(10) + 1;
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                }
              case 5:
                {
                  io.print(7, " 드디어 나는 당신들의 능력을 믿을수 있게 되");
                  io.print(7, "었소.  그렇다면 당신들에게 Necromancer 응징");
                  io.print(7, "이라는 막중한 임무를 한번 맡겨 보겠소.");
                  io.cprint(7, 11, " 먼저 대륙의 동쪽에 있는 '", "LASTDITCH", "'에 가보");
                  io.cprint(7, 11, "도록 하시오. '", "LASTDITCH", "'성에는 지금 많은 근");
                  io.print(7, "심에 쌓여있소. 그들을 도와 주시오.");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                  etc[10] = etc.read(10) + 1;
                }
              case 6:
                {
                  io.print(7, " 당신은 이제 스스로 행동해 나가시오.");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                }
            }
          }
        }
      case 7:
        {
          if (at(51, 55)) {
            io.print(7, "LASTDITCH 성과 VALIANT PEOPLES 성은 매우 닮았다는 말이 있습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(8, 44)) {
            io.print(7, "이 세계는 다섯개의 대륙으로 되어 있다더군요.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(68, 35)) {
            io.print(7, "각각의 대륙에는 서로 통하는 문이 존재합니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(43, 9)) {
            io.print(7, "당신은 PYRAMID 안에서 쉽게 창을 발견할 수 있을것입니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(65, 10)) {
            io.print(7, "GROUND GATE 는 여기로부터 서쪽에 나타나곤 합니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(14, 68)) {
            io.print(7, "LORE 특공대의 지휘관은 저의 남편인데 `Lore Hunter'라고 불렸습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(57, 42)) {
            io.print(7, "Major Mummy 와 두마리의 Sphinx 의 공격은 가히 치명적입니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(44, 34)) {
            io.print(7, "GROUND GATE 는 당신을 다른 대륙으로 인도해 줄것입니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(32, 56)) {
            io.print(7, "LORE 특공대의 지휘관은 상당히 능력있는 인물이었습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(36, 19) ||
              at(36, 21) ||
              at(41, 18) ||
              at(41, 20) ||
              at(41, 22) ||
              at(40, 41)) {
            if (etc.read(13) == 0) {
              io.print(7, "성주님을 만나 보십시오.");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            } else {
              io.print(7, "당신이 성공하기를 빕니다.");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            }
          }
          if (at(37, 41) && (etc.read(13) < 2)) {
            await io.recruit(LoreTalkProcedures.polarisRecruit);
            if (!io.isOpen) return;
          }
          if (at(18, 19) || at(24, 19) || at(21, 21) || at(16, 24)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(57, 17) || at(54, 20) || at(58, 22) || at(59, 25)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(59, 56) || at(59, 58) || at(59, 60)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(17, 56) || at(17, 58) || at(17, 60)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(38, 17)) {
            switch (etc.read(13)) {
              case 0:
                {
                  io.print(7, " 당신이 " + party.first.name + "이오 ?");
                  io.print(7, " 나는 Lord Ahn 에게 당신이 온다는 소식을 전");
                  io.print(7, "해받았소.  들었다시피 우리성에는  큰 문제가");
                  io.print(7, "있소. 그것은 이 성의 북쪽에 위치해있는 동굴");
                  io.print(7, "때문이오.  그 동굴때문에 우리들은 상당한 압");
                  io.print(7, "박을받고 있소.");
                  io.cprint(7, 11, " 만약 당신들이 위대한 영웅이라면, ", "PYRAMID", "라");
                  io.cprint(7, 11, "는 동굴에 있는 ", "Major Mummy", "를 처단해 주시오.");
                  io.print(7, " 당신들이 이 임무를 완수하면  나는 당신들에");
                  io.print(7, "게 도움에 대한 댓가를 치뤄주겠소.");
                  io.print(7, "");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                  etc[13] = etc.read(13) + 1;
                }
              case 1:
                {
                  io.cprint(
                    7,
                    11,
                    " 부탁하건데, PYRAMID의 '",
                    "Major Mummy",
                    "'를 처단",
                  );
                  io.print(7, "해 주시오.");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                }
              case 2:
                {
                  io.print(7, "당신의 성공에 경의를 표하오.");
                  io.print(11, "[EXP + 10000]");
                  io.print(7, "당신의 도움 덕분에 우리의 성이 구제 되었소.");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                  for (var i = 1; i <= 6 && i <= party.length; i++) {
                    if (party[i - 1].name != "") {
                      party[i - 1].experience = LorePascal.longint(
                        party[i - 1].experience + 10000,
                      );
                    }
                  }
                  etc[13] = etc.read(13) + 1;
                }
              case 3:
                {
                  io.cprint(7, 11, " 이 성의 북동쪽에 '", "GROUND GATE", "' 라는것이 있");
                  io.cprint(7, 11, "소. 만약 당신이 '", "GROUND GATE", "' 속에 들어간다");
                  io.cprint(7, 11, "면 '", "VALIANT PEOPLES", "'성으로 통하게 될것이오.");
                  io.cprint(
                    7,
                    11,
                    "'",
                    "VALIANT PEOPLES",
                    "'는 Necromancer에게 매우 심",
                  );
                  io.print(7, "하게 영향을 받고있소.");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                }
            }
          }
        }
      case 9:
        {
          if (at(12, 11) || at(15, 12) || at(12, 15)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(40, 37) || at(37, 39) || at(41, 41)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(37, 10) || at(40, 12) || at(41, 15)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(9, 39) || at(12, 41) || at(16, 40)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(24, 38)) {
            io.print(7, " EVIL SEAL 의 어디엔가에 '황금의 봉인'이 숨겨져 있다더군요.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(23, 12)) {
            io.print(7, " 황금의 갑옷이 QUAKE 동굴 안에 숨겨져있다는 소문이 떠돌고 있습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(28, 18)) {
            io.print(7, " VALIANT PEOPLES 성은 Necromancer에 대한 강");
            io.print(7, "한저항 때문에  그에 의해 쑥밭이 되어 버렸습");
            io.print(7, "니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(30, 31)) {
            io.print(7, " VALIANT PEOPLES 최대의 사냥꾼인 Rigel은 성");
            io.print(7, "을파괴시킨 적들을 물리치기 위해서 EVIL SEAL");
            io.print(7, "로 들어갔습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(34, 38)) {
            io.print(7, "위쪽에는 SWAMP 대륙으로 통하는 문이 있지만 아무도 접근 할 수가 없습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(38, 14)) {
            io.print(7, "QUAKE속에는 많은 비밀문이 있다고 들었습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(15, 42)) {
            io.print(7, "WATER FIELD 로 통하는 문에는 세마리의 Wivern이 지키고 있습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(26, 7)) {
            io.print(7, "SWAMP 대륙으로 통하는 문에는 고르곤 세자매가 살고 있소.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(34, 24) ||
              at(37, 24) ||
              at(41, 24) ||
              at(35, 27) ||
              at(38, 27) ||
              at(41, 27)) {
            if (etc.read(14) == 0) {
              io.print(7, "우리 성주님을 만나보십시오.");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            } else {
              io.print(7, "당신의 성공을 빌겠습니다.");
              await io.pressAnyKey();
              if (!io.isOpen) return;
            }
          }
          if (at(42, 25)) {
            switch (etc.read(14)) {
              case 0:
                {
                  io.print(7, " 당신을 만나게되어 영광이오.");
                  io.print(7, " 나는 LORE 대륙에서의 당신의 공훈을 높이 평");
                  io.print(7, "가하며, 또한 LAST DITCH성을 구제하것에 대해");
                  io.print(7, "서도 감사를 표하오.  LAST DITCH 성의 쌍둥이");
                  io.cprint(
                    7,
                    11,
                    "성인 '",
                    "VALIANT PEOPLES",
                    "'는 Necromancer에 대한",
                  );
                  io.print(7, "강한 저항 때문에 그에 의해서  처참히 파괴되");
                  io.print(7, "었소.  그런후에 그는 'VALIANT PEOPLES'의 지");
                  io.cprint(7, 11, "하에다가 ", "EVIL SEAL", "이라는 동굴을 구축하였소.");
                  io.print(7, "그리고 그는 EVIL SEAL의 어디엔가에  이 대륙");
                  io.print(7, "의 운명을 담고 있는  황금의 봉인을 숨겨놓았");
                  io.print(7, "소. 만약 그 봉인이 풀어진다면, 이 대륙은 봉");
                  io.print(7, "인 속에서 나타난 괴물들에 의해서 황폐화  될");
                  io.print(7, "것이오.");
                  io.cprint(7, 11, " 한시바삐 EVIL SEAL 로 가시오, 그리고 '", "황금", "");
                  io.cprint(7, 11, "", "의 봉인", "'을 찾으시오.");
                  io.print(7, "");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                  etc[14] = etc.read(14) + 1;
                }
              case 1:
                {
                  io.cprint(
                    7,
                    11,
                    " VALIANT PEOPLES에 있는 EVIL SEAL로 가서 ",
                    "황",
                    "",
                  );
                  io.cprint(7, 11, "", "금의 봉인", "을 찾아오시오.");
                  io.print(7, " 지금 지체할 시간이 없소.");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                }
              case 2:
                {
                  io.print(15, " 오, 당신은 황금의 봉인을 찾았군요 !");
                  io.print(15, " [ EXP + 10000 ]");
                  for (var i = 1; i <= 6 && i <= party.length; i++) {
                    if (party[i - 1].name != "") {
                      party[i - 1].experience = LorePascal.longint(
                        party[i - 1].experience + 10000,
                      );
                    }
                  }
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                  etc[14] = etc.read(14) + 1;
                }
              case 3:
                {
                  io.print(7, " 그러나, 이 대륙에는 아직 위험한 장소가  많");
                  io.print(7, "이 있소.");
                  io.cprint(7, 11, " 여기로부터 북동쪽에 '", "QUAKE", "' 라고 불리는 동");
                  io.print(7, "굴이있소. 만약 QUAKE 마저 무너뜨리면, 이 대");
                  io.print(7, "륙은 다시 평화롭게 될것이오.");
                  io.cprint(
                    7,
                    11,
                    " ",
                    "QUAKE",
                    " 로 가서 보스인 ArchiGagoyle과 Zombie",
                  );
                  io.print(7, "들을 물리쳐 주십시오.");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                  etc[14] = etc.read(14) + 1;
                }
              case 4:
                {
                  io.cprint(7, 11, "QUAKE의 ", "ArchiGagoyle", "을 물리치십시오.");
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                }
              case 5:
                {
                  io.print(7, "당신들은 위대한 영웅임에 틀림없군요.");
                  io.print(11, "[ EXP + 40000 ]");
                  io.print(7, "");
                  io.cprint(7, 11, " 여기에 ", "Water Key", "가 있소.");
                  io.cprint(7, 11, " 이 열쇠는 ", "WATER FIELD", "의 문을 열것이오.");
                  for (var i = 1; i <= 6 && i <= party.length; i++) {
                    if (party[i - 1].name != "") {
                      party[i - 1].experience = LorePascal.longint(
                        party[i - 1].experience + 40000,
                      );
                    }
                  }
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                  etc[14] = etc.read(14) + 1;
                }
              case 6:
                {
                  io.cprint(
                    7,
                    11,
                    "WIVERN 동굴의 ",
                    "WATER FIELD의 문",
                    "을 통하여 다음 대륙으로 가십시오.",
                  );
                  await io.pressAnyKey();
                  if (!io.isOpen) return;
                }
            }
          }
        }
      case 10:
        {
          if (at(36, 32) || at(38, 33) || at(39, 35)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(17, 57) || at(12, 59) || at(11, 55)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(11, 30) || at(11, 32) || at(13, 34)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(33, 60) || at(35, 54) || at(41, 58)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(11, 16)) {
            io.print(7, "NOTICE 동굴의 Hidra는 머리가 셋이나 달렸다더군요.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(14, 18)) {
            io.print(7, "NOTICE 동굴은 혼란스러운 미로라서 항상 주위를 염두에 두셔야 합니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(24, 22)) {
            io.print(7, "LOCKUP 동굴은 미로로 구성된 동굴이오.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(27, 22)) {
            io.print(7, "LOCKUP 속에 Minotaur는 Necromancer의 부하는 아닙니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(24, 69)) {
            io.print(7, " LOCKUP 의 보스인 Huge Dragon은 아주 거대한");
            io.print(7, "용이라는데,  그것의 꼬리 또한 강력한 무기라");
            io.print(7, "서 조심해야 할것이오.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(37, 16)) {
            io.print(7, " 고르곤 세자매의 힘은 Necromancer의 힘과 필");
            io.print(7, "적하지만 중대한 약점이 하나 있소.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(40, 18)) {
            io.print(7, "Stheno 와 Euryale는 거의 불멸의 생명체 입니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(40, 56)) {
            await io.recruit(LoreTalkProcedures.loreHunterRecruit);
            if (!io.isOpen) return;
          }
          if (at(25, 18)) {
            await LoreWaterLord.run(party: party, etc: etc, io: io);
          }
        }

      case 24:
        {
          if (at(11, 22) || at(14, 24)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(33, 35) || at(35, 37) || at(41, 38)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(33, 21) || at(37, 24) || at(40, 23)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(15, 36) || at(11, 38) || at(14, 40)) {
            // Facility selected by original coordinates before talkmode.
          }
          if (at(17, 15)) {
            io.print(7, " Ancient Evil은 우리의 구세주였습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(18, 10)) {
            io.print(7, " 이 세상을 이렇게 불행하게 한자는 바로 안 영기라는 프로그래머입니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(20, 13)) {
            io.print(7, " 우리는 여태껏 당신들이 오기를 기다렸습니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(27, 8)) {
            io.print(7, " Ancient Evil은 결코 평판과 같이 나쁜 존재가 아닙니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(31, 13)) {
            io.print(7, " 당신들은 분명히 우리들을 밖으로 나가게 해줄것입니다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
          }
          if (at(33, 10)) {
            // Source pixel coordinates.
            // Source pixel coordinates.
            // Source visual effect.
            // Source visual effect.
            // Source visual effect.
            io.print(7, " 이 사람들은 잘 모르겠지만  사실 나는 이 게");
            io.print(7, "임의 제작자인 안 영기요.");
            io.print(7, " 나는 여태껏 계속 당신들이 가는 도시마다 주");
            io.print(7, "민으로 가장한채 당신들을 지켜 보았소. 이 게");
            io.print(7, "임의 버그를 찾거나 난이도를 조절하기 위해서");
            io.print(7, "말이요. 만약 당신들이 Necromancer 를 물리친");
            io.print(7, "다면 내가 마지막으로 당신앞에 나타나겠소.");
            io.print(7, " 그럼, 이만 나는 가보겠소.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            etc[43] = (etc.read(43) | 8);
            io.setTile(33, 10, 47);
            io.refresh();
          }
        }
      case 27:
        {
          if (at(15, 6)) {
            // Source pixel coordinates.
            // Source pixel coordinates.
            // Source visual effect.
            // Source visual effect.
            // Source visual effect.
            io.print(7, " 당신 앞의 사람이 갑자기 어떤 남자로 변하였");
            io.print(7, "다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(7, " 당신과는 초면이 아니지요? LORE 성에서도 봤");
            io.print(7, "으니까 말이죠. 당신은 나의 정체가 어떨지 궁");
            io.print(7, "금하기도 하겠지만 나중에 밝혀질 일이이까 천");
            io.print(7, "천히 알아보기로 하고  먼저 이 피라밋에 대해");
            io.print(7, "서 말하기로 하지요.");
            io.print(7, " 이 피라밋은 Necromancer와 함께 저편의 공간");
            io.print(7, "에서 퉁겨져 나왔지요. 이곳은 육신은 죽고 의");
            io.print(7, "지만 남은 사람들의 안식처라고도 할수 있죠.");
            io.print(7, " 여기의 '의지'들 중에서  당신과 관계가 없는");
            io.print(7, "의지는 모두 재가 되어버릴 거요. 여기서 얻은");
            io.print(7, "정보는 모두 당신의 운명을 더욱 더 모질게 만");
            io.print(7, "들어 버릴 것들이지만, 만약 당신이 알지 못한");
            io.print(7, "다면 더더욱 더 당신을 힘겹게 하는 것들만 있");
            io.print(7, "지요.  당신의 현명한 판단에 모든걸 맡기도록");
            io.print(7, "하지요.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            // Source visual effect.
          } else if (at(10, 14)) {
            io.print(7, " 당신이 유골에 다가서자  어디선가 소리가 들");
            io.print(7, "려왔다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(7, " 오! 당신이 나의 잠을 깨웠나 ?");
            io.print(7, " 실로 몇 천년 만에 보는 세상이군. 나는 당신");
            io.cprint(7, 12, "의 운명적인 만남을 관장하는 ", "데네브의 의지", "라");
            io.print(7, "고 불리우고 있지. 당신이 만나게 될 사람들은");
            io.print(7, "이미 자네가 세상에 나기 전부터  정해져 있었");
            io.print(7, "다네.  만약 그 사람들을 만나지 않고  지나쳐");
            io.print(7, "버린다거나 못 만나는 경우가 생긴다면 절대로");
            io.print(7, "Necromancer 를 물리치지 못할걸세.  그렇다면");
            io.print(7, "당신이 꼭 만나야 할 사람들을 말해 보겠네.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(15, " Red Antares");
            io.print(7, " 그는 이미 죽은지가 수 천년이 지났지만 그의");
            io.print(7, "의지는 아직 NOTICE란 동굴속에 잠들어 있네.");
            io.print(7, " 그는 과거 최강의 마법사로서 이 땅을 통치하");
            io.print(7, "였고 다시 세계가 혼미스러울때 새로이 나타나");
            io.print(7, "겠노라고 말하며  홀로 그 동굴에서 살다가 죽");
            io.print(7, "었지. 하지만 지금이 그가 말한때라는 걸 그의");
            io.print(7, "영혼이 알수있게만 한다면,  그는 다시금 최강");
            io.print(7, "의 마법사로 부활해서 당신들을 도와주게 되는");
            io.print(7, "사람이지.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(15, " Spica");
            io.print(7, " 지금  초자연력에 대해 알고있고 사용할수 있");
            io.print(7, "는 사람은 몇명되지 않는데, 그중의 한 사람이");
            io.print(7, "Necromancer 이고 또 지금 말하는 Spica 라네.");
            io.print(7, " 자네가 이 기술을 그녀에게 배우지 않는 다면");
            io.print(7, "Necromancer 를 만나기 위한 도중에 무릎을 꿇");
            io.print(7, "고 말것이며 설령 그와 대결하게 된다 해도 자");
            io.print(7, "네들은 참패를 하게 될걸세. 이 기술로 자연을");
            io.print(7, "조작하고 인간의 마음을 읽으며 시공간을 넘겨");
            io.print(7, "볼수만 있다면  분명 당신은 세계 최강의 전사");
            io.print(7, "가 되어있을 걸세.  그리고, 그녀가 있는 곳은");
            io.print(7, "바로 물로 덮인 대륙의 Dragon 이 사는 동굴의");
            io.print(7, "어느 깊숙한 곳이라네.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(15, " Ancient Evil");
            io.print(7, " 그는 지금, 늪의 대륙의 서쪽 바다 건너 작은");
            io.print(7, "섬에 살고 있다네.  그가 사는 섬을 찾기는 무");
            io.print(7, "척 어렵겠지만 초자연력으로 공간을 넘겨 보아");
            io.print(7, "위치를 파악한후 텔리포트 마법을 통해 이동하");
            io.print(7, "면 다다를수 있을 걸세.  그는  당신의 미래를");
            io.print(7, "쉽게 풀어주고, 또 새로운 만남을 이어주게 될");
            io.print(7, "걸세.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(7, " 이 외에도 Polaris, Jr.Antares, Lore Hunter");
            io.print(7, ", Rigel 등등의 사람들을 수도 없이 만나게 되");
            io.print(7, "겠지만 반드시 당신에게 도움을 주지만은 않을");
            io.print(7, "것이며, 만약 당신이 남을 도와 준다면 반드시");
            io.print(7, "그도  당신에게 보이지 않는 도움을 주게 될거");
            io.print(7, "라는 말을 끝으로  나는 다시 몇천년의 잠으로");
            io.print(7, "빠져들어야 겠네. 그럼 안녕히 ...");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            // Source pixel coordinates.
            // Source pixel coordinates.
            // Source blink animation is a presentation effect.
            io.setTile(targetX, targetY, 35);
          } else if (at(10, 18)) {
            io.print(7, " 당신이 유골에 다가서자  어디선가 소리가 들");
            io.print(7, "려왔다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(7, " 당신과 나의 만남은 어렇듯 운명적이네. 나는");
            io.print(7, "당신이 이때쯤 나를 찾아오리라고 내가 잠들기");
            io.print(7, "전 몇 천년 전에 이미 알고 있었다네.");
            io.print(7, " 소개하지. 나는 당신의 순회적 운명을 관장하");
            io.cprint(7, 12, "는 ", "시리우스의 의지", "라고 하네. 당신은 나를 처");
            io.print(7, "음  봤겠지만 나는 원래 당신의 또다른 분신으");
            io.print(7, "로서 당신은 결코 나에게는 낯 설지가 않다네.");
            io.print(7, "당신은 어느 순간에도 당신이  단지 이 세계에");
            io.print(7, "서만 당신의 삶이 존재한다고 생각하는가 ? 분");
            io.print(7, "명 지금 현재로서는 그렇게 밖에  생각을 못하");
            io.print(7, "지만 실제는 그렇지 않지.  당신은 분명 이 순");
            io.print(7, "간에도 다른 공간에서는 또 다른 삶을 살고 있");
            io.print(7, "다네. 하지만 ... '또 다른 삶'이라고 내가 말");
            io.print(7, "했지만  결국은 한 운명을 가지고 계속 윤회하");
            io.print(7, "는 것일뿐이지.  나는 이렇게 당신이 찾아오는");
            io.print(7, "것만도 헤아릴수 없이 겪었지.  언제나 당신은");
            io.print(7, "정해진 운명 때문에 어쩔수 없이 나를 계속 찾");
            io.print(7, "아오게 되는 거라네.  이해가 가지 않을거라고");
            io.print(7, "나도 생각하면서도 달리 설명할 방도가 없어서");
            io.print(7, "이런 애매한 말만 되풀이 할 뿐이네.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(7, " 더 자세한 운명을 알고 싶다면 스왐프 게이트");
            io.print(7, "에 있는 피라밋의 예언서를 읽어 보게나. 그러");
            io.print(7, "면 더 이해가 빠를걸세.");
            io.print(7, " 그래도 잘 이해가 안된다면 '늪의 대륙'의 외");
            io.print(7, "딴 섬에 은둔하고 있는 Draconian을 만나 보도");
            io.print(7, "록 하게. 그는 Necromancer가 이전의 공간에서");
            io.print(7, "이 공간으로 온 이유를 알고 있기 때문이라네.");
            io.print(7, " 그럼 우리의 만남은  다음 공간의 또 다른 운");
            io.print(7, "명에 의해 다시 시작될걸세. 그럼 그때까지 안");
            io.print(7, "녕히!");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            // Source pixel coordinates.
            // Source pixel coordinates.
            // Source blink animation is a presentation effect.
            io.setTile(targetX, targetY, 35);
          } else if (at(10, 30)) {
            io.print(7, " 당신이 유골에 다가서자  어디선가 소리가 들");
            io.print(7, "려왔다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.cprint(7, 12, " 나는 이 세계의 운명을 담당하는  ", "알비레오의", "");
            io.cprint(7, 12, "", "의지", "라고 하오. 나는 이 세상이 생기면서 부터");
            io.print(7, "늘 이런 모습으로 여기서 지내왔소. 나는 이제");
            io.print(7, "껏 세상의 많은 위기들을 보아왔소. 하지만 지");
            io.print(7, "금과 같은 공간을 뛰어 넘은 침입자에 의한 위");
            io.print(7, "기는 처음이라고 기억되오.  나는 이 곳에서도");
            io.print(7, "이 세상 모든것을 볼수있소. 그리고 여태껏 당");
            io.print(7, "신의 자라온 모습과 여기에 서 있는 이유도 알");
            io.print(7, "고 있소. 또한 Necromancer가 이 세상에 온 이");
            io.print(7, "후로 부터의 그의 행동도 보아왔소. 그리고 결");
            io.print(7, "국은 ... ... 당신과 그의 미래도 나에게는 보");
            io.print(7, "여지고 있소.  나는 이 자리에서  미래의 일을");
            io.print(7, "말할수는 없소. 당신이 그 결말을 알고 싶다면");
            io.print(7, "'늪의 대륙'에 있는 Draconian 을 만나 보는게");
            io.print(7, "좋을거요. 그전에 Ancient Evil도 역시 만나게");
            io.print(7, "될것이오. 그리고 한가지를 명심하시오.");
            io.print(15, " 당신이 옳다고 생각하는게 항상 옳은 것은 아");
            io.print(15, "니오. 남들이 증오하는 것이 항상 당신에게 그");
            io.print(15, "릇되게 작용하지는 않을 것이오. 또한, 현재의");
            io.print(15, "증오가 미래의 증오가 되지도 않을 것이오. 그");
            io.print(15, "리고 결국에는 Necromancer를 용서하시오.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            // Source pixel coordinates.
            // Source pixel coordinates.
            // Source blink animation is a presentation effect.
            io.setTile(targetX, targetY, 35);
          } else if (at(21, 32)) {
            io.print(7, " 당신이 유골에 다가서자  어디선가 소리가 들");
            io.print(7, "려왔다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(7, " 안녕하시오. 나는 Necromancer 의 운명을 관장");
            io.cprint(7, 12, "하고 있는 ", "카노푸스의 의지", "라고 하오.  이 공간");
            io.print(7, "뿐만 아니라 다른 공간에서 존재하고 있는 Nec-");
            io.print(7, "romancer의 운명 또한 내가 담당하는 범주에 들");
            io.print(7, "어간다오.  하지만 그는 그의 운명을 따르는 존");
            io.print(7, "재일뿐 그 이상의 의미는 없소.  그는 수도없는");
            io.print(7, "저편의 공간에서 지워진 운명을 다해갔소. 그리");
            io.print(7, "고 또 여기서  다시 그의 운명을 시작하려 하고");
            io.print(7, "있소. 이 공간 하나 밖에 인식하지 못하는 인간");
            io.print(7, "의 사고로는 별 가치가 없는 일이지만,  운명을");
            io.print(7, "따르기 위해 다음 공간에서도 같은 운명을 반복");
            io.print(7, "해야 한다는 그 금단의 이치는  분명 그도 따르");
            io.print(7, "고 싶지 않았을 것이오. 하지만 그는 그 자신도");
            io.print(7, "그것이 절대 바뀔수 없는  패러독스라는걸 알고");
            io.print(7, "있을게요.  Necromancer 그 자신은 정말 불행한");
            io.print(7, "존재라오.  스스로의 운명을 등에 지고  힘겹게");
            io.print(7, "차원을 쫓기어 다니는 힘없는 짐승일 뿐이오.");
            io.print(7, " 당신이  마지막의 그에게  받을수 있는 느낌은");
            io.print(7, "진정한 마음에서 우러나오는 동정일것이오.  당");
            io.print(7, "신은  저번 공간에서도 역시 그것을 느꼈소. 하");
            io.print(7, "지만 그때의 기억은  당신이 이 세계에 그를 물");
            io.print(7, "리치려는 운명을 지니고 다시 태어났을때  이미");
            io.print(7, "사라져 버렸소. 당신은 내말을 이해하지 못하겠");
            io.print(7, "지만 그것은 사실이오.  지금은  그를 증오로서");
            io.print(7, "맞이하려 하겠지만 그 증오는 다시 다음 공간으");
            io.print(7, "로 이어지려하오.  당신이 그를 물리 친다고 하");
            io.print(7, "여도 다시 다음 공간에서도 지금과 같은 대립을");
            io.print(7, "반복할 뿐이오.  당신과 그와의 대립은 이 우주");
            io.print(7, "가 생기기 시작할때 부터 지금까지 수도없이 반");
            io.print(7, "복했고 그 이후로도 이 우주가 사라질때까지 영");
            io.print(7, "원히 반복될 것이오.  그리고  마지막으로 내가");
            io.print(7, "하고 싶은 말은 이런것이오.");
            io.print(15, " 당신은 결국 Necromancer를 동정 할지 모르오.");
            io.print(15, "하지만 결코 그만이 동정의 대상이 아니오.  결");
            io.print(15, "국은  그와 연관되어 운명이 결정지워진 당신도");
            io.print(15, "예외가 될수는 없소.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            // Source pixel coordinates.
            // Source pixel coordinates.
            // Source blink animation is a presentation effect.
            io.setTile(targetX, targetY, 35);
          } else if (at(21, 22)) {
            io.print(7, " 당신이 유골에 다가서자  어디선가 소리가 들");
            io.print(7, "려왔다.");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            io.print(7, " 당신 앞의 유골은 바로 나의것이오. 나를 소개");
            io.cprint(7, 12, "하자면 ", "아크투루스의 의지", "라고 불리우는 존재로");
            io.print(7, "서 Ancient Evil의 운명을 관장하고 있소. 이름");
            io.print(7, "에서 알수있듯이  그를 수호하는 의지는 목자의");
            io.print(7, "성격을 갖고있소. 하지만 그의 이름이나 평판으");
            io.print(7, "로 볼때는  전혀 그런 성격을 알지 못하게 되고");
            io.print(7, "마는게 보통이오. 그는 Lord Ahn과 대립하는 운");
            io.print(7, "명을 지니고 세상에 존재하게 되었소.  마치 당");
            io.print(7, "신과 Necromancer와 같이 말이오. Lord Ahn과의");
            io.print(7, "대립 관계란 운명 때문에  그는 그의 모든 성격");
            io.print(7, "을 포기한채 Lord Ahn을 위하여 악의 편에 서게");
            io.print(7, "되었던 것이오. 그때, 둘중에 누구 하나가 악의");
            io.print(7, "대표가 되지 않으면 안되었고  Lord Ahn은 결코");
            io.print(7, "세인의 지탄을 받는 악을 대표하려고 하지 않음");
            io.print(7, "으로 해서  그가 직접 악의 대표가 되기로 하였");
            io.print(7, "던 것이오. 하지만 원래 그의 마음은 극도의 선");
            io.print(7, "에 있었기 때문에  결국 그의 악이란 악의 대표");
            io.print(7, "정도 밖에는 될수없었던 것이오. 하지만 반대로");
            io.print(7, "Lord Ahn의 입장에서는  그를 계속 비판하며 사");
            io.print(7, "람들에게  선의 개념을 심어주려 하였으므로 결");
            io.print(7, "국은 그에 대한 철저한 조작으로 위장해서 그를");
            io.print(7, "비하 시키고 자신을 부각 시켜, 어릴때 부터 선");
            io.print(7, "과 악의 개념을 구분 시키고  악을 배척하는 생");
            io.print(7, "활을 하여 사회를 순탄하게 이끌어 나가려고 하");
            io.print(7, "였소. 물론 Lord Ahn의 생각이 틀렸다고는 할수");
            io.print(7, "없소.  그게 Lord Ahn의 운명이라 할수 있기 때");
            io.print(7, "문이오. 항상 Lord Ahn의 마음도 편하지 않다는");
            io.print(7, "걸 알고 있소. 절친한 동반자인 그를 적으로 돌");
            io.print(7, "려 버린것도  그의 운명을 벗어날 수 없었기 때");
            io.print(7, "문이오. 그리고 그들의 경지는 반신 반인이라는");
            io.print(7, "최고의 경지에 올랐소.  당신 역시 Necromancer");
            io.print(7, "에게 도전하고자 한다면 그 경지에 다다라야 하");
            io.print(7, "오. 분명 그들 둘의 능력으로는 당신과 당신 일");
            io.print(7, "행들을 반신 반인으로 만들어 줄수 있을것이오.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            // Source pixel coordinates.
            // Source pixel coordinates.
            // Source blink animation is a presentation effect.
            io.setTile(targetX, targetY, 35);
          } else if (at(21, 12)) {
            io.print(7, " 당신 앞에 있는 유골의 손에는 어떤 두루마리");
            io.print(7, "가 쥐어져 있었다.");
            m[0] = "";
            m[1] = "그 문서를 읽어 보고 싶다";
            m[2] = "그냥 지나 가겠다";
            if ((await io.select(m[0], [m[1], m[2]], clean: false)) != 1) {
              return;
            }
            io.clear();
            io.print(15, " Durant l'estoille cheuelue apparente,");
            io.print(7, " 머리를 푼 별이 나타날때");
            io.print(15, " Les trois grand princes seront faits ennemies,");
            io.print(7, " 거대한 세 왕자가 서로를 적대한다");
            io.print(15, " Frappez du ciel paix terre trembulente,");
            io.print(7, " 평화는 하늘에서 당하고 대지는 요동한다");
            io.print(15, " En son haut auge de l'exaltation,");
            io.print(7, " 그 찬미해야 할 높은 오류 속에서");
            io.print(15, " Neromancer sur le bord mis.");
            io.print(7, " Necromancer 는 해안으로 밀려나리라.");
            io.print(7, "");
            await io.pressAnyKey();
            if (!io.isOpen) return;
            // Source pixel coordinates.
            // Source pixel coordinates.
            // Source blink animation is a presentation effect.
            io.setTile(targetX, targetY, 35);
          } else {
            // Source pixel coordinates.
            // Source pixel coordinates.
            io.message(7, " 당신이 유골에 다가가자 재로 변하였다.");
            // Source blink animation is a presentation effect.
            io.setTile(targetX, targetY, 35);
          }
        }
    }
  }
}
