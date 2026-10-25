"""勤務記録を1人ごと・月ごとに集計する（標準のPythonだけで動く）。
使い方: python attendance.py 人事フォルダ YYYY-MM
読むもの: 勤務記録.csv（日付,名前,区分,出勤,退勤,休憩分,メモ）、シフト表_YYYY-MM.csv（あれば予定と比べる）
作るもの: 勤務集計_YYYY-MM.csv
- 実働時間＝（退勤−出勤）−休憩。退勤が出勤より早いときは日をまたいだとみなす
- 8時間を超えた分を「8時間超」として数える（残業の目安。会社の決まりで違う）
- 深夜（22:00〜翌5:00）に働いた時間を数える（休憩は差し引かない目安。正確な計算は会社の決まりで）
- 休憩が短い日（6時間超で45分未満・8時間超で60分未満）を「休憩の確認」に出す
"""
import csv, sys, os, datetime
from collections import defaultdict

def mins(t):
    h, m = map(int, t.split(':')); return h * 60 + m

def night_overlap(s, e):
    total = 0
    for base in (0, 1440):
        for a, b in ((base + 22 * 60, base + 29 * 60),):
            total += max(0, min(e, b) - max(s, a))
    total += max(0, min(e, 5 * 60) - max(s, 0))
    return total

def main(base, ym):
    rows = list(csv.DictReader(open(os.path.join(base, '勤務記録.csv'), encoding='utf-8-sig')))
    agg = defaultdict(lambda: dict(days=0, work=0, over=0, night=0, notes=[]))
    for r in rows:
        if not r['日付'].startswith(ym) or not r['出勤'] or not r['退勤']:
            continue
        s, e = mins(r['出勤']), mins(r['退勤'])
        if e <= s:
            e += 1440
        brk = int(r['休憩分'] or 0)
        work = e - s - brk
        a = agg[r['名前']]
        a['days'] += 1; a['work'] += work; a['over'] += max(0, work - 480); a['night'] += night_overlap(s, e)
        if (work > 360 and brk < 45) or (work > 480 and brk < 60):
            a['notes'].append(f'{r["日付"]} 休憩{brk}分')
    out = os.path.join(base, f'勤務集計_{ym}.csv')
    with open(out, 'w', encoding='utf-8-sig', newline='') as f:
        w = csv.writer(f)
        w.writerow(['名前', '出勤日数', '実働時間', '8時間超（目安）', '深夜時間（22-5時・目安）', '休憩の確認'])
        for n, a in agg.items():
            h = lambda x: f'{x // 60}:{x % 60:02d}'
            w.writerow([n, a['days'], h(a['work']), h(a['over']), h(a['night']), '／'.join(a['notes'])])
    print('ok', out, len(agg), '人')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
