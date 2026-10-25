#!/bin/bash
# 見張り番（Mac）：AIを使わずに会社フォルダを見て、やることがあるときだけ Claude を起こす（やることが無ければ何もしない＝トークン0）。
# 10分ごとに動かす：ターミナルで  crontab -e  を開き、次の1行を足す（場所は自分の会社フォルダに直す）
#   */10 * * * * /bin/bash "/Users/名前/会社フォルダ/仕組み/見張り番.sh"
# 試すだけ：bash 見張り番.sh --dry-run
F="$(cd "$(dirname "$0")/.." && pwd)"; H="$F/仕組み"; LOG="$H/見張り番の記録.txt"; LOCK="$H/動いています.lock"
log() { echo "$(date '+%Y-%m-%d %H:%M') $1" | tee -a "$LOG"; }
if [ -f "$LOCK" ] && [ -n "$(find "$LOCK" -mmin -120)" ]; then exit 0; fi
TODAY=$(date +%F); HOUR=$(date +%-H); R=()
# ===== 新しい版（AIは使わない）：1日1回 GitHub で版を確かめて判断待ちに出す。社長が「OK」を押したら、データはそのまま仕組みだけ新しくする =====
rm -f "$F/箱/止めて.txt"   # 作業していないときに押された「止める」は消す
VURL="${AIHONSHA_VERSION_URL:-https://raw.githubusercontent.com/jetstream20200901/aihonsha/main/version.txt}"
ZURL="${AIHONSHA_ZIP_URL:-https://github.com/jetstream20200901/aihonsha/releases/latest/download/aihonsha.zip}"
unz() { if command -v ditto >/dev/null; then ditto -x -k "$1" "$2"; elif command -v python3 >/dev/null; then python3 -m zipfile -e "$1" "$2"; else unzip -q "$1" -d "$2"; fi; }   # 日本語のファイル名をこわさずに展開（Mac は ditto）
UPD=$(perl -MJSON::PP -e 'my $d = eval { local $/; open my $f, "<", $ARGV[0] or die; decode_json(<$f>) } || []; for (@$d) { if (($_->{id}//"") =~ /^upd-(?!fail)(.+)$/ && ($_->{answer}//"") eq "OK") { print $1; last } }' "$F/箱/判断箱.json" 2>/dev/null)
if [ -n "$UPD" ]; then
  if [ "$1" = "--dry-run" ]; then log "【試し】v$UPD に更新します（実際にはしません）"
  else
    log "AI本社を v$UPD に更新します（社長がOK）"; T=$(mktemp -d); OK=0
    if curl -fsSL --max-time 180 "$ZURL" -o "$T/a.zip" && unz "$T/a.zip" "$T/x" && /bin/bash "$T/x/アップデート（Mac）.command" --target "$F" --source "$T/x/会社フォルダ" --yes > "$H/さいごの更新.txt" 2>&1; then OK=1; fi
    rm -rf "$T"
    perl -Mutf8 -MJSON::PP -e 'my ($box, $pend, $id, $ok, $ver, $stamp) = @ARGV; my $js = JSON::PP->new->utf8->pretty->canonical;
      sub rd { my $p = shift; my $d = eval { local $/; open my $f, "<", $p or die; decode_json(<$f>) }; return $d || [] }
      sub wr { my ($p, $d) = @_; open my $f, ">", $p or die; print $f $js->encode($d); close $f }
      wr($box, [grep { ($_->{id}//"") ne $id } @{rd($box)}]);
      my @p = grep { ($_->{id}//"") ne $id } @{rd($pend)};
      unshift @p, { id => "upd-fail-$ver-$stamp", kind => "確認", text => "AI本社を v$ver に新しくできませんでした。データは元のままです（控えから戻しました）。仕組み/さいごの更新.txt を JETSTREAM にお知らせください", buttons => ["わかった"] } unless $ok;
      wr($pend, \@p);' "$F/箱/判断箱.json" "$F/台帳/判断待ち.json" "upd-$UPD" "$OK" "$UPD" "$(date +%Y%m%d%H%M)"
    [ -f "$F/台帳/部署の記録.csv" ] && { [ $OK = 1 ] && echo "$TODAY,事務,AI本社を v$UPD に更新（データはそのまま）," || echo "$TODAY,事務,AI本社の v$UPD への更新に失敗（元に戻した）,"; } >> "$F/台帳/部署の記録.csv"
    [ $OK = 1 ] && log "v$UPD に更新しました" || log "v$UPD への更新に失敗し、元に戻しました"
  fi
fi
AUTO=$(perl -MJSON::PP -e 'my $d = eval { local $/; open my $f, "<", $ARGV[0] or die; decode_json(<$f>) } || {}; print((exists $d->{auto_update_check} && !$d->{auto_update_check}) ? 0 : 1)' "$F/設定.json" 2>/dev/null)
if [ "${AUTO:-1}" = 1 ] && [ "$HOUR" -ge 7 ] && [ "$(cat "$H/版を確かめた日.txt" 2>/dev/null)" != "$TODAY" ]; then
  [ "$1" != "--dry-run" ] && echo "$TODAY" > "$H/版を確かめた日.txt"
  RV=$(curl -fsSL --max-time 15 "$VURL" 2>/dev/null)
  if [ -n "$RV" ]; then
    MSG=$(perl -Mutf8 -CO -MJSON::PP -e 'my ($txt, $lvf, $pend, $dry) = @ARGV; my @l = grep { /\S/ } split /\r?\n/, $txt; my $rv = $l[0] // ""; $rv =~ s/\s//g; my $note = $l[1] // ""; $note =~ s/^\s+|\s+$//g;
      my $lv = "0"; if (open my $f, "<", $lvf) { local $/; $lv = <$f>; $lv =~ s/\s//g }
      my $cmp = sub { my @a = split /\./, shift; my @b = split /\./, shift; for my $i (0 .. 3) { my $c = ($a[$i] // 0) <=> ($b[$i] // 0); return $c if $c } 0 };
      exit 0 unless $rv =~ /^[\d.]+$/ && $cmp->($rv, $lv) > 0;
      my $js = JSON::PP->new->utf8->pretty->canonical; my $d = eval { local $/; open my $f, "<", $pend or die; decode_json(<$f>) } || [];
      exit 0 if grep { ($_->{id}//"") eq "upd-$rv" } @$d;
      if ($dry) { print "【試し】新しい版 v$rv があります（判断待ちには出していません）"; exit 0 }
      push @$d, { id => "upd-$rv", kind => "確認", text => "AI本社の新しい版 v$rv があります（" . do { my $n = $note; utf8::decode($n); $n } . "）。「OK」で、台帳・書類・設定はそのまま、仕組み（画面・スキル・見張り番）だけを新しくします。先に控えを取り、データが変わったら自動で元に戻します", link => "https://github.com/jetstream20200901/aihonsha/releases/latest", buttons => ["OK", "あとで"] };
      open my $o, ">", $pend or die; print $o $js->encode($d); close $o; print "新しい版 v$rv があるので、判断待ちに出しました"' "$RV" "$H/バージョン.txt" "$F/台帳/判断待ち.json" "$([ "$1" = "--dry-run" ] && echo 1 || echo 0)")
    [ -n "$MSG" ] && log "$MSG"
  fi
fi
cnt() { python3 -c "import json,sys
try: d=json.load(open(sys.argv[1],encoding='utf-8'))
except Exception: d=[]
print(len([x for x in d if sys.argv[2]=='' or x.get('status')==sys.argv[2]]))" "$1" "$2"; }
n=$(cnt "$F/箱/依頼箱.json" 未着手); [ "$n" -gt 0 ] && R+=("頼みごと${n}件")
n=$(cnt "$F/箱/判断箱.json" ""); [ "$n" -gt 0 ] && R+=("判断の返事${n}件")
n=$(find "$F/00_受付箱" -type f ! -name '.*' ! -name 'ここに入れる.txt' 2>/dev/null | wc -l | tr -d ' '); [ "$n" -gt 0 ] && R+=("受付箱に${n}件")
old=$(python3 -c "import json,datetime
try:
  s=json.load(open('$F/設定.json',encoding='utf-8'))
  if s.get('accounting','none')=='none': print(0); raise SystemExit
  m=json.load(open('$F/台帳/お金.json',encoding='utf-8')); t=datetime.datetime.strptime(m['synced_at'],'%Y-%m-%d %H:%M')
  print(1 if t<datetime.datetime.now()-datetime.timedelta(hours=6) else 0)
except SystemExit: pass
except Exception: print(1)" 2>/dev/null)
[ "$old" = "1" ] && [ "$HOUR" -ge 7 ] && [ "$HOUR" -lt 19 ] && R+=("会計ソフトの数字が古い")
MORNING=0; if [ "$HOUR" -ge 7 ] && [ "$(cat "$H/朝の確認をした日.txt" 2>/dev/null)" != "$TODAY" ]; then MORNING=1; R+=("今日の朝の確認"); fi
MH=$(python3 -c "import json
try: print(int(json.load(open('$F/設定.json',encoding='utf-8')).get('minutes_hour') or 18))
except Exception: print(18)" 2>/dev/null); MH=${MH:-18}
MIN=0; if [ "$HOUR" -ge "$MH" ] && [ "$(cat "$H/議事録を書いた日.txt" 2>/dev/null)" != "$TODAY" ] && [ ! -f "$F/20_議事録/AI本社/${TODAY}_AI本社_議事録.md" ]; then MIN=1; R+=("今日の議事録"); fi
[ ${#R[@]} -eq 0 ] && exit 0
WHY=$(IFS=・; echo "${R[*]}")
if [ "$1" = "--dry-run" ]; then log "【試し】起こす理由：$WHY（実際には起こしていません）"; exit 0; fi
command -v claude >/dev/null || { log "Claude Code（claude コマンド）が見つかりません。理由：$WHY"; exit 1; }
if [ $MORNING = 1 ]; then P="会社のルール（CLAUDE.md と AI本社の基本ルール）の「毎朝の確認」を行って。ただし、やることが無い手順はとばして短く終わらせて。"
else ONLY=$(printf '%s
' "${R[@]}" | grep -v '^今日の議事録$' | paste -sd '・' -)
  if [ -n "$ONLY" ]; then P="会社のルール（CLAUDE.md と AI本社の基本ルール）の「毎朝の確認」のうち、次に関係する手順だけを行って：$ONLY。それ以外はしないで、短く終わらせて。"; else P="ほかの手順はしないで、短く終わらせて。"; fi; fi
[ $MIN = 1 ] && P="$P 最後に /daily-minutes で今日の議事録を書いて。"
echo "$(date '+%Y-%m-%d %H:%M') $WHY" > "$LOCK"; log "Claude を起こします：$WHY"   # 画面が「AIが作業中：○○」と出すための目印
EXTRA=(); while IFS= read -r x; do [ -n "$x" ] && [ -d "$x" ] && EXTRA+=(--add-dir "$x"); done < <(perl -MJSON::PP -e 'my $d = eval { local $/; open my $f, "<", $ARGV[0] or die; decode_json(<$f>) } || {}; print join("\n", grep { /\S/ } split /\r?\n/, ($d->{ai_read_dirs} // ""))' "$F/設定.json" 2>/dev/null)   # 設定で許した、会社フォルダの外のフォルダ
(cd "$F" && exec claude -p "$P" --permission-mode acceptEdits "${EXTRA[@]}" --allowedTools "Read,Write,Edit,Glob,Grep,WebSearch,WebFetch" > "$H/さいごの作業.txt" 2>&1) &
CPID=$!; STOPPED=0
while kill -0 "$CPID" 2>/dev/null; do
  if [ -f "$F/箱/止めて.txt" ]; then   # 社長が画面で「⏹ 止める」を押した
    pkill -TERM -P "$CPID" 2>/dev/null; kill -TERM "$CPID" 2>/dev/null; STOPPED=1; rm -f "$F/箱/止めて.txt"
    echo '[]' > "$F/箱/判断箱.json"
    perl -MJSON::PP -e 'my $p = shift; my $d = eval { local $/; open my $f, "<", $p or die; decode_json(<$f>) } || []; for (@$d) { $_->{status} = "止めた" if ($_->{status} // "") =~ /^(未着手|作業中)$/ } open my $o, ">", $p or die; print $o JSON::PP->new->utf8->pretty->encode($d)' "$F/箱/依頼箱.json" 2>/dev/null
    [ -f "$F/台帳/部署の記録.csv" ] && echo "$TODAY,秘書室,社長がAIの作業を止めた（$WHY）," >> "$F/台帳/部署の記録.csv"
    log "社長が止めました：$WHY"; break
  fi
  sleep 2
done
wait "$CPID" 2>/dev/null
[ $STOPPED = 0 ] && [ $MORNING = 1 ] && echo "$TODAY" > "$H/朝の確認をした日.txt"
[ $STOPPED = 0 ] && [ $MIN = 1 ] && echo "$TODAY" > "$H/議事録を書いた日.txt"
[ $STOPPED = 0 ] && log "終わりました"; rm -f "$LOCK"
