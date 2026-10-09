# 이식 완료 검증의 빈칸

`python3 tool/report_completion_gaps.py --check`로 최신 여부를 확인한다.
실행 계획은 `docs/porting/direct_port_strategy.md` 하나이며, 이 문서는 장부에서 생성한 검토 색인이다.
미분류·부분 근거는 미구현 개수나 완료율이 아니다. 플랫폼 분기의 제외도 어댑터 검증 완료를 뜻하지 않는다.

게임 제어 지점 1848개: 미분류 0개, 부분 근거 34개, 검증 완료 1814개.
지도 쓰기 0개는 개별 계약 연결이 없다. 테스트가 없는 것으로 해석하지 않는다.

## 미분류가 남은 루틴

| 원본 루틴 | 미분류 | 부분 근거 | 검증 완료 |
| --- | ---: | ---: | ---: |

## 테스트에서 참조하지만 계약 연결이 없는 DOS 근거 후보

파일명·테스트 참조만으로 원본 분기를 검증했다고 판정하지 않는다. 각 fixture의 source/scope와 실제 테스트 비교를 검토해야 한다.
명시 연결과 계약 note의 파일명 언급을 모두 검색하며, 간접 helper 참조는 이 표에서 누락될 수 있다.

| 근거 파일 | 테스트 후보 |
| --- | --- |
| `test/fixtures/dos_archi_continuation.json` | `test/archi_native_dos_test.dart` |
| `test/fixtures/dos_auto_select.json` | `test/auto_select_dos_test.dart` |
| `test/fixtures/dos_battle_clear.json` | `test/battle_clear_dos_test.dart` |
| `test/fixtures/dos_battle_commands.json` | `test/battle_commands_dos_test.dart` |
| `test/fixtures/dos_battle_esp.json` | `test/battle_esp_dos_test.dart` |
| `test/fixtures/dos_battle_menus.json` | `test/battle_menus_dos_test.dart` |
| `test/fixtures/dos_cast_special.json` | `test/cast_special_dos_test.dart` |
| `test/fixtures/dos_chamber_battle_phase.json` | `test/chamber_battle_native_dos_test.dart` |
| `test/fixtures/dos_chamber_continuation.json` | `test/chamber_battle_native_dos_test.dart` |
| `test/fixtures/dos_companion_selection.json` | `test/companion_selection_dos_test.dart` |
| `test/fixtures/dos_condition_storage.json` | `test/boss_hp_override_ui_test.dart` · `test/condition_storage_dos_test.dart` |
| `test/fixtures/dos_creation_class.json` | `test/creation_class_dos_test.dart` |
| `test/fixtures/dos_creation_fourth.json` | `test/creation_fourth_dos_test.dart` |
| `test/fixtures/dos_creation_palette.json` | `test/creation_palette_dos_test.dart` |
| `test/fixtures/dos_creation_second.json` | `test/creation_second_dos_test.dart` |
| `test/fixtures/dos_cure_overflow.json` | `test/field_magic_test.dart` |
| `test/fixtures/dos_draconian_continuation.json` | `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_enemy_colors.json` | `test/enemy_colors_dos_test.dart` |
| `test/fixtures/dos_enemy_phase.json` | `test/enemy_phase_dos_test.dart` |
| `test/fixtures/dos_enemy_selection.json` | `test/enemy_selection_dos_test.dart` |
| `test/fixtures/dos_enemy_special_cast.json` | `test/enemy_special_cast_dos_test.dart` |
| `test/fixtures/dos_evil_god_first_attempt.json` | `test/crab_king_battle_dos_test.dart` · `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_evil_god_success.json` | `test/evil_god_native_completion_test.dart` |
| `test/fixtures/dos_field_pages.json` | `test/field_pages_dos_test.dart` |
| `test/fixtures/dos_fill_patterns.json` | `test/scroll_fill_dos_test.dart` |
| `test/fixtures/dos_final_battle_phase.json` | `test/final_battle_native_dos_test.dart` |
| `test/fixtures/dos_final_party_order.json` | `test/final_battle_native_dos_test.dart` |
| `test/fixtures/dos_findgold.json` | `test/findgold_dos_test.dart` · `test/menace_entry_dos_ui_test.dart` |
| `test/fixtures/dos_first_field_battle.json` | `test/first_field_battle_dos_test.dart` · `test/first_field_battle_dos_ui_test.dart` |
| `test/fixtures/dos_frost_battle_phase.json` | `test/frost_battle_dos_test.dart` |
| `test/fixtures/dos_frost_continuation.json` | `test/frost_battle_dos_test.dart` |
| `test/fixtures/dos_hidden_levers_continuation.json` | `test/hidden_levers_native_dos_test.dart` |
| `test/fixtures/dos_hospital_wound.json` | `test/hospital_wound_dos_test.dart` |
| `test/fixtures/dos_join_bounds.json` | `test/join_bounds_dos_test.dart` |
| `test/fixtures/dos_keep2_completion.json` | `test/keep2_completion_dos_test.dart` |
| `test/fixtures/dos_keep2_continuation.json` | `test/keep2_battle_dos_test.dart` · `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_keep3_continuation.json` | `test/keep3_native_dos_test.dart` |
| `test/fixtures/dos_load_font_errors.json` | `test/load_font_errors_dos_test.dart` |
| `test/fixtures/dos_load_phases.json` | `test/load_phases_dos_test.dart` · `test/saved_map_header_test.dart` |
| `test/fixtures/dos_load_record_errors.json` | `test/load_record_errors_dos_test.dart` |
| `test/fixtures/dos_lockup_continuation.json` | `test/lockup_battle_dos_test.dart` · `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_lorehunter_reentry.json` | `test/dialogue_window_test.dart` |
| `test/fixtures/dos_madjoe_reentry.json` | `test/dialogue_window_test.dart` |
| `test/fixtures/dos_main_input_gates.json` | `test/main_input_gates_dos_test.dart` · `test/main_tab_palette_dos_test.dart` |
| `test/fixtures/dos_main_sound.json` | `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_menace_center.json` | `test/menace_center_dos_test.dart` · `test/menace_entry_dos_ui_test.dart` |
| `test/fixtures/dos_menace_return.json` | `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_metal_battle_phase.json` | `test/metal_battle_dos_test.dart` |
| `test/fixtures/dos_metal_continuation.json` | `test/metal_battle_dos_test.dart` |
| `test/fixtures/dos_muddy_continuation.json` | `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_notice_continuation.json` | `test/hidra_battle_dos_test.dart` · `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_pyramid_battle.json` | `test/pyramid_battle_dos_test.dart` |
| `test/fixtures/dos_quake_continuation.json` | `test/menace_return_dos_ui_test.dart` · `test/quake_battle_dos_test.dart` |
| `test/fixtures/dos_random_order.json` | `test/random_order_dos_test.dart` |
| `test/fixtures/dos_random_stream.json` | `test/lore_random_test.dart` |
| `test/fixtures/dos_recruit_storage.json` | `test/condition_storage_dos_test.dart` · `test/recruit_storage_dos_test.dart` · `test/special_cast_slots_test.dart` |
| `test/fixtures/dos_rest_states.json` | `test/rest_dos_parity_test.dart` |
| `test/fixtures/dos_second_field_battle.json` | `test/first_field_battle_dos_ui_test.dart` · `test/second_field_battle_dos_test.dart` |
| `test/fixtures/dos_special_arrival.json` | `test/special_arrival_dos_test.dart` |
| `test/fixtures/dos_swamp_gate_continuation.json` | `test/gorgon_battle_dos_test.dart` · `test/menace_return_dos_ui_test.dart` |
| `test/fixtures/dos_terrain_states.json` | `test/terrain_dos_parity_test.dart` |
| `test/fixtures/dos_title_intro.json` | `test/title_intro_dos_test.dart` |
| `test/fixtures/dos_town_tile42.json` | `test/bgi_font_decoder_test.dart` |
| `test/fixtures/dos_training_dispatch.json` | `test/training_dispatch_dos_test.dart` |
| `test/fixtures/dos_water_lord_rewards.json` | `test/lore_water_lord_test.dart` |
| `test/fixtures/dos_wivern_continuation.json` | `test/menace_return_dos_ui_test.dart` · `test/wivern_battle_dos_test.dart` |

## 상세 위치

동명의 JSON에 미분류 지점의 원본 파일·행·루틴·계약 ID, 지도 쓰기의 좌표식·값,
DOS fixture별 명시 연결·note 언급·테스트 후보를 모두 기록한다.

최근 최종전/엔딩 근거는 기존 partial 계약의 supporting_evidence로 연결했다.
최종전의 8개 닫힌 턴과 실제 엔딩 도달은 새 게임부터의 연속 재생, 모든 패배/도주 분기,
전체 BGI/DAC·busy Thunder 난수 동등성을 증명하지 않는다.
