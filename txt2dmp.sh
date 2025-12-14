#!/usr/bin/perl
use strict;
use warnings;

# Perlスクリプトはバイナリデータを扱うため、printの後にバッファリングを解除します
select(STDOUT); $| = 1;

# =================================================================
# ファイル名: txt2dmp.sh
# 機能: dmp2txt.shで生成された構造化テキストを読み込み、元のバイナリダンプファイルを再構築する。
# =================================================================

# --- 1. 引数とファイルパスの処理 ---
if (@ARGV != 1) {
    die "使用法: $0 <入力ファイル.txt>\n";
}

my $INPUT_FILE = shift @ARGV;
my $OUTPUT_FILE;

if ($INPUT_FILE =~ /\.txt$/i) {
    $OUTPUT_FILE = $INPUT_FILE;
    $OUTPUT_FILE =~ s/\.txt$//i;
    $OUTPUT_FILE .= ".dmp";
} else {
    $OUTPUT_FILE = $INPUT_FILE . ".dmp";
}

open(my $IN, '<', $INPUT_FILE) or die "エラー: 入力ファイル '$INPUT_FILE' を開けません: $!";
open(my $OUT, '>:raw', $OUTPUT_FILE) or die "エラー: 出力ファイル '$OUTPUT_FILE' を開けません: $!";

print "処理中 (バイナリ再構築): $INPUT_FILE -> $OUTPUT_FILE ...\n";

# --- 2. 状態管理変数 ---
my %header_values;
my $current_section = "";
my $file_content = "";
my $is_raw_mode = 0;

# --- 3. プロトコル定義 (バイト順を関数で管理) ---

# 3.1. uint32値を4バイトのバイナリ文字列にパックする
sub pack_uint32 {
    my ($value, $is_raw_field, $is_ip_addr) = @_;
    
    if ($is_ip_addr) {
        return pack("N", $value); # N: Big-endian 32-bit unsigned
    }
    
    if ($is_raw_field) {
        return pack("V", $value); # V: Little-endian 32-bit unsigned
    }

    return pack("N", $value); # Big Endian (BE)
}

# 3.2. IPv4文字列をuint32値に変換
sub ip_to_uint32 {
    my ($ip_str) = @_;
    return unpack("N", pack("C4", split(/\./, $ip_str)));
}

# --- 4. ファイル解析ループ ---
while (my $line = <$IN>) {
    chomp $line;
    $line =~ s/^\s+//; # 行頭の空白を削除

    # --- A. セクションヘッダーの検出と状態遷移 ---
    if ($line =~ /^=== ProtcolHeader ===/) {
        $current_section = "PH";
        %header_values = ();
        $is_raw_mode = 0;
        next;
    } elsif ($line =~ /^=== CommandHeader #\d+ ===/) {
        # ★ 修正点1: 前のコマンドブロックがPHでない、かつ内容があればここで確定
        if ($current_section ne "PH" && keys %header_values) {
            process_command_block();
        }
        # ProtocolHeaderの処理を確定 (CHブロック開始前にPHの内容を書き出す)
        if ($current_section eq "PH") {
            process_protocol_header();
        }
        $current_section = "CH";
        %header_values = ();
        next;
    } elsif ($line =~ /^=== ARGS ===/) {
        $current_section = "ARGS";
        $header_values{ARGS_DATA} = "";
        next;
    } elsif ($line =~ /^=== DATA ===/) {
        $current_section = "DATA";
        $header_values{DATA_DATA} = "";
        next;
    } elsif ($line eq "" || $line =~ /^\s*$/) {
        # ★ 修正点2: 空行は単に無視し、ブロック確定は次のヘッダー検出時に行う
        next;
    }

    # --- B. フィールドの読み取り ---
    if ($current_section eq "PH" || $current_section eq "CH") {
        if ($line =~ /^([a-z_]+)\s*(\(raw\))?\s*:\s*(\S+)/i) {
            my ($key, $raw_tag, $value) = ($1, $2, $3);
            
            $key .= $raw_tag if defined $raw_tag;
            $header_values{$key} = $value;
            
            if ($current_section eq "PH" && defined $raw_tag) {
                $is_raw_mode = 1;
            }
        }
    }

    # --- C. ARGS/DATAのコンテンツ読み取り ---
    elsif ($current_section eq "ARGS") {
        if ($line =~ /^\(None\)$/) {
            $header_values{ARGS_DATA} = "";
        } else {
            $header_values{ARGS_DATA} = $line;
        }
    }
    elsif ($current_section eq "DATA") {
        if ($line =~ /^\(None\)$/) {
            $header_values{DATA_DATA} = "";
        } else {
            $header_values{DATA_DATA} .= $line . " ";
        }
    }
}

# --- 5. 終端処理 ---
# ファイルの最後にCommand Blockが閉じられずに終わった場合を処理
if ($current_section eq "CH" || $current_section eq "DATA" || $current_section eq "ARGS") {
    process_command_block();
}
# ProtocolHeaderが閉じられずに終わった場合を処理
elsif ($current_section eq "PH") {
    process_protocol_header();
}


# --- 6. サブ関数定義 ---

sub process_protocol_header {
    return unless keys %header_values;
    
    my $v = $header_values{$is_raw_mode ? "version(raw)" : "version"} // 0;
    my $t = $header_values{$is_raw_mode ? "type_code(raw)" : "type_code"} // 0;
    my $e = $header_values{$is_raw_mode ? "err_code(raw)" : "err_code"} // 0;
    my $l = $header_values{$is_raw_mode ? "length(raw)" : "length"} // 0;
    my $i_str = $header_values{"ip_addr"} // "0.0.0.0";
    
    my $i = ip_to_uint32($i_str);

    $file_content .= pack_uint32($v, $is_raw_mode, 0);
    $file_content .= pack_uint32($t, $is_raw_mode, 0);
    $file_content .= pack_uint32($e, $is_raw_mode, 0);
    $file_content .= pack_uint32($i, 0, 1); # IPアドレスは常にBEとしてパック
    $file_content .= pack_uint32($l, $is_raw_mode, 0);

    %header_values = ();
}

sub process_command_block {
    return unless keys %header_values;

    my @ch_fields = qw(version type_code err_code command length args_length data_length use_flg time micro_sec dummy);
    
    # 1. CommandHeader (常にBE)
    foreach my $field (@ch_fields) {
        my $value = $header_values{$field} // 0;
        
        if ($field eq "command" && $value =~ /^0x(\S+)/i) {
            $value = hex($1);
        }

        $file_content .= pack_uint32($value, 0, 0);
    }
    
    # 2. ARGS データ (ヌルバイトパディング修正済み)
    my $args_str = $header_values{ARGS_DATA} // "";
    my $args_len_expected = $header_values{args_length} // 0;
    my $current_args_len = length $args_str;
    
    $file_content .= $args_str;
    
    # ARGSのバイト長がargs_length未満の場合、ヌルバイト(0x00)でパディング
    if ($current_args_len < $args_len_expected) {
        my $padding_len = $args_len_expected - $current_args_len;
        $file_content .= "\x00" x $padding_len;
    }
    
    # 3. DATA データ
    my $data_hex_str = $header_values{DATA_DATA} // "";
    my $data_bin = "";

    if ($data_hex_str =~ /\S/) {
        $data_hex_str =~ s/\s//g;
        $data_bin = pack("H*", $data_hex_str);
    }
    
    $file_content .= $data_bin;
    
    %header_values = ();
}


# --- 7. バイナリファイルの書き出し ---
binmode $OUT;
print $OUT $file_content;

close $IN;
close $OUT;

print "完了: $OUTPUT_FILE を作成しました。\n";
