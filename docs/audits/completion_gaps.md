# 이식 완료 검증의 빈칸

`python3 tool/report_completion_gaps.py --check`로 최신 여부를 확인한다.
실행 계획은 `docs/porting/direct_port_strategy.md` 하나이며, 이 문서는 장부에서 생성한 검토 색인이다.
미분류·부분 근거는 미구현 개수나 완료율이 아니다. 플랫폼 분기의 제외도 어댑터 검증 완료를 뜻하지 않는다.

게임 제어 지점 1848개: 미분류 356개, 부분 근거 1492개, 검증 완료 0개.
지도 쓰기 123개는 개별 계약 연결이 없다. 테스트가 없는 것으로 해석하지 않는다.

## 미분류가 남은 루틴

| 원본 루틴 | 미분류 | 부분 근거 | 검증 완료 |
| --- | ---: | ---: | ---: |
| `LORECRET.PAS:erase:1` | 42 | 0 | 0 |
| `LOREENT.PAS:entermode:1` | 40 | 46 | 0 |
| `LORECRET.PAS:fourth:1` | 22 | 4 | 0 |
| `LOREHELP.PAS:title_menu:1` | 21 | 0 | 0 |
| `LORECRET.PAS:third:1` | 17 | 0 | 0 |
| `LORESUB.PAS:load:1` | 15 | 6 | 0 |
| `LORETALK.PAS:talkmode:1` | 14 | 132 | 0 |
| `LOREMAIN.PAS:main:1` | 13 | 13 | 0 |
| `LORESPEC.PAS:specialevent_part2:1` | 13 | 247 | 0 |
| `LORECRET.PAS:second:1` | 10 | 0 | 0 |
| `LORESUB.PAS:selectenemy:1` | 10 | 0 | 0 |
| `LORE.PAS:<main>` | 8 | 0 | 0 |
| `LORECRET.PAS:name:1` | 8 | 0 | 0 |
| `LORESUB.PAS:set_all:1` | 8 | 0 | 0 |
| `LORESUB.PAS:simplediscond:1` | 8 | 0 | 0 |
| `LORESPEC.PAS:specialevent_part1:1` | 7 | 157 | 0 |
| `LORESUB.PAS:choosewhom:1` | 7 | 0 | 0 |
| `LORESUB.PAS:auxscroll:1` | 6 | 0 | 0 |
| `LOREHELP.PAS:scroll_sub:1` | 5 | 0 | 0 |
| `LORESUB.PAS:display_condition:1` | 5 | 0 | 0 |
| `LORESUB.PAS:scroll:1` | 5 | 2 | 0 |
| `LORECRET.PAS:last:1` | 4 | 1 | 0 |
| `LORECRET.PAS:display:1` | 3 | 0 | 0 |
| `LOREHELP.PAS:box:1` | 3 | 0 | 0 |
| `LORESUB.PAS:displaycondition:1` | 3 | 0 | 0 |
| `LORESUB.PAS:displayesp:1` | 3 | 0 | 0 |
| `LORESUB.PAS:displayhp:1` | 3 | 0 | 0 |
| `LORESUB.PAS:displaysp:1` | 3 | 0 | 0 |
| `LORESUB.PAS:eprint:1` | 3 | 0 | 0 |
| `LORESUB.PAS:save:1` | 3 | 0 | 0 |
| `LORECRET.PAS:profile:1` | 2 | 0 | 0 |
| `LOREENT.PAS:sign:1` | 2 | 28 | 0 |
| `LOREHELP.PAS:text_fading:1` | 2 | 0 | 0 |
| `LOREMAIN.PAS:enter_lava:1` | 2 | 11 | 0 |
| `LOREMAIN.PAS:enter_swamp:1` | 2 | 15 | 0 |
| `LOREMAIN.PAS:enter_water:1` | 2 | 0 | 0 |
| `LORESPEC.PAS:sgn:1` | 2 | 0 | 0 |
| `LORESUB.PAS:join:1` | 2 | 0 | 0 |
| `LORESUB.PAS:pressanykey:1` | 2 | 0 | 0 |
| `LORESUB.PAS:returnjoinmember:1` | 2 | 0 | 0 |
| `LORESUB.PAS:returnmagic:1` | 2 | 0 | 0 |
| `LORESUB.PAS:returnweapon:1` | 2 | 0 | 0 |
| `LORESUB.PAS:setscrolltype:1` | 2 | 0 | 0 |
| `LORECRET.PAS:createcharacter:1` | 1 | 0 | 0 |
| `LORECRET.PAS:whatclass:1` | 1 | 0 | 0 |
| `LORECRET.PAS:which:1` | 1 | 0 | 0 |
| `LOREHELP.PAS:messagebox:1` | 1 | 0 | 0 |
| `LORESPEC.PAS:specialevent:1` | 1 | 0 | 0 |
| `LORESUB.PAS:at:1` | 1 | 0 | 0 |
| `LORESUB.PAS:auxprint:1` | 1 | 0 | 0 |
| `LORESUB.PAS:clear:1` | 1 | 0 | 0 |
| `LORESUB.PAS:exist:1` | 1 | 0 | 0 |
| `LORESUB.PAS:message:1` | 1 | 0 | 0 |
| `LORESUB.PAS:on:1` | 1 | 0 | 0 |
| `LORESUB.PAS:returnclass:1` | 1 | 0 | 0 |
| `LORESUB.PAS:returndefense:1` | 1 | 0 | 0 |
| `LORESUB.PAS:returnmessage:1` | 1 | 0 | 0 |
| `LORESUB.PAS:returnsex:1` | 1 | 0 | 0 |
| `LORESUB.PAS:returnsexdata:1` | 1 | 0 | 0 |
| `LORESUB.PAS:turn_mind:1` | 1 | 0 | 0 |
| `LORESUB.PAS:unsound:1` | 1 | 0 | 0 |

## 테스트에서 참조하지만 계약 연결이 없는 DOS 근거 후보

파일명·테스트 참조만으로 원본 분기를 검증했다고 판정하지 않는다. 각 fixture의 source/scope와 실제 테스트 비교를 검토해야 한다.
명시 연결과 계약 note의 파일명 언급을 모두 검색하며, 간접 helper 참조는 이 표에서 누락될 수 있다.

| 근거 파일 | 테스트 후보 |
| --- | --- |
| `test/fixtures/dos_archi_continuation.json` | `test/archi_native_dos_test.dart` |
| `test/fixtures/dos_auto_select.json` | `test/auto_select_dos_test.dart` |
| `test/fixtures/dos_chamber_battle_phase.json` | `test/chamber_battle_native_dos_test.dart` |
| `test/fixtures/dos_chamber_continuation.json` | `test/chamber_battle_native_dos_test.dart` |
| `test/fixtures/dos_condition_storage.json` | `test/boss_hp_override_ui_test.dart` · `test/condition_storage_dos_test.dart` |
| `test/fixtures/dos_cure_overflow.json` | `test/field_magic_test.dart` |
| `test/fixtures/dos_draconian_continuation.json` | `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_evil_god_first_attempt.json` | `test/crab_king_battle_dos_test.dart` · `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_evil_god_success.json` | `test/evil_god_native_completion_test.dart` |
| `test/fixtures/dos_final_battle_phase.json` | `test/final_battle_native_dos_test.dart` |
| `test/fixtures/dos_final_party_order.json` | `test/final_battle_native_dos_test.dart` |
| `test/fixtures/dos_first_field_battle.json` | `test/first_field_battle_dos_test.dart` · `test/first_field_battle_dos_ui_test.dart` |
| `test/fixtures/dos_frost_battle_phase.json` | `test/frost_battle_dos_test.dart` |
| `test/fixtures/dos_frost_continuation.json` | `test/frost_battle_dos_test.dart` |
| `test/fixtures/dos_hidden_levers_continuation.json` | `test/hidden_levers_native_dos_test.dart` |
| `test/fixtures/dos_hospital_wound.json` | `test/hospital_wound_dos_test.dart` |
| `test/fixtures/dos_keep2_completion.json` | `test/keep2_completion_dos_test.dart` |
| `test/fixtures/dos_keep2_continuation.json` | `test/keep2_battle_dos_test.dart` · `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_keep3_continuation.json` | `test/keep3_native_dos_test.dart` |
| `test/fixtures/dos_lockup_continuation.json` | `test/lockup_battle_dos_test.dart` · `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_lorehunter_reentry.json` | `test/dialogue_window_test.dart` |
| `test/fixtures/dos_madjoe_reentry.json` | `test/dialogue_window_test.dart` |
| `test/fixtures/dos_main_sound.json` | `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_menace_center.json` | `test/menace_center_dos_test.dart` · `test/menace_entry_dos_ui_test.dart` |
| `test/fixtures/dos_menace_return.json` | `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_metal_battle_phase.json` | `test/metal_battle_dos_test.dart` |
| `test/fixtures/dos_metal_continuation.json` | `test/metal_battle_dos_test.dart` |
| `test/fixtures/dos_muddy_continuation.json` | `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_notice_continuation.json` | `test/hidra_battle_dos_test.dart` · `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_quake_continuation.json` | `test/menace_return_dos_ui_test.dart` · `test/quake_battle_dos_test.dart` |
| `test/fixtures/dos_random_stream.json` | `test/lore_random_test.dart` |
| `test/fixtures/dos_recruit_storage.json` | `test/condition_storage_dos_test.dart` · `test/recruit_storage_dos_test.dart` · `test/special_cast_slots_test.dart` |
| `test/fixtures/dos_rest_states.json` | `test/rest_dos_parity_test.dart` |
| `test/fixtures/dos_second_field_battle.json` | `test/first_field_battle_dos_ui_test.dart` · `test/second_field_battle_dos_test.dart` |
| `test/fixtures/dos_swamp_gate_continuation.json` | `test/gorgon_battle_dos_test.dart` · `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_terrain_states.json` | `test/terrain_dos_parity_test.dart` |
| `test/fixtures/dos_town_tile42.json` | `test/bgi_font_decoder_test.dart` |
| `test/fixtures/dos_water_lord_rewards.json` | `test/lore_water_lord_test.dart` |
| `test/fixtures/dos_wivern_continuation.json` | `test/menace_return_dos_ui_test.dart` · `test/wivern_battle_dos_test.dart` |

## 상세 위치

동명의 JSON에 미분류 지점의 원본 파일·행·루틴·계약 ID, 지도 쓰기의 좌표식·값,
DOS fixture별 명시 연결·note 언급·테스트 후보를 모두 기록한다.

최근 최종전/엔딩 근거는 기존 partial 계약의 supporting_evidence로 연결했다.
최종전의 8개 닫힌 턴과 실제 엔딩 도달은 새 게임부터의 연속 재생, 모든 패배/도주 분기,
전체 BGI/DAC·busy Thunder 난수 동등성을 증명하지 않는다.
