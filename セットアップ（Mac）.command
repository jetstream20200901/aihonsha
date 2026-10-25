#!/bin/bash
# AI本社 セットアップ（Mac）。ダブルクリックで動かないときは、ターミナルに  bash と1つ空けて、このファイルをドラッグして Enter。
# すること：①会社フォルダを作る ②Claude Code（AI本体）を入れる ③Obsidian を入れる（選べる）④見張り番を登録 ⑤画面を開く ⑥Claude へのログイン画面を開く
# しないこと：ログイン・お支払い・パスワードの入力（ご本人が行います）。ファイルを消すこともしません。
HERE="$(cd "$(dirname "$0")" && pwd)"; SRC="$HERE/会社フォルダ"
ask() { local a; read -r -p "$1 $( [ "$2" = y ] && echo '[Y/n]' || echo '[y/N]' ) " a; a="${a:-$2}"; [[ "$a" =~ ^([yY]|yes|はい)$ ]]; }
step() { echo; echo "■ $1"; }
done_() { read -r -p "終わりました。Enter キーで閉じます" _; }

echo "======================================"
echo "  AI本社 セットアップ（JETSTREAM合同会社）"
echo "======================================"
echo "このあと、いくつか質問します。Enter だけ押すと［ ］の大文字の答えになります。"
if [ ! -f "$SRC/CLAUDE.md" ]; then echo "「会社フォルダ」が見つかりません。ZIP をダブルクリックで展開してから、もう一度開いてください。"; done_; exit 1; fi

step "① 会社フォルダを作ります"
read -r -p "会社名を入れてください（例：さくら工務店）: " NAME; NAME="${NAME:-私の会社}"
SAFE="$(printf '%s' "$NAME" | tr '/:' '--')"; T="$HOME/Documents/${SAFE}_AI"; i=2
while [ -e "$T" ]; do T="$HOME/Documents/${SAFE}_AI（$i）"; i=$((i+1)); done
cp -R "$SRC" "$T"
for f in 設定.json CLAUDE.md 画面/dashboard.html 画面/settings.html; do
  [ -f "$T/$f" ] && NAME="$NAME" perl -CSD -Mutf8 -pi -e 's/○○株式会社/$ENV{NAME}/g' "$T/$f"
done
echo "作りました：$T"

step "② Claude Code（AI本体）"
export PATH="$HOME/.local/bin:$PATH"
if command -v claude >/dev/null; then echo "もう入っています。"
elif ask "Claude Code を入れますか？（公式のインストーラーを使います）" y; then
  echo "入れています（数分かかることがあります）…"; curl -fsSL https://claude.ai/install.sh | bash
  command -v claude >/dev/null && echo "入りました。" || echo "見つかりません。あとで「はじめの30分」の手順で入れてください。"
else echo "とばしました（見張り番を使うときは必要です）。"; fi

step "③ Obsidian（オブシディアン）"
echo "Obsidian は、会社フォルダの議事録やマニュアルを「ノート帳」のように読める無料のアプリです（入れなくても使えます）。"
if ask "Obsidian を入れますか？" n; then
  if command -v brew >/dev/null; then brew install --cask obsidian; else echo "ダウンロードのページを開きます。"; open "https://obsidian.md/download"; fi
fi

step "④ 見張り番（やることがあるときだけ AI を起こす仕組み）"
if ask "見張り番を登録しますか？（10分ごとに会社フォルダを見ます）" y; then
  LINE="*/10 * * * * PATH=\"$HOME/.local/bin:/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin\" /bin/bash \"$T/仕組み/見張り番.sh\""
  ( crontab -l 2>/dev/null; echo "$LINE" ) | crontab - && echo "登録しました。" || echo "登録できませんでした（「仕組み/見張り番.sh」の説明どおりに足してください）。"
fi

step "⑤ 会社の画面と設定を開きます"
APP=""; for a in "Google Chrome" "Microsoft Edge"; do [ -d "/Applications/$a.app" ] && { APP="$a"; break; }; done
if [ -n "$APP" ]; then open -a "$APP" "$T/画面/dashboard.html" "$T/画面/settings.html"
else echo "※ 会社の画面は Chrome か Edge で開いてください（Safari ではフォルダとつなげません）。"; open "$T/画面/dashboard.html"; fi
if command -v claude >/dev/null && ask "⑥ Claude にログインしますか？（ターミナルの窓が開き、ブラウザでログインします）" y; then
  osascript -e "tell application \"Terminal\" to do script \"cd '$T'; echo 'ブラウザでログインしてください。終わったら /exit で閉じてかまいません。'; claude\"" >/dev/null
fi
printf 'セットアップ %s\n会社名：%s\n場所：%s\n' "$(date '+%Y-%m-%d %H:%M')" "$NAME" "$T" > "$T/セットアップの記録.txt"

step "終わりました。残りは、ご本人がする3つだけです"
echo "  1. Claude にログイン（有料プランが必要です）"
echo "  2. 会社の画面の右上「📁 会社フォルダとつなぐ」を押し、次のフォルダを選んで「編集を許可」"
echo "       $T"
echo "  3. 設定画面で、目標・口座残高・会計ソフトなどを入れて「保存する」"
echo "くわしくは「はじめの30分.md」をご覧ください。"
done_
