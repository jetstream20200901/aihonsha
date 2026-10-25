"""シフト表を組む（標準のPythonだけで動く）。
使い方: python shift.py 人事フォルダ YYYY-MM
読むもの: 従業員.csv / 勤務の型.csv / シフト希望.csv / 祝日.csv（任意）
作るもの: シフト表_YYYY-MM.csv / シフト表_YYYY-MM.html / シフトの確認_YYYY-MM.md
決まり（変えたいときは /fit-company で）:
- 夜勤の次の日は「明け」で休み。夜勤は2日続けない
- 週（月〜日）の勤務日数は「週の上限日数」まで。連続勤務は「連続勤務の上限」まで
- 「休み」の希望は必ず守る。「日勤だけ」「夜勤だけ」の希望も守る
- 必要人数を満たせない日は、無理に埋めずに「不足」として知らせる
- 勤務の回数が人によって偏らないように、少ない人から入れる
"""
import csv, sys, os, datetime, html, calendar

def rd(path):
    if not os.path.exists(path):
        return []
    with open(path, encoding='utf-8-sig') as f:
        return list(csv.DictReader(f))

def main(base, ym):
    y, m = map(int, ym.split('-'))
    days = [datetime.date(y, m, d) for d in range(1, calendar.monthrange(y, m)[1] + 1)]
    staff = rd(os.path.join(base, '従業員.csv'))
    types = rd(os.path.join(base, '勤務の型.csv'))
    reqs = rd(os.path.join(base, 'シフト希望.csv'))
    hol = {r['日付'] for r in rd(os.path.join(base, '祝日.csv'))}
    names = [s['名前'] for s in staff]
    can = {s['名前']: set(s['できる勤務'].replace('、', '・').split('・')) for s in staff}
    wmax = {s['名前']: int(s['週の上限日数'] or 5) for s in staff}
    cmax = {s['名前']: int(s['連続勤務の上限'] or 5) for s in staff}
    want = {}
    for r in reqs:
        want[(r['名前'], r['日付'])] = r['希望']
    # 夜勤のような日をまたぐ区分を先に埋める
    types_sorted = sorted(types, key=lambda t: 0 if t['終了'] < t['開始'] else 1)
    sched = {n: {} for n in names}  # name -> date -> 区分 / '明け'
    count = {n: 0 for n in names}
    short = []
    def is_holiday(d):
        return d.weekday() >= 5 or d.isoformat() in hol
    def week_days(n, d):
        mon = d - datetime.timedelta(days=d.weekday())
        return sum(1 for k in range(7) if (mon + datetime.timedelta(days=k)) in sched[n] and sched[n][mon + datetime.timedelta(days=k)] != '明け')
    def streak(n, d):
        c, k = 0, d - datetime.timedelta(days=1)
        while k in sched[n] and sched[n][k] != '明け':
            c += 1; k -= datetime.timedelta(days=1)
        return c
    for d in days:
        ds = d.isoformat()
        for t in types_sorted:
            kind = t['区分']; overnight = t['終了'] < t['開始']
            need = int(t['必要人数（土日祝）'] if is_holiday(d) else t['必要人数（平日）'])
            got = 0
            cands = []
            for n in names:
                if d in sched[n]:
                    continue
                if kind not in can[n]:
                    continue
                w = want.get((n, ds), '')
                if w == '休み' or (w.endswith('だけ') and w != kind + 'だけ'):
                    continue
                if week_days(n, d) >= wmax[n] or streak(n, d) >= cmax[n]:
                    continue
                prev = sched[n].get(d - datetime.timedelta(days=1))
                if overnight and prev == kind:
                    continue  # 夜勤を2日続けない
                if overnight:
                    nd = (d + datetime.timedelta(days=1)).isoformat()
                    if want.get((n, nd), '') not in ('', '休み'):
                        continue  # 次の日（明け）に勤務の希望がある人は入れない
                cands.append(n)
            cands.sort(key=lambda n: (count[n] / wmax[n], names.index(n)))
            for n in cands:
                if got >= need:
                    break
                sched[n][d] = kind; count[n] += 1; got += 1
                if overnight:
                    nxt = d + datetime.timedelta(days=1)
                    if nxt.month == m:
                        sched[n][nxt] = '明け'
            if got < need:
                short.append((ds, kind, need, got))
    sym = {t['区分']: t['記号'] for t in types}
    sym['明け'] = '明'
    head = ['名前'] + [f'{d.day}({"月火水木金土日"[d.weekday()]})' for d in days] + ['勤務日数']
    rows = [[n] + [sym.get(sched[n].get(d, ''), '') if sched[n].get(d) else '休' for d in days] + [count[n]] for n in names]
    with open(os.path.join(base, f'シフト表_{ym}.csv'), 'w', encoding='utf-8-sig', newline='') as f:
        wr = csv.writer(f); wr.writerow(head); wr.writerows(rows)
        for t in types:
            wr.writerow([f'{t["区分"]}の人数'] + [sum(1 for n in names if sched[n].get(d) == t['区分']) for d in days] + [''])
    color = {'日': '#e8f1fb', '夜': '#3b3f6b', '明': '#d9d9e6', '休': '#ffffff'}
    tcol = {'夜': '#fff'}
    th = ''.join(f'<th class="{"we" if is_holiday(d) else ""}">{d.day}<br>{"月火水木金土日"[d.weekday()]}</th>' for d in days)
    body = ''.join('<tr><td class="nm">' + html.escape(r[0]) + '</td>' + ''.join(f'<td style="background:{color.get(c, "#fff8e1")};color:{tcol.get(c, "#222")}">{c}</td>' for c in r[1:-1]) + f'<td class="nm">{r[-1]}</td></tr>' for r in rows)
    page = f'''<!doctype html><meta charset="utf-8"><title>シフト表 {ym}</title><style>
body{{font-family:"Yu Gothic UI","Meiryo",sans-serif;margin:24px;color:#222}}table{{border-collapse:collapse;font-size:14px}}
td,th{{border:1px solid #ccd;padding:4px 6px;text-align:center;min-width:26px}}th.we{{background:#fde8e8}}td.nm{{text-align:left;white-space:nowrap;font-weight:600}}
.note{{margin-top:12px;color:#555}}</style><h2>シフト表 {ym}</h2><table><tr><th>名前</th>{th}<th>日数</th></tr>{body}</table>
<p class="note">日＝日勤　夜＝夜勤　明＝夜勤明け（休み）　休＝休み。赤い日付は土日祝。</p>'''
    open(os.path.join(base, f'シフト表_{ym}.html'), 'w', encoding='utf-8').write(page)
    # 確認
    broken = []
    for n in names:
        for (nm, ds), w in want.items():
            if nm != n or not ds.startswith(ym):
                continue
            got = sched[n].get(datetime.date.fromisoformat(ds), '休')
            if w == '休み' and got not in ('休', '明け'):
                broken.append(f'{n} {ds} 休み希望なのに {got}')
    md = [f'# シフトの確認 {ym}', '', f'- 従業員 {len(names)}人・{len(days)}日', '- 勤務日数：' + '、'.join(f'{n} {count[n]}日' for n in names), '']
    md += ['## 人が足りない日（手で調整してください）'] + ([f'- {d} {k}：必要{nd}人に対して{g}人' for d, k, nd, g in short] or ['- なし'])
    md += ['', '## 守れなかった希望'] + (broken or ['- なし（休みの希望はすべて守りました）'])
    md += ['', '※就業規則・36協定・休日の決まりは会社によって違います。最終の確認は社会保険労務士などにご相談ください。']
    open(os.path.join(base, f'シフトの確認_{ym}.md'), 'w', encoding='utf-8').write('\n'.join(md))
    print(f'不足{len(short)}件 希望違反{len(broken)}件', {n: count[n] for n in names})

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
