#!/bin/bash
#
###############################################
# FILE: 	local-backup.sh
# PORPOSE: 	本地备份服务程序、日志、数据库
# AUTHOR: 	handonglin
# DATE: 	2014-08-27
###############################################

# 设置变量为空则退出
set -o nounset

# 读取全局变量
set -e
. ../lib/SHOWINFO.SHL
. ../lib/GLOBAL.SHL
. ../lib/CUTSTRING.AWK
set +e

# 确认信息交互
if [[ $# -lt "1" ]];then
	_LOGFAIL_ "FAIL-WOULD-KILL" "输入为空，请确认！"
else
	echo "--------------------------"
	_LOGINFO_ "输入区服：{ $@ }"
fi

# 交互信息确认
while true;do
echo "--------------------------"
read -t 30 -p "非常重要！！！以上信息是否正确...?请输入[y|n]" ENTERNUM
        case ${ENTERNUM} in
                "")     echo
			_LOGFAIL_ "FAIL-WOULD-KILL" "等待超时,脚本退出..."
                        ;;
                y|Y)    _LOGOK_ "开始计算，请耐心等待..."
                        break
                        ;;
                n|N)    _LOGOK_ "脚本已手动退出..."
                        exit 1
                        ;;
                *)      _LOGFAIL_ "非法输入...，请重新输入...！！"
                        continue
                        ;;
        esac
done

# 创建(根)备份目录
test -d ${_PATH_BACKUP_DATE_} || mkdir -p ${_PATH_BACKUP_DATE_}

# 重定向输出
exec 3>&1 3>>${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}

# 审请40天日志
declare -a _DATE_=($(for s in {0..40};do date --date=''${s}' days ago' "+%Y%m%d";done))

# 开始计算...
while read line;do

	# 判断输入是否合法
	if echo ${line} | egrep -q "^[1-9][0-9]*$";then
                :
        elif echo ${line} | egrep -q "^[1-9][0-9]*_[1-9][0-9]*$";then
                :
        else
		_LOGFAIL_ "FAIL-WOULD-KILL" "${line}" "非法输入"
        fi

	# 赋值
	if [[ ${line} =~ "_" ]];then
		logicserver="logicserver${line}"
		dbserver="dbserver${line}"
		firstname="${line%%_*}"
		lastname="${line##*_}"
	else
		logicserver="logicserver_${line}"
		dbserver="dbserver_${line}"
		firstname="${line}"
		lastname="${line}"
	fi

	# 检查目录与进程
	test -d ${_PATH_OF_SERVER_}/${logicserver} || _LOGFAIL_ "FAIL-WOULD-KILL" "${logicserver}" "目录不存在"
	test -d ${_PATH_OF_SERVER_}/${dbserver} || _LOGFAIL_ "FAIL-WOULD-KILL" "${dbserver}" "目录不存在"
	test -d ${_PATH_OF_CQACTOR_}/cq_actor${firstname} || _LOGFAIL_ "FAIL-WOULD-KILL" "cq_actor${firstname}" "目录不存在"

	! pgrep -f "${_PATH_OF_SERVER_}/${logicserver}/logicserver_r" >/dev/null 2>&1 || _LOGFAIL_ "FAIL-WOULD-KILL" "${logicserver}" "进程存在"
	! pgrep -f "${_PATH_OF_SERVER_}/${dbserver}/dbserver_r" >/dev/null 2>&1 || _LOGFAIL_ "FAIL-WOULD-KILL" "${dbserver}" "进程存在"

	# 创建备份目录
	test -d ${_PATH_BACKUP_DATE_}/${line} || mkdir -p ${_PATH_BACKUP_DATE_}/${line} && _RESULT_ "创建备份目录" "${line}" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}
	test -d ${_PATH_BACKUP_DATE_}/${line}/mysqldata/cq_locallog || \
	install -o mysql -g mysql -d ${_PATH_BACKUP_DATE_}/${line}/mysqldata && \
	install -o mysql -g mysql -d ${_PATH_BACKUP_DATE_}/${line}/mysqldata/cq_locallog && _RESULT_ "创建备份目录" "mysqldata" "cq_locallog" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}

	# 关停网关进程和删除网关配置文件
	_GATEPORT_="$(_CUT_STRINGS_ "c_gateway_port" "${_PATH_OF_SERVER_}/${logicserver}/script/agent_vars.sh")"
	if [[ -f ${_PATH_OF_GATEWAY_}/gateservice_${_GATEPORT_}.txt ]];then
		_LOGINFO_ "删除网关配置文件" "gateservice_${_GATEPORT_}.txt" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}
		rm -fv ${_PATH_OF_GATEWAY_}/gateservice_${_GATEPORT_}.txt >&3
		_RESULT_ "删除网关配置文件" "gateservice_${_GATEPORT_}.txt" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}
	fi
	
	if [[ -n `fuser -n tcp ${_GATEPORT_} 2>/dev/null` ]];then
		_LOGINFO_ "关停网关" "TCP:${_GATEPORT_}" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}
                fuser -ksn tcp ${_GATEPORT_} >&3
		_RESULT_ "关停网关" "TCP:${_GATEPORT_}" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}
        fi

	# 迁移程序与数据库
	_LOGINFO_ "迁移引擎服" "${logicserver}" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}
	mv -vf ${_PATH_OF_SERVER_}/${logicserver} ${_PATH_BACKUP_DATE_}/${line}/ >&3
	_RESULT_ "FAIL-WOULD-KILL" "迁移引擎服" "${logicserver}" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}

	_LOGINFO_ "迁移数据服" "${dbserver}" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}
	mv -vf ${_PATH_OF_SERVER_}/${dbserver} ${_PATH_BACKUP_DATE_}/${line}/ >&3
	_RESULT_ "FAIL-WOULD-KILL" "迁移数据服" "${dbserver}" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}

	_LOGINFO_ "拷贝数据库" "cq_actor${firstname}" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}
	\cp -rfpv ${_PATH_OF_CQACTOR_}/cq_actor${firstname} ${_PATH_BACKUP_DATE_}/${line}/mysqldata/ >&3
	_RESULT_ "FAIL-WOULD-KILL" "迁移数据库" "cq_actor${firstname}" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}


	# 迁移日志
	_LOGINFO_ "拷贝日志" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}
	if [[ ${lastname} -ge ${firstname} ]];then
		for m in $(seq ${firstname} ${lastname});do

			pushd ${_PATH_OF_CQLOG_} >&3 && {
				
				for datetime in ${_DATE_[@]};do

                                        find ./ \
                                        \( -regextype posix-extended -type f -regex "\.\/log_(common|suggest)_[0-9]+_${m}_${datetime}\.(frm|MYD|MYI)" \) | \
                                        xargs -I {} \cp -fvp {} ${_PATH_BACKUP_DATE_}/${line}/mysqldata/cq_locallog/ >&3

                                done

			} && popd >&3

		#find ${_PATH_OF_CQLOG_}/ -type f -mtime -40 -name "log_common_*_${m}_*" -o -name "log_suggest_*_${m}_*" | xargs -I {} \cp -fpv {} ${_PATH_BACKUP_DATE_}/${line}/mysqldata/cq_locallog/ >&3

		done
	else
		exit 1
	fi
	_RESULT_ "FAIL-WOULD-KILL" "拷贝日志" | tee -a ${_PATH_BACKUP_DATE_}/move.out.${_NOW_OF_TIME_}

	echo "------------------------（华丽分割线）--------------------------"

done < <(for i in $@;do eval echo "$(basename ${i})";done)

#### 退出重定向 ####
exec 3>&-

_LOGINFO_ "本地迁移" "（END）"

exit 0
