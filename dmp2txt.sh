#!/bin/bash

# =================================================================
# ファイル名: dmp2txt.sh
# 機能: バイナリダンプファイル (.dmp) を解析し、構造体形式のテキストに出力する。
# =================================================================

# 引数チェック
if [ $# -ne 1 ]; then
    echo "使用法: $0 <入力ファイル.dmp>"
    exit 1
fi

INPUT_FILE="$1"

# 拡張子の置換 (.dmp -> .txt)
if [[ "$INPUT_FILE" == *.dmp ]]; then
    OUTPUT_FILE="${INPUT_FILE%.dmp}.txt"
else
    OUTPUT_FILE="${INPUT_FILE}.txt"
fi

if [ ! -f "$INPUT_FILE" ]; then
    echo "エラー: ファイル '$INPUT_FILE' が見つかりません。"
    exit 1
fi

echo "処理中 (バイナリ解析スクリプト実行): $INPUT_FILE -> $OUTPUT_FILE ..."

# バイナリを1バイトごとの10進数リストに変換し、awkで構造体解析を行う
od -An -v -t u1 "$INPUT_FILE" | awk '
BEGIN {
    # 構造体のサイズ定義
    SZ_CMD_HDR = 44
    # ProtcolHeaderのラベル幅を定義
    HEADER_LABEL_WIDTH = 15
}

# 入力データをすべて配列に格納
{
    for (i = 1; i <= NF; i++) {
        bytes[idx++] = $i
    }
}

END {
    ptr = 0
    # ★ 修正: total_bytes は要素の総数 (Count) である idx に等しい
    total_bytes = idx

    # --- 1. ProtocolHeader の Version の判定を行う ---
    # ★ 修正: 境界チェックを ptr + size > total_bytes に変更
    if (ptr + 20 > total_bytes) {
        print "エラー: ファイルサイズが ProtocolHeader (20バイト) よりも小さいです。" > "/dev/stderr"
        exit 1
    }
    
    ptr_start = ptr
    
    v1 = read_byte(); v2 = read_byte(); v3 = read_byte(); v4 = read_byte();
    ph_version_be_check = to_uint32_be(v1, v2, v3, v4);
    
    ptr = ptr_start; 

    # モードの決定 (16777216 = 0x01000000)
    is_raw_mode = (ph_version_be_check >= 16777216);
    raw_label = is_raw_mode ? "(raw)" : "";


    # --- 2. ProtocolHeader の全フィールドを読み込み、モードに従って値を決定 ---

    ph_v1 = read_byte(); ph_v2 = read_byte(); ph_v3 = read_byte(); ph_v4 = read_byte();
    ph_version_be = to_uint32_be(ph_v1, ph_v2, ph_v3, ph_v4);
    ph_version_le = to_uint32_le(ph_v1, ph_v2, ph_v3, ph_v4);
    ph_version = is_raw_mode ? ph_version_le : ph_version_be;

    ph_t1 = read_byte(); ph_t2 = read_byte(); ph_t3 = read_byte(); ph_t4 = read_byte();
    ph_type_code_be = to_uint32_be(ph_t1, ph_t2, ph_t3, ph_t4);
    ph_type_code_le = to_uint32_le(ph_t1, ph_t2, ph_t3, ph_t4);
    ph_type_code = is_raw_mode ? ph_type_code_le : ph_type_code_be;

    ph_e1 = read_byte(); ph_e2 = read_byte(); ph_e3 = read_byte(); ph_e4 = read_byte();
    ph_err_code_be = to_uint32_be(ph_e1, ph_e2, ph_e3, ph_e4);
    ph_err_code_le = to_uint32_le(ph_e1, ph_e2, ph_e3, ph_e4);
    ph_err_code = is_raw_mode ? ph_err_code_le : ph_err_code_be;
    
    ph_i1 = read_byte(); ph_i2 = read_byte(); ph_i3 = read_byte(); ph_i4 = read_byte();
    ph_ip_addr = to_uint32_be(ph_i1, ph_i2, ph_i3, ph_i4);

    ph_l1 = read_byte(); ph_l2 = read_byte(); ph_l3 = read_byte(); ph_l4 = read_byte();
    ph_length_be = to_uint32_be(ph_l1, ph_l2, ph_l3, ph_l4);
    ph_length_le = to_uint32_le(ph_l1, ph_l2, ph_l3, ph_l4);
    ph_length = is_raw_mode ? ph_length_le : ph_length_be;
    
    # --- 3. ProtocolHeader 出力 ---
    print "=== ProtcolHeader ==="
    printf "%-*s : %u\n", HEADER_LABEL_WIDTH, "version" raw_label, ph_version
    printf "%-*s : %u\n", HEADER_LABEL_WIDTH, "type_code" raw_label, ph_type_code
    printf "%-*s : %u\n", HEADER_LABEL_WIDTH, "err_code" raw_label, ph_err_code
    printf "%-*s : %s\n", HEADER_LABEL_WIDTH, "ip_addr", ip_to_string(ph_ip_addr)
    printf "%-*s : %u\n", HEADER_LABEL_WIDTH, "length" raw_label, ph_length
    print ""

    remaining_len = ph_length
    
    # 警告メッセージのチェック (総数 total_bytes = idx で正しく比較)
    if (remaining_len + 20 > total_bytes) {
         printf "警告: ProtocolHeader.length (%u) と ProtocolHeaderサイズ (20) の合計がファイルサイズ (%u) を超えています。処理を続行しますが、データ不足になる可能性があります。\n", remaining_len, total_bytes
    }

    cmd_count = 1

    # --- 4. CommandHeader とデータブロックのループ処理 ---
    while (remaining_len > 0) {
        if (remaining_len < SZ_CMD_HDR) {
            if (remaining_len > 0) {
                printf "情報: 残りデータ(%d byte)はヘッダサイズ未満のため無視します。\n", remaining_len
            }
            break
        }
        
        # ★ 修正: 境界チェックを ptr + size > total_bytes に変更
        if (ptr + SZ_CMD_HDR > total_bytes) {
            break
        }

        # CommandHeader 読み込み (常にBEで読み込む)
        ch_version     = read_uint32_be()
        ch_type_code   = read_uint32_be()
        ch_err_code    = read_uint32_be()
        ch_command     = read_uint32_be()
        ch_length      = read_uint32_be()
        ch_args_length = read_uint32_be()
        ch_data_length = read_uint32_be()
        ch_use_flg     = read_uint32_be()
        ch_time        = read_uint32_be()
        ch_micro_sec   = read_uint32_be()
        ch_dummy       = read_uint32_be()

        # CommandHeader 出力
        printf "=== CommandHeader #%d ===\n", cmd_count
        printf "version     : %u\n", ch_version
        printf "type_code   : %u\n", ch_type_code
        printf "err_code    : %u\n", ch_err_code
        printf "command     : 0x%X\n", ch_command
        printf "length      : %u\n", ch_length
        printf "args_length : %u\n", ch_args_length
        printf "data_length : %u\n", ch_data_length
        printf "use_flg     : %u\n", ch_use_flg
        printf "time        : %u\n", ch_time
        printf "micro_sec   : %u\n", ch_micro_sec
        printf "dummy       : %u\n", ch_dummy

        consumed = SZ_CMD_HDR

        # Args 読み込み
        print "" 
        print "=== ARGS ==="
        if (ch_args_length > 0) {
            # ★ 修正: 境界チェックを ptr + size > total_bytes に変更
            if (ptr + ch_args_length > total_bytes) {
                 print "(Error: Unexpected EOF in Args)"
                 break
            }
            args_str = ""
            for (k = 0; k < ch_args_length; k++) {
                val = read_byte()
                consumed++
                if (val == 0) {
                    consumed = consumed + ch_args_length - k - 1
                    ptr = ptr + ch_args_length - k - 1
                    break
                }
                args_str = args_str sprintf("%c", val)
            }
            printf "%s\n", args_str
        } else {
            print "(None)"
        }
        
        # Data 読み込み
        print "" 
        print "=== DATA ==="
        if (ch_data_length > 0) {
            # ★ 修正: 境界チェックを ptr + size > total_bytes に変更
            if (ptr + ch_data_length > total_bytes) {
                 print "(Error: Unexpected EOF in Data)"
                 break
            }
            for (k = 0; k < ch_data_length; k++) {
                val = read_byte()
                printf "%02X ", val
                consumed++
                if ((k + 1) % 16 == 0 && k != ch_data_length - 1) printf "\n" 
            }
            print ""
        } else {
            print "(None)"
        }
        print ""

        remaining_len -= consumed
        cmd_count++
    }
}

# ------------------------------------------------------------------
# AWK 関数定義
# ------------------------------------------------------------------

# 1バイト読み取りとポインタ更新
function read_byte() {
    if (ptr > total_bytes) return 0 # total_bytes (idx) が総数
    return bytes[ptr++]
}

# Big Endian (BE) 変換関数
function to_uint32_be(b1, b2, b3, b4) {
    return (b1 * 16777216) + (b2 * 65536) + (b3 * 256) + b4
}

# Little Endian (LE) 変換関数 (raw値として使用)
function to_uint32_le(b1, b2, b3, b4) {
    return (b4 * 16777216) + (b3 * 65536) + (b2 * 256) + b1
}

# CommandHeaderの読み込みに使用 (常にBE)
function read_uint32_be() {
    b1 = read_byte()
    b2 = read_byte()
    b3 = read_byte()
    b4 = read_byte()
    
    return to_uint32_be(b1, b2, b3, b4)
}

# 32ビット整数をIPv4文字列に変換
function ip_to_string(ip_addr) {
    b1 = int(ip_addr / 16777216) % 256; 
    b2 = int(ip_addr / 65536) % 256;   
    b3 = int(ip_addr / 256) % 256;     
    b4 = ip_addr % 256;                

    return b1 "." b2 "." b3 "." b4
}
' > "$OUTPUT_FILE"

echo "完了: $OUTPUT_FILE を作成しました。"
