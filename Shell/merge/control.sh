#!/bin/bash
#
# -----------------------------
#  author: handonglin
# porpose: 自动计算和迁移区服
#    date: 2014-06-25
# version: v1.0
# -----------------------------
#

set -o nounset

# 导入相关函数
set -e
. `dirname $0`/lib/SHOWINFO.SHL
. `dirname $0`/lib/GLOBAL.SHL
set +e

_DESIGNATED_IP_=""	# 赋空值

# 过滤捡取输入参数
while getopts ":p:l:d" opt;do
        case "${opt}"  in
                p)      _AGENT_GAME_="`echo "${OPTARG}" | tr [a-z] [A-Z]`"

			if [[ -d "${_PATH_CRTLIST_}/${_AGENT_GAME_}" ]];then

				pushd ${_PATH_CRTLIST_}/${_AGENT_GAME_}/ >/dev/null

					if ls LHZS_${_AGENT_GAME_}_ENGINE_*.ini >/dev/null 2>&1;then
						declare -a _ALL_AGENT_IP_=($(ls LHZS_${_AGENT_GAME_}_ENGINE_*.ini 2>&- | egrep -o "[1-9][0-9]{1,2}\.[1-9][0-9]{1,2}\.[1-9][0-9]{1,2}\.[1-9][0-9]{1,2}\.ini" | sed 's/\.ini//g'))
					else
						_LOGFAIL_ "FAIL-WOULD-KILL" "${_AGENT_GAME_}" "没有session文件..."
					fi

				popd >/dev/null

			else
				_LOGFAIL_ "FAIL-WOULD-KILL" "${_AGENT_GAME_}" "代理不存在..."
			fi

                       	;;

                d)      _DISPLAY_="TRUE"
                        ;;

		l)	_DESIGNATED_IP_="${OPTARG}"
			_DESIGNATEDIP_STATUS_="TRUE"
			
			if ! echo "${_DESIGNATED_IP_}" | egrep -q "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}";then
				_LOGFAIL_ "FAIL-WOULD-KILL" "指定迁移IP地址格式非法..."
			fi
				
			;;
		
                :)      _PRINT_TITLE_
			_LOGFAIL_ "FAIL-WOULD-KILL" "参数<-p>或<-l>后面需赋值..."
                        ;;

                \?)     _PRINT_TITLE_
			_PRINT_HELP_INFO_
                        exit 1
                        ;;
        esac
done
        shift $((${OPTIND} - 1))

##########################################################################
#【开关说明】
#	* 设置限制条件,参数<-d>优先级别最高；
#	* 出现参数<-d>，无论后面接任何参数都均以<-d>执行；
# 	* 参数<-d>和其它参数互斥；
#########################################################################
if [[ "${_DISPLAY_:-NULL}" == "TRUE" ]];then

	_PRINT_DISPLAY_TITLE_	# 打印脚本说明

	_LOG_ "平台：${_AGENT_GAME_}，共 ${#_ALL_AGENT_IP_[@]} 台主机"
	_LOG_ "-----------------------------"

	for ((i=0;i<${#_ALL_AGENT_IP_[@]};i++));do
		echo "[${i}] ${_ALL_AGENT_IP_[i]}"
		ssh -T -x -p23004 "${_ALL_AGENT_IP_[i]}" "cd ${_PATH_MERGE_SCRIPTS_}/template/;bash ${_PATH_MERGE_SCRIPTS_}/template/scanserver.sh" | column -t
		_LOG_ "-----------------------------"
	done

	if [ "${_DESIGNATEDIP_STATUS_:-NULL}" == "TRUE" -o "$#" -gt "0" ];then
		
		_LOG_ "###########################################################"
		_LOG_ "#【说明】"
		_LOG_ "#       * 设置限制条件,参数<-d>优先级别最高；"
		_LOG_ "#       * 出现参数<-d>，无论后面接任何参数都均以<-d>执行；"
		_LOG_ "#       * 参数<-d>和其它参数互斥；"
		_LOG_ "############################################################"

	fi

	exit 0	# 退出脚本
fi

if [[ "$#" -lt "2" ]];then
	_LOGFAIL_ "FAIL-WOULD-KILL" "输入区服少于2个..."
fi

############################（限制条件结束）#############################

_PRINT_TITLE_	# 打印脚本说明

# 定义输入变量组成数组
declare -a arr=()
i=0
while (($#>=1)); do

	#### 判断区服是否为合法输入 ####
	if echo ${1} | egrep -q "^[1-9][0-9]*$";then
		:
	elif echo ${1} | egrep -q "^[1-9][0-9]*_[1-9][0-9]*$";then
		:
	else
		_LOGFAIL_ "FAIL-WOULD-KILL" "${1}" "非法输入..."
	fi
	
	arr[i++]=${1}
        shift
done

# 输入变量排序由大到小重新组合
declare -a arr2=(`for val in "${arr[@]}";do echo "$val";done | sort -n`)

# 显示提示信息
_LOGINFO_ "区服由小到大排序：" "{ ${arr2[@]} }"
_LOGINFO_ "最小主区为：" "{ ${arr2[0]} }"

# 交互信息确认
while true;do
_LOG_ "---------------------------------------------------"
read -t 30 -p "非常重要！！！以上信息是否正确...?请输入[y/N] " ENTERNUMBER_2
        case ${ENTERNUMBER_2} in
                "")     echo
			_LOGFAIL_ "FAIL-WOULD-KILL" "等待超时,脚本退出..."
                        ;;
                y|Y)    _LOGOK_ "开始计算，请耐心等待..."
                        break
                        ;;
                n|N)    _LOGOK_ "脚本已手动退出..."
			kill -9 $$
                        ;;
                *)      _LOGFAIL_ "非法输入...，请重新输入...！！"
                        continue
                        ;;
        esac
done

# 提示IP地址
_LOGINFO_ "平台：${_AGENT_GAME_}" "主机数：${#_ALL_AGENT_IP_[@]}台"
_LOGINFO_ "主机IP：" "${_ALL_AGENT_IP_[@]}"
_LOG_ "--------------------------------------------------------------"

_JUDGE_SERVER_()
{

	if [[ "${2}" =~ "_" ]];then
		echo "${1}${2}"
	else
		echo "${1}_${2}"
	fi

}

set +o nounset

declare -a MOVEPART=()
declare -a MOVEPARTIP=()

# 判断所输入区服是否存在
for((i=0;i<${#arr2[@]};i++));do

	if [[ "${arr2[i]}" == ${arr2[0]} ]];then

		exitID=1

		for j in ${_ALL_AGENT_IP_[*]};do

			ssh -T -p23004 ${j} "[ -d ${_PATH_OF_SERVER_}/$(_JUDGE_SERVER_ logicserver ${arr2[0]}) -a -d ${_PATH_OF_SERVER_}/$(_JUDGE_SERVER_ dbserver ${arr2[0]}) ] && exit 0 || exit 1"

			if [[ $? -eq 0 ]];then

				exitID=0	# 设置开关

				if [[ ${_DESIGNATED_IP_:-NULL} == "NULL" ]];then
					_MASTER_PART_IP_="${j}"

					# 参照系设定
					_LOGINFO_ "【参照系】" "主区服：${arr2[0]}"
					_LOGINFO_ "【参照系】" "主区地址：${_MASTER_PART_IP_}"
					_LOG_ "--------------------------------------------------------------"
					
					break
				else
					_MASTER_PART_IP_=${_DESIGNATED_IP_}
					_M_PART_IP_="${j}"

					if [[ "${_MASTER_PART_IP_}" != "${_M_PART_IP_}" ]];then
						MOVEPART+=(${arr2[0]})
						MOVEPARTIP+=(${_M_PART_IP_})
					fi

					# 参照系设定
					_LOGINFO_ "【参照系】" "指定地址：${_MASTER_PART_IP_:-NULL}"
					_LOG_ "--------------------------------------------------------------"

				fi
	
			fi
		done
		
		##########################################	
		# 上一轮循环完成，至少要完成主区IP的赋值，
		# 或者被合区IP赋值；
		##########################################
		[[ "${exitID}" == 1 ]] && _LOGFAIL_ "FAIL-WOULD-KILL" "找不到区${arr2[0]}" "请手动确认..."

	else

		exitID=1	# 设置开关

	        for j in ${_ALL_AGENT_IP_[*]};do

                	ssh -T -p23004 ${j} "[ -d ${_PATH_OF_SERVER_}/$(_JUDGE_SERVER_ logicserver ${arr2[i]}) -a -d ${_PATH_OF_SERVER_}/$(_JUDGE_SERVER_ dbserver ${arr2[i]}) ] && exit 0 || exit 1"

                	if [[ $? -eq 0 ]];then

				exitID=0	# 设置开关

				_M_PART_IP_="${j}"

				if [[ "${_MASTER_PART_IP_}" != "${_M_PART_IP_}" ]];then
					MOVEPART+=(${arr2[i]})
					MOVEPARTIP+=(${_M_PART_IP_})
				fi
				
			fi

        	done

                ##########################################      
                # 上一轮循环完成，至少要完成主区IP的赋值，
                # 或者被合区IP赋值；
                ##########################################
		[[ "${exitID}" == 1 ]] && _LOGFAIL_ "FAIL-WOULD-KILL" "找不到区${arr2[i]}" "请手动确认..."

	fi
done

set -o nounset

# 添加约束条件
[[ ${#MOVEPART[@]} -eq ${#MOVEPARTIP[@]} ]] || _LOGFAIL_ "FAIL-WOULD-KILL" "被合区数≠被合区IP数" "请检查脚本..."

# 开始迁移合区
if [[ "${#MOVEPART[@]}" != 0 ]];then

	# 被合区显示
	_LOGINFO_ "需迁区服${#MOVEPART[@]}个：" "${MOVEPART[@]}"
	_LOGINFO_ "需迁区服地址${#MOVEPARTIP[@]}个：" "${MOVEPARTIP[@]}"
	_LOG_ "--------------------------------------------------------------"
	
	_SERVER_CORRESPONDING_()
	{
	       for((i=0;i<${#MOVEPART[@]};++i))
	       do
	
	               if [ "${1}" == ${MOVEPART[i]} ];then
	                       echo "${MOVEPARTIP[i]}"  
	               fi
	
	       done
	}
	
	test -d ${_PATH_OF_TMP_} || mkdir -p ${_PATH_OF_TMP_}
	
	for m in ${MOVEPART[@]};do

		_CORRESPONDING_IP_="$(_SERVER_CORRESPONDING_ ${m})"
		
		_LOGINFO_ "本地备份${m}区服" "IP地址：$(_SERVER_CORRESPONDING_ ${m})"
		ssh -T -x -p23004 "${_CORRESPONDING_IP_}" "cd ${_PATH_MERGE_SCRIPTS_}/template/;echo "y" | bash ${_PATH_MERGE_SCRIPTS_}/template/localbak.sh ${m}"
		_RESULT_ "FAIL-WOULD-KILL" "本地备份${m}区服" "IP地址：${_CORRESPONDING_IP_}"

		sleep 3

		pushd ${_PATH_OF_TMP_}/ > /dev/null
	
		_LOGINFO_ "远程主机拉取到中心机"  "存放路径" "${_PATH_OF_TMP_}/${_AGENT_GAME_}-${m}.tar.gz"
		ssh -T -p23004 "${_CORRESPONDING_IP_}" "cd ${_PATH_BACKUP_DATE_}/${m}/;tar mzcf - ./* --exclude=log/* --exclude=*.dmp --exclude=core-* --exclude=nohup.out" | cat > ${_AGENT_GAME_}-${m}.tar.gz
		_RESULT_ "FAIL-WOULD-KILL" "远程主机拉取到中心机" "存放路径" "${_PATH_OF_TMP_}/${_AGENT_GAME_}-${m}.tar.gz"

		sleep 3
		
		_LOGINFO_ "推送至主区" "主区IP：${_MASTER_PART_IP_}"
		ssh -T -p23004 "${_MASTER_PART_IP_}" "cd ${_PATH_OF_SERVER_}/;tar mzxf -" < ${_AGENT_GAME_}-${m}.tar.gz
		_RESULT_ "FAIL-WOULD-KILL" "推送到主区所在服务器" "主区IP：${_MASTER_PART_IP_}"

		sleep 3
		
		_LOGINFO_ "中心机删除临时文件" "${_AGENT_GAME_}-${m}.tar.gz"
		rm -f ${_PATH_OF_TMP_}/${_AGENT_GAME_}-${m}.tar.gz
		_RESULT_ "中心机删除临时文件" "${_AGENT_GAME_}-${m}.tar.gz"
	
		popd > /dev/null
		
		_LOG_ "--------------------------------------------------------------"
		
	done

else
	_LOGINFO_ "区服均在同一主机上..." "主区地址：${_MASTER_PART_IP_}"

fi

#### 开始合服操作 ####
_LOGINFO_ "请注意，开始远程启动合服程序..."
ssh -T -x -p23004 "${_MASTER_PART_IP_}" "cd ${_PATH_MERGE_SCRIPTS_}/template/;echo "y" | bash ${_PATH_MERGE_SCRIPTS_}/template/combine.sh ${arr2[@]}"

exit 0
