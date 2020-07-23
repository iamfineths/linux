#!/bin/bash
#
########################################################
#
#    脚本名称: %{SCRIPTS}%.sh
#
#    功    能: restart programs
#
#    用    法: bash %{SCRIPTS}%.sh
#
#    作    者: JerryHan
#
#    日    期: 2019/12/10
#
########################################################
#
set -o pipefail; set -u; set -e

readonly APPS="$(basename ${0} \.sh)"
readonly IPADDR=`ifconfig eth0 | awk -F '[ :]+' 'NR==2 {print $4}'`

readonly APPS_HOME="/data/apps"
readonly APPS_LOGS="/data/logs/${APPS}"; test -d "${APPS_LOGS}" || mkdir -p ${APPS_LOGS}
readonly JAVA_PATH="/usr/local/jdk/bin/java"
readonly CLASSNAME="类名"

stop(){

    cat ${APPS_LOGS}/${APPS}.pid &>/dev/null && local PID=`cat ${APPS_LOGS}/${APPS}.pid` || { echo "pid文件不存在";false; }

    for((count=0;count<3;count++));do

        if kill -0 ${PID} &>/dev/null;then
            kill -9 ${PID} &>/dev/null
        else
            rm ${APPS_LOGS}/${APPS}.pid &>/dev/null || true
            break
        fi

        [ ${count} = 2 ] && { echo "尝试3次关闭程序无效，请手动检查";false; }
        sleep 1

    done

}

start(){

    cat ${APPS_LOGS}/${APPS}.pid &>/dev/null && { 

        local PID=`cat ${APPS_LOGS}/${APPS}.pid`
        if kill -0 ${PID} &>/dev/null;then
            { echo "pid文件存在和进程都存在，请手动检查";false; }
        fi

    }

    cd ${APPS_HOME}/${APPS}/WEB-INF/classes 2>&- || cd ${APPS_HOME}/${APPS}/BOOT-INF/classes 2>&-
    local ___=$(dirname `pwd`)

    local CLASSPATH=
    for i in ${___}/lib/*.jar;do CLASSPATH="${CLASSPATH}${i}:";done

    (exec nohup ${JAVA_PATH} \
    -server \
    -Xms4096m \
    -Xmx4096m \
    -Xmn2048m \
    -Xss512k \
    -XX:PermSize=512m \
    -XX:MaxPermSize=1024m \
    -XX:SurvivorRatio=4 \
    -XX:+PrintGCTimeStamps \
    -XX:+PrintGCDetails \
    -XX:+UseConcMarkSweepGC \
    -XX:MaxTenuringThreshold=15 \
    -Dsun.rmi.dgc.server.gcInterval=600000 \
    -Dsun.rmi.dgc.client.gcInterval=600000 \
    -Dcom.sun.management.jmxremote \
    -Dcom.sun.management.jmxremote.port=10056 \
    -Dcom.sun.management.jmxremote.ssl=false \
    -Dcom.sun.management.jmxremote.authenticate=false \
    -Dproject.dir=${___} \
    -Djava.awt.headless=true \
    -Djava.rmi.server.hostname="${IPADDR}" -classpath "${CLASSPATH}" "${CLASSNAME}" &>/data/logs/${APPS}/stout.log )&

    echo $! > ${APPS_LOGS}/${APPS}.pid

}

set +o pipefail; set +u; set +e

case ${1} in
    "stop")
        stop
        ;;

    "start")
        start
        ;;

    "restart")
        stop
        start
        ;;

    "")
        stop
        start
        ;;

    *)
        echo "位置参数输入有误" 2>&-
        ;;

esac
#END