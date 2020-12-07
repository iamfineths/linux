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


#### 建立区服信息保存、查询机制 ####
#通过参数获得区服信息  返回格式：spid,serverid,合区最大id,数据库id,文件夹后缀
_GET_SRV_INFO_()
{
	set -u
	local srv_arg="$1"
	if [ -d "${_DB_PATH_PREFIX_}${srv_arg}" ] && [ -d "${_LOGIC_PATH_PREFIX_}${srv_arg}" ];then
		local isCombine='True'
		local db_path="${_DB_PATH_PREFIX_}${srv_arg}"
		local db_cnf="${db_path}/dbserver.txt"
	elif [ -d "${_DB_PATH_PREFIX_}_${srv_arg}" ] && [ -d "${_LOGIC_PATH_PREFIX_}_${srv_arg}" ];then
		local isCombine='Failed'
		local db_path="${_DB_PATH_PREFIX_}_${srv_arg}"
		local db_cnf="${db_path}/dbserver.txt"
	else
		_LOGFAIL_ "参数${srv_arg}错误：对应的目录不存在。请检查！" >&2
		exit 2
	fi
	
	local dir_suffix="$( echo ${db_path}| sed "s#${_DB_PATH_PREFIX_}##")"
	local db_cnf_file="${db_path}/dbserver.txt" 
	local db_cnf_shell="${db_path}/script/agent_vars.sh"
	local spid="$(grep  "c_server_spid"  "${db_cnf_shell}" | awk -F'=' '{print $2}' |  sed "s#[\ \"']##g")"
	local serverid=$(sed -n '/ServerIndex/s#[^0-9]##gp' ${db_cnf} )
	
	if [ "${isCombine}" = 'True' ];then
		local bypart=$(echo "${srv_arg}" | awk -F'_' '{print $2}')
	else
		local bypart=${serverid}
	fi
	
	local db_id=$(sed -n  '/DBName/s#.*cq_actor\([0-9]*\)".*#\1#p' ${db_cnf})
	
	echo "${spid},${serverid},${bypart},${db_id},${dir_suffix}"
	set +u
}

#从信息行中提取出特定信息
_EXTRACT_ITEM_INFO_()
{
	item_type="$1"
	detail_line="$2"
	case ${item_type} in 
	spid)
	echo "${detail_line}" | awk -F',' '{print $1}'
	;;
	
	srvid)
	echo "${detail_line}" | awk -F',' '{print $2}'
	;;
	bypart)
	#最大的合区名字
	echo "${detail_line}" | awk -F',' '{print $3}'
	;;
	dbid)
	#数据库id
	echo "${detail_line}" | awk -F',' '{print $4}'
	;;
	dir)
	echo "${detail_line}" | awk -F',' '{print $5}'
	;;
	
	*)
	#错误参数
	_RED_ "提取的信息错误！"
	exit 2
	esac
}

#针对信息提取的简略行
_EXTRAC_SPID_(){ 
_EXTRACT_ITEM_INFO_ spid "${*}" 
}

_EXTRAC_SRVID_(){ 
_EXTRACT_ITEM_INFO_ srvid "${*}" 
}
_EXTRAC_BYPART_(){
_EXTRACT_ITEM_INFO_ bypart "${*}" 
}
_EXTRAC_DBID_(){ 
_EXTRACT_ITEM_INFO_ dbid "${*}" 
}
_EXTRAC_DIR_(){ 
_EXTRACT_ITEM_INFO_ dir "${*}" 
}

#### 查询区服的平台id#####
_GET_SGUID_()
{
	:
}

#判断是否合区
_GET_IS_COMBINE_()
{
	:
}

#后台信息提示
function houtai_tips()
{	
	local c_server_spid=${1}
	local c_server_id=${2}
	if  echo "${c_server_id}"|grep -q "_";then
		c_server_id="$(echo ${c_server_id} | sed 's#_.*##')"
	fi
	local c_db_id=${3}
	local c_open_date=${4}
	local c_gateway_port=${5}
	

	#输出信息
	echo 
	echo "后台信息提示："
	#游戏名称: 
	echo "游戏名称: LHZS"
	#平台: 923
	echo "平台: ${c_server_spid}"
	#区服
	echo "区服号: ${c_server_id}"
	#开区时间
	echo "开区时间: ${c_open_date}"
	#数据库:
	echo "数据库: cq_actor${c_db_id}"
	#ip信息
	echo "IP信息:"
	ips=$(ifconfig | grep 'inet addr' | grep -v 127.0.0.1 | awk '{print $2}' | awk -F: '{print $2}')
	echo $ips
	echo	
	#gate 端口
	echo "网关端口:"
	echo "${c_gateway_port}"
	echo
	echo "允许覆盖旧IP: YES"
}

#-------------------------开始执行----------------------------------
#### 定义全局变量 ####
readonly _PATH_OF_SERVER_="/data/app/lhzs/server"
readonly _DB_PATH_PREFIX_="${_PATH_OF_SERVER_}/dbserver"
readonly _LOGIC_PATH_PREFIX_="${_PATH_OF_SERVER_}/logicserver"
readonly _TIME_OF_YEARS_=$(date "+%Y")
readonly _TIME_OF_DAYS_=$(date "+%Y-%m-%d")
readonly _NOW_TIME_=$(date "+%Y%m%d%H%M%S")
readonly _PATH_OF_COMBIN_="/data/app/lhzs/public/esql"
readonly _PATH_OF_BACKUP_="/data/app/lhzs/public/backup/${_TIME_OF_YEARS_}/${_TIME_OF_DAYS_}"

#### 定义数组 ####
declare -a ARR=()
declare -A ARR_DETAIL
declare -A COMBINE_DIST
declare -a ARRMAINPART=()
declare -a ARRBYPART=()

#### 开始计算输入 ####
if [[ $# -le 0 ]];then
	_LOGFAIL_ "区服输入空值" "请检查！！！"
	kill -9 $$
fi

i=0
while (($#>=1)); do
	arg_string=$1
	detail_info=$(_GET_SRV_INFO_ "$arg_string")
    if [ 0 != "$?" ];then
        exit 2
    fi
	ARR_DETAIL["$arg_string"]=${detail_info}

	dir_suffix=$(_EXTRAC_DIR_  ${ARR_DETAIL["$arg_string"]})
	logicserver="logicserver${dir_suffix}"
	dbserver="dbserver${dir_suffix}"


	#### 检查进程是否存在 ####
	pgrep -f "${logicserver}/" >/dev/null 2>&1 && { _LOGFAIL_ "${logicserver}" "进程存在" "请手动检查!" >&2;exit 1; }
	pgrep -f "${dbserver}/" >/dev/null 2>&1 && { _LOGFAIL_ "${dbserver}" "进程存在" "请手动检查!" >&2;exit 1; }
	ARR+=($arg_string)
	ARRMAINPART+=("$(_EXTRAC_SRVID_  ${ARR_DETAIL["$arg_string"]} )")
	ARRBYPART+=("$(_EXTRAC_BYPART_  ${ARR_DETAIL["$arg_string"]} )")
	unset arg_string
	let i++

	shift
done



#### 重新由大到小重新排序 ####
declare -a ARR2=(`for val in "${ARR[@]}";do echo "$val";done | sort -n`)
declare -a ARRBYPART2=(`for val in "${ARRBYPART[@]}";do echo "$val";done | sort -n -r`)
unset val


#判断合区类型

agent_name=$(_EXTRAC_SPID_ "${ARR_DETAIL[${ARR[0]}]}")
for arg in ${ARR[@]};
do
	detail_line=${ARR_DETAIL[${arg}]}
	spid=$(_EXTRAC_SPID_ "${detail_line}")
	if  echo ${agent_name}| grep -q "${spid}";then
		:
	else
		agent_name="${agent_name} ${spid}"
	fi
done

#是否混服？
if  echo "${agent_name}" | egrep -q '^[0-9a-zA-Z]{3}$';then
	is_merge='Failed'
else
	is_merge='True'
	_COMB_TYPE_='merge'
fi

if [ "${is_merge}" == 'Failed' ];then
	first_arg_string=${ARR2[0]}
	spid=$( _EXTRAC_SPID_  ${ARR_DETAIL["$first_arg_string"]} )
	first_sid=$( _EXTRAC_SRVID_  ${ARR_DETAIL["$first_arg_string"]})
	
	last_sid=${ARRBYPART2[0]}
	db_id=$( _EXTRAC_DBID_  ${ARR_DETAIL["$first_arg_string"]} )
	dist_title="双线[${first_sid}_${last_sid}]区" 
	
	if [ "${first_sid}" = "${db_id}" ];then
		#普通
		_COMB_TYPE_='normal'
		dist_dirname="${first_sid}_${last_sid}"
	else
		#PUB服
		_COMB_TYPE_='pub'
		dist_dirname="${first_sid}_${last_sid}_${spid}"
	fi
	COMBINE_DIST['oldsrv']="${first_arg_string}"
	COMBINE_DIST['title']="${dist_title}"
	COMBINE_DIST['sid']="${first_sid}"
	COMBINE_DIST['db_id']="${db_id}"
	COMBINE_DIST['dir_suffix']="${dist_dirname}"
	COMBINE_DIST['spid']="${spid}"
	
else
	#混服处理
	COMBINE_DIST['oldsrv']="${ARR[0]}"
	COMBINE_DIST['title']="混服标题请自行修改"
	COMBINE_DIST['sid']="$(_EXTRAC_SRVID_ "${ARR_DETAIL[${ARR[0]}]}"  | sed 's#_.*$##'|sed 's#_##g')"
	COMBINE_DIST['db_id']="$(_EXTRAC_DBID_ "${ARR_DETAIL[${ARR[0]}]}")"
	COMBINE_DIST['dir_suffix']="$(_EXTRAC_DIR_ "${ARR_DETAIL[${ARR[0]}]}")"
	COMBINE_DIST['spid']="$(_EXTRAC_SPID_ "${ARR_DETAIL[${ARR[0]}]}")"
fi


#判断目标区服以及最终文件夹名

#### 确认信息(重要) ####
while true;do
echo "-----------------------------------------"
_LOGINFO_ "平台：" "${agent_name}"
_LOGINFO_ "合区类型：" "${_COMB_TYPE_}"
_LOGINFO_ "参与合区的区服：" "${ARR2[@]}"
_LOGINFO_ "原区服:  " "${COMBINE_DIST[oldsrv]}"
_LOGINFO_ "目标区服:  " "${COMBINE_DIST[dir_suffix]}"
_LOGINFO_ "目标数据库id:" "${COMBINE_DIST[db_id]}"
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

if ! awk -F "=" '/^DBPass/{print $2}' ${_PATH_OF_COMBIN_}/Config.ini | grep -E -o -q "^12[0-9,A-Z]*$";then
	_LOGFAIL_ "ESQL" "Config.ini" "未配置正确" "脚本强行退出" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	kill -9 $$
fi
#########################################################################################################################

#### 合区完成后命名 ####
#_MERGED_SERVER_="${ARRMAINPART2[0]}_${ARRBYPART2[${#ARRBYPART2[@]}-1]}${agent_suffix}"
_MERGED_SERVER_="${COMBINE_DIST['dir_suffix']}"

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

	#处理目标服（备份、重命名）
		the_lgc_dir="${_LOGIC_PATH_PREFIX_}$(_EXTRAC_DIR_ ${ARR_DETAIL[${COMBINE_DIST[oldsrv]}]})"
		the_db_dir="${_DB_PATH_PREFIX_}$(_EXTRAC_DIR_ ${ARR_DETAIL[${COMBINE_DIST[oldsrv]}]})"
		the_db_id="$(_EXTRAC_DBID_ ${ARR_DETAIL[${COMBINE_DIST[oldsrv]}]})"
		#### 转移库目录和runtime目录 ####
		cp -rfpv "${the_lgc_dir}"/data/runtime ${_PATH_OF_BACKUP_}/runtime${the_db_id} >&3
		cp -rfpv mysqldata/cq_actor${the_db_id} ${_PATH_OF_BACKUP_}/ >&3

		mv -vf ${the_db_dir} dbserver${_MERGED_SERVER_} >&3
		mv -vf ${the_lgc_dir} logicserver${_MERGED_SERVER_} >&3

		#### 转换文本格式(重要) ####
		_LOGINFO_ "转换配置文件格式" "dbserver${_MERGED_SERVER_}/dbserver.txt" "logicserver${_MERGED_SERVER_}/logicserver.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
		dos2unix -k dbserver${_MERGED_SERVER_}/dbserver.txt >&3 2>&3 && \
		dos2unix -k logicserver${_MERGED_SERVER_}/logicserver.txt >&3 2>&3
		_RESULT_ "转换配置文件格式" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
		
		unset the_lgc_dir
		unset the_db_dir
		unset the_db_id
	
	for i in ${ARR[@]};do
		the_lgc_dir="${_LOGIC_PATH_PREFIX_}$(_EXTRAC_DIR_ ${ARR_DETAIL[${i}]})"
		the_db_dir="${_DB_PATH_PREFIX_}$(_EXTRAC_DIR_ ${ARR_DETAIL[${i}]})"
		the_db_id="$(_EXTRAC_DBID_ ${ARR_DETAIL[${i}]})"
		#### 重命名和移动被合区服 ####
		if [[ "${i}" == ${COMBINE_DIST[oldsrv]} ]];then
			#目标区已经处理，跳过。
			:
		else
			#### 转移库目录和runtime目录 ####
			cp -rfpv ${the_lgc_dir}/data/runtime logicserver${_MERGED_SERVER_}/data/runtime${the_db_id} >&3
			cp -rfpv mysqldata/cq_actor${the_db_id} ${_PATH_OF_BACKUP_}/ >&3
	
			#### 转移服目录 ####
			mv -vf ${the_db_dir} ${_PATH_OF_BACKUP_}/ >&3
			mv -vf ${the_lgc_dir} ${_PATH_OF_BACKUP_}/ >&3
		fi	
		
		unset the_lgc_dir
		unset the_db_dir
		unset the_db_id
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
	sed \
			-i -e "/^\s*GateService\s*=/,/Port/s#Port\s*=.*#Port = ${c_logic_port}#" \
			-i -e "/^\s*DbServer\s*=/,/Port/s#Port\s*=.*#Port = ${c_db_port}#" \
	logicserver${_MERGED_SERVER_}/logicserver.txt
	
	#非混服的合区需要修改ServerCombineTime
	if [ ${_COMB_TYPE_} != 'merge' ];then
		sed \
			-i -e  '/^\s*ServerCombineTime/d' \
			-i -e "/^\s*ServerOpenTime/aServerCombineTime = \"$(date -I) 01:00:00\"," \
			logicserver${_MERGED_SERVER_}/logicserver.txt
	#else
	#	#混服模式需要清除
	#	sed \
	#		-i -e  '/^\s*ServerCombineTime/d' 
	#		logicserver${_MERGED_SERVER_}/logicserver.txt
	fi

	_RESULT_ "修改配置" "logicserver${_MERGED_SERVER_}/logicserver.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

	_LOGINFO_ "修改配置" "dbserver${_MERGED_SERVER_}/dbserver.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	sed -i -e "12c Port = ${c_db_port}" dbserver${_MERGED_SERVER_}/dbserver.txt
	_RESULT_ "修改配置" "dbserver${_MERGED_SERVER_}/dbserver.txt" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

	_LOGINFO_ "修改配置" "logicserver${_MERGED_SERVER_}/script/agent_vars.sh" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	sed \
		-i -e "4c c_server_id=\'$(echo ${_MERGED_SERVER_} | sed 's#^_##')\'" \
		-i -e "7c c_server_path=\'/data/app/lhzs/server/logicserver${_MERGED_SERVER_}\'" \
		-i -e "8c c_db_port=\'${c_db_port}\'" \
		-i -e "9c c_logic_port=\'${c_logic_port}\'" \
		-i -e "10c c_gateway_port=\'${c_gateway_port}\'" \
		-i -e "12c c_merge_time=\'$(date -I) 01:00:00\'" \
	logicserver${_MERGED_SERVER_}/script/agent_vars.sh
	_RESULT_ "修改配置" "logicserver${_MERGED_SERVER_}/script/agent_vars.sh" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}

	_LOGINFO_ "修改配置" "dbserver${_MERGED_SERVER_}/script/agent_vars.sh" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	sed \
		-i -e "4c c_server_id=\'$(echo ${_MERGED_SERVER_} | sed 's#^_##')\'" \
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
	_EXTRAC_DBID_
	_LOGINFO_ "开始合并数据库" "主库" "cq_actor${COMBINE_DIST[db_id]}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	pushd ${_PATH_OF_COMBIN_}/ >/dev/null
		_DATABASE_FIRSTPART_="${COMBINE_DIST[db_id]}"
		for j in ${ARR[@]};do	
			#### 循环到首服则进行物理授权 ####
			if [[ "${j}" == "${COMBINE_DIST[oldsrv]}" ]];then

				_RESULT_PHISICAL_="$(./esql -ncq_actor${_DATABASE_FIRSTPART_} -f physical_merge_server.esql -s ${_DATABASE_FIRSTPART_} -l ${_DATABASE_FIRSTPART_} 2>&1)"
				echo "${_RESULT_PHISICAL_}" >&3	# 结果插入日志

				if echo "${_RESULT_PHISICAL_}" | grep -q -w "succeed";then
					_LOGOK_ "数据主库物理授权" "cq_actor${_DATABASE_FIRSTPART_}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
				else
					_LOGFAIL_ "数据主库物理授权" "cq_actor${_DATABASE_FIRSTPART_}" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
					echo "${_RESULT_PHISICAL_}"
					exit 1
				fi

			else
				
				_DATABASE_NUM_="$(_EXTRAC_DBID_ ${ARR_DETAIL[${j}]})"
				_RESULT_MERGE_="$(./esql -ncq_actor${_DATABASE_FIRSTPART_} -f merge2actor.esql -s ${_DATABASE_NUM_} -l ${_DATABASE_FIRSTPART_} 2>&1)"
				echo "${_RESULT_MERGE_}" >&3 # 结果插入日志

				if echo "${_RESULT_MERGE_}" | grep -q -w "succeed";then
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
	_LOGINFO_ "${COMBINE_DIST['title']} " "(END)" | tee -a ${_PATH_OF_BACKUP_}/merge.out.${_NOW_TIME_}
	
	#输出提示信息，协助修改后台
	c_open_date="$(grep 'ServerOpenTime' ${_PATH_OF_SERVER_}/logicserver${_MERGED_SERVER_}/logicserver.txt | sed 's#.*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*#\1#')"
	echo
	#houtai_tips "c_server_spid" "c_server_id" "${COMBINE_DIST[db_id]}" "${c_open_date}" "${_PORT_GATEWAY_}"
	houtai_tips "${COMBINE_DIST['spid']}" "${COMBINE_DIST['sid']}" "${COMBINE_DIST['db_id']}" "${c_open_date}" "${_PORT_GATEWAY_}"
	
#### 退出重定向 ####
exec 3>&-

popd >/dev/null

exit 0
