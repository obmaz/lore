#!/usr/bin/env python3
"""원작 Pascal 이벤트 본문을 포트 스크립트 스텝으로 옮기는 변환기.

`LORESPEC.PAS`(좌표 이벤트)와 `LORETALK.PAS`(NPC 대화)가 공통으로 쓰는
"중첩 if 로 갈라지는 대사 + 진행 플래그" 구조를 다룬다.

핵심 아이디어
-------------
원작은 한 좌표 안에서 조건에 따라 **서로 다른 대사**를 보여준다
(예: 맵 4의 Draconian은 첫 방문이면 장문 강의, 두 번째면 동료 권유).
포트의 스크립트 엔진은 `find()`가 **첫 일치 항목 하나만** 실행하므로,
조건 분기마다 **별도의 스크립트 항목**으로 쪼개고 `require`로 갈라준다.

    if on(26,16) then begin
       <항상 보이는 대사>
       if party.etc[16] and bit2 > 0 then begin <A>; exit; end;
       if party.etc[5] = 0 then <B> else <C>;
    end;

  →  spec-4-26-16-1  require etc16_bit2              steps = 항상 + A + block
      spec-4-26-16-2  require notAllFlags[etc16_bit2, etc5]  steps = 항상 + B
      spec-4-26-16-3  require notAllFlags[etc16_bit2] allFlags[etc5]  steps = 항상 + C

지원 구문
---------
- `Print(n,'..')` / `talk('..')` / `message(n,'..')`      → `{"say": ...}`
- `m[N] := '..'` + `k := select(...)` + `if k = v then`    → `{"choice": ...}`
- `party.etc[N] := party.etc[N] or bitM` / `and not bitM`  → `{"flag": "etcN_bitM"}`
- `inc(party.etc[N])` / `party.etc[N] := v` (10/13/14/15)  → `{"questStep": ...}`
- `party.gold := party.gold + n` / `party.food := ...`     → `{"gold": n}` / `{"food": n}`
- `map[x,y] := v` / `map[x+x1,y+y1] := v`                  → `{"setTile": ...}` / `{"setTileAtTarget": v}`
- `map[i,j] := v` (반복문 안)                               → `{"setTileArea": ...}` (가능한 경우만)
- `x := a; y := b; scroll`                                 → `{"teleport": ...}`
- `exit`                                                   → `{"block": true}`
- `BattleMode` + `joinenemy(i, m)`                          → `{"battle": {"monsters": [...]}}`
- `join(n, k)`                                              → `{"join": ...}` (번호→키 표는 tool/lore_join_map.py)

지원하지 못한 구문은 `notes`로 보고한다(대사는 그대로 살린다).
"""
from __future__ import annotations

import re
import sys

STRING = re.compile(r"'((?:[^']|'')*)'")
# 문자열 리터럴(작은따옴표 안)을 지운 사본. `begin`/`end` 세기에 쓴다.
STRING_SPAN = re.compile(r"'(?:[^']|'')*'", re.S)


def strip_strings(line: str) -> str:
    """문자열 리터럴을 빈 리터럴로 바꾼다(키워드 세기용)."""
    return STRING_SPAN.sub("''", line)


def count_kw(line: str, word: str) -> int:
    return len(re.findall(r'\b' + word + r'\b', strip_strings(line), re.I))


def block_delta(line: str) -> int:
    """`begin`/`case`/`repeat` 는 +1, `end`/`until` 은 -1 로 세는 깊이 변화."""
    s = strip_strings(line)
    return (
        len(re.findall(r'\bbegin\b', s, re.I))
        + len(re.findall(r'\bcase\b', s, re.I))
        + len(re.findall(r'\brepeat\b', s, re.I))
        - len(re.findall(r'\bend\b', s, re.I))
        - len(re.findall(r'\buntil\b', s, re.I))
    )
PRINT = re.compile(r"^(Print|cPrint|talk|Talk|message|Message)\s*\(", re.I)
MENU = re.compile(r"^m\[(\d+)\]\s*:=\s*'((?:[^']|'')*)'\s*;")
SELECT = re.compile(r"select\(", re.I)
ETC_BIT_SET = re.compile(
    r"party\.etc\[(\d+)\]\s*:=\s*party\.etc\[\d+\]\s*or\s+bit(\d+)", re.I)
ETC_BIT_CLR = re.compile(
    r"party\.etc\[(\d+)\]\s*:=\s*party\.etc\[\d+\]\s*and\s+not\s+bit(\d+)", re.I)
ETC_BIT_REQ = re.compile(r"party\.etc\[(\d+)\]\s+and\s+bit(\d+)\s*(=|>|<)\s*(\d+)")
ETC_NUM_REQ = re.compile(r"party\.etc\[(\d+)\]\s*(=|>|<|<=|>=)\s*(\d+)")
ETC_INC = re.compile(r"inc\(\s*party\.etc\[(\d+)\]\s*\)", re.I)
ETC_SET = re.compile(r"party\.etc\[(\d+)\]\s*:=\s*(-?\d+)\s*;")
GOLD = re.compile(r"party\.gold\s*:=\s*party\.gold\s*\+\s*(\d+)")
FOOD = re.compile(r"party\.food\s*:=\s*party\.food\s*\+\s*(\d+)")
TILE = re.compile(r"map\[\s*(\d+)\s*,\s*(\d+)\s*\]\s*:=\s*(\d+)")
TILE_TARGET = re.compile(
    r"map\[\s*x\s*\+\s*x1\s*,\s*y\s*\+\s*y1\s*\]\s*:=\s*(\d+)")
TILE_PLAYER = re.compile(r"map\[\s*x\s*,\s*y\s*\]\s*:=\s*(\d+)")
TELEPORT = re.compile(r"^\s*x\s*:=\s*(\d+)\s*;\s*y\s*:=\s*(\d+)\s*;", re.M)
JOINENEMY = re.compile(r"joinenemy\(\s*([^,]+?)\s*,\s*([^)]+?)\s*\)", re.I)
JOIN = re.compile(r"join\(\s*([^,]+?)\s*,\s*([^)]+?)\s*\)", re.I)
PEEK = re.compile(r"scroll\(\s*FALSE\s*\)", re.I)

NOTE_ONLY = re.compile(
    r"^(Clear|PressAnyKey|Pressanykey|Delay|Sound|Voice|Discard|line|SetColor"
    r"|HPrintXY|PutImage|Display|originposition|load|Silent_Scroll)\b", re.I)

# `party.etc[N] < v` 같은 단계 비교를 퀘스트 이름으로 옮긴다.
QUEST_BY_ETC = {10: 'lordahn', 13: 'lastditch', 14: 'gaia', 15: 'water'}

# 몬스터 번호 → 포트 몬스터 (원작 enemydata[] 번호). 그대로 쓴다.
MAX_VARIANT_STEPS = 400


def decode(raw: bytes) -> str:
    try:
        return raw.decode('johab')
    except Exception:  # noqa: BLE001
        return raw.decode('latin-1')


def unescape(lit: str) -> str:
    return lit.replace("''", "'")


def norm(text: str) -> str:
    return re.sub(r'\s+', '', text)


# ── 조건 → require ────────────────────────────────────────────────


class Req:
    """스크립트 `require` 조건을 모은다(긍정/부정 모두)."""

    def __init__(self, pos=None, neg=None, quests=None):
        self.pos = set(pos or ())
        self.neg = set(neg or ())
        # (`퀘스트 이름`, 비교, 값) 목록 - 원작 `party.etc[10/13/14/15]` 단계
        self.quests: list[tuple[str, str, int]] = list(quests or ())

    def copy(self):
        return Req(self.pos, self.neg, self.quests)

    def add_flag(self, name, want=True):
        if want:
            self.pos.add(name)
            self.neg.discard(name)
        else:
            self.neg.add(name)
            self.pos.discard(name)

    def merge(self, other):
        for f in other.pos:
            self.add_flag(f, True)
        for f in other.neg:
            self.add_flag(f, False)
        for q in other.quests:
            if q not in self.quests:
                self.quests.append(q)

    def add_quest(self, name: str, op: str, value: int):
        """원작 비교 연산자를 포트의 `lt`/`gte`/`eq` 로 정규화해 담는다."""
        if op == '<':
            self.quests.append((name, 'lt', value))
        elif op == '<=':
            self.quests.append((name, 'lt', value + 1))
        elif op == '>':
            self.quests.append((name, 'gte', value + 1))
        elif op == '>=':
            self.quests.append((name, 'gte', value))
        else:
            self.quests.append((name, 'eq', value))

    def add_quest_negation(self, q):
        name, op, val = q
        if op == 'lt':
            self.add_quest(name, '>=', val)
        elif op == 'gte':
            self.quests.append((name, 'lt', val))
        else:  # eq 의 부정은 `>= v+1` 로 근사한다.
            self.quests.append((name, 'gte', val + 1))

    def invert_quests(self):
        """조건의 부정(else 쪽)을 만든다."""
        old = list(self.quests)
        self.quests = []
        for q in old:
            self.add_quest_negation(q)

    def to_json(self):
        if not self.pos and not self.neg and not self.quests:
            return None
        out = {}
        if self.pos:
            out['allFlags'] = sorted(self.pos)
        if self.neg:
            out['notAllFlags'] = sorted(self.neg)
        if self.quests:
            out['quest'] = [
                {'name': n, **{op: v}} for n, op, v in self.quests
            ]
        return out

    def key(self):
        return (
            tuple(sorted(self.pos)),
            tuple(sorted(self.neg)),
            tuple(self.quests),
        )


ON_COORD = re.compile(r"on\(\s*(\d+)\s*,\s*(\d+)\s*\)", re.I)
Y_EQ = re.compile(r"\by\s*=\s*(\d+)")
X_EQ = re.compile(r"\bx\s*=\s*(\d+)")
X_RANGE = re.compile(r"\bx\s+in\s+\[\s*(\d+)\s*\.\.\s*(\d+)\s*\]", re.I)


def split_coords(cond: str):
    """조건식에서 좌표 조건을 떼어내고 (좌표 목록, 나머지 조건)을 돌려준다.

    좌표는 `{x, y}` / `{xMin, xMax}` / `{yMin, yMax}` 형태의 dict 로 준다.
    """
    coords = []
    rest = cond
    for m in ON_COORD.finditer(cond):
        coords.append({'x': int(m.group(1)), 'y': int(m.group(2))})
    rest = ON_COORD.sub('', rest)
    m = X_RANGE.search(rest)
    if m:
        coords.append({'xMin': int(m.group(1)), 'xMax': int(m.group(2))})
        rest = X_RANGE.sub('', rest)
    m = Y_EQ.search(rest)
    if m:
        coords.append({'yMin': int(m.group(1)), 'yMax': int(m.group(1))})
        rest = Y_EQ.sub('', rest)
    m = X_EQ.search(rest)
    if m:
        coords.append({'xMin': int(m.group(1)), 'xMax': int(m.group(1))})
        rest = X_EQ.sub('', rest)
    return coords, rest


def flag_name_for_bit(etc_n: int, bit: int) -> str:
    if etc_n in QUEST_BY_ETC:
        # 퀘스트 단계는 카운터이므로 비트 조건은 `>= n` 으로 옮긴다.
        return f'__quest_{etc_n}_bit{bit}'
    return f'etc{etc_n}_bit{bit}'


def condition_to_req(text: str) -> tuple[Req, bool]:
    """조건식 → (Req, 파싱 성공 여부).

    알아본 조건을 모두 지운 뒤에도 뭔가 남으면, 옮기지 못한 조건이 있다는
    뜻이므로 `ok=False` 로 알린다(호출한 쪽에서 그 분기를 끈다).
    """
    req = Req()
    ok = True
    for m in ETC_BIT_REQ.finditer(text):
        etc_n, bit, op, val = (int(m.group(1)), int(m.group(2)),
                               m.group(3), int(m.group(4)))
        # `and bitM = 0` → 미설정, `> 0`/`= 1` → 설정
        want = not (op == '=' and val == 0)
        req.add_flag(flag_name_for_bit(etc_n, bit), want)
    stripped = ETC_BIT_REQ.sub('', text)
    for m in ETC_NUM_REQ.finditer(stripped):
        etc_n, op, val = int(m.group(1)), m.group(2), int(m.group(3))
        if etc_n in QUEST_BY_ETC:
            # 원작의 퀘스트 단계(etc[10]/[13]/[14]/[15])는 포트에서도
            # 퀘스트 카운터로 비교한다.
            req.add_quest(QUEST_BY_ETC[etc_n], op, val)
            continue
        if op == '=':
            req.add_flag(f'etc{etc_n}', val != 0)
        elif op in ('>', '>='):
            req.add_flag(f'etc{etc_n}', True)
        else:
            req.add_flag(f'etc{etc_n}', False)
    stripped = ETC_NUM_REQ.sub('', stripped)

    # 남은 조각이 있으면 옮기지 못한 조건이 있다는 뜻이다.
    residue = re.sub(r'\b(and|or|not|true|false)\b', '', stripped, flags=re.I)
    residue = re.sub(r'[()\s]', '', residue)
    # 좌표 조건 조각은 이미 떼어냈으므로 남아 있으면 미지원이다.
    if residue:
        ok = False
    return req, ok


# ── 본문 파싱 ────────────────────────────────────────────────────


def join_headers(body: list[str]) -> list[str]:
    """여러 줄에 걸친 `if ... then` 헤더를 한 줄로 합친다.

    원작은 조건이 길면 `if on(75,52) and (..)` / `and (..) then begin` 처럼
    줄을 나눠 쓴다. 그대로 두면 헤더 인식이 깨지므로 미리 붙여 둔다.
    """
    out: list[str] = []
    i = 0
    while i < len(body):
        line = body[i]
        plain = strip_strings(line)
        if (re.match(r'^\s*(?:else\s+)?if\b', plain, re.I)
                and not re.search(r'\bthen\b', plain, re.I)):
            joined = line.rstrip()
            j = i + 1
            while j < len(body):
                plain_next = strip_strings(body[j])
                joined += ' ' + body[j].strip()
                j += 1
                if re.search(r'\bthen\b', plain_next, re.I):
                    break
            out.append(joined)
            i = j
            continue
        out.append(line)
        i += 1
    return out


def split_statements(body: list[str]) -> list[list[str]]:
    """본문을 문장(여러 줄일 수 있음) 단위로 자른다.

    `begin`으로 시작하는 복합문은 대응하는 `end;`까지 한 문장으로 묶는다.
    """
    body = join_headers(body)
    stmts: list[list[str]] = []
    i = 0
    while i < len(body):
        line = body[i]
        s = line.strip()
        if not s:
            i += 1
            continue
        # `begin`/`end` 뿐 아니라 `case`/`repeat` 도 한 덩어리로 묶는다.
        delta = block_delta(line)
        if delta > 0:
            depth = delta
            chunk = [line]
            i += 1
            while i < len(body) and depth > 0:
                chunk.append(body[i])
                depth += block_delta(body[i])
                i += 1
            stmts.append(chunk)
            continue
        # 여러 문장이 한 줄에 있을 수 있다(`else talk('..');`).
        stmts.append([line])
        i += 1
    return stmts


def header_condition(header: str) -> str:
    """`if <조건> then` 에서 조건 부분만 뽑는다."""
    m = re.match(r'^\s*(?:else\s+)?if\s+(.*?)\s+then\b(.*)$', header, re.I | re.S)
    return m.group(1) if m else ''


def header_tail(header: str) -> str:
    m = re.match(r'^\s*(?:else\s+)?if\s+(.*?)\s+then\b(.*)$', header, re.I | re.S)
    return m.group(2).strip() if m else ''


def split_if_else(chunk: list[str]) -> tuple[str, list[str], list[str] | None]:
    """`if C then <then-part> [else <else-part>]` 로 나눈다."""
    header = chunk[0]
    cond = header_condition(header)
    tail = header_tail(header)
    rest = chunk[1:]
    if tail.lower().startswith('begin'):
        then_lines = rest
        # `end;` / `end else begin`
        else_lines = None
        if then_lines and re.match(r'^\s*end\s*$', then_lines[-1], re.I):
            then_lines = then_lines[:-1]
        elif then_lines and re.match(r'^\s*end\s+else\s+begin\s*$',
                                    then_lines[-1], re.I):
            then_lines = then_lines[:-1]
            else_lines = []
        return cond, then_lines, else_lines
    # 한 줄 형태: `if C then talk('..')` 또는 `if C then begin`
    stmt = tail
    if stmt.endswith('end'):
        stmt = stmt[:-3].rstrip()
    then_lines = [stmt] if stmt else []
    return cond, then_lines, None


class Ctx:
    """본문 변환 중의 상태."""

    def __init__(self, map_id: int, x: int | None, y: int | None):
        self.map_id = map_id
        self.x = x
        self.y = y
        self.notes: list[str] = []
        # 옮기지 못한 조건이 하나라도 있었는지(있으면 실행하지 않는다).
        self.unsupported = False
        # 조건 분기별로 (요구 조건, 스텝들) 을 모은다.
        self.variants: list[tuple[Req, list[dict]]] = [(Req(), [])]
        # `exit` 로 끝난 변형들(이후 문장의 영향을 받지 않는다).
        self.done: list[tuple[Req, list[dict]]] = []

    def add_step(self, step: dict):
        for _req, steps in self.variants:
            if len(steps) < MAX_VARIANT_STEPS:
                steps.append(step)

    def note(self, text: str):
        if text not in self.notes:
            self.notes.append(text)

    def fork(self, cond: str):
        """`if C then` - (C 인 변형들, ¬C 인 변형들)을 만들어 돌려준다.

        상태([`variants`])는 건드리지 않는다. 호출한 쪽에서 원하는 쪽을
        `variants` 로 넣고 본문을 해석한 뒤 두 쪽을 합치면 된다.
        """
        req, ok = condition_to_req(cond)
        if not ok:
            self.unsupported = True
            self.note(f'조건 미지원: {cond.strip()[:60]}')
        yes: list[tuple[Req, list[dict]]] = []
        no: list[tuple[Req, list[dict]]] = []
        for base_req, steps in self.variants:
            y = base_req.copy()
            y.merge(req)
            n = base_req.copy()
            for f in req.pos:
                n.add_flag(f, False)
            for f in req.neg:
                n.add_flag(f, True)
            for q in req.quests:
                n.add_quest_negation(q)
            yes.append((y, list(steps)))
            no.append((n, list(steps)))
        return yes, no

    def close_all(self):
        """원작 `exit` - 지금 살아있는 변형들을 모두 닫는다."""
        self.done.extend(self.variants)
        self.variants = []

    def finish(self):
        """닫힌 변형까지 합쳐 최종 변형 목록을 만든다(중복 제거)."""
        allv = self.variants + self.done
        seen = set()
        out = []
        for req, steps in allv:
            k = (req.key(), repr(steps))
            if k in seen:
                continue
            seen.add(k)
            out.append((req, steps))
        self.variants = out
        self.done = []

    def drop_dupes(self):
        self.finish()


def collect_texts(chunk: list[str]) -> list[str]:
    """한 줄에서 원작 문구를 뽑는다.

    `Print(11,'당신은 '+s+'마리의 Wivern...')` 처럼 변수를 끼워 붙인 경우,
    원작의 **리터럴 조각을 그대로** 살리기 위해 조각별로 돌려준다
    (합쳐 버리면 원문 대조에서 어긋난다).
    """
    out = []
    for line in chunk:
        if not PRINT.match(line.strip()):
            continue
        literals = [unescape(s.group(1)) for s in STRING.finditer(line)]
        if not literals:
            continue
        has_var = bool(re.search(r"'\s*\+\s*[A-Za-z_]", line)) or bool(
            re.search(r"[A-Za-z_0-9\]\)]\s*\+\s*'", line))
        if has_var and len(literals) > 1:
            out.extend(t for t in literals if t.strip())
        else:
            out.append(''.join(literals))
    return out


def strip_leading_else(line: str) -> str:
    return re.sub(r'^\s*else\s+', '', line, count=1, flags=re.I)


END_ONLY = re.compile(r'^\s*end\s*;?\s*$', re.I)
BEGIN_ONLY = re.compile(r'^\s*begin\s*$', re.I)


def _trim_end(lines: list[str]) -> list[str]:
    if lines and END_ONLY.match(lines[-1]):
        return lines[:-1]
    return lines


def resolve_if(stmts: list[list[str]], i: int):
    """`i`번째 `if` 문장을 (조건, then 본문, else 본문|None, 다음 인덱스)로 푼다.

    원작은 조건이 길면 `if ... \n ... then` 처럼 헤더를 나누고, 본문이
    `then` 뒤 다음 줄에 오는 경우도 있다. Pascal 의 dangling-else 규칙
    (`else` 는 가장 안쪽 `if` 에 붙는다)까지 반영한다.
    """
    chunk = stmts[i]
    cond = header_condition(chunk[0])
    tail = header_tail(chunk[0])
    j = i + 1
    dangling_taken = False
    if tail.lower().startswith('begin'):
        body = _trim_end(chunk[1:])
    elif tail:
        body = [tail]
    else:
        # 본문이 다음 문장이다.
        body = []
        if j < len(stmts):
            chunk2 = stmts[j]
            nfirst = chunk2[0].strip()
            if BEGIN_ONLY.match(nfirst):
                body = _trim_end(chunk2[1:])
            else:
                body = list(chunk2)
                if re.match(r'^(?:else\s+)?if\b', nfirst, re.I):
                    # 본문이 `if` 문이면 뒤따르는 `else` 는 그 안쪽 `if` 에 붙는다.
                    k = j + 1
                    while k < len(stmts) and re.match(
                            r'^else\b', stmts[k][0].strip(), re.I):
                        body = body + list(stmts[k])
                        k += 1
                    dangling_taken = True
                    j = k - 1
            j += 1
    else_body = None
    if not dangling_taken and j < len(stmts):
        nfirst = stmts[j][0].strip()
        if re.match(r'^else\b', nfirst, re.I):
            if re.match(r'^else\s+begin\s*$', nfirst, re.I):
                else_body = _trim_end(stmts[j][1:])
            else:
                else_body = _trim_end(
                    [strip_leading_else(nfirst)] + stmts[j][1:]
                )
            j += 1
    return cond, body, else_body, j


def walk_statements(ctx, stmts: list[list[str]], depth: int = 0):
    """문장 목록을 해석한다(`walk` 과 같은 일을 하지만 목록을 직접 받는다)."""
    i = 0
    pending_menu: list[str] = []
    while i < len(stmts):
        chunk = stmts[i]
        first = chunk[0].strip()

        m = MENU.match(first)
        if m:
            idx = int(m.group(1))
            if idx > 0:
                while len(pending_menu) < idx:
                    pending_menu.append('')
                pending_menu[idx - 1] = unescape(m.group(2))
            i += 1
            continue
        if SELECT.search(first) and 'k :=' in first:
            option_bodies: dict[int, list[list[str]]] = {}
            j = i + 1
            while j < len(stmts):
                nxt = stmts[j][0].strip()
                km = re.match(r'^if\s+k\s*=\s*(\d+)\s+then\b(.*)$', nxt,
                              re.I | re.S)
                if not km:
                    break
                val = int(km.group(1))
                option_bodies.setdefault(val, []).extend(
                    split_statements(if_then_body(stmts[j]))
                )
                j += 1
            options = []
            for k_idx, label in enumerate(pending_menu, start=1):
                sub = Ctx(ctx.map_id, ctx.x, ctx.y)
                sub.variants = [(Req(), [])]
                walk_statements(sub, option_bodies.get(k_idx, []), depth + 1)
                sub.finish()
                opt_steps = sub.variants[0][1] if sub.variants else []
                options.append({'text': label, 'steps': opt_steps})
            if 0 in option_bodies:
                options.append({'text': '취소', 'steps': [{'block': True}]})
            ctx.add_step({'choice': {'options': options}})
            pending_menu = []
            i = j
            continue

        if re.match(r'^(?:else\s+)?if\b', first, re.I):
            cond, then_body, else_body, j = resolve_if(stmts, i)
            snapshot = [(r.copy(), list(s)) for r, s in ctx.variants]

            yes, _no = ctx.fork(cond)
            ctx.variants = yes
            walk(ctx, then_body, depth + 1)
            then_side = ctx.variants

            ctx.variants = snapshot
            _yes, no = ctx.fork(cond)
            ctx.variants = no
            if else_body is not None:
                walk(ctx, else_body, depth + 1)
            else_side = ctx.variants

            ctx.variants = then_side + else_side
            i = j
            continue

        translate_statement(ctx, chunk)
        i += 1


def if_then_body(chunk: list[str]) -> list[str]:
    """`if ... then <본문>` 청크에서 then 본문만 뽑는다."""
    tail = header_tail(chunk[0])
    if tail.lower().startswith('begin'):
        body = chunk[1:]
        if body and re.match(r'^\s*end\s*;?\s*$', body[-1], re.I):
            body = body[:-1]
        return body
    return [tail] if tail else chunk[1:]


def walk(ctx: Ctx, body: list[str], depth: int = 0):
    """본문을 순서대로 해석해 ctx.variants 의 스텝 목록을 채운다."""
    if depth > 24:  # 비정상적으로 깊은 중첩은 더 들어가지 않는다.
        ctx.note('중첩 깊이 초과')
        return
    walk_statements(ctx, split_statements(body), depth)


def translate_statement(ctx: Ctx, chunk: list[str]):
    for line in chunk:
        s = line.strip()
        if not s:
            continue
        texts = collect_texts([line])
        for t in texts:
            if t.strip():
                ctx.add_step({'say': t})
            elif texts:
                pass
        if texts:
            continue

        m = ETC_BIT_SET.search(s)
        if m:
            ctx.add_step({'flag': f'etc{m.group(1)}_bit{m.group(2)}'})
            continue
        m = ETC_BIT_CLR.search(s)
        if m:
            ctx.note(f'비트 해제: {s[:50]}')
            continue
        m = ETC_INC.search(s)
        if m:
            etc_n = int(m.group(1))
            if etc_n in QUEST_BY_ETC:
                ctx.add_step({'questStep': {'name': QUEST_BY_ETC[etc_n], 'inc': 1}})
            else:
                ctx.add_step({
                    'questStep': {
                        'name': f'etc{etc_n}',
                        'inc': 1,
                    }
                })
            continue
        m = ETC_SET.search(s)
        if m:
            etc_n, val = int(m.group(1)), int(m.group(2))
            if etc_n in QUEST_BY_ETC:
                ctx.add_step({
                    'questStep': {'name': QUEST_BY_ETC[etc_n], 'set': val}
                })
            else:
                ctx.note(f'party.etc[{etc_n}] := {val} (숫자 대입)')
            continue
        m = GOLD.search(s)
        if m:
            ctx.add_step({'gold': int(m.group(1))})
            continue
        m = FOOD.search(s)
        if m:
            ctx.add_step({'food': int(m.group(1))})
            continue
        m = TILE_TARGET.search(s)
        if m:
            ctx.add_step({'setTileAtTarget': int(m.group(1))})
            continue
        m = TILE_PLAYER.search(s)
        if m:
            ctx.add_step({'setTileAtPlayer': {'tile': int(m.group(1))}})
            continue
        m = TILE.search(s)
        if m:
            ctx.add_step({
                'setTile': {
                    'x': int(m.group(1)),
                    'y': int(m.group(2)),
                    'tile': int(m.group(3)),
                }
            })
            continue
        m = TELEPORT.search(s)
        if m:
            ctx.add_step({
                'teleport': {'x': int(m.group(1)), 'y': int(m.group(2))}
            })
            continue
        if re.match(r'^\s*exit\s*;?\s*$', s, re.I):
            ctx.add_step({'block': True})
            ctx.close_all()
            continue
        if PEEK.search(s):
            continue
        if re.match(r'^\s*(BattleMode|battlemode)\b', s):
            ctx.note('전투 개시(BattleMode)')
            continue
        m = JOINENEMY.search(s)
        if m:
            ctx.note(f'적 배치: joinenemy({m.group(1)}, {m.group(2)})')
            continue
        m = JOIN.search(s)
        if m:
            ctx.note(f'동료 영입: join({m.group(1)}, {m.group(2)})')
            continue
        if NOTE_ONLY.match(s):
            continue
        if re.match(r'^\s*(end|begin|until|repeat)\b', s, re.I):
            continue
        ctx.note(f'미지원: {s[:60]}')


def main() -> int:
    text = decode(open(sys.argv[1], 'rb').read())
    print(len(text.split('\n')))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
