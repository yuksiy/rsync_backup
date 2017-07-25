#!/bin/sh

# ==============================================================================
#   機能
#     同期元リストに従ってRSYNC によるバックアップを実行する
#   構文
#     USAGE 参照
#
#   Copyright (c) 2004-2017 Yukio Shiiya
#
#   This software is released under the MIT License.
#   https://opensource.org/licenses/MIT
# ==============================================================================

######################################################################
# 基本設定
######################################################################
trap "" 28				# TRAP SET
trap "POST_PROCESS;exit 1" 1 2 15	# TRAP SET

SCRIPT_FULL_NAME=`realpath $0`
SCRIPT_ROOT=`dirname ${SCRIPT_FULL_NAME}`
SCRIPT_NAME=`basename ${SCRIPT_FULL_NAME}`
PID=$$

######################################################################
# 関数定義
######################################################################
PRE_PROCESS() {
	:
}

POST_PROCESS() {
	:
}

CMD_V() {
	if [ "${FLAG_OPT_NO_PLAY}" = "FALSE" ];then
		(eval "set -x; $*")
	else
		(echo "++ $*")
	fi
	return
}

USAGE() {
	cat <<- EOF 1>&2
		Usage:
		  Syntax1. Destination is local.
		    rsync_backup.sh [OPTIONS ...] SRC_LIST DEST_DIR
		  Syntax2. Destination is remote.
		    rsync_backup.sh [OPTIONS ...] SRC_LIST [DEST_USER@]DEST_HOST::DEST_DIR
		
		    SRC_LIST  : Specify a RSYNC source list.
		    DEST_DIR  : Specify a destination directory for RSYNC.
		    DEST_HOST : Specify a destination hostname for RSYNC.
		    DEST_USER : Specify a destination username for RSYNC.
		
		OPTIONS:
		    -n (no-play)
		       Print the commands that would be executed, but do not execute them.
		    -H (host-directory)
		       Enable generation of host-prefixed directory.
		    -X EXCLUDE_LIST (exclude)
		       Specify a RSYNC exclude list if you need it.
		    -P PASSWD_FILE (password)
		       Specify a RSYNC password file if you do not want to input the password
		       repeatedly when you specify DEST_HOST.
		    -S SRC_PREFIX (source-prefix)
		       Specify prefix which should be added to all the lines in SRC_LIST.
		    -C CUT_DIRS_NUM (cut-dirs-number)
		       Specify the number of directory components you want to ignore.
		    -t RETRY_NUM
		       Specify the retry interval seconds of 'rsync' command,
		       when recoverable network error occured. ("max connections reached", etc.)
		       The default is to retry 20 times.
		       Specify 0 for infinite retrying.
		    -T RETRY_INTERVAL
		       Specify the interval seconds of retries of 'rsync' command,
		       when recoverable network error occured. ("max connections reached", etc.)
		       The default is to retry every 10 seconds.
		    -W WAIT_INTERVAL
		       Specify the wait interval seconds of 'rsync' command.
		       The default is to retry every 10 seconds.
		    -E "RSYNC_OPTIONS ..."
		       Specify options which execute rsync command with.
		       Following options are supported now.
		         -vulHpAXogDtSBez8P --iconv
		       Other options are used internally or not supported.
		       See also rsync(1) or "rsync --help" for the further information on each option.
		    --help
		       Display this help and exit.
	EOF
}

. is_numeric_function.sh

######################################################################
# 変数定義
######################################################################
#ユーザ変数

# システム環境 依存変数 (rsync)
RSYNC="rsync"

RSYNC_OPTIONS_INT="-r --delete --delete-excluded"
RSYNC_OPTIONS_DIR_CHECK="-d"

RSYNC_EXCLUDE_FROM_OPT="--exclude-from"
RSYNC_PASSWD_FILE_OPT="--password-file"
RSYNC_ICONV_OPT="--iconv"

RSYNC_RELATIVE_OPT="--relative"
RSYNC_NO_RELATIVE_OPT="--no-relative"

RSYNC_LOG_FORMAT_OPT="--log-format"
RSYNC_LOG_FORMAT_OPTARG="%o %f %l"

# プログラム内部変数
FLAG_OPT_NO_PLAY=FALSE
FLAG_OPT_HOST_DIR=FALSE
CUT_DIRS_NUM="0"
EXCLUDE_LIST=""
PASSWD_FILE=""
SRC_PREFIX=""
CONVERT_SPEC=""
RETRY_NUM="20"
RETRY_INTERVAL="10"
WAIT_INTERVAL="10"

RSYNC_OPTIONS_EXT=""
RSYNC_OPTIONS_EXT_ORG=""

#DEBUG=TRUE

######################################################################
# メインルーチン
######################################################################

# オプションのチェック
CMD_ARG="`getopt -o nHX:P:S:C:t:T:W:E: -l help -- \"$@\" 2>&1`"
if [ $? -ne 0 ];then
	echo "-E ${CMD_ARG}" 1>&2
	USAGE;exit 1
fi
eval set -- "${CMD_ARG}"
while true ; do
	opt="$1"
	case "${opt}" in
	-n)	FLAG_OPT_NO_PLAY=TRUE ; shift 1;;
	-H)	FLAG_OPT_HOST_DIR=TRUE ; shift 1;;
	-X)
		EXCLUDE_LIST="$2" ; shift 2
		# 除外リストのチェック
		if [ ! -f "${EXCLUDE_LIST}" ];then
			echo "-E EXCLUDE_LIST not a file -- \"${EXCLUDE_LIST}\"" 1>&2
			USAGE;exit 1
		fi
		RSYNC_OPTIONS_INT="${RSYNC_OPTIONS_INT} ${RSYNC_EXCLUDE_FROM_OPT}=\"${EXCLUDE_LIST}\""
		;;
	-P)
		PASSWD_FILE="$2" ; shift 2
		# パスワードファイルのチェック
		if [ ! -f "${PASSWD_FILE}" ];then
			echo "-E PASSWD_FILE not a file -- \"${PASSWD_FILE}\"" 1>&2
			USAGE;exit 1
		fi
		RSYNC_OPTIONS_INT="${RSYNC_OPTIONS_INT} ${RSYNC_PASSWD_FILE_OPT}=\"${PASSWD_FILE}\""
		RSYNC_OPTIONS_DIR_CHECK="${RSYNC_OPTIONS_DIR_CHECK} ${RSYNC_PASSWD_FILE_OPT}=\"${PASSWD_FILE}\""
		;;
	-S)
		SRC_PREFIX="$2" ; shift 2
		;;
	-C|-t|-T|-W)
		# 指定された文字列が数値か否かのチェック
		IS_NUMERIC "$2"
		if [ $? -ne 0 ];then
			echo "-E argument to \"-${opt}\" not numeric -- \"$2\"" 1>&2
			USAGE;exit 1
		fi
		case ${opt} in
		-C)	CUT_DIRS_NUM="$2" ; shift 2;;
		-t)	RETRY_NUM="$2" ; shift 2;;
		-T)	RETRY_INTERVAL="$2" ; shift 2;;
		-W)	WAIT_INTERVAL="$2" ; shift 2;;
		esac
		;;
	-E)	RSYNC_OPTIONS_EXT_ORG="$2" ; shift 2;;
	--help)
		USAGE;exit 0
		;;
	--)
		shift 1;break
		;;
	esac
done

# オプションのチェック (RSYNC_OPTIONS_EXT)
if [ ! "${RSYNC_OPTIONS_EXT_ORG}" = "" ];then
	CMD_ARG_SAVE="$@"
	CMD_ARG="`eval getopt -o vulHpAXogDtSB:e:z8P -l iconv: -- ${RSYNC_OPTIONS_EXT_ORG} 2>&1`"
	if [ $? -ne 0 ];then
		echo "-E ${CMD_ARG}" 1>&2
		USAGE;exit 1
	fi
	eval set -- "${CMD_ARG}"
	while true ; do
		opt="$1"
		case "${opt}" in
		-v|-u|-l|-H|-p|-A|-X|-o|-g|-D|-t|-S|-z|-8|-P)
			RSYNC_OPTIONS_EXT="${RSYNC_OPTIONS_EXT} ${opt}" ; shift 1;;
		-B|-e)
			RSYNC_OPTIONS_EXT="${RSYNC_OPTIONS_EXT} ${opt}=\"$2\"" ; shift 2;;
		${RSYNC_ICONV_OPT})
			CONVERT_SPEC="$2" ; shift 2
			RSYNC_OPTIONS_EXT="${RSYNC_OPTIONS_EXT} ${RSYNC_ICONV_OPT}=\"${CONVERT_SPEC}\""
			RSYNC_OPTIONS_DIR_CHECK="${RSYNC_OPTIONS_DIR_CHECK} ${RSYNC_ICONV_OPT}=\"${CONVERT_SPEC}\""
			;;
		--)
			shift 1;break
			;;
		esac
	done
	eval set -- "${CMD_ARG_SAVE}"
fi

# RSYNC_OPTIONS の初期化
RSYNC_OPTIONS="${RSYNC_OPTIONS_EXT:+${RSYNC_OPTIONS_EXT} }${RSYNC_OPTIONS_INT:+${RSYNC_OPTIONS_INT}}"

# 第1引数のチェック
if [ "$1" = "" ];then
	echo "-E Missing 1st argument" 1>&2
	USAGE;exit 1
else
	SRC_LIST=$1
	# バックアップ元リストのチェック
	if [ ! -f "${SRC_LIST}" ];then
		echo "-E SRC_LIST not a file -- \"${SRC_LIST}\"" 1>&2
		USAGE;exit 1
	fi
fi

# 第2引数のチェック
if [ "$2" = "" ];then
	echo "-E Missing 2nd argument" 1>&2
	USAGE;exit 1
else
	DEST=`echo "$2" | sed 's,/$,,'`
	########################################
	# バックアップ先ディレクトリのチェック
	########################################
	# DEST がリモートである場合
	# (例1(remote shell)：DEST="[user@]server:dir1/dir2")
	# (例2(rsync daemon)：DEST="[user@]server::dir1/dir2")
	echo "${DEST}" | grep -q ':'
	if [ $? -eq 0 ];then
		# 「：」「::」をセパレータとしてDEST の第1フィールドを取得する。
		DEST_HOST="`echo \"${DEST}\" | sed 's,::,:,' | awk -F':' '{print $1}'`"
		# 「：」「::」をセパレータとしてDEST の第2フィールドを取得する。
		DEST_DIR="`echo \"${DEST}\" | sed 's,::,:,' | awk -F':' '{print $2}'`"
		# DEST_HOST がユーザ名を含む場合
		# (例：DEST_HOST="user@server")
		echo "${DEST_HOST}" | grep -q '@'
		if [ $? -eq 0 ];then
			# 「@」をセパレータとしてDEST_HOST の第1フィールドを取得する。
			DEST_USER="`echo \"${DEST_HOST}\" | awk -F'@' '{print $1}'`"
			# 「@」をセパレータとしてDEST_HOST の第2フィールドを取得する。
			DEST_HOST="`echo \"${DEST_HOST}\" | awk -F'@' '{print $2}'`"
		# DEST_HOST がユーザ名を含まない場合
		# (例：DEST_HOST="server")
		else
			DEST_USER=""
		fi
		eval ${RSYNC} ${RSYNC_OPTIONS_DIR_CHECK} "${DEST}" 2>/dev/null | grep -q '^d'
	# DEST がリモートでない場合
	# (例：DEST="/dir1/dir2")
	else
		DEST_DIR="${DEST}"
		DEST_HOST=""
		DEST_USER=""
		test -d "${DEST}"
	fi
	if [ $? -ne 0 ];then
		echo "-E \"${DEST}\" not exist" 1>&2
		USAGE;exit 1
	fi
fi

# 作業開始前処理
PRE_PROCESS

# 処理開始メッセージの表示
echo
echo "-I rsync backup has started."

#####################
# メインループ 開始 #
#####################
backup_count=0
warning_count=0
error_count=0

# バックアップ元(src)のループ
while read src ; do
	# コメントと空行は無視
	echo "${src}" | grep -q -e '^#' -e '^$'
	if [ $? -ne 0 ];then
		src="${SRC_PREFIX}${src}"
		########################################
		# バックアップ元(src)のチェック
		########################################
		# src がリモートである場合
		# (例1(remote shell)：src="[user@]server:dir1/dir2")
		# (例2(rsync daemon)：src="[user@]server::dir1/dir2")
		echo "${src}" | grep -q ':'
		if [ $? -eq 0 ];then
			# 「：」「::」をセパレータとしてsrc の第1フィールドを取得する。
			src_host="`echo \"${src}\" | sed 's,::,:,' | awk -F':' '{print $1}'`"
			# 「：」「::」をセパレータとしてsrc の第2フィールドを取得し、先頭に"/" を付加する。
			src_path="`echo \"${src}\" | sed 's,::,:,' | awk -F':' '{print \"/\"$2}'`"
			# src_host がユーザ名を含む場合
			# (例：src_host="user@server")
			echo "${src_host}" | grep -q '@'
			if [ $? -eq 0 ];then
				# 「@」をセパレータとしてsrc_host の第1フィールドを取得する。
				src_user="`echo \"${src_host}\" | awk -F'@' '{print $1}'`"
				# 「@」をセパレータとしてsrc_host の第2フィールドを取得する。
				src_host="`echo \"${src_host}\" | awk -F'@' '{print $2}'`"
			# src_host がユーザ名を含まない場合
			# (例：src_host="server")
			else
				src_user=""
			fi
		# src がリモートでない場合
		# (例：src="/dir1/dir2")
		else
			src_path="${src}"
			src_host=""
			src_user=""
		fi
		# src がリモートである場合、かつDEST もリモートである場合、警告を表示する。
		# (例：! src_host="", ! DEST_HOST="")
		if [ ! "${src_host}" = "" ];then
			if [ ! "${DEST_HOST}" = "" ];then
				warning_count=`expr ${warning_count} + 1`
				echo "-W Both backup source \"${src}\" and destination \"${DEST}\" are remote, skipped" 1>&2
				continue
			fi
		fi
		# src がリモートでない場合、かつsrc_path が存在しない場合、警告を表示する。
		# (例：src_host="", src_path="/dir1/dir2")
		if [ "${src_host}" = "" ];then
			if [ \( ! -d "${src_path}" \) -a \( ! -f "${src_path}" \) -a \( ! -h "${src_path}" \) ];then
				warning_count=`expr ${warning_count} + 1`
				echo "-W \"${src_path}\" backup source not exist, skipped" 1>&2
				continue
			fi
		fi
		########################################
		# バックアップ元ディレクトリ(src_dir)
		# ・省略ディレクトリ(cut_dir)の取得
		########################################
		# src_path の終端が「/」である場合
		# (例：src_path="/dir1/dir2/")
		echo "${src_path}" | grep -q '/$'
		if [ $? -eq 0 ];then
			src_dir="${src_path}"
			src_file=""
		# src_path の終端が「/」でない場合
		# (例：src_path="/dir1/file1")
		else
			# src_path の親ディレクトリを取得(dirname)し、末尾に"/" を付加する。
			src_dir="`dirname \"${src_path}\"`/"
			# src_path のファイル名を取得(basename)する。
			src_file="`basename \"${src_path}\"`"
		fi
		# cut_dir を初期化
		cut_dir=""
		# CUT_DIRS_NUM オプションが指定されている場合
		if [ ${CUT_DIRS_NUM} -ne 0 ];then
			# src_dir の先頭からCUT_DIRS_NUM 個分のディレクトリをcut_dir に移動
			cut_dirs_count=0
			while [ ${cut_dirs_count} -lt ${CUT_DIRS_NUM} ];do
				# src_dir が最短(="/") になっていない場合
				if [ "${src_dir}" != "/" ];then
					cut_dirs_count=`expr ${cut_dirs_count} + 1`
					# src_dir の先頭から1個分のディレクトリをcut_dir の末尾に追加
					cut_dir="${cut_dir}`echo \"${src_dir}\" | sed 's,^\(/[^/]*\)/.*$,\1,'`"
					# src_dir の先頭から1個分のディレクトリを削除
					src_dir="`echo \"${src_dir}\" | sed 's,^/[^/]*/,/,'`"
				# src_dir が最短(="/") になってしまった場合
				else
					# ループ脱出
					break
				fi
			done
		fi
		########################################
		# バックアップ先ディレクトリ(dest_dir)の取得
		########################################
		# src がリモートである場合
		if [ ! "${src_host}" = "" ];then
			# HOST_DIR オプションが指定されている場合
			if [ "${FLAG_OPT_HOST_DIR}" = "TRUE" ];then
				# src_dir の先頭に「DEST_DIR/src_host」を付加する。
				dest_dir="${DEST_DIR}/${src_host}${src_dir}"
			# HOST_DIR オプションが指定されていない場合
			else
				# src_dir の先頭に「DEST_DIR」を付加する。
				dest_dir="${DEST_DIR}${src_dir}"
			fi
			# dest_dir が存在しない場合、dest_dir を作成する。
			if [ ! -d "${dest_dir}" ];then
				CMD_V "mkdir -p \"${dest_dir}\""
				if [ $? -ne 0 ];then
					error_count=`expr ${error_count} + 1`
					echo "-E Error has detected, skipped" 1>&2
					continue
				fi
			fi
		# src がリモートでない場合
		else
			# DEST_DIR の末尾に"/" を付加する。
			dest_dir="${DEST_DIR}/"
		fi
		########################################
		# RSYNC の実行
		########################################
		count=0
		# カウンタ<RETRY_NUM の場合はループ (RETRY_NUM=0 の場合は無限ループ)
		while [ \( ${count} -lt ${RETRY_NUM} \) -o \( ${RETRY_NUM} -eq 0 \) ];do
			count=`expr ${count} + 1`
			echo "-I 'rsync' command execution count = \"${count}/${RETRY_NUM}\""
			# RSYNC の実行
			# src がリモートでない場合
			if [ "${src_host}" = "" ];then
				if [ ! "${cut_dir}" = "" ];then
					CMD_V "(cd \"${cut_dir}\" && ${RSYNC} ${RSYNC_OPTIONS} ${RSYNC_RELATIVE_OPT} ${RSYNC_LOG_FORMAT_OPT}=\"${RSYNC_LOG_FORMAT_OPTARG}\" \".${src_dir}${src_file}\" \"${DEST_USER:+${DEST_USER}@}${DEST_HOST:+${DEST_HOST}::}${dest_dir}\")"
				else
					CMD_V                       "${RSYNC} ${RSYNC_OPTIONS} ${RSYNC_RELATIVE_OPT} ${RSYNC_LOG_FORMAT_OPT}=\"${RSYNC_LOG_FORMAT_OPTARG}\" \"${src_dir}${src_file}\" \"${DEST_USER:+${DEST_USER}@}${DEST_HOST:+${DEST_HOST}::}${dest_dir}\""
				fi
			# src がリモートである場合
			else
				CMD_V                           "${RSYNC} ${RSYNC_OPTIONS} ${RSYNC_NO_RELATIVE_OPT} ${RSYNC_LOG_FORMAT_OPT}=\"${RSYNC_LOG_FORMAT_OPTARG}\" \"${src}\" \"${dest_dir}\""
			fi
			RSYNC_RC=$?
			echo "-I 'rsync' command return code was \"${RSYNC_RC}\"."
			case ${RSYNC_RC} in
			# RSYNC がネットワーク的なエラーで正常終了しなかった場合
			#   EXIT VALUES
			#     (rsync(1)より抜粋)
			#       5   Error starting client-server protocol   (="max connections reached", etc.)
			#       10  Error in socket I/O                     (="Connection refused", etc.)
			#       12  Error in rsync protocol data stream     (="max connections reached", etc.)
			#     (その他)
			#       139 Segmentation fault
			5|10|12|139)	# ループ継続
				echo "-I Waiting for 'rsync' RETRY_INTERVAL = \"${RETRY_INTERVAL}\" seconds..."
				sleep ${RETRY_INTERVAL}
				continue
				;;
			# その他の場合
			*)	# ループ脱出
				echo "-I Waiting for 'rsync' WAIT_INTERVAL = \"${WAIT_INTERVAL}\" seconds..."
				sleep ${WAIT_INTERVAL}
				break
				;;
			esac
		done
		# RSYNC のループが正常終了しなかった場合
		if [ ${RSYNC_RC} -ne 0 ];then
			error_count=`expr ${error_count} + 1`
			echo "-E Error has detected, skipped" 1>&2
			continue
		# RSYNC のループが正常終了した場合
		else
			backup_count=`expr ${backup_count} + 1`
			echo "-I \"${src}\" backup has ended successfully."
			continue
		fi
	fi
done < "${SRC_LIST}"
#####################
# メインループ 終了 #
#####################

# 統計の表示
echo
echo "Total of backup count  : ${backup_count}"
echo "----------------------------------------"
echo "Total of warning count : ${warning_count}"
echo "Total of error count   : ${error_count}"

# 処理終了メッセージの表示
if [ \( ${warning_count} -ne 0 \) -o \( ${error_count} -ne 0 \) ];then
	echo
	echo "-E Total of warning or error count was not 0." 1>&2
	echo "-E rsync backup has ended unsuccessfully." 1>&2
	POST_PROCESS;exit 1
else
	echo
	echo "-I rsync backup has ended successfully."
	# 作業終了後処理
	POST_PROCESS;exit 0
fi

