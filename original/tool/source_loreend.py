"""Extract LOREEND.PAS (`End_Demo`) constants for independent replay.

This is a narrow source recognizer, not a Pascal interpreter: any changed
shape fails instead of silently producing expectations for different logic.
It records the FadeSub palette table (evaluated with Pascal `div`), the
EndMessage / StaffMessage draw lists, the thunder constants, the walking
sprite state machine and the closing text-mode screen.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'repo_source/LORE_1993_src/LOREEND.PAS'
OUTPUT = ROOT / 'test/fixtures/loreend_parity.json'

STR = r"'((?:''|[^'])*)'"


def text(raw):
    return raw.replace("''", "'")


def load_source():
    """Source bytes and text with LF endings, so CRLF checkouts hash the same."""
    raw = SOURCE.read_bytes().replace(b'\r\n', b'\n')
    return raw, raw.decode('johab')


def body(source, name, following):
    match = re.search(
        rf'\nProcedure {name}[^\n]*\n(.*?)\nProcedure {following}', source, re.S)
    if match is None:
        raise ValueError(f'LOREEND procedure boundary moved: {name}')
    return match.group(1)


def pascal_eval(expression, adder):
    if not re.fullmatch(r'[\d\s+*()a-z]+', expression):
        raise ValueError(f'Unsupported FadeSub expression: {expression}')
    # `*` and `div` share one precedence level and associate left to right,
    # exactly like Python's `*` and `//` for non-negative integers.
    python = re.sub(r'\bdiv\b', '//', expression)
    return eval(python, {'__builtins__': {}}, {'adder': adder})


def fade_table(source):
    fade = body(source, 'FadeSub', 'FadeIn')
    cases = re.findall(
        r'(\d+) : begin\s*r := ([^;]+);\s*g := ([^;]+);\s*b := ([^;]+);\s*end;', fade)
    if [int(c[0]) for c in cases] != list(range(15)):
        raise ValueError('Unsupported FadeSub case layout')
    if 'SetPalette(color,color);' not in fade or 'RGB(color,r,g,b);' not in fade:
        raise ValueError('Unsupported FadeSub palette calls')
    steps = {}
    for adder in range(0, 311, 10):
        rows = []
        for _, r, g, b in cases:
            rgb = [pascal_eval(e.strip(), adder) for e in (r, g, b)]
            if any(v < 0 or v > 255 for v in rgb):
                raise ValueError('FadeSub component exceeds a byte')
            rows.append(rgb)
        steps[str(adder)] = rows
    return {
        'expressions': [[int(c[0]), c[1].strip(), c[2].strip(), c[3].strip()] for c in cases],
        'table': steps,
    }


def extract(source):
    fade = fade_table(source)
    fade_in = body(source, 'FadeIn', 'FadeOut')
    if 'for adder := 0 to 31 do FadeSub(adder*10);' not in fade_in:
        raise ValueError('Unsupported FadeIn')
    fade_out = body(source, 'FadeOut', 'EndMessage')
    if 'for adder := 31 downto 0 do FadeSub(adder*10);' not in fade_out:
        raise ValueError('Unsupported FadeOut')

    message = body(source, 'EndMessage', 'ThunderEffect')
    color = re.search(r'SetColor\((\d+)\);', message)
    lines = [
        [int(x), int(y), text(s)]
        for x, y, s in re.findall(rf'cHPrint\((\d+),(\d+),{STR}\);', message)
    ]
    if color is None or len(lines) != 11 or len(re.findall('HPrint', message)) != 11:
        raise ValueError('Unsupported EndMessage layout')

    thunder = body(source, 'ThunderEffect', 'PutSprite')
    thunder_match = re.search(
        r'ok := FALSE;\s*SetPalette\(6,6\);\s*RGB\(6,(\d+),(\d+),(\d+)\);\s*repeat\s*'
        r'if random\((\d+)\) = 0 then\s*if random\((\d+)\) = 0 then begin\s*'
        r'RGB\(6,(\d+),(\d+),(\d+)\);\s*delay\(random\((\d+)\)\+(\d+)\);\s*'
        r'RGB\(6,(\d+),(\d+),(\d+)\);\s*end;\s*'
        r'if keypressed then c := readkey;\s*if c = #27 then ok := true;\s*until ok;', thunder)
    if thunder_match is None:
        raise ValueError('Unsupported ThunderEffect')
    t = [int(v) for v in thunder_match.groups()]
    thunder_info = {
        'base': t[0:3], 'firstRandom': t[3], 'secondRandom': t[4], 'flash': t[5:8],
        'delayRandom': t[8], 'delayBase': t[9], 'restore': t[10:13], 'escape': 27,
    }

    put = re.search(
        r'Procedure PutSprite\(x,y,number : integer\);\s*begin\s*'
        r'PutImage\(x,y,Chara\^\[number\+(\d+)\],AndPut\);\s*'
        r'PutImage\(x,y,Chara\^\[number\],OrPut\);\s*end;', source)
    if put is None:
        raise ValueError('Unsupported PutSprite')

    staff = body(source, 'StaffMessage', 'End_Demo')
    if not re.search(
            r'for j := 0 to 18 do\s*for i := 0 to 32 do PutImage\(i\*20,j\*20,Font\^\[47\],CopyPut\);',
            staff):
        raise ValueError('Unsupported StaffMessage background')
    ops = []
    for line in staff.split('\n'):
        for statement in re.findall(
                rf"SetColor\((\d+)\);|bHPrint\((\d+),(\d+),{STR}\);|"
                rf"PutSprite\((\d+),(\d+),(\d+)\);|"
                rf"cHPrint\((\d+),(\d+),{STR}(?:\+player\[1\]\.name\+{STR})?\);", line):
            c, bx, by, bs, sx, sy, sn, cx, cy, cs, cn = statement
            if c:
                ops.append(['color', int(c)])
            elif bs or bx:
                ops.append(['bold', int(bx), int(by), text(bs)])
            elif sn:
                ops.append(['sprite', int(sx), int(sy), int(sn)])
            else:
                row = ['text', int(cx), int(cy), text(cs)]
                if 'player[1].name' in line:
                    row.append(text(cn))
                ops.append(row)
    if len([o for o in ops if o[0] == 'text']) != 9 or len([o for o in ops if o[0] == 'sprite']) != 17:
        raise ValueError('Unsupported StaffMessage layout')

    end = source[source.index('Procedure End_Demo;'):]
    sequence = re.search(
        r'SetFont\(0\);\s*FadeIn;\s*SetBkColor\(0\);\s*ClearDevice;\s*EndMessage;\s*FadeOut;\s*'
        r'setFont\(1\);\s*StaffMessage;\s*'
        r'RGB\(6,(\d+),(\d+),(\d+)\);\s*delay\((\d+)\);\s*RGB\(6,(\d+),(\d+),(\d+)\);\s*delay\((\d+)\);\s*'
        r'RGB\(6,(\d+),(\d+),(\d+)\);\s*delay\((\d+)\);\s*RGB\(6,(\d+),(\d+),(\d+)\);\s*'
        r'ThunderEffect;\s*ClearDevice;', end)
    if sequence is None:
        raise ValueError('Unsupported End_Demo opening')
    g = [int(v) for v in sequence.groups()]
    flashes = [
        {'color': g[0:3], 'delayMs': g[3]},
        {'color': g[4:7], 'delayMs': g[7]},
        {'color': g[8:11], 'delayMs': g[11]},
        {'color': g[12:15], 'delayMs': 0},
    ]

    walk = re.search(
        r'y := 0; c := #255;\s*j := (\d+); i := (\d+);\s*ok := FALSE;\s*repeat\s*'
        r'PutImage\((\d+),\(y div 20\)\*20,Font\^\[47\],CopyPut\);\s*'
        r'PutImage\(\3,\(y div 20 \+ 1\)\*20,Font\^\[47\],CopyPut\);\s*'
        r'if y > (\d+) then y := 0;\s*y := y \+ (\d+);\s*PutSprite\(\3,y,j\);\s*'
        r'if i = 1 then begin\s*case j of(.*?)end;\s*end\s*else begin\s*case j of(.*?)end;\s*end;\s*'
        r'if KeyPressed then c := ReadKey;\s*if c = #27 then ok := TRUE;\s*delay\((\d+)\);\s*until ok;',
        end, re.S)
    if walk is None:
        raise ValueError('Unsupported walking sprite loop')

    def transitions(block):
        table = {}
        for key, simple, cj, ci in re.findall(
                r'(\d+) : (?:j := (\d+);|begin\s*j := (\d+);\s*i := (\d+);\s*end;)', block):
            pass
        for match in re.finditer(
                r'(\d+) : (?:j := (\d+);|begin\s*j := (\d+);\s*i := (\d+);\s*end;)', block):
            key, simple, bj, bi = match.groups()
            table[int(key)] = ([int(simple), None] if simple else [int(bj), int(bi)])
        return table

    first, second = transitions(walk.group(6)), transitions(walk.group(7))
    if sorted(first) != [20, 21, 24] or sorted(second) != [20, 21, 24]:
        raise ValueError('Unsupported walking sprite transitions')
    walker = {
        'startJ': int(walk.group(1)), 'startI': int(walk.group(2)), 'x': int(walk.group(3)),
        'wrapAbove': int(walk.group(4)), 'step': int(walk.group(5)),
        'delayMs': int(walk.group(8)),
        'whenI1': {str(k): v for k, v in first.items()},
        'whenI0': {str(k): v for k, v in second.items()},
        'tile': 47, 'escape': 27,
    }

    outro_match = re.search(
        r'TextColor\(7\);\s*TextBackGround\(0\);\s*ClrScr;\s*TextColor\(7\);\s*Writeln\(#13\);\s*'
        r'RGB\(7,0,0,0\);\s*SetPalette\(15,15\);\s*RGB\(15,0,0,0\);\s*TextColor\(15\);\s*Writeln\(#13\);\s*'
        rf"Writeln\({STR}\);\s*Writeln\({STR}\);\s*TextColor\(7\);\s*Writeln\({STR}\);\s*"
        r'for i := 1 to (\d+) do begin\s*RGB\(7,i,i,i\);\s*SetPalette\(15,15\);\s*RGB\(15,i,i,i\);\s*'
        r'delay\((\d+)\);\s*end;\s*delay\((\d+)\);\s*for i := (\d+) downto (\d+) do begin\s*'
        r'RGB\(7,i,i,i\);\s*delay\((\d+)\);\s*end;', end)
    if outro_match is None:
        raise ValueError('Unsupported closing text screen')
    o = outro_match.groups()
    outro = {
        'blankLinesBefore': 2,
        'lines': [text(o[0]), text(o[1]), text(o[2])],
        'colors': [15, 15, 7],
        'fadeUpTo': int(o[3]), 'fadeDelayMs': int(o[4]), 'holdMs': int(o[5]),
        'dimFrom': int(o[6]), 'dimTo': int(o[7]), 'dimDelayMs': int(o[8]),
    }
    if not end.rstrip().endswith('Halt;\nend;\n\nbegin;') and 'Halt;' not in end:
        raise ValueError('End_Demo no longer halts')

    return {
        'source': 'LOREEND.PAS',
        'scope': 'End_Demo FadeSub/EndMessage/ThunderEffect/StaffMessage/walker/outro; BGI and palette timing adapted',
        'fade': fade,
        'fadeSteps': {'in': list(range(0, 32)), 'out': list(range(31, -1, -1)), 'scale': 10},
        'message': {'color': int(color[1]), 'lines': lines},
        'staff': {'putSpriteMaskOffset': int(put[1]), 'tile': 47, 'ops': ops},
        'thunder': thunder_info,
        'openingFlashes': flashes,
        'walker': walker,
        'outro': outro,
    }


def walker_frames(contract, count):
    """Sprite numbers and y values for the first `count` frames."""
    w = contract['walker']
    y, j, i = 0, w['startJ'], w['startI']
    frames = []
    for _ in range(count):
        if y > w['wrapAbove']:
            y = 0
        y += w['step']
        frames.append([y, j])
        table = w['whenI1'] if i == 1 else w['whenI0']
        new_j, new_i = table[str(j)]
        j = new_j
        if new_i is not None:
            i = new_i
    return frames


def fixture():
    raw, source = load_source()
    contract = extract(source)
    contract['sourceSha256'] = hashlib.sha256(raw).hexdigest()
    contract['walkerFrames'] = walker_frames(contract, 12)
    return contract


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    data = fixture()
    if args.check:
        if json.loads(OUTPUT.read_text(encoding='utf-8')) != data:
            raise SystemExit('LOREEND fixture has drifted')
    else:
        OUTPUT.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
