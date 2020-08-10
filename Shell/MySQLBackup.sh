#!/bin/bash
#
########################################################
#
#    脚本名称: MySQLBackup.sh
#
#    功    能: Daily Backup MySQL
#
#    用    法: bash MySQLBackup.sh
#
#    作    者: JerryHan
#
#    日    期: 2020/07/14
#
########################################################
#
set -o pipefail; set -u; set -e

__printHelp() {
    echo
    grep -w "^#    用    法:" < "$0" | cut -c6-
}

__execNoRoot() {
    [[ $(whoami) != "root" ]] && { echo "请在root用户下执行脚本";false; }
}

########################################################
if ! which innobackupex expect pv lsb_release &>/dev/null;then { echo "请检查系统插件是否安装";false; };fi

readonly user="####"; readonly passwd="######"
readonly MAIN_MYSQL="/data/mysql"
readonly PATH_BACKUP="/data/backup"; test -d ${PATH_BACKUP} || mkdir -p ${PATH_BACKUP}
readonly __HOST="###.###.###.###"

readonly TIMESTAMP=$(date "+%Y-%m-%d_%H:%M:%S")
readonly SCRIPTS_PATH=$(cd `dirname $0`;pwd)
readonly SCRIPTS_NAME=$(basename $0 \.sh)
readonly HOST_NAME=$(hostname)

case `lsb_release -r | awk '{print substr($2,1,2)}'` in

    "6.")

        readonly IPADDR=`/sbin/ifconfig eth0 2>&- | awk -F '[ :]+' 'NR==2 {print $4}' || /sbin/ifconfig em1 2>&- | awk -F '[ :]+' 'NR==2 {print $4}'`
        ;;

    "7.")

        readonly IPADDR=`/sbin/ifconfig eth0 2>&- | awk -F '[ :]+' 'NR==2 {print $3}' || /sbin/ifconfig em1 2>&- | awk -F '[ :]+' 'NR==2 {print $3}'`
        ;;

    "*")

        echo "没有符合要求的操作系统版本" 2>&-
        false
        ;;

esac

expect -c "

set timeout -1;

spawn -noecho bash -c \"innobackupex \
--defaults-file=${MAIN_MYSQL}/conf/my1.cnf \
--user=${user} \
--password=${passwd} \
--socket=${MAIN_MYSQL}/data1/mysql.sock \
--no-timestamp \
--slave-info \
--tmpdir=${PATH_BACKUP}/ \
--stream=tar ${PATH_BACKUP}/ | pv -q -L${1:-10}m | ssh ${user}@${__HOST} 'gzip - > ${PATH_BACKUP}/${HOST_NAME}_${IPADDR}_${TIMESTAMP}.tar.gz'\";

expect {

    \"yes/no\" { send \"yes\r\";exp_continue }

    \"\(completed OK!\)\" {exit 0;}
    \"\(error|ERROR\)\" {exit 1;}
    eof

}" || { echo "备份失败";false; }

set +o pipefail; set +u; set +e
#（END）