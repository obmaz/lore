# 또 다른 지식의 성전 (LORE 1993) 게임 명세서 (DOCS_GAME_SPECS.md)

본 문서는 1993년 출시된 16비트 MS-DOS/Borland Pascal 6.0 기반 RPG **‘또 다른 지식의 성전’ (LORE, 1993)** 원본 소스 코드(`LORESUB.PAS`, `LOREBATT.PAS`, `LOREMAIN.PAS`, `LORECRET.PAS`, `FOEDATA.DAT` 등)를 정밀 역공학 및 분석하여, Flutter 게임 엔진(Flame 등)으로 완벽하게 이식하기 위해 작성된 공식 기술 명세서입니다.

---

## 1. 코어 데이터 구조 (Core Data Structures)

### 1.1 플레이어 캐릭터 구조체 (`lore` Record)
파스칼 원본의 파티원 캐릭터 정보(`player: array[1..7] of lore`, 실제 파티 슬롯은 최대 6명) 정의입니다.

| 필드명 | 파스칼 타입 | Dart 권장 타입 | 설명 |
| :--- | :--- | :--- | :--- |
| `name` | `string[17]` | `String` | 캐릭터 이름 (최대 16자 한글/영문) |
| `sex` | `(male, female)` | `Gender (enum)` | 성별 (0: 남성, 1: 여성) |
| `class` | `byte` | `int` / `PlayerClass (enum)` | 직업 ID (1 ~ 10) |
| `strength` | `byte` | `int` | 힘 (물리 공격력 및 근력) |
| `mentality` | `byte` | `int` | 정신력 / 지능 (마법 공격력 및 최대 SP) |
| `concentration` | `byte` | `int` | 집중력 (초감각 공격력 및 최대 ESP) |
| `endurance` | `byte` | `int` | 지구력 / 체력 (최대 HP 및 방어 기절 저항) |
| `resistance` | `byte` | `int` | 저항력 (적의 공격/마법 저지 확률, 백분율 0~100) |
| `agility` | `byte` | `int` | 민첩성 (도망 확률, 회피 등에 관여) |
| `accuracy` | `array[1..3] of byte` | `List<int>` | 명중률 ([1]: 물리 무기, [2]: 마법, [3]: 초능력) |
| `luck` | `byte` | `int` | 행운 (레벨업 시 스탯 증가 확률, 상태이상 회피) |
| `poison` | `byte` | `int` | 독 누적 턴 카운터 (0: 정상, >0: 중독) |
| `unconscious` | `integer` | `int` | 의식불명(기절) 누적 피해량 (0: 정상, >0: 기절) |
| `dead` | `integer` | `int` | 사망 누적 수치 (0: 생존, >0: 사망) |
| `hp` | `integer` | `int` | 현재 체력 (최대치: `endurance * level[1]`) |
| `sp` | `integer` | `int` | 현재 마법 포인트 (최대치: `mentality * level[2]`) |
| `esp` | `integer` | `int` | 현재 초감각 포인트 (최대치: `concentration * level[3]`) |
| `level` | `array[1..3] of byte` | `List<int>` | [1]: 전투 레벨, [2]: 마법 레벨, [3]: 초감각 레벨 |
| `ac` | `byte` | `int` | Armor Class (방어도, `shi_power + arm_power`, 최대 10) |
| `experience` | `longint` | `int` | 누적 경험치 |
| `weapon` | `byte` | `int` | 장착 무기 ID (0: 맨손, 1~9: 무기류) |
| `shield` | `byte` | `int` | 장착 방패 ID (0: 없음, 1~5: 방패 등급) |
| `armor` | `byte` | `int` | 장착 갑옷 ID (0: 없음, 1~5: 갑옷 등급) |
| `wea_power` | `byte` | `int` | 무기 위력 수치 |
| `shi_power` | `byte` | `int` | 방패 방어력 수치 |
| `arm_power` | `byte` | `int` | 갑옷 방어력 수치 |

### 1.2 파티 및 월드 상태 구조체 (`loreplayer` Record)
파티 전역 데이터(`party: loreplayer`)로 월드 이동 및 퀘스트 플래그를 저장합니다.

| 필드명 | 파스칼 타입 | Dart 권장 타입 | 설명 |
| :--- | :--- | :--- | :--- |
| `map` | `byte` | `int` | 현재 맵 ID (1~5: 필드, 6~13: 마을, 14~: 던전 등) |
| `xaxis` | `byte` | `int` | 파티의 X 좌표 (격자 인덱스) |
| `yaxis` | `byte` | `int` | 파티의 Y 좌표 (격자 인덱스) |
| `food` | `byte` | `int` | 현재 보유 식량 (최대 255) |
| `gold` | `longint` | `int` | 보유 골드 (금화) |
| `etc` | `array[1..100] of byte` | `List<int>` | 퀘스트 및 시스템 플래그 (비트마스크 조합 사용) |

### 1.3 몬스터 데이터 구조체 (`enemydata1` & `enemydata2`)
- `enemydata1`: 원본 템플릿 레코드 (`FOEDATA.DAT`에서 75종 로드, 각 29바이트 고정)
- `enemydata2`: 전투 중 인스턴스 레코드 (`enemy: array[1..7] of enemydata2`)

```pascal
enemydata2 = record
   E_number : byte;                  // 몬스터 도감 ID (1 ~ 75)
   name : string[16];                // 몬스터 이름 (예: Orc, Goblin, Dragon)
   strength : byte;                  // 공격력
   mentality : byte;                 // 마법 공격력 / 속성
   endurance : byte;                 // 체력 계수 (최대 HP = endurance * level)
   resistance : byte;                // 플레이어 공격/마법 저지율 (백분율)
   agility : byte;                   // 민첩성 (특수기 발동 판정 및 턴)
   accuracy : array[1..2] of byte;   // [1]: 무기 명중률, [2]: 마법 명중률
   ac : byte;                        // 방어도
   special : byte;                   // 특수 공격 플래그
   castlevel : byte;                 // 마법 구사 레벨 (0~5)
   specialcastlevel : byte;          // 특수 마법 구사 레벨
   level : byte;                     // 몬스터 레벨
   hp : integer;                     // 현재 HP
   poison : boolean;                 // 독 상태
   unconscious : boolean;            // 의식불명(기절) 상태
   dead : boolean;                   // 사망 상태
end;
```

---

## 2. 직업, 아이템 및 장비 체계

### 2.1 직업 (Classes) 목록
| ID | 직업명 | 특성 및 기본 보너스 |
| :---: | :--- | :--- |
| **1** | 기사 (Knight) | 기본 AC +1 보너스, 무기 위력 +50% 보너스. 물리/방어형 |
| **2** | 마법사 (Mage) | 마법 명중률 우수, 고레벨 공격/보조 마법 구사 |
| **3** | 에스퍼 (Esper) | 염력/투시 등 초감각(ESP) 특화 직업 |
| **4** | 전사 (Warrior) | 높은 체력과 물리 공격력, 균형 잡힌 명중률 |
| **5** | 전투승 (Monk) | 무기 장착 불가, 레벨에 따라 맨손 위력 자동 상승 (`wea_power = level*2 + 10`) |
| **6** | 닌자 (Ninja) | 높은 저항력과 민첩성, 하이브리드 성장 |
| **7** | 사냥꾼 (Hunter) | 무기 정확도 및 민첩성 중심 |
| **8** | 떠돌이 (Vagrant) | 올라운드형 캐릭터 |
| **9** | 혼령 (Ghost) | 마법 중심 성장 |
| **10** | 반신 (Demigod) | 모든 능력치가 최상급인 특수 캐릭터 |

### 2.2 무기 (Weapons)
`LORESUB.PAS`의 상점 및 초기화 정의에 따른 무기 목록:

| ID | 무기명 | 기본 위력 (`wea_power`) | 구매 가격 (금화) | 비고 |
| :---: | :--- | :---: | :---: | :--- |
| **0** | 맨손 | 2 (기사: 3, 전투승: 12) | - | 기본 장착 |
| **1** | 단도 | 5 | 500 | |
| **2** | 곤봉 | 7 | 1,500 | |
| **3** | 미늘창 | 9 | 3,000 | |
| **4** | 장검 | 10 | 5,000 | |
| **5** | 철퇴 | 15 | 10,000 | |
| **6** | 기병창 | 20 | 30,000 | |
| **7** | 도끼창 | 30 | 60,000 | |
| **8** | 삼지창 | 40 | 80,000 | |
| **9** | 화염검 | 50 | 100,000 | 최상급 무기 |

* 기사(Class 1)가 무기 장착 시: `wea_power = wea_power + round(wea_power * 0.5)`
* 전투승(Class 5)은 무기 상점 구매 불가(맨손 자동 레벨 스케일링)

### 2.3 방어구 (Armor & Shields)
| 등급 ID | 재질명 | 방패 위력 (`shi_power`) | 방패 가격 | 갑옷 위력 (`arm_power`) | 갑옷 가격 |
| :---: | :--- | :---: | :---: | :---: | :---: |
| **0** | 없음 | 0 | - | 0 | - |
| **1** | 가죽 | 1 | 1,000 | 2 (`k + 1`) | 5,000 |
| **2** | 청동 | 2 | 5,000 | 3 (`k + 1`) | 25,000 |
| **3** | 강철 | 3 | 25,000 | 4 (`k + 1`) | 80,000 |
| **4** | 은제 | 4 | 80,000 | 5 (`k + 1`) | 100,000 |
| **5** | 금제 | 5 | 100,000 | 6 (`k + 1`) | 200,000 |

* **총 방어도 공식**:
  $$\text{AC} = \min(10, \text{shi\_power} + \text{arm\_power} + (\text{class} == 1 ? 1 : 0))$$

---

## 3. 전투 시스템 및 상세 공식 (Combat Mechanics - LOREBATT.PAS)

### 3.1 전투 흐름 및 턴 결정 구조 (Turn Flow)
1. **인카운터 및 기습(`assault`) 판정**:
   - `assault == false` (적에게 기습당함): 적들이 1턴 먼저 전체 공격을 실행한 후 2단계로 진행.
   - `assault == true` (정상 인카운터): 플레이어 파티가 먼저 행동을 선택.
2. **명령 입력 단계 (Player Phase)**:
   - 생존한 파티원(1..6)이 순차적으로 명령 선택:
     1. 무기 공격 (단일 적 대상 지정)
     2. 단일 마법 공격 (마법 종류 및 대상 적 지정)
     3. 전체 마법 공격 (마법 종류 지정)
     4. 특수 마법 공격
     5. 일행 치료
     6. 초능력 (ESP) 사용
     7. 도망 시도 (1번 리더의 경우 '일행 전체 자동 공격(AutoBattle)' 선택 가능)
3. **플레이어 행동 실행 단계**:
   - 파티원 1번부터 6번까지 순서대로 입력된 행동을 즉시 실행.
   - 도망 성공 시 즉시 전투 종료(`party.etc[6] = 2`).
4. **적 행동 단계 (Enemy Phase)**:
   - 적 1번부터 `enemynumber`까지 순차적으로 행동:
     - 중독(`poison`) 상태인 경우:
       - 기절(`unconscious`) 상태면 즉시 사망(`dead = true`)
       - 기절 상태가 아니면 `hp = hp - 1`, `hp <= 0`이면 기절
     - 사망하지 않고 기절하지 않은 적은 `EnemyAttack` AI 루틴 실행.
5. **전투 종료 판정 (`EndBattle`)**:
   - 모든 파티원이 사망/기절 시: 패배 -> 게임 오버 (`GameOver`)
   - 모든 적이 사망/기절 시: 승리 -> 골드 정산 (`PlusGold`), 필드 복귀

---

### 3.2 일반 무기 공격 공식 (`AttackOne`)

#### [단계 1] 대상 상태 확인 및 자동 타겟 보정
- 지정한 적 `k`가 이미 사망(`dead`)한 경우, 번호가 큰 다음 생존한 적(`k = k + 1`)으로 자동 타겟 변경.
- 대상이 기절(`unconscious == true && dead == false`) 상태인 경우:
  - 명중/대미지 계산 없이 **무조건 즉사 처형**:
    $$\text{enemy}[k].\text{hp} = 0, \quad \text{enemy}[k].\text{dead} = \text{true}$$
    경험치 획득(`PlusExperience(person, k)`) 후 종료.

#### [단계 2] 명중 판정 (Hit Check)
- 파스칼 난수: `random(20)`은 0부터 19까지의 정수 반환.
- **빗나감(Miss) 조건**:
  $$\text{random}(20) > \text{player}[\text{person}].\text{accuracy}[1]$$
  (즉, `0 <= random(20) <= accuracy[1]` 일 때만 명중)

#### [단계 3] 기초 대미지 계산 및 난수 분산 (Base Damage)
- 순수 공격력 산출:
  $$\text{BaseDamage} = \left\lfloor \frac{\text{strength} \times \text{wea\_power} \times \text{level}[1]}{20} \right\rfloor$$
- 난수 분산 (최대 50% 무작위 감소):
  $$\text{Damage}_1 = \text{BaseDamage} - \left\lfloor \frac{\text{BaseDamage} \times \text{random}(50)}{100} \right\rfloor$$
  *(즉, 원래 기초 공격력의 50% ~ 100% 사이 값)*

#### [단계 4] 적의 저항 판정 (Resistance Check)
- 적의 저항률: `0 <= random(100) < enemy[k].resistance`
- 조건 만족 시 적이 공격을 **저지(Resisted)**함 -> 대미지 0 (공격 실패)

#### [단계 5] 적의 방어력(AC) 차감 (Defense Reduction)
- 적의 방어 감소량 산출:
  $$\text{DefReduce} = \text{round}\left( \text{enemy}[k].\text{ac} \times \text{enemy}[k].\text{level} \times \frac{\text{random}(10) + 1}{10} \right)$$
- 최종 대미지:
  $$\text{FinalDamage} = \text{Damage}_1 - \text{DefReduce}$$
- 만약 $\text{FinalDamage} \le 0$ 이면: "적이 공격을 막았다 (Blocked)" 출력 후 종료 (피해 없음).

#### [단계 6] 피해 적용 및 상태 전이
- 적 체력 감소:
  $$\text{enemy}[k].\text{hp} = \text{enemy}[k].\text{hp} - \text{FinalDamage}$$
- 만약 체력이 0 이하가 된 경우:
  $$\text{enemy}[k].\text{hp} = 0, \quad \text{enemy}[k].\text{unconscious} = \text{true}$$
  적은 **의식불명(기절)** 상태로 전환되며, 공격자에게 경험치 지급 (`PlusExperience`).

---

### 3.3 단일 마법 공격 공식 (`CastOne`)

1. **소모 마나 (SP Cost)**:
   $$\text{ReqSP} = \text{round}\left( \frac{\text{level}[2] \times j^2}{2} \right) \quad (j = \text{선택한 마법 번호 } 1..6)$$
   현재 `sp < ReqSP`이면 시전 실패 ("마법 지수가 부족했다").
   성공 시 `sp = sp - ReqSP`.
2. **명중 판정**:
   - `if (random(20) >= player[person].accuracy[2])` -> 빗나감 (Miss).
3. **마법 기본 위력**:
   $$\text{BaseMagicPower} = j^2 \times \text{level}[2] \times 2$$
4. **적 저항 및 방어력 차감**:
   - 저항: `random(100) < enemy[k].resistance` -> 저지됨.
   - 방어 차감: $\text{DefReduce} = \text{round}(\text{ac} \times \text{level} \times \frac{\text{random}(10) + 1}{10})$
   - 최종 마법 피해: $\text{FinalMagicDamage} = \text{BaseMagicPower} - \text{DefReduce}$ ($\le 0$ 시 방어됨)

---

### 3.4 적의 공격 공식 (`WeaponAttack` & `EnemyAttack`)

#### 적의 일반 물리 공격 (`WeaponAttack`)
1. **명중 판정**:
   - `if (random(20) >= enemy[person].accuracy[1])` -> 빗맞음 (Miss).
2. **공격 대상 선정**:
   - 생존한 파티원(`exist(i)`) 중 무작위 1명 균등 선택 ($j$).
3. **적 기본 대미지**:
   $$\text{EnemyDmg} = \left\lfloor \frac{\text{enemy}.\text{strength} \times \text{enemy}.\text{level} \times (\text{random}(10) + 1)}{10} \right\rfloor$$
4. **플레이어 저항 판정**:
   - `if (random(50) < player[j].resistance)` -> 플레이어가 적의 공격 저지 (방어 성공).
5. **플레이어 방어력(AC) 감쇄**:
   $$\text{EnemyDmg} = \text{EnemyDmg} - \left\lfloor \frac{\text{player}[j].\text{ac} \times \text{player}[j].\text{level}[1] \times (\text{random}(10) + 1)}{10} \right\rfloor$$
   $\text{EnemyDmg} \le 0$ 이면 방어 성공 (피해 0).
6. **플레이어 피해 누적 및 기절/사망 판정**:
   - `player[j].hp > 0`인 경우:
     $$\text{player}[j].\text{hp} = \text{player}[j].\text{hp} - \text{EnemyDmg}$$
     체력이 0 이하가 되면:
     $$\text{player}[j].\text{unconscious} = 1$$
   - 이미 기절(`unconscious > 0 && dead == 0`)인 상태에서 추가 피격 시:
     $$\text{player}[j].\text{unconscious} = \text{player}[j].\text{unconscious} + \text{EnemyDmg}$$
     만약 $\text{unconscious} > \text{endurance} \times \text{level}[1]$ 이 되면:
     $$\text{player}[j].\text{dead} = 1 \quad (\text{최종 사망})$$
   - 이미 사망(`dead > 0`)한 상태에서 피격 시: `player[j].dead = player[j].dead + EnemyDmg`

#### 적 AI 행동 분기 (`EnemyAttack`)
1. 특수 마법 조건(`specialcastlevel > 0`): `specialcastattack` 실행.
2. 특수기 조건: 생존 적 수가 3마리 초과이고, `random(50) < min(20, agility)`이며 `special > 0`일 때 -> `specialattack` 실행.
3. 통상 공격 결정:
   - 난수 주사위: $\text{random}(\text{accuracy}[1] \times 1000) > \text{random}(\text{accuracy}[2] \times 1000)$ 이고 $\text{strength} > 0$ 이면 $\rightarrow$ `WeaponAttack` (물리 공격)
   - 그렇지 않으면 $\rightarrow$ `castattack` (마법 공격: 단일 마법, 전체 마법, 자가 치료 `enemycure` 등)

---

### 3.5 도망 공식 (`RunAway`)
- 파티원 민첩성 기반 판정:
  $$\text{Random}(50) \le \text{player}[\text{person}].\text{agility} \implies \textbf{도망 성공}$$
  (즉, 주사위 $0 \sim 49$ 중 민첩성 이하이면 성공, 초과 시 실패)

---

### 3.6 보상 계산 공식

#### 경험치 보상 (`PlusExperience`)
적 처치 또는 기절 시 대상 적의 도감 번호(`E_number`)를 기반으로 산출:
$$\text{EXP} = \max\left(1, \left\lfloor \frac{\text{E\_number}^3}{8} \right\rfloor\right)$$
- 살아있는 적을 기절시켰을 때: **막타를 친 플레이어 캐릭터 1명**에게만 해당 EXP 지급.
- 기절한 적을 완전히 사망시켰을 때: **생존한 파티원 전원**에게 각자 해당 EXP 지급.

#### 골드 보상 (`PlusGold`)
전투 승리 시 살아남아 쓰러뜨린 모든 적의 총합:
$$\text{Gold} = \sum_{\text{enemy}} \left( \text{level}^3 \times \max(1, \text{ac}) \right)$$

---

## 4. 캐릭터 성장 및 편의 시설 (Town Facilities)

### 4.1 훈련소 레벨업 테이블 (`Train_Center`)
경험치 누적 구간에 따라 전투 레벨(`level[1]`)이 상승하며, 수련 비용을 지불해야 합니다.

| 도달 레벨 | 필요 누적 경험치 | 훈련 비용 (금화) |
| :---: | :---: | :---: |
| **1** | 0 ~ 1,499 | - |
| **2** | 1,500 ~ 5,999 | 3 |
| **3** | 6,000 ~ 19,999 | 5 |
| **4** | 20,000 ~ 49,999 | 8 |
| **5** | 50,000 ~ 149,999 | 15 |
| **6** | 150,000 ~ 249,999 | 25 |
| **7** | 250,000 ~ 499,999 | 40 |
| **8** | 500,000 ~ 799,999 | 70 |
| **9** | 800,000 ~ 1,049,999 | 120 |
| **10** | 1,050,000 ~ 1,319,999 | 200 |
| **11** | 1,320,000 ~ 1,619,999 | 350 |
| **12** | 1,620,000 ~ 1,949,999 | 600 |
| **13** | 1,950,000 ~ 2,309,999 | 1,000 |
| **14** | 2,310,000 ~ 2,699,999 | 1,700 |
| **15** | 2,700,000 ~ 3,119,999 | 3,000 |
| **16** | 3,120,000 ~ 3,569,999 | 5,000 |
| **17** | 3,570,000 ~ 4,049,999 | 8,300 |
| **18** | 4,050,000 ~ 4,559,999 | 14,000 |
| **19** | 4,560,000 ~ 5,099,999 | 24,000 |
| **20** | 5,100,000 이상 (최고 레벨) | 40,000 |

* **레벨업 시 스탯 성장 판정**:
  - `if (luck > random(30))` 일 때 주 스탯 1 상승 (최대 20)
  - 기사: 힘 $\to$ 체력 $\to$ 물리명중 $\to$ 민첩
  - 마법사: 마법 레벨 동기화, 지능 $\to$ 집중력 $\to$ 마법명중
  - 전투승: 맨손 공격력 자동 갱신 ($\text{level}[1] \times 2 + 10$)

### 4.2 병원 치료 공식 (`Hospital`)
1. **상처 치료 (HP 완전 회복)**:
   - 비용: $\left\lfloor \frac{(\text{endurance} \times \text{level}[1] - \text{hp}) \times \text{level}[1]}{2} \right\rfloor + 1$
   - 효과: $\text{hp} = \text{endurance} \times \text{level}[1]$
2. **독 치료**:
   - 비용: $\text{level}[1] \times 10$
   - 효과: $\text{poison} = 0$
3. **의식 회복 (기절 치료)**:
   - 비용: $\text{unconscious} \times 2$
   - 효과: $\text{unconscious} = 0, \quad \text{hp} = 1$
4. **부활 (사망 부활)**:
   - 비용: $\text{dead} \times 100 + 400$
   - 효과: $\text{dead} = 0, \quad \text{unconscious} = \min(\text{unconscious}, \text{endurance} \times \text{level}[1])$
   - 주의: 원작 부활은 HP를 회복시키지 않으며 `unconscious`를 최대 HP로 제한할 뿐이다.

### 4.3 식료품점 가격표 (`Grocery`, `LORESUB.PAS:1155`)
| 구매 단위 | 가격 (금화) |
| :---: | :---: |
| 10 인분 | 100 |
| 20 인분 | 200 |
| 30 인분 | 300 |
| 40 인분 | 400 |
| 50 인분 | 500 |

* 환율은 10인분당 100금화 고정이며, 보유 식량 상한은 **255인분**이다.
* 상한을 넘는 분량은 버려진다(원작은 금화만 차감하고 clamp).

### 4.4 야외 캠프 휴식 (`Rest`, `LOREMENU.PAS:869`)
파티원 1~6번 순서로 아래 분기를 적용한다.

| 상태 | 처리 | 식량 |
| :--- | :--- | :--- |
| `food <= 0` | "일행은 식량이 바닥났다"만 출력 | - |
| `dead > 0` | "{이름}는 죽었다" (회복 불가) | - |
| `unconscious > 0 && poison == 0` | `unconscious -= level[1]+level[2]+level[3]`, 0 이하가 되면 `unconscious=0`, `hp<=0`이면 `hp=1` | 깨어난 경우 1 소모 |
| `unconscious > 0 && poison > 0` | "독때문에, {이름} {그의/그녀의} 의식은 회복되지 않았다" | - |
| `poison > 0` | "독때문에, {이름} {그의/그녀의} 건강은 회복되지 않았다" | - |
| 정상 | `hp += (level[1]+level[2]+level[3]) * 2` (최대치 clamp) | 1 소모 (만복이면 1 회복 후 1 소모 = 순 0) |

* 휴식 후 `party.etc[1]`(마법의 횃불)이 1 감소하고 `etc[2..4]`(물위걸음/늪위걸음/공중부상)는 초기화된다.
* 이름이 있는 파티원 전원은 `sp = mentality * level[2]`, `esp = concentration * level[3]`로 **완전 회복**된다. (사망자 포함)

### 4.5 동료 영입 (`join`, `LORESUB.PAS:1042`)
* `join(몬스터번호, 파티슬롯)`으로 몬스터 템플릿을 파티원으로 편입한다.
  - `class := 0`, `resistance := enemydata.resistance div 2`, `concentration/accuracy[3]/esp := 0`, `luck := 10`
  - `level[1] := 몬스터 레벨`, `level[2] := castlevel * 3` (0이면 1), `level[3] := 1`
  - `wea_power := level[1] * 2 + 10`, `arm_power := ac`, `hp := endurance * level[1]`, `sp := mentality * level[2]`
* 영입 후 캐릭터별로 이름/직업/장비/능력치를 덮어쓴다.

| 동료 | 원작 위치 | 몬스터 | 직업 | 비고 |
| :--- | :--- | :---: | :--- | :--- |
| Mad Joe | LORETALK:197 (지하 감옥) | #1 | 8 떠돌이 | 장비/방어도 전부 0 |
| Polaris | LORETALK:413 (LASTDITCH) | #9 | 4 전사 | 장검(wea 10), 마법Lv 3 |
| Rigel | LORESPEC:620 (EVIL SEAL) | #14 | 7 사냥꾼 | `hp := 1` 빈사 상태 |
| Red Antares | LORESPEC:1040 | #55 | 9 혼령 | 장비 제거, `hp := 0`, resistance 15 |
| Spica | LORESPEC:1230 (LOCKUP) | #43 | 3 에스퍼 | 여성, Lv 11/6/11 |
| Lore Hunter | LORETALK:623 (WATER FIELD) | #39 | 7 사냥꾼 | 철퇴(wea 15) |

* `ReturnJoinMember`는 합류시킬 슬롯(2~6번)을 골라야 하며, 파티는 최대 6인이다.
  - 6번 슬롯이 비어 있으면 그 자리 라벨이 `'보조 일원으로 둠'`으로 바뀈다(원작과 동일).
  - 선택한 슬롯에 이미 파티원이 있으면 **교체**되고, 리더(1번)는 교체 대상이 아니다.

#### 동료 영입 좌표 (LORESPEC.PAS)
| 동료 | 맵 | 좌표 | 원작 조건 |
| :--- | :---: | :---: | :--- |
| Mad Joe | 6 (CASTLE LORE 지하 감옥) | (40,15) | `at(40,15)` - 6번 슬롯 고정 (`k := 6`) |
| Polaris | 7 (LASTDITCH) | (37,41) | `etc[13] < 2` |
| Rigel | 12 (T_DEN2) | (12,48) | `etc[31] bit2 = 0` |
| Lore Hunter | 10 (WATER FIELD) | (40,56) | `etc[38] bit4` |
| Red Antares | 17 (NOTICE) | (75,52) | 1단계 특수마법 전수(`etc[38] bit1`) → 2단계 합류 |
| Spica | 18 (LOCKUP) | (37,31) | `etc[5] > 0`(독심술) **그리고** 파티 최고 초능력 Lv.5 이상 |

### 4.6 성문/동굴 입구 확인 (`wantenter` / `wantexit`)
* 성문·동굴 입구 타일로 이동하면 확인 대화상자를 띄운다.
  - `Print(11, name + ' 에 들어가기를 원합니까 ?')` / `'여기서 나가기를 원합니까 ?'`
  - 선택지: `'예, 그렇습니다.'` / `'아니오, 원하지 않습니다.'`
  - 거절하면 `asyouwish`(`'당신이 바란다면 ...'`)만 출력되고 제자리에 머무른다.

### 4.7 금화 발견 (`findgold`, `LORESPEC.PAS`)
* 문구: `'당신은 금화 N개를 발견했다.'`
* 좌표당 1회만 획득하며(원작 `party.etc[32/33/35]` 비트), 저장 시 불리언 플래그
  `gold:<mapId>:<x>:<y>`로 직렬화된다.

| 맵 | 좌표 | 금액 |
| :---: | :--- | :---: |
| 9 (TOWN4) | (10,24) (12,26) (15,25) (16,23) (18,27) | 각 5,000 |
| 10 (TOWN5) | (20,30) (18,36) (35,32) (33,36) (35,14) (14,16) (37,12) | 각 5,000 |
| 14 (DEN1) | (6,6) 1,000 / (18,10) 2,500 / (6,44) 400 / (31,30) 600 / (31,8) 1,500 / (14,28) 1,000 | |

### 4.8 특수 마법(간접 공격) 해금
* 원작 `LOREBATT.PAS:245 CastSpecial`은 `party.etc[38] bit1 = 0`이면
  `'당신에게는 아직 능력이 없다.'`를 출력하고 시전 자체를 막는다.
* 해금 경로: 맵 17 NOTICE 동굴 (75,52)에서 Red Antares의 영혼을 만나
  "간접 공격" 6종(독 / 기술 무력화 / 방어 무력화 / 능력 저하 / 마법 불능 / 탈초인화)을 전수받는다.

### 4.9 원작 소스 표기 오류 (이식 시 정정)
* `Train_Center`의 `Expdata` 문자열 상수에 오타가 있다.
  - Lv.15 `'270000'` → 실제 값 **2,700,000**
  - Lv.20 `'510000'` → 실제 값 **5,100,000**
* 본 이식판은 실제 진행 값(정정값)을 사용한다 (`PartyMember.expTable`).
* 또한 원작 훈련소는 승급 시 **HP/SP/ESP를 회복시켜 주지 않는다**. 회복은 병원의 "상처를 치료"만 가능하다.

---

## 5. 필드 탐험 및 타일 상호작용 (`LOREMAIN.PAS`)

### 5.1 이동 조작 및 핫키
- 이동: 방향키 (상/하/좌/우)
- 메뉴 열기: Space Bar (`SelectMode`)
- 단축키:
  - `P`: 파티 정보 (`ViewParty`)
  - `V`: 캐릭터 상세 (`ViewCharacter`)
  - `Q`: 빠른 정보 (`QuickView`)
  - `C`: 마법 시전 (`CastSpell`)
  - `E`: 초능력 (`Extrasense`)
  - `R`: 캠프 휴식 (`Rest`, `LOREMENU.PAS:869` - 4.4절 참조)
  - `G`: 게임 저장/불러오기 (`GameOption`)
  - `F1` / `H`: 원작자 서문 & 게임 매뉴얼 (`LOREHELP.PAS` Title_Str / Title_Menu 자막)

### 5.2 타일 속성 및 특수 효과
- 일반 바닥: 1걸음마다 독 진행 (10스텝마다 HP 감소), 1걸음마다 인카운터 확률 검사.
- 인카운터 확률: $\text{random}(\text{encounterRate} \times 20) == 0$ (기본 약 $5\% \sim 10\%$)
- 늪지(`swamp`): 진입 시 행운 판정 실패 시 중독(`poison = 1`).
- 용암(`lava`): 진입 시 파티원 전원에게 $40 \sim 79 - 2 \times \text{random}(\text{luck})$ 피해.
- 벽/장애물: 충돌 처리(`originposition`), 원래 위치 유지.

---

## 6. 결론 및 Flutter 이식 아키텍처 가이드

본 명세서에 정의된 데이터 모델과 수학적 수식은 도스/Crt 종속성 없이 100% 순수 Dart 코드로 분리 구현 가능합니다:
- `lib/models/`: `party_member.dart`, `monster.dart`, `item.dart`, `party.dart`
- `lib/logic/`: `battle_engine.dart` (본 명세서의 수식을 단위 테스트로 100% 검증 가능)
- `lib/screens/`: 4:3 레트로 도스 레이아웃 (뷰포트, 파티창, 3~4줄 콘솔 텍스트 로그)
- `lib/game/`: Flame 기반 또는 그리드 타일맵 이동 컴포넌트

---

## 7. 이식 현황 및 잔여 항목 (최종 리뷰)

### 7.1 이식 완료
| 원작 | 이식 위치 | 검증 테스트 |
| :--- | :--- | :--- |
| `LORESUB.PAS` 데이터 구조/무기점/식료품점/훈련소/병원/휴식 | `lib/logic/town_logic.dart`, `lib/widgets/town_*.dart` | `step5_train_rest_guide_test.dart` |
| `LORESUB.PAS:986/999/1012` 성문 확인·금화 발견·공통 메시지 | `lib/logic/lore_field_logic.dart` | `step6_field_prompts_test.dart` |
| `LORESUB.PAS:1042/1144` 동료 영입(join) 및 슬롯 선택 | `lib/logic/lore_join.dart` | `step3/step6` |
| `LOREBATT.PAS` 전투 전 공식 + 특수 마법 해금 게이트 | `lib/logic/battle_engine.dart`, `battle_viewport_view.dart` | `battle_test.dart` |
| `LOREMENU.PAS` 필드 메뉴/휴식/게임 옵션 + 핫키 | `lib/widgets/field_menu_dialog.dart`, `lib/logic/field_hotkeys.dart` | `keyboard_input_test.dart` |
| `LOREMAIN.PAS` 이동/지형 위험(늪·용암·물) | `lib/game/lore_game.dart` | `field_test.dart`, `step1_...` |
| `LORESPEC.PAS` 보스/봉인/식량나무/금화 좌표/동료 6명 | `lib/game/lore_dungeon_event_manager.dart`, `lore_dialogue_manager.dart` | `step3/step6` |
| `LORETALK.PAS` 4대 마을 NPC/영주 퀘스트 | `lib/game/lore_dialogue_manager.dart`, `town_dialog.dart` | `step3` |
| `LORECRET.PAS` 캐릭터 생성/성향 문답 | `character_creation_screen.dart` | `widget_test.dart` |
| `LOREEND.PAS` 엔딩/스태프롤 | `lib/widgets/ending_view.dart` | `step4` |
| `LOREHELP.PAS` 제작자 서문/타이틀 자막 | `lib/widgets/lore_guide_dialog.dart` (F1) | `step5` |

### 7.2 남은 항목 (미이식)
1. **선택지 분기 대화** ✅ 완료: `LoreScriptEngine`의 `choice` 스텝으로 2~3지선다를
   JSON에서 정의·실행한다(예: Rigel 3지선다, Spica 합류 여부). 원작의 대안 경로
   ("식량과 치료는 해결해 주겠소" = 식량 5 소모)도 그대로 구현했다.
2. **지형 변형 / 강제 이동** ✅ 지원: 스크립트에 `setTile`(원작 `map[x,y] := 값`)과
   `teleport`(원작 `x := ..; y := ..`) 스텝을 추가하고 게임 화면에서 적용한다.
   (적용 위치: 맵 6 (62,82) 상자, 맵 4 (20,39) Ancient Evil 비밀 통로)
3. **`wantexit` 게이트별 분기** ✅ 완료: 맵별 목적지를 `assets/data/portals.json`의
   포털 표(정확 좌표 + `yMin` 범위 조건)로 옮겨 코드 수정 없이 편집할 수 있다.
   원작 `if y = N then if wantexit` 출구 21곳을 모두 이관했다.
4. **남은 서사형 좌표 이벤트** ✅ 완료: 원작 `LORESPEC.PAS`의
   `if y = N then ...` 처럼 **행/구역 단위 조건**을 스크립트의 `xMin/xMax/yMin/yMax`
   로 옮겼고, `equip`(장비 지급)과 `peek`(카메라 연출) 스텝을 추가해 다음을 이관했다.
   - 맵 4: (40,18) 공간 이동, (26,16) Draconian 강의 + 영입(6번 슬롯 고정),
     (20,39) Ancient Evil 안내 중 **시야 연출**(48,57 → 82,16 → 16,15)
   - 맵 6: (51,12) 수감소 병사 전투(2명 → 재방문 7명), (41,79) 기본 무장,
     (y=95) 성문 Skeleton 영입(원작 `join(19,6)`)
   - 맵 11: (y=44) 오이디푸스의 창, (y=24) 미이라의 방(Sphinx ×2 + Major Mummy)
   - 맵 12: (18,10) **황금의 봉인** (원작 `party.etc[14] := 2`)
   - 맵 14: (16,20) 황금의 방패, (25,8)/(26,8) MENACE 중심 도달
   - 맵 15: (14,7) 황금의 방패, (45,19) 황금의 갑옷, (y=27) Zombie ×2 +
     ArchiGagoyle, (y=48) 보물 6000 → 4000 두 단계
5. **이관 완료(진행형 퍼즐·보스전)**
   - 맵 17 NOTICE: Hidra 삼두룡 (x = 22 열 진입, `bossHidraDefeated`), `y = 38` 통로
     개방 + (56,93) 강제 이동, `x = 72` 지름길
   - 맵 18 LOCKUP: Huge Dragon (x = 31 열 진입, `bossHugeDragonDefeated`)
     · 꼬리 쪽 5마리는 원작 `random(3)+30`을 배틀 스텝의 `random` 으로 그대로 구현
   - 맵 19 EVIL GOD: 레버 2개(늪위 걷기 마법이 켜져 있으면 못 당김) → 통로 개방 +
     **일곱 방 중 한 곳을 무작위로 뽑는 봉인 퍼즐**(`randomFlag`) → 정답 방에서
     CRAB GOD의 왕 7마리 전투 → 봉인 해제(`evilSealRoomCleared`). 봉인이 남아 있는
     동안 y=8~12 에서는 `random(3)+3` 마리의 수호 무리가 나온다.
   - 맵 12 T_DEN2: 수수께끼 문(오른쪽 문 통로 개방 / 오답이면 (25,70)으로 되돌림)
6. **원작 좌표 이벤트 전수 이관** ✅ `LORESPEC.PAS` 의 `on(x,y)` / `if y = N` 이벤트
   **46건 모두** 커버한다. 자동 점검: `python3 tool/audit_lorespec.py
   repo_source/LORE_1993_src/LORESPEC.PAS --coverage` (미커버가 있으면 종료코드 1).
   - 맵 18 LOCKUP: (22,41) 통로 교체, (21,41) 수문장 Minotaur 전투
   - 맵 19 EVIL GOD: 레버 2개 → 일곱 방 중 하나를 무작위로 뽑는 봉인 퍼즐,
     잘못된 방/수호 무리 전투 후 밟은 칸 봉쇄(`setTileAtPlayer`)
   - 맵 20 DEN 7 (**퀴즈 미로**): y=91/75 문항 무작위 뽑기(`randomSteps`) + 좌/우 문,
     y=54 옳다/틀리다 선택 문제, y=88/71 숨은 통로(`tileAtPlayerZero` + `keepX` 이동),
     y=18 횃불 지급, y=48 Minotaur, y=13 거룡 → 진흙 인간 → Astral Mud 3연전
   - 맵 21 SWAMP KEEP: (25,20) 봉인문(두 퍼즐이 모두 풀려야 열림)
   - 맵 22 KEEP2: (25,18) Wraith 5 + Death Knight, (y=25) 수문장 5명,
     그 외 좌표는 상시 습격(`else` 분기 그대로 — y=46 출구 행만 제외)
   - 맵 23/25: 함정 해제·열쇠 두 개(순서 무관)·통로 개방
   - 맵 12: 수수께끼 문, `y=10` 함정(플레이어가 선 열 차단)
   - 맵 17: `y=38` 통로 + (56,93) 이동, `x=72` 지름길
7. **알려진 편차(원작과 다른 점)**
   - 전투 승리 여부에 따라 갈리는 이동(예: 미궁의 주인 격파 시에만 퇴장)은
     스크립트가 전투 결과를 기다리지 못하므로, 격파를 플래그로 표시한 뒤 **다음
     걸음에 이동**하도록 옮겼다.
   - 마법의 횃불 소모는 원작이 특정 구역(`x 8~42`, `y 19~43`)에서만 줄지만,
     이식편은 모든 걸음에서 줄인다.
   - 맵 20 퀴즈의 `delay(3000)`/`PressAnyKey` 연출은 메시지 로그로 대체했다.
8. **`LORECHT/LORECHT2`(개발용 유틸), `FOEDITOR/LOOKFOE/GFE`(제작 도구)** 는 게임 본편이
   아니므로 이식 대상에서 제외한다.
9. **근사 이벤트 정리** ✅ 완료: `lib/game/lore_dungeon_event_manager.dart`에 있던
   임의 좌표 보스전·보물상자(7의 배수 좌표) 연출을 제거하고, 그 자리는 원작 좌표를
   쓴 `scripts.json`으로 대체했다. 현재 Dart 쪽에 남은 것은 `findgold` 표(폴백용)와
   맵 1 식량 발견뿐이다.

---

## 8. 현대적 구조: JSON 데이터 & 이미지 에셋

게임 데이터를 코드에서 분리해 JSON/이미지 파일로 관리한다. **파일이 없거나 파싱에
실패하면 코드에 내장된 원작 테이블로 자동 폴백**하므로 어떤 경우에도 게임은 동작한다.

### 8.1 데이터 파일 (`assets/data/`)
| 파일 | 내용 | 로더 |
| :--- | :--- | :--- |
| `monsters.json` | 원작 FOEDATA 75종 템플릿 | `LoreData.instance.monster(id)` |
| `items.json` | 무기 10 / 방패 6 / 갑옷 6 (위력·가격) | `LoreData.instance.weapon/shield/armor(id)` |
| `spells.json` | 45종 마법 (분류·설명·기본 SP) | `LoreData.instance.spell(id)` |
| `maps.json` | 27개 맵 메타데이터 (파일명·분류·BGM·폰트) | `LoreData.instance.map(mapId)` |
| `scripts.json` | 좌표 이벤트 / NPC 대화 / 선택지 분기 (106건) | `LoreScriptEngine.instance` |
| `portals.json` | 맵 연결(포털 30) + 표지판 문구 (21) | `LoreWorldManager.instance.findPortal/getSignMessage` |
| `dialogues.json` | 좌표 기반 NPC 대사 (30) | `LoreDialogueManager.instance.getDialogue` |

`LoreData` / `LoreScriptEngine` / `LoreWorldManager` / `LoreDialogueManager`는 `main()`에서
한 번 로드한다. JSON이 없거나 파싱에 실패하면 코드 내장 데이터로 폴백한다.

### 8.2 스크립트 스키마 (`scripts.json`)
```json
{
  "id": "rigel-join", "trigger": "talk", "map": 12, "x": 12, "y": 48, "once": true,
  "require": { "flag": "metPyramidSage", "flagNot": "rigelJoined",
               "mindRead": true, "minEspLevel": 5 },
  "steps": [
    { "say": "대사" },
    { "gold": 5000 }, { "food": -5 }, { "flag": "rigelJoined" },
    { "join": "rigel", "slot": 4 },
    { "battle": { "title": "미이라의 방", "monsters": [26, 8, 8] } },
    { "setTile": { "x": 62, "y": 82, "tile": 44 } },
    { "setTileArea": { "xMin": 25, "xMax": 27, "yMin": 27, "yMax": 37, "tile": 44 } },
    { "setTileAtPlayer": { "tile": 49 } },
    { "nudge": { "dy": 1 } },
    { "randomFlag": ["evilSealRoom1", "evilSealRoom2"] },
    { "teleport": { "x": 46, "y": 41 } },
    { "teleport": { "y": 80, "keepX": true } },
    { "torch": true },
    { "randomSteps": [ [ { "say": "문항 A" } ], [ { "say": "문항 B" } ] ] },
    { "equip": { "kind": "weapon", "index": 3, "power": 12, "prompt": true } },
    { "peek": { "x": 48, "y": 57 } },
    { "choice": { "prompt": "?", "options": [
        { "text": "예", "steps": [ { "join": "rigel" } ] },
        { "text": "아니오", "steps": [ { "say": "..." } ] } ] } }
  ]
}
```
* `trigger`: `step`(좌표 진입) / `talk`(NPC 접촉)
* `once`: 1회성. 실행 이력은 `LoreScriptEngine.consumedScripts`에 남는다.
* 좌표는 `x`/`y`(정확) 대신 `xMin`/`xMax`/`yMin`/`yMax`로 **행/구역 전체**를 쓸 수
  있다(원작 `if y = 44 then ...` 조건 그대로).
* `require`: `flag` / `flagNot` / `mindRead`(독심술 사용 가능) / `minEspLevel` /
  `notMindReadOrLowEsp`(조건 미충족 안내용) / `tileAtPlayerZero`(밟은 타일이 0)
* `join` 키: `mad_joe`, `polaris`, `rigel`, `red_antares`, `spica`, `lore_hunter`,
  `draconian`, `skeleton`
* `equip` 스텝: `kind`(weapon/shield/armor), `index`, `power`, `prompt`(누가 장착할지
  선택 - 원작 `choosewhom`), `onlyUnarmed`(무기 없는 대원만 - 원작 맵 6 기본 무장)
* `peek` 스텝: 원작 `scroll(FALSE)` 연출. 파티는 그대로 두고 **시야만** 옮겨 다른
  장소를 보여준 뒤 잠시 뒤 자동으로 돌아온다(원작의 `PressAnyKey` 대체).
* `setTileArea` 스텝: `xMin`/`xMax`/`yMin`/`yMax` 영역을 한 타일로 바꾼다
  (원작 `for j := .. do map[i,j] := v`). `atPlayerX: true`면 x를 **플레이어가 선 열**로
  삼고, `ifZero: v`면 현재 타일이 0일 때만 바꾼다.
* `setTileAtPlayer` 스텝: 플레이어가 밟고 있는 칸을 바꾼다(`map[x,y] := v`).
* `nudge` 스텝: `{"dx": 0, "dy": 1}` 로 플레이어를 한 칸 민다(원작 `inc(y)`/`dec(y)`).
* `randomSteps` 스텝: 여러 스텝 목록 중 **하나를 무작위로 골라 실행**한다
  (원작 퀴즈 미로처럼 문항과 효과가 함께 정해져야 하는 경우).
* `teleport` 의 `keepX`/`keepY`: 한 축만 바꾸고 나머지는 그대로 둔다(원작 `y := 80`).
* `torch` 스텝: 마법의 횃불을 켠다(원작 `party.etc[1] := 1`).
* `require.tileAtPlayerZero`: 플레이어가 밟은 타일이 0일 때만 발동(원작 `map[x,y] = 0`).
* `randomFlag` 스텝: 이름 목록 중 하나를 무작위로 세운다
  (원작 `party.etc[40] := (random(7)+1) shl 1` 같은 "방 번호 뽑기").
* `battle` 스텝의 `random`: `{"pool": [59], "min": 3, "max": 5}` 로
  `monsters` 뒤에 난수 마리를 추가 소환한다(원작 `enemynumber := random(3) + 3`).

### 8.3 이미지 에셋 (`assets/images/`)
| 파일 | 내용 |
| :--- | :--- |
| `chara.png` | CHARA.FNT 스프라이트 56개 (20×20, 배경 투명) |
| `town.png` / `ground.png` / `den.png` / `keep.png` | 타일 스프라이트 56개 (배경 불투명) |
| `manifest.json` | 타일 크기와 폰트별 파일/개수 |

* 렌더링 우선순위: **PNG 스프라이트 시트 → FNT 디코더 → 벡터 도형**.
* 이미지 교체만으로 그래픽을 바꿀 수 있다(도트 크기 20×20 유지 시 코드 수정 불필요).

### 8.4 데이터/이미지 재생성 도구
```sh
# 코드에 내장된 원작 테이블 → JSON
flutter test test/tools/export_data_test.dart --dart-define=EXPORT_DATA=true

# 원작 .FNT → PNG 스프라이트 시트
flutter test test/tools/export_images_test.dart --dart-define=EXPORT_IMAGES=true
```
* 좌표 대사 → JSON: `python3 tool/export_dialogues.py` (dialogues.json 재생성)
* 원작 소스 감사: `python3 tool/audit_lorespec.py repo_source/LORE_1993_src/LORESPEC.PAS`
* 원작 한글 문자열 디코딩: `python3 tool/dec_johab.py <PAS파일> <시작Proc> [끝Proc]`


