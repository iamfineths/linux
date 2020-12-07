#!/bin/bash
#
# -----------------------------
#  author: Jerry.han
# porpose: 区服合并脚本
#    date: 2014-07-18
# version: v1.0
# -----------------------------
#

#### 变量空值退出 ####
set -u

#### 导入脚本库 ####
#. lib/show-info.shl

#### 定义打印颜色 ####
_RED_(){ echo -e "[\e[31;1m ${1} \e[0m]"; }
_GREEN_(){ echo -e "[\e[32;1m ${1} \e[0m]"; }
_CYAN_(){ echo -e "[\e[36;1m ${1} \e[0m]"; }
_LOG_(){ echo -e "\e[1m$@\e[m"; }
_LOGFAIL_(){ _LOG_ "[ $(date "+%Y-%m-%d %H:%M:%S") ]" $@ $(_RED_ "FAIL"); }
_LOGOK_(){ _LOG_ "[ $(date "+%Y-%m-%d %H:%M:%S") ]" $@ $(_GREEN_ "SUCESSE"); }
_LOGINFO_(){ _LOG_ "[ $(date "+%Y-%m-%d %H:%M:%S") ]" $@ $(_CYAN_ "INFO"); }

#### 打印程序执行结果 ####
_RESULT_()
{
	if [[ $? -eq 0 ]];then
		_LOGOK_ "RESULT" $@
	else
		if [[ ${1} == "FAIL-WOULD-KILL" ]];then
			_LOGFAIL_ "RESULT" $@
			kill -9 $$
		else
			_LOGFAIL_ "RESULT" $@
		fi
	fi
}

#### 定义全局变量 ####
readonly _PATH_OF_SERVER_="/data/app/lhzs/server"
readonly _TIME_OF_YEARS_=$(date "+%Y")
readonly _TIME_OF_DAYS_=$(date "+%Y-%m-%d")
readonly _NOW_TIME_=$(date "+%Y%m%d%H%M%S")
readonly _PATH_OF_COMBIN_="/data/app/lhzs/public/esql"
readonly _PATH_OF_BACKUP_="/data/app/lhzs/public/backup/${_TIME_OF_YEARS_}/${_TIME_OF_DAYS_}"

#### 定义数组 ####
declare -a ARR=()
declare -a ARRMAINPART=()
declare -a ARRBYPART=()

#### 开始计算输入 ####
if [[ $# -le 0 ]];then
	_LOGFAIL_ "区服输入空值" "请检查！！！"
	kill -9 $$
fi

i=0
while (($#>=1)); do

	#### 判断是否为合法输入 ####
      	if echo ${1} | egrep -q "^[1-9][0-9]*$";then
      	        logicserver="logicserver_${1}"
      	        dbserver="dbserver_${1}"
      	        mainpart=`echo ${1}`
      	        bypart=`echo ${1}`

       		#### 检查逻辑区服本地是否存在 ####
       		test -d ${_PATH_OF_SERVER_}/${logicserver} || { _LOGFAIL_ "${logicserver}" "区服不存在，请检查..." >&2;exit 1; }
       		test -d ${_PATH_OF_SERVER_}/${dbserver} || { _LOGFAIL_ "${dbserver}" "区服不存在，请检查..." >&2;exit 1; }

		#### 检查进程是否存在 ####
		pgrep -f "${logicserver}/" >/dev/null 2>&1 && { _LOGFAIL_ "${logicserver}" "进程存在" "请手动检查!" >&2;exit 1; }
		pgrep -f "${dbserver}/" >/dev/null 2>&1 && { _LOGFAIL_ "${dbserver}" "进程存在" "请手动检查!" >&2;exit 1; }

      	elif echo ${1} | egrep -q "^[1-9][0-9]*_[1-9][0-9]*$";then
      	        logicserver="logicserver${1}"
      	        dbserver="dbserver${1}"
      	        mainpart=`echo ${1} | cut -d "_" -f 1`
      	        bypart=`echo ${1} | cut -d "_" -f 2`

		#### 检查主区与副区是否数值相等
      	        [[ "${mainpart}" == ${bypart} ]] && { _LOGFAIL_ "区服输入有误，主区和副区不能相等..." >&2;exit 1; }

       		#### 检查数据区服本地是否存在 ####
		test -d ${_PATH_OF_SERVER_}/${logicserver} || { _LOGFAIL_ "${logicserver}" "区服不存在，请检查..." >&2;exit 1; }
       		test -d ${_PATH_OF_SERVER_}/${dbserver} || { _LOGFAIL_ "${dbserver}" "区服不存在，请检查..." >&2;exit 1; }

		#### 检查进程是否存在 ####
                pgrep -f "${logicserver}/" >/dev/null 2>&1 && { _LOGFAIL_ "${logicserver}" "进程存在" "请手动检查!" >&2;exit 1; }
                pgrep -f "${dbserver}/" >/dev/null 2>&1 && { _LOGFAIL_ "${dbserver}" "进程存在" "请手动检查!" >&2;exit 1; }

      	else
      	        _LOGFAIL_ "${1}" "非法输入..." >&2
      	        exit 1
      	fi

	#### 输入的变量添加到数组 ####
        ARR+=(${1})
        ARRMAINPART+=(${mainpart})
        ARRBYPART+=(${bypart})
        let i++

        shift
done

#### 重新由大到小重新排序 ####
declare -a ARR2=(`for val in "${ARR[@]}";do echo "$val";done | sort -n`)
declare -a ARRMAINPART2=(`for val in "${ARRMAINPART[@]}";do echo "$val";done | sort -n`)
declare -a ARRBYPART2=(`for val in "${ARRBYPART[@]}";do echo "$val";done | sort -n`)
unset val

#### 确认信息(重要) ####
while true;do
echo "-----------------------------------------"
_LOGINFO_ "区服由小到大排序：" "${ARR2[@]}"
_LOGINFO_ "最小区为主区：" "${ARR2[0]}"
echo "-----------------------------------------"
read -t 30 -p "非常重要！！！以上信息是否正确...?请输入[y|n]" ENTERNUMBER
        case ${ENTERNUMBER} in
                "")	echo
                        _LOGFAIL_ "抱歉，等待超时" "如有需要请重新运行脚本...谢谢！！！"
			kill $$
                        ;;
                y|Y)    _LOGOK_ "脚本开始运行，请耐心等待..."
                        break
                        ;;
                n|N)    _LOGOK_ "脚本自行退出" "谢谢使用..."
			kill $$
                        ;;
                *)      _LOGFAIL_ "非法输入" "请重新输入...谢谢！！！"
                        continue
                        ;;
        esac
done

#### 判断区服和赋值 ####
_JUDGE_SERVER_()
{
	if [[ "${1}" =~ "_" ]];then
		echo "${2}${1}"
	else
		echo "${2}_${1}"
	fi
}

#### 建立区服与主区之间的对应关系 ####
_SERVER_CORRESPONDING_()
{
       for((i=0;i<${#ARR2[@]};++i))
       do

               if [ "${1}" == "${ARR2[i]}" ];then
                       echo "${ARRMAINPART2[i]}"  
               fi

       done
}

####################################################
# 合区前需进行以下检查筛选:
#	* 检查是否安装文本格式转换工具（dos2unix）;
#	* 检查数据库工具（esql）密码是否打开;
####################################################
if ! which dos2unix >/dev/null 2>&1;then
	_LOGINFO_ "dos2unix" "不存在" "马上安装" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	yum -y install dos2unix >/dev/null 2>&1
	_RESULT_ "dos2unix" "安装情况" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
fi

if ! awk -F "=" '/^DBPass/{print $2}' ${_PATH_OF_COMBIN_}/Config.ini | egrep -q "^12[0-9,A-Z]*$";then
	_LOGFAIL_ "ESQL" "Config.ini" "未配置正确" "脚本强行退出" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	kill -9 $$
fi
#########################################################################################################################

#### 合区完成后命名 ####
_MERGED_SERVER_="${ARRMAINPART2[0]}_${ARRBYPART2[${#ARRBYPART2[@]}-1]}"

#### 进入目录进行系列操作 ####
pushd ${_PATH_OF_SERVER_} >/dev/null

#### 创建备份目录 ####
_LOGINFO_ "判断是否需要创建备份文件夹"
test -d ${_PATH_OF_BACKUP_} || mkdir -p ${_PATH_OF_BACKUP_} && _RESULT_ "备份文件夹路径" "${_PATH_OF_BACKUP_}"

#### 创建输出文件 ####
_LOGINFO_ "新建输出文件" "文件名" "merge.out.${_NOW_TIME_}"
:>${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
_RESULT_ "新建输出文件" "路径" "${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}"

#### 定义输出重定向 ####
exec 3>&1 3>>${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

	#### 备份各区服和数据库 ####
	_LOGINFO_ "注意！！！" "开始备份..." | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	for i in ${ARR2[@]};do

		#### 重命名和移动被合区服 ####
		if [[ "${i}" == ${ARR2[0]} ]];then
			#### 转移库目录和runtime目录 ####
			cp -rfpv "$(_JUDGE_SERVER_ ${i} logicserver)"/data/runtime ${_PATH_OF_BACKUP_}/runtime$(_SERVER_CORRESPONDING_ ${i}) >&3
			cp -rfpv mysqldata/cq_actor$(_SERVER_CORRESPONDING_ ${i}) ${_PATH_OF_BACKUP_}/ >&3
	
			mv -vf $(_JUDGE_SERVER_ ${i} dbserver) dbserver${_MERGED_SERVER_} >&3
			mv -vf $(_JUDGE_SERVER_ ${i} logicserver) logicserver${_MERGED_SERVER_} >&3

			#### 转换文本格式(重要) ####
			_LOGINFO_ "转换配置文件格式" "dbserver${_MERGED_SERVER_}/dbserver.txt" "logicserver${_MERGED_SERVER_}/logicserver.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
			dos2unix -k dbserver${_MERGED_SERVER_}/dbserver.txt >&3 2>&3 && \
			dos2unix -k logicserver${_MERGED_SERVER_}/logicserver.txt >&3 2>&3
			_RESULT_ "转换配置文件格式" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
		else
			#### 转移库目录和runtime目录 ####
			cp -rfpv $(_JUDGE_SERVER_ ${i} logicserver)/data/runtime logicserver${_MERGED_SERVER_}/data/runtime$(_SERVER_CORRESPONDING_ ${i}) >&3
			cp -rfpv mysqldata/cq_actor$(_SERVER_CORRESPONDING_ ${i}) ${_PATH_OF_BACKUP_}/ >&3
	
			#### 转移服目录 ####
			mv -vf $(_JUDGE_SERVER_ ${i} dbserver) ${_PATH_OF_BACKUP_}/ >&3
			mv -vf $(_JUDGE_SERVER_ ${i} logicserver) ${_PATH_OF_BACKUP_}/ >&3
		fi	
		
	done
	_RESULT_ "数据备份" "备份路径" "${_PATH_OF_BACKUP_}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

	#### 由小到大计算可使用端口 ####
	_LOGINFO_ "计算可使用端口" "计算区间" "00-99" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	_LOGICSERVER_=($(ls -l 2>&- | grep "^d" | grep "logicserver*" | awk '{print $NF}'))
	for server in ${_LOGICSERVER_[@]};do
        	_PORTNUM_=$(awk 'BEGIN{FS="="}{if(/c_logic_port/){FIRST=$2}}END{print substr(FIRST,5,length(FIRST)-5)}' ${server}/script/agent_vars.sh)
        	PORTARRY+=(${_PORTNUM_})
        	unset _PORTNUM_
	done
	unset server
	
	for sequence in $(seq -f '%02g' 0 99)
	do
        	if [[ "${PORTARRY[@]}" =~ ${sequence} ]];then
                	continue
		elif [[ ${sequence} == "04" ]];then
			continue
        	else
                	c_logic_port="230${sequence}"
                	c_gateway_port="130${sequence}"
                	c_db_port="320${sequence}"
                	break
        	fi
	done
	_RESULT_ "可使用端口:" "${c_gateway_port}" "${c_logic_port}" "${c_db_port}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

#### 添加网关配置 ####
_COMFIG_GATEWAY_=$(/bin/cat <<_GATEWAY_CONFIG_
GateServer = { {\n
LocalService = {\n
\tServerName = "[130%_SEQUENCT_%]",\n
\tAddress = "0.0.0.0",\n
\tPort = "130%_SEQUENCT_%",\n
\tMaxSession = 8192,\n
\tSendThreadCount = 2\n
},\n
BackServer = {\n
\tHost = "127.0.0.1",\n
\tPort = 230%_SEQUENCT_%,\n
}, },\n
}\n
_GATEWAY_CONFIG_
)

	##########################################################
	#
	#	* 修改logicserver.txt
	#	* 修改logicserver${name}/script/agent_vars.sh
	#	* 修改dbserver.txt
	#	* 修改dbserver${name}/script/agent_vars.sh
	#	* 生成网关配置文件
	#
	##########################################################

	_LOGINFO_ "生成网关配置文件" "${_PATH_OF_SERVER_}/gateserver/gateservice_130${sequence}.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	echo -e  ${_COMFIG_GATEWAY_//%_SEQUENCT_%/${sequence}} > ${_PATH_OF_SERVER_}/gateserver/gateservice_130${sequence}.txt
	_RESULT_ "生成网关配置文件" "${_PATH_OF_SERVER_}/gateserver/gateservice_130${sequence}.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	unset sequence

	_LOGINFO_ "修改配置" "logicserver${_MERGED_SERVER_}/logicserver.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	if [[ "${ARR2[0]}" =~ "_" ]];then

		sed \
			-i -e "6c ServerCombineTime = \"$(date -I) 01:00:00\"," \
			-i -e "9c Port = ${c_logic_port}" \
			-i -e "35c Port = ${c_db_port}" \
		logicserver${_MERGED_SERVER_}/logicserver.txt

	else
		sed \
			-i -e "5a ServerCombineTime = \"$(date -I) 01:00:00\"," \
                        -i -e "8c Port = ${c_logic_port}" \
                        -i -e "34c Port = ${c_db_port}" \
		logicserver${_MERGED_SERVER_}/logicserver.txt
	fi
	_RESULT_ "修改配置" "logicserver${_MERGED_SERVER_}/logicserver.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

	_LOGINFO_ "修改配置" "dbserver${_MERGED_SERVER_}/dbserver.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	sed -i -e "12c Port = ${c_db_port}" dbserver${_MERGED_SERVER_}/dbserver.txt
	_RESULT_ "修改配置" "dbserver${_MERGED_SERVER_}/dbserver.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

	_LOGINFO_ "修改配置" "logicserver${_MERGED_SERVER_}/script/agent_vars.sh" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	sed \
		-i -e "4c c_server_id=\'${_MERGED_SERVER_}\'" \
		-i -e "7c c_server_path=\'/data/app/lhzs/server/logicserver${_MERGED_SERVER_}\'" \
		-i -e "8c c_db_port=\'${c_db_port}\'" \
		-i -e "9c c_logic_port=\'${c_logic_port}\'" \
		-i -e "10c c_gateway_port=\'${c_gateway_port}\'" \
		-i -e "12c c_merge_time=\'$(date -I) 01:00:00\'" \
	logicserver${_MERGED_SERVER_}/script/agent_vars.sh
	_RESULT_ "修改配置" "logicserver${_MERGED_SERVER_}/script/agent_vars.sh" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

	_LOGINFO_ "修改配置" "dbserver${_MERGED_SERVER_}/script/agent_vars.sh" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	sed \
		-i -e "4c c_server_id=\'${_MERGED_SERVER_}\'" \
		-i -e "7c c_server_path=\'/data/app/lhzs/server/dbserver${_MERGED_SERVER_}\'" \
		-i -e "8c c_db_port=\'${c_db_port}\'" \
		-i -e "9c c_logic_port=\'${c_logic_port}\'" \
		-i -e "10c c_gateway_port=\'${c_gateway_port}\'" \
		-i -e "12c c_merge_time=\'$(date -I) 01:00:00\'" \
	dbserver${_MERGED_SERVER_}/script/agent_vars.sh
	_RESULT_ "修改配置" "dbserver${_MERGED_SERVER_}/script/agent_vars.sh" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

	######################################################### ( 华丽分割线 ) ###########################################################################

	#### 合日志文件(重要) ####
	_LOGINFO_ "合并排行版" "runtime" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	pushd logicserver${_MERGED_SERVER_}/data/ >/dev/null
		cp -fvp ${_PATH_OF_COMBIN_}/combinfiles_r ./ >&3 && chmod u+x combinfiles_r && ./combinfiles_r >&3 2>&3
		_RESULT_ "FAIL-WOULD-KILL" "排行版合并" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

		_LOGINFO_ "排行版文件" "$(ls -d runtime*)" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
		_LOGINFO_ "删除排行版文件" "runtime" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
		find ./ -type d -name "runtime*" ! -name "runtime" | xargs rm -rfv >&3
		_RESULT_ "删除排行版文件" "runtime" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

	popd >/dev/null

	#### 合数据库数据(重要) ####
	_LOGINFO_ "开始合并数据库" "主库" "cq_actor$(_SERVER_CORRESPONDING_ ${ARR2[0]})" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	pushd ${_PATH_OF_COMBIN_}/ >/dev/null
		for j in ${ARR2[@]};do	
	
			#### 循环到首服则进行物理授权 ####
			if [[ "${j}" == ${ARR2[0]} ]];then

				_DATABASE_FIRSTPART_="$(_SERVER_CORRESPONDING_ ${ARR2[0]})"

				_RESULT_PHISICAL_="$(./esql -ncq_actor${_DATABASE_FIRSTPART_} -f physical_merge_server.esql -s ${_DATABASE_FIRSTPART_} -l ${_DATABASE_FIRSTPART_} 2>&1)"
				echo "${_RESULT_PHISICAL_}" >&3	# 结果插入日志

				if echo "${_RESULT_PHISICAL_}" | grep -qw "succeed";then
					_LOGOK_ "数据主库物理授权" "cq_actor${_DATABASE_FIRSTPART_}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
				else
					_LOGFAIL_ "数据主库物理授权" "cq_actor${_DATABASE_FIRSTPART_}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
					echo "${_RESULT_PHISICAL_}"
					exit 1
				fi

			else
				
				_DATABASE_NUM_="$(_SERVER_CORRESPONDING_ ${j})"

				_RESULT_MERGE_="$(./esql -ncq_actor${_DATABASE_FIRSTPART_} -f merge2actor.esql -s ${_DATABASE_NUM_} -l ${_DATABASE_FIRSTPART_} 2>&1)"
				echo "${_RESULT_MERGE_}" >&3 # 结果插入日志

				if echo "${_RESULT_MERGE_}" | grep -qw "succeed";then
					_LOGOK_ "数据库合并" "cq_actor${_DATABASE_NUM_}" "-->" "cq_actor${_DATABASE_FIRSTPART_}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
				else
					_LOGFAIL_ "数据库合并" "cq_actor${_DATABASE_NUM_}" "-->" "cq_actor${_DATABASE_FIRSTPART_}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
					echo "${_RESULT_MERGE_}"
					exit 1
				fi

			fi

		done
	popd >/dev/null

	_LOGINFO_ "启动相关进程服务" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

	#### 定义检查模块 ####
	_CHECK_PROGRAM_()
	{
		exitID=1
		for((i=1;i<=90;i++));do
			sleep 1
			if /sbin/fuser -n tcp ${1} >/dev/null 2>&1;then
				exitID=0
				break
			else
				continue
			fi
		done
		return ${exitID}
	}

	#### 定义获取端口模块 ####
	_GET_PORT_()
	{
		awk '
			BEGIN{
				FS="="
				}
				{
					if(/'${1}'/)
						{
							FIRST=$2
						}
				}
			END{
				print substr(FIRST,2,length(FIRST)-2)
			}' ${2}
	}

	#### 启动数据服 ####
	_PORT_DBSERVER_="$(_GET_PORT_ "c_db_port" "logicserver${_MERGED_SERVER_}/script/agent_vars.sh")"
	pushd dbserver${_MERGED_SERVER_}/ >/dev/null
		_LOGINFO_ "启动进程" "${_PATH_OF_SERVER_}/dbserver${_MERGED_SERVER_}/dbserver_r" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
		(nohup ${_PATH_OF_SERVER_}/dbserver${_MERGED_SERVER_}/dbserver_r >/dev/null 2>&1 &)
		_CHECK_PROGRAM_ "${_PORT_DBSERVER_}"
		_RESULT_ "启动进程" "dbserver${_MERGED_SERVER_}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	popd >/dev/null

	sleep 5

	#### 启动引擎 ####
	_PORT_LOGICSERVER_="$(_GET_PORT_ "c_logic_port" "logicserver${_MERGED_SERVER_}/script/agent_vars.sh")"
	pushd logicserver${_MERGED_SERVER_}/ >/dev/null
		_LOGINFO_ "启动进程" "${_PATH_OF_SERVER_}/logicserver${_MERGED_SERVER_}/logicserver_r" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
		(nohup ${_PATH_OF_SERVER_}/logicserver${_MERGED_SERVER_}/logicserver_r >/dev/null 2>&1 &)
		_CHECK_PROGRAM_ "${_PORT_LOGICSERVER_}"
		_RESULT_ "启动进程" "logicserver${_MERGED_SERVER_}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	popd >/dev/null

	sleep 5

	#### 启动网关 ####
	_PORT_GATEWAY_="$(_GET_PORT_ "c_gateway_port" "logicserver${_MERGED_SERVER_}/script/agent_vars.sh")"
	pushd gateserver/ >/dev/null
		_LOGINFO_ "启动进程" "${_PATH_OF_SERVER_}/gateserver/gateserver_r gateservice_${_PORT_GATEWAY_}.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
		(nohup ${_PATH_OF_SERVER_}/gateserver/gateserver_r gateservice_${_PORT_GATEWAY_}.txt >/dev/null 2>&1 &)
		_CHECK_PROGRAM_ "${_PORT_GATEWAY_}"
		_RESULT_ "启动进程" "gateservice_${_PORT_GATEWAY_}.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	popd >/dev/null

	declare -a IPADDR="($(/sbin/ifconfig | grep "inet addr:" | sed -n '1,2p' | awk '{print $2}' | cut -d ":" -f 2))"

	_LOGINFO_ "[电信/联通]地址:" "${IPADDR[@]}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	_LOGINFO_ "双线[${_MERGED_SERVER_}]区" "(END)" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	
#### 退出重定向 ####
exec 3>&-

popd >/dev/null

exit 0
