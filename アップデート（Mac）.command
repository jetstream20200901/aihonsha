#!/bin/bash
# AI本社 アップデート（Mac）。ダブルクリックで動かないときは、ターミナルに  bash と1つ空けて、このファイルをドラッグして Enter。
# 決まり：台帳・箱・書類・設定の値・社長が書いたルールは変えない。差し替えるのは「仕組み」だけ（画面・スキル・見張り番・基本ルール）。
# 流れ：①会社フォルダを選ぶ ②控えを取る ③仕組みだけ差し替え ④データが1つも変わっていないか確かめる → 変わっていたら控えから元に戻す
# 使い方（試し）：bash アップデート（Mac）.command --target 会社フォルダ --yes [--source 新しい会社フォルダ] [--backup 控えの置き場]
HERE="$(cd "$(dirname "$0")" && pwd)"
exec perl -CSDA -Mutf8 -x "$0" "$HERE" "$@"
#!perl
use strict; use warnings; use utf8;
use File::Find; use File::Path qw(make_path remove_tree); use File::Copy qw(copy); use File::Basename qw(dirname basename); use JSON::PP; use POSIX qw(strftime);
binmode STDOUT, ':encoding(UTF-8)'; binmode STDIN, ':encoding(UTF-8)';
my $here = shift @ARGV; my ($target, $source, $bkroot, $yes, $testbreak) = ('', "$here/会社フォルダ", '', 0, 0);
while (@ARGV) { my $a = shift @ARGV; if ($a eq '--target') { $target = shift @ARGV } elsif ($a eq '--source') { $source = shift @ARGV } elsif ($a eq '--backup') { $bkroot = shift @ARGV } elsif ($a eq '--yes') { $yes = 1 } elsif ($a eq '--test-break') { $testbreak = 1 } }
sub say_ { print "$_[0]\n" } sub step { print "\n■ $_[0]\n" }
sub ask { my ($q, $def) = @_; return $def if $yes; print "$q ", ($def ? '[Y/n] ' : '[y/N] '); my $a = <STDIN> // ''; chomp $a; return $def if $a eq ''; return $a =~ /^(y|yes|はい)$/i }
sub done_ { unless ($yes) { print "Enter キーで閉じます"; <STDIN> } }
sub rd { my $p = shift; open my $f, '<:raw', $p or die "読めません：$p"; local $/; my $t = <$f>; close $f; utf8::decode($t); return $t }
sub wr { my ($p, $t) = @_; make_path(dirname($p)); my $b = $t; utf8::encode($b); open my $f, '>:raw', $p or die "書けません：$p"; print $f $b; close $f }
sub files_under { my $base = shift; my @r; return @r unless -d $base; my $b = $base; utf8::encode($b) if utf8::is_utf8($b); find({ no_chdir => 1, wanted => sub { if (-f $File::Find::name) { my $n = substr($File::Find::name, length($b) + 1); utf8::decode($n); push @r, $n } } }, $b); return @r }
sub copy_tree { my ($from, $to) = @_; if (-d $from) { for my $r (files_under($from)) { make_path(dirname("$to/$r")); copy("$from/$r", "$to/$r") or die "コピーできません：$r"; utime((stat "$from/$r")[8,9], "$to/$r") } } elsif (-f $from) { make_path(dirname($to)); copy($from, $to) or die; utime((stat $from)[8,9], $to) } }

say_ '======================================'; say_ '  AI本社 アップデート（JETSTREAM合同会社）'; say_ '======================================';
unless (-f "$source/仕組み/バージョン.txt") { say_ '新しい版の「会社フォルダ」が見つかりません。ZIP を展開してから、中の「アップデート（Mac）.command」を開いてください。'; done_(); exit 1 }
(my $newver = rd("$source/仕組み/バージョン.txt")) =~ s/\s+//g;

step '① アップデートする会社フォルダを選びます';
sub is_company { my $p = shift; return -f "$p/CLAUDE.md" && -f "$p/画面/dashboard.html" && -d "$p/台帳" }
unless ($target) {
  my @c; for my $root ("$ENV{HOME}/Documents", "$ENV{HOME}/Desktop") { opendir(my $d, $root) or next; for my $n (readdir $d) { utf8::decode($n); next if $n =~ /^\./; push @c, "$root/$n" if -d "$root/$n" && is_company("$root/$n") } closedir $d }
  if (@c == 1 && ask("「$c[0]」をアップデートしますか？", 1)) { $target = $c[0] }
  elsif (@c > 1) { for my $i (0..$#c) { say_ '  ' . ($i + 1) . ". $c[$i]" } print '番号を入れてください：'; my $n = <STDIN> // ''; chomp $n; $target = $c[$n - 1] if $n =~ /^\d+$/ && $n >= 1 && $n <= @c }
  unless ($target) { print '会社フォルダをこの窓にドラッグして Enter：'; $target = <STDIN> // ''; chomp $target; $target =~ s/^\s+|\s+$//g; $target =~ s/^['"]|['"]$//g; $target =~ s/\\ / /g }
}
$target =~ s{/$}{};
unless ($target && is_company($target)) { say_ "会社フォルダではないようです：$target（CLAUDE.md・画面・台帳 があるフォルダを選んでください）"; done_(); exit 1 }
my $oldver = -f "$target/仕組み/バージョン.txt" ? do { (my $v = rd("$target/仕組み/バージョン.txt")) =~ s/\s+//g; $v } : '1.3 以前';
say_ "会社フォルダ：$target"; say_ "今の版：$oldver → 新しい版：$newver";
if ($oldver =~ /^[\d.]+$/ && $oldver eq $newver) { unless (ask('もう同じ版です。それでも入れ直しますか？', 0)) { done_(); exit 0 } }

my $lock = "$target/仕組み/動いています.lock";
if (-f $lock && time - (stat $lock)[9] < 7200) { say_ 'いま AI が作業中です。終わってからもう一度アップデートしてください。'; done_(); exit 1 }
wr($lock, '');

my @sys = ('画面/dashboard.html', '画面/settings.html', '画面/contacts.html', '画面/theme.css', '画面/theme.js', '仕組み/見張り番.ps1', '仕組み/見張り番.sh', '仕組み/見張り番を始める.ps1', '仕組み/AI本社の基本ルール.md', '仕組み/バージョン.txt');
push @sys, map { ".claude/skills/$_" } files_under("$source/.claude/skills");
push @sys, map { "画面/img/$_" } files_under("$source/画面/img");
my %sysset = map { lc($_) => 1 } (@sys, '設定.json', 'CLAUDE.md', '仕組み/アップデートの記録.txt', '仕組み/動いています.lock');
sub snapshot { my %h; for my $r (files_under($target)) { next if $sysset{lc $r}; my @s = stat "$target/$r"; $h{$r} = "$s[7]|$s[9]" } return %h }

step '② 控え（バックアップ）を取ります';
$bkroot ||= "$ENV{HOME}/Documents/AI本社_アップデート前の控え";
(my $vtag = $oldver) =~ s/[^\d.]//g;
my $bk = "$bkroot/" . basename($target) . '_' . strftime('%Y%m%d-%H%M%S', localtime) . "_v$vtag";
make_path($bk);
for my $item ('設定.json', 'CLAUDE.md', '画面', '仕組み', '.claude', '台帳', '箱') { copy_tree("$target/$item", "$bk/$item") if -e "$target/$item" }
unlink "$bk/仕組み/動いています.lock";
my %before = snapshot();
say_ "控えを取りました：$bk"; say_ '（書類のフォルダは触らないので控えは取りません。' . scalar(keys %before) . ' 個のファイルが変わらないことを最後に確かめます）';

my @created;
sub restore { my $why = shift; say_ "
問題が見つかったため、元に戻します：$why"; for my $c (@created) { unlink "$target/$c" }
  opendir(my $d, $bk); for my $n (readdir $d) { utf8::decode($n); next if $n eq '.' || $n eq '..'; copy_tree("$bk/$n", "$target/$n") } closedir $d;
  say_ "元に戻しました（控えは $bk に残っています）。お手数ですが、この画面を写真に撮って JETSTREAM までお知らせください。" }

my $sp = "$target/設定.json"; my $cp = "$target/CLAUDE.md"; my ($cur, $oldclaude);
eval {
  step '③ 仕組みを新しくします（画面・スキル・見張り番・基本ルール）';
  my %blocks = ('画面/dashboard.html' => 'company-data', '画面/settings.html' => 'settings-data', '画面/contacts.html' => 'contacts-data');
  for my $f (@sys) {
    my ($src, $dst) = ("$source/$f", "$target/$f");
    if ($blocks{$f} && -f $dst) {
      my $id = $blocks{$f}; my $old = rd($dst); my $new = rd($src);
      if ($old =~ m{<script id="\Q$id\E" type="application/json">([\s\S]*?)</script>}) { my $keep = $1; $new =~ s{(<script id="\Q$id\E" type="application/json">)[\s\S]*?(</script>)}{$1$keep$2} }
      wr($dst, $new);
    } else { push @created, $f unless -e $dst; make_path(dirname($dst)); copy($src, $dst) or die "コピーできません：$f" }
  }
  for my $r (files_under($source)) { next if $sysset{lc $r}; next if -e "$target/$r"; make_path(dirname("$target/$r")); copy("$source/$r", "$target/$r") or die; push @created, $r; say_ "  足しました：$r" }
  my $st = rd($sp); $st =~ s/\s+$//; $cur = decode_json(do { my $b = $st; utf8::encode($b); $b }); my $def = decode_json(do { my $b = rd("$source/設定.json"); utf8::encode($b); $b });
  my $js = JSON::PP->new->allow_nonref->canonical; my @add;
  for my $k (sort keys %$def) { push @add, ' "' . $k . '": ' . $js->encode($def->{$k}) unless exists $cur->{$k} }
  if (@add) { die '設定.json の形が読めません' unless $st =~ /\}$/; $st =~ s/\s*\}$//; $st .= ",\n" . join(",\n", @add) . "\n}\n"; decode_json(do { my $b = $st; utf8::encode($b); $b }); wr($sp, $st); say_ '  設定に新しい項目を ' . scalar(@add) . ' 個足しました（今の値はそのまま）' }
  $oldclaude = rd($cp);
  unless ($oldclaude =~ /AI本社の基本ルール\.md/) { (my $c = $oldclaude) =~ s/\s+$//; $c .= "\n\n## AI本社の基本ルール（アップデートで新しくなる）\n（この上が会社だけの決まり。食い違うときは上の決まりを優先）\n\@./仕組み/AI本社の基本ルール.md\n"; wr($cp, $c); say_ '  会社のルール（CLAUDE.md）の最後に、基本ルールを読む1行を足しました（今の決まりはそのまま）' }
  if ($testbreak) { my ($t) = sort grep { m{^台帳/[^/]+$} } files_under($target); open my $f, '>>', "$target/$t"; print $f "こわれたテスト\n"; close $f }

  step '④ データが変わっていないか確かめます';
  my %after = snapshot(); my @bad;
  for my $k (sort keys %before) { push @bad, !exists $after{$k} ? "なくなった：$k" : $after{$k} ne $before{$k} ? "変わった：$k" : () }
  my $chk = decode_json(do { my $b = rd($sp); utf8::encode($b); $b }); my $js2 = JSON::PP->new->allow_nonref->canonical;
  for my $k (keys %$cur) { push @bad, "設定の値が変わった：$k" if $js2->encode($chk->{$k}) ne $js2->encode($cur->{$k}) }
  (my $o = $oldclaude) =~ s/\s+$//; push @bad, '会社のルールが変わった' if index(rd($cp), $o) != 0;
  die join('／', @bad[0 .. ($#bad < 4 ? $#bad : 4)]) . "\n" if @bad;
  say_ '台帳・箱・書類 ' . scalar(keys %before) . ' 個と、設定の値・会社のルールは、すべてそのままです。';
  1;
} or do { my $e = $@; chomp $e; restore($e); unlink $lock; done_(); exit 2 };

open my $lg, '>>:encoding(UTF-8)', "$target/仕組み/アップデートの記録.txt"; print $lg strftime('%Y-%m-%d %H:%M', localtime) . " $oldver → $newver（控え：$bk）\n"; close $lg;
unlink $lock;
step "終わりました（$oldver → $newver）";
say_ '会社の画面を開き直すと、新しい画面になります。'; say_ "調子が悪いときは、控え（$bk）の中身を会社フォルダに戻せば、前の版に戻ります。";
done_();
