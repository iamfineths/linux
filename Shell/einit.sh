#!/bin/bash
#
# -----------------------------
# 版本: Version 1.0
# 日期: 2014-09-03
# 作者: ithandonglin@gmail.com
# 描述: 中心机引导安装游戏服区
# -----------------------------
#
set -o nounset

set -e
. lib/GLOBAL.SHL
. lib/SHOWINFO.SHL
. lib/FINDAGENT.AWK
. lib/CHECK-AGENT.SHL
. lib/WRITE-CONFIG.SHL
. lib/CORRESPONDING.SHL
set +e

# 计算时间戳
DateToday=`date +%w`
DaysNextTuesday=`expr 7 + \( 2 - ${DateToday} \)`
TimesNextTuesday="$(date --date=''${DaysNextTuesday}' days' "+%Y-%m-%d 23:59:59")"

# 设置约束条件
if [ "$#" != "0" ];then

	while getopts ":p:ahv" opt;do
		case "${opt}"  in
		    p)		_AGENT_GAME_="`echo "${OPTARG}" | tr [a-z] [A-Z]`"

					# 需过滤主机
					Filter="LHZS_37W_ENGINE_119.146.202.186|LHZS_937_ENGINE_119.146.207.160|LHZS_VSK_ENGINE_119.146.201.98"

					declare -a _ALL_AGENT_IP_=($(find ${_PATH_CRTLIST_}/${_AGENT_GAME_}/ 2>&- \
					\( -regextype posix-extended -type f -regex \
					"${_PATH_CRTLIST_}\/${_AGENT_GAME_}\/LHZS_${_AGENT_GAME_}_ENGINE_[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\.ini" \) \
					| egrep -v "${Filter}" | grep -Po "\d+\.\d+\.\d+\.\d+" ))
					
					[[ ${#_ALL_AGENT_IP_[@]} == 0 ]] && _LOGFAIL_ "FAIL-WOULD-KILL" "找不到session文件"
					
					;;

			a)		TimesNextTuesday=""
					;;
		
			h|help)	_PRINT_HELP_INFO_
					exit 0
					;;

			v|version)
					_PRINT_DISPLAY_TITLE_
					exit 0
					;;
	
		    :)
		            _LOGFAIL_ "FAIL-WOULD-KILL" "参数<-p>后面请赋值！"
					kill -9 $$
		            ;;
	
		    \?)
		            _PRINT_HELP_INFO_
		            exit 1
		            ;;
		esac
	done
	shift $((${OPTIND} - 1))


	# 计算结果显示
	_LOGINFO_ "平台：${_AGENT_GAME_}，共 ${#_ALL_AGENT_IP_[@]} 台主机"
	_LOG_ "---------------------------------------------------"

else

	_LOGFAIL_ "FAIL-WOULD-KILL" "请输入安装区服..."

fi

#####################################################################################
################################ （控制脚本获取相关数据） ###########################
#####################################################################################
RET=""
declare -a HOST=()
declare -a ALL_SVR=()
declare -a FREESVR=()
for ((i=0;i<${#_ALL_AGENT_IP_[@]};i++));do
		
	# 读取数值;
	INFO=""[`expr ${i} + 1`]" "${_ALL_AGENT_IP_[i]}" "$(ssh -T -x -p23004 "${_ALL_AGENT_IP_[i]}" "cd ${_PATH_SETUP_SCRIPTS_}/template/;bash ${_PATH_SETUP_SCRIPTS_}/template/status.sh")""

	read SerialNum IpAddr FreeSvr UsedSvr IdleMem Server <<< ${INFO}

	# 当轮循第一台主机前先插入描述
	[[ ${i} == 0 ]] && RET+="Num|Addr|Free|Used|Mem|Svr\n"

	RET+="${SerialNum}|${IpAddr}|${FreeSvr}|${UsedSvr}|${IdleMem}M|${Server}\n"
	#RET+="\t${Server}\n"

	# 轮循将所有主机中获取的区服加入数组
	ALL_SVR+=(${Server})

	# 当轮循到最后主机时，重新计算排序获取最大区服
	[[ "${i}" == `expr "${#_ALL_AGENT_IP_[@]}" - 1` ]] && { 

		ALL_SVR=($(for s in ${ALL_SVR[@]};do echo ${s};done | sort -rn))
		MaxSvr="${ALL_SVR[0]}"

	}

	[[ ${FreeSvr} -gt 0 ]] && {

		HOST+=(${IpAddr})
		FREESVR+=(${FreeSvr})

	}

done
#####################################################################################
# 显示获取的数据
echo -e "${RET}" | column -s "|" -t
###########################

[[ "${#HOST[@]}" == 0 ]] && {

	_LOG_ "---------------------------------------------------"
	_LOGFAIL_ "FAIL-WOULD-KILL" "\e[33m\e[05m资源耗尽！\e[0m"

}

# 声明数组,导入将安装区服;
[[ $# -ne 0 ]] && {

	set -- $@
	declare -a INSTALLPART="($(for part in $@;do eval echo ${part};done))"
	set --
	_LOGINFO_ "你已指定区服 ${INSTALLPART[@]} 安装"

} || {
	_LOG_ "---------------------------------------------------"
	_LOGINFO_ "你选择全平台自动安装模式！"
	declare -a INSTALLPART=($(for part in $(python ${_PATH_OF_INIT}/getsvr.py ${_AGENT_GAME_} "${TimesNextTuesday:-Null}");do eval echo ${part};done | sort -n))

	((${#INSTALLPART[@]}>0)) && _LOGINFO_ "从接口获取未安装新区 ${#INSTALLPART[@]} 个，分别：${INSTALLPART[@]}" || { _LOGOK_ "接口搜索 ${_AGENT_GAME_} 平台未发现需要初始化的新区！";exit 0; }
}

############################（计算结束）#############################
while true;do
_LOG_ "---------------------------------------------------"
read -t 30 -p "是否继续运行脚本...?请输入[y/N] " ENTER
	case ${ENTER} in
		"") 	echo
	    		_LOGFAIL_ "FAIL-WOULD-KILL" "等待超时,脚本退出..."
	    		;;

		y|Y) 	_LOGOK_ "开始计算，请耐心等待..."
				break
				;;

		n|N)	_LOGOK_ "脚本已手动退出..."
				kill -9 $$
				;;

		*)		_LOGFAIL_ "非法输入...，请重新输入...！！"
				continue
				;;
	esac
done

for _host in ${HOST[@]};do

	j=${FREESVR[0]}

	for installpart in ${INSTALLPART[@]};do

		[[ ${installpart} -le ${MaxSvr} ]] && _LOGFAIL_ "FAIL-WOULD-KILL" "区服：${installpart}" "抱歉，安装已经安装过了..."
	
		_LOGINFO_ "调用IP_${_host} 主机资源"
		ssh -T -x -p23004 "${_host}" "cd ${_PATH_OF_INIT};python install.py -p ${_AGENT_GAME_} -s ${installpart} --nocheck-ram"
		[[ $? == 0 ]] && { ((j=j-1));:; } || _LOGFAIL_ "FAIL-WOULD-KILL" "区服：${installpart}" "安装不成功..."
		_LOGOK_ "区服：${installpart}" "安装成功！"

		declare -a INSTALLPART=(${INSTALLPART[@]:1})
		
		if [[ ${j} == "0" ]];then

			[[ ${#INSTALLPART[@]} == "0" ]] && STATUS=0 || { STATUS=1;break; }

		else

			[[ ${#INSTALLPART[@]} == "0" ]] && STATUS=0

		fi

	done

	############################################################################################################################################

	if [[ "${STATUS}" == "1" ]];then

		declare -a HOST=(${HOST[@]:1})
		declare -a FREESVR=(${FREESVR[@]:1})

		if [[ ${#HOST[@]} == "0" ]];then

			[[ "${#INSTALLPART[@]}" != "0" ]] && _LOGFAIL_ "FAIL-WOULD-KILL" "服务器资源紧张" "未安装区服：${INSTALLPART[@]}"

		else

			continue

		fi

	else

		{ _LOGOK_ "已按要求完成安装！";break; }

	fi
			
done

exit 0