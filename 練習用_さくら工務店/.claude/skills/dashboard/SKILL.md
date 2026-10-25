---
name: dashboard
description: 台帳・設定・経営の記録を集計して、画面/dashboard.html（今日の会社）と画面/settings.html のデータを最新にする。「画面を更新して」「会社の状況を見せて」と頼まれたとき、毎朝の確認の最後（1日1回）に使う。
---

# 今日の会社（画面の更新）

**トークン節約の決まり**：画面（dashboard.html・contacts.html）は、会社フォルダとつながっていれば台帳を自分で読んで計算する（AIは要らない）。この手順は「フォルダとつながっていないときの表示用の写し」を作るだけなので、**1日1回（朝の確認の最後）だけ**行う。ほかのスキルのあとに毎回しない。

画面/dashboard.html の中の `<script id="company-data" type="application/json">` と `</script>` の間だけを書き換える。HTMLのほかの部分は変えない。
画面/settings.html の `<script id="settings-data" type="application/json">` の間も、設定.json と同じ中身に書き換える（フォルダとつながっていないときの表示用）。

## 読むもの
- 設定.json（会社名・目標・口座残高・決まった支払い・部署・お知らせの日数・出す件数）
- 台帳/売上台帳.csv（請求日,請求番号,取引先,内容,金額,入金期限,入金日）
- 台帳/書類台帳.csv（受付日,書類の種類,取引先,書類の日付,金額,期限,ファイルの場所,メモ）
- 台帳/やること.csv（期限,内容,担当,状態）
- 台帳/判断待ち.json（AIが社長に聞きたいこと）
- 台帳/経営.json（戦略・PDCA・同業の動き）
- 台帳/部署の記録.csv（日付,部署,やったこと,次の予定）
- 箱/依頼箱.json（画面から頼まれたこと）
- 台帳/入出金の予定.csv
- 20_議事録/AI本社 の新しい3日分と 台帳/議事録の確認.json

## 作るデータ（今日＝今日の日付。金額は整数）
```json
{
  "company": "設定.json の company",
  "updated": "YYYY-MM-DD HH:MM",
  "decisions": [{"id":"d-YYYYMMDD-1","kind":"対策|お金|確認","text":"…","link":"開くファイルの場所（任意）","buttons":["OK","やめる","あとで"]}],
  "requests": [{"date":"…","text":"…","status":"未着手|作業中|済","result":"AIの返事（短く）"}],
  "strategy": {"policy":"…","year_goal":"売上○万円・利益○万円","items":[{"name","goal","now","pct","late","pdca"}],"next_review":"YYYY-MM-DD"},
  "pdca": {"title","round","stage","days_in_stage","kpi":{"label","now","target","now_text","target_text"},"prev","next_check","issue","peers","proposal"},
  "pdca_history": [],
  "depts": [{"name":"事務","last":"昨日：書類5枚を仕分け","days_idle":0,"next":"…"}],
  "ai_log": ["きのうAIがやったこと（1行ずつ・新しい順・最大10）"],
  "money": {"source":"freee|moneyforward|csv|空","synced_at":"YYYY-MM-DD HH:MM","balance":数字またはnull,"pay30":数字またはnull,"receivable","receivable_over_count","receivable_over_amount","sales_month","sales_target":数字またはnull,"sales_last","expense_month","monthly_sales":[{"month":"YYYY-MM","amount"}],"by_client":[{"name","amount"}]},
  "deadlines": [{"date":"YYYY-MM-DD","text":"…"}],
  "deadlines30": [],
  "todos": [{"due","task","owner"}],
  "recent_docs": [{"received","type","client","path"}],
  "cash": {"start","start_from","safety","over","months":[{"ym","label","start","in","out","end"}],"items":[{"date","text","amount（入金は＋・出金は−）"}],"warn"}（口座残高が無ければ null）,
  "minutes": [{"date":"YYYY-MM-DD","file":"20_議事録/AI本社/…","text":"議事録の中身","confirmed":"確認した時刻または空"}],
  "peers": [{"date","company","text","url"}]
}
```

## 集計の決まり
1. decisions：台帳/判断待ち.json のうち、まだ答えのないもの。大事な順（お金と期限が近いもの→対策→確認）。画面が上から 設定の decision_rows 件だけ出すので、全部入れてよい。
2. money
   - **台帳/お金.json があり、synced_at が3日以内なら**（会計ソフトから /money-sync で取った数字）、balance・receivable・pay30・sales_month・expense_month・monthly_sales はそちらを使い、money.source と money.synced_at を写す。receivable_over_* は receivable_items の期日から数える。お金.json が3日より古いときは下の計算に戻し、判断待ちに「会計ソフトの数字が古い（/money-sync が動いていない）」を1件足す
   - 会計ソフトを使わないとき（設定の accounting が none）は source を空にして、次のとおり計算する
   - balance：設定.json の balance（空なら null）。pay30：今日から30日以内の「決まった支払い」（設定の fixed_pay）の合計（balance が空なら null）
   - receivable：売上台帳で入金日が空の行の合計。receivable_over_*：そのうち入金期限を過ぎた件数と合計
   - sales_month／sales_last：請求日が今月／先月の合計。sales_target：設定の month_sales（空なら null）
   - expense_month：書類台帳で種類が「領収書・経費」かつ書類の日付が今月の金額の合計
   - monthly_sales：今月を含む直近12か月（古い順）。by_client：今年度の取引先別合計（多い順・10社まで）
3. deadlines：書類台帳の期限・入金待ちの入金期限・やること（済以外）・決まった支払いの日のうち、過ぎたものと、今日から 設定の notice_days 日以内。過ぎたものを先頭に。text は「相手＋何の期限＋金額」を短く。deadlines30 は30日以内すべて。
4. strategy・pdca・pdca_history・peers：台帳/経営.json から写す。days_in_stage＝今日−pdca.stage_since の日数。strategy.items が空で、設定に目標があるときは、そのことを decisions に「戦略の案を作ってよいか」として1件入れる。
5. depts：設定でチェックされた部署ごとに、部署の記録.csv の一番新しい行。days_idle＝今日−その日付。記録がない部署は last を「まだ記録なし」、days_idle を 0。
6. ai_log：部署の記録.csv の昨日（なければ一番新しい日）の行を「部署：やったこと」で。
7. requests：箱/依頼箱.json を新しい順に。
8-0. cash：/cashflow の「計算のしかた」のとおり（今月の残り＋3か月）。
8. minutes：20_議事録/AI本社 の新しい順に3日分（中身も入れる）。confirmed は 台帳/議事録の確認.json のその日の値。
9. recent_docs：受付日の新しい順に20件。todos：済以外を期限の近い順に。

## 連絡先の画面
画面/contacts.html の `<script id="contacts-data" type="application/json">` の間を、次の形に書き換える（フォルダとつながっていないときの表示用）：
{"contacts": 連絡先.json の contacts, "drafts": メール下書き.json の drafts, "pending": 判断待ち.json の kind「登録」のもの, "mail": {"work_email","client"（設定の mail_client）,"signature"（設定の mail_signature）}}

## 報告
「判断待ち○件・入金待ち○円（期限切れ○件）・7日以内の期限○件・止まっている部署○つ」と伝え、「画面/dashboard.html を開いてください（設定は ⚙️ から）」と案内する。

## 守ること
- 台帳は読むだけで変えない（この手順で書き換えるのは画面の2つのファイルだけ）。
- 計算できない行は集計に入れず、報告で「○○の○行目を読めませんでした」と伝える。
- 推測で数字を作らない。わからない所は null か空にする（画面は「—」や案内を出す）。
