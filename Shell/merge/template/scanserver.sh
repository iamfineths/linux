#!/bin/bash
#
###############################################
# FILE:         GLOBAL.SHL
# PORPOSE:      定义全局变量
# AUTHOR:       handonglin
# DATE:         2014-08-27
###############################################
#
set -e
. ../lib/CUTSTRING.AWK
. ../lib/GLOBAL.SHL
. ../lib/SHOWINFO.SHL
set +e

######## 定义数组 ########
declare -a  _DBSERVER_=($(ls -l ${_PATH_OF_SERVER_}/ 2>&- | grep "^d" | grep "db[a-z]*server*" | awk '{print $NF}'))
declare -a  _LOGICSERVER_=($(ls -l ${_PATH_OF_SERVER_}/ 2>&- | grep "^d" | grep "logicserver*" | awk '{print $NF}'))

_ENVIRONMENT_CHECK_()
{


	# 判断数据服务器和引擎服务器数量是否一致
	if [[ "${#_DBSERVER_[@]}" != "${#_LOGICSERVER_[@]}" ]];then
	        echo "NUMBER OF DBSERVER AND LOGICSERVER IS NOT EQUEL..."
	        exit 1
	fi
	
	# 限制该脚本只适合引擎(+混服)和跨服使用
	local _VAR_PATERN_=$(hostname | cut -d "_" -f 3)
	case "${_VAR_PATERN_}" in
		"KUAFU")
				:
				;;

		"ENGINE")	
				:
				;;

		*)
			echo -e "[\e[31;1m ERROR \e[0m]\t该脚本只适合检查ENGINE和KUAFU服务...!!!"
			exit 1

			;;
	esac

}

_PROGRAM_DEFINE_()
{
	for((i=0;i<${#_DBSERVER_[@]};++i))
	do
		if [[ "$1" == "${_DBSERVER_[i]}" ]];then
			echo "${_LOGICSERVER_[i]}"  
		fi
	done
}

_SERVER_PID_CHECK_()
{

	case "${1}" in
		*server*)
				if [ -z "`pgrep -f "${1}/" 2>&1`" ];then
					echo -e "${1} [\e[31;1m FAIL \e[0m]"
				else
					echo -e "${1} [\e[32;1m OK \e[0m]"
				fi
			;;
		*)
				if [ -z "`pgrep -f "${1}" 2>&1`" ];then
					echo -e "${1} [\e[31;1m FAIL \e[0m]"
				else
					echo -e "${1} [\e[32;1m OK \e[0m]"
				fi
			;;
	esac

}

_ENVIRONMENT_CHECK_
for dbserver in ${_DBSERVER_[*]};do

	if echo "${dbserver}" | egrep -q "^dbserver_[1-9][0-9]*$";then
	        _DEPART_="${dbserver##dbserver_}"
	elif echo "${dbserver}" | egrep -q "^dbserver[1-9][0-9]*_[1-9][0-9]*$";then
	        _DEPART_="${dbserver##dbserver}"
	fi

	_GATEPORT_="$(_CUT_STRINGS_ "c_gateway_port" "${_PATH_OF_SERVER_}/$(_PROGRAM_DEFINE_ ${dbserver})/script/agent_vars.sh")"
	echo "{${_DEPART_}}区 $(_SERVER_PID_CHECK_ ${dbserver}) $(_SERVER_PID_CHECK_ $(_PROGRAM_DEFINE_ ${dbserver})) $(_SERVER_PID_CHECK_ gateservice_${_GATEPORT_}.txt)"

done

echo "共有${#_DBSERVER_[@]}个服"

exit 0
