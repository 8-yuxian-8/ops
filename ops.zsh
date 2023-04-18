#!/bin/zsh
# Author： 欲仙
# Date：2023-03-08 11:41
# 运维可视化脚本

### 初始化
function Init(){
    source ${HOME}/.zshrc &> /dev/null
##  全局变量定义
#   获取当前时间
	Time=$(date +%F-%H:%M:%S)
#   获取当前时间并格式化输出
    EndTime=`perl -MPOSIX -le 'print strftime "%Y-%m-%dT%H:%M:%SZ", localtime(time)'`
#   获取一小时前的时间并格式化输出
	StartTime=`perl -MPOSIX -le 'print strftime "%Y-%m-%dT%H:%M:%SZ", localtime(time-1*1*60*60)'`
#   工作目录
	Workspace=${HOME}/aliyun/visualization
    Homespace=${HOME}/workspaces/aliyun_ops/aliyun-cost/aliyun_check_shell_scripts/visualization
	Tempspace=${Workspace}/temp-files
#   AccessKey信息
	AccessKeyId=`cat ${Homespace}/AccessKey | awk '{print $1}'`
	AccessKey=`cat ${Homespace}/AccessKey | awk '{print $2}'`
#   地域列表
	Region=(beijing guigu)
#   产品列表
	Product=(MongoDB Redis ECS RDS OSS SLB CDN ACK)
#   API分页
	Page=(1 2 3 4 5 6 7 8 9 10)
    
##  创建工作目录
    if [ ! -d ${Tempspace} ]; then
		mkdir -p ${Tempspace}
	fi
}

### 配置 Access 登录凭证
function AccessConfigure(){
	case $RegionName in
		beijing)
			RegionId=cn-beijing	# 资源地域
			RegionId_1=cn-beijing	# API请求地域
			confname=beijing
			Name=北京
			;;
		guigu)
			RegionId=us-west-1	# 资源地域
			RegionId_1=cn-beijing	# API请求地域
			confname=guigu
			Name=硅谷
			;;
		*)
			;;
	esac
	aliyun configure set --profile ${confname} --mode AK --region ${RegionId_1} --language zh --access-key-id ${AccessKeyId} --access-key-secret ${AccessKey}
}

### 产品判断及调用对应函数获取信息
function GetMessage(){
    case ${ProductName} in 
        MongoDB)
			MongoDB
        ;;
        Redis)
			Redis
        ;;
        ECS)
			ECS
        ;;
        RDS)
        ;;
        OSS)
        ;;
        SLB)
        ;;
        CDN)
        ;;
        ACK)
           ACK
        ;;
        *)
			echo "错误！！！产品列表不全"
        ;;
    esac
}

### MongoDB
## 获取实例费用
function MongoDB_Cost(){
	Cost=`aliyun dds DescribeRenewalPrice --profile ${confname} --RegionId ${RegionId} --DBInstanceId ${InstanceId} --output cols=TradeAmount rows=SubOrders.SubOrder | egrep -v "TradeAmount|-----------|^$"`
	return ${Cost}
}

## 获取实例监控信息
function MongoDB_Message(){
#   Massage
    InstanceName=`cat ${Tempspace}/${ProductName}_List_${confname}.txt | grep ${InstanceId} | awk -F ',' '{print $3}' | sort -ru`
    Tag=`cat ${Tempspace}/${ProductName}_List_${confname}.txt | grep ${InstanceId} | awk -F ',' '{print $5}' | sort -ru`
    Label=`echo ${Tag} | awk -F 'Key:App_NameValue:' '{print $2}' | sed 's/\]//g'`
    case ${Label} in
        '')
            Label=None
        ;;
        *)
        ;;
    esac

#   Usage
	declare -a mongodb_proc
	declare -i mongodb_proc_end
	for MetricName in ${Metric[@]}
	do
		aliyun cms DescribeMetricTop --profile ${confname} --RegionId ${RegionId} --Period 3600 --Namespace acs_mongodb --MetricName ${MetricName} --StartTime ${StartTime} --EndTime ${EndTime} --Dimensions [{"instanceId":"${InstanceId}"}] --Orderby Maximum | grep "\"Datapoints\":" | tr '{' '\n' | grep -v Datapoints | awk -F '"' '{print $17,$19,$21,$6,$10}' | sed 's/[:,\\]//g' | sort -ru > ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt
		for NodeName in ${Node[@]}
		do
			if [ ${NodeName} = Primary ]; then
				case ${MetricName} in
					CPUUtilization)
						mongodb_proc[1]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $1}'` # CPU_Primary_Minimum
						mongodb_proc[2]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $2}'` # CPU_Primary_Maximum
						mongodb_proc[3]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $3}'` # CPU_Primary_Average
					;;
					MemoryUtilization)
						mongodb_proc[4]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $1}'` # MEM_Primary_Minimum
						mongodb_proc[5]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $2}'` # MEM_Primary_Maximum
						mongodb_proc[6]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $3}'` # MEM_Primary_Average
					;;
					*) # ConnectionUtilization
						mongodb_proc[7]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $1}'` # CONNECT_Primary_Minimum
						mongodb_proc[8]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $2}'` # CONNECT_Primary_Maximum
						mongodb_proc[9]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $3}'` # CONNECT_Primary_Average
					;;
				esac
			else # Secondary
				case ${MetricName} in
					CPUUtilization)
						mongodb_proc[10]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $1}'` # CPU_Secondary_Minimum
						mongodb_proc[11]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $2}'` # CPU_Secondary_Maximum
						mongodb_proc[12]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $3}'` # CPU_Secondary_Average
					;;
					MemoryUtilization)
						mongodb_proc[13]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $1}'` # MEM_Secondary_Minimum
						mongodb_proc[14]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $2}'` # MEM_Secondary_Maximum
						mongodb_proc[15]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $3}'` # MEM_Secondary_Average
					;;
					*) # ConnectionUtilization
						mongodb_proc[16]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $1}'` # CONNECT_Secondary_Minimum
						mongodb_proc[17]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $2}'` # CONNECT_Secondary_Maximum
						mongodb_proc[18]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep ${NodeName} | awk '{print $3}'` # CONNECT_Secondary_Average
					;;
				esac
			fi
		done
	done
	if [ `awk -v num1=${mongodb_proc[2]} -v num2=${mongodb_proc[11]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
		CPU_Maximum=${mongodb_proc[11]}
	else
		CPU_Maximum=${mongodb_proc[2]}
	fi
	if [ `awk -v num1=${mongodb_proc[5]} -v num2=${mongodb_proc[14]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
		MEM_Maximum=${mongodb_proc[14]}
	else
		MEM_Maximum=${mongodb_proc[5]}
	fi
	if [ `awk -v num1=${mongodb_proc[8]} -v num2=${mongodb_proc[17]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
		CONNECT_Maximum=${mongodb_proc[17]}
	else
		CONNECT_Maximum=${mongodb_proc[8]}
	fi
    case ${CPU_Maximum} in
        '')
            CPU_Maximum=-1
        ;;
        *)
        ;;
    esac
    case ${MEM_Maximum} in
        '')
            MEM_Maximum=-1
        ;;
        *)
        ;;
    esac
    case ${CONNECT_Maximum} in
        '')
            CONNECT_Maximum=-1
        ;;
        *)
        ;;
    esac

#   Cost
    MongoDB_Cost
    Cost_PutOut=$?

#   OutPut
    echo -e "${EndTime},${RegionId},${Label},,${ProductName},${InstanceId},${InstanceName},${CPU_Maximum},${MEM_Maximum},${CONNECT_Maximum},${Cost_PutOut}"
    echo "${EndTime},${RegionId},${Label},,${ProductName},${InstanceId},${InstanceName},${CPU_Maximum},${MEM_Maximum},${CONNECT_Maximum},${Cost_PutOut}" >> ${Workspace}/OutPut.csv
}

function MongoDB(){
# 	获取实例列表
	for PageNumber in ${Page[@]}
	do
		aliyun dds DescribeDBInstances --profile ${confname} --RegionId ${RegionId} --PageNumber ${PageNumber} --PageSize 50 --output cols=RegionId,DBInstanceId,DBInstanceDescription,DBInstanceClass,Tags rows=DBInstances.DBInstance | sed s/[[:space:]]//g | sed s/\|/,/g | egrep -v "RegionId,DBInstanceId,DBInstanceDescription,DBInstanceClass,Tags|--------,------------,---------------------,---------------,----|^$" >> ${Tempspace}/${ProductName}_List_${confname}.txt
	done

#	查询实例监控数据
	Metric=(CPUUtilization MemoryUtilization ConnectionUtilization)
	Node=(Primary Secondary)
	for InstanceId in `cat ${Tempspace}/${ProductName}_List_${confname}.txt | awk -F ',' '{print $2}' | sort -ru`
	do
		MongoDB_Message
	done
}

### Redis
## 获取实例费用
function Redis_Cost(){
	Cost=`aliyun r-kvstore DescribePrice --profile ${confname} --RegionId ${RegionId} --OrderType BUY --InstanceClass ${InstanceClass} --ChargeType PrePaid --Period 1 --output cols=TradeAmount rows=SubOrders.SubOrder | egrep -v "TradeAmount|-----------|^$"`
	return ${Cost}
}

## 获取实例监控信息
function Redis_Message(){
#   Message
    InstanceName=`cat ${Tempspace}/${ProductName}_List_${confname}.txt | grep ${InstanceId} | awk -F ',' '{print $3}' | sort -ru`
    Tag=`cat ${Tempspace}/${ProductName}_List_${confname}.txt | grep ${InstanceId} | awk -F ',' '{print $5}' | sort -ru`
    Label=`echo ${Tag} | awk -F 'Key:App_NameValue:' '{print $2}' | sed 's/\]//g'`
    case $Label in
        '')
            Label=None
        ;;
        *)
        ;;
    esac

#   Usage
	declare -a redis_proc
	declare -i redis_proc_end
	ProcNum=1
	for MetricName in ${Metric[@]}
	do
		aliyun cms DescribeMetricTop --profile ${confname} --RegionId ${RegionId} --Period 3600 --Namespace acs_kvstore --MetricName ${MetricName} --StartTime ${StartTime} --EndTime ${EndTime} --Dimensions [{"instanceId":"${InstanceId}"}] --Orderby Maximum | grep "\"Datapoints\":" | tr '{' '\n' | grep -v Datapoints | awk -F '"' '{print $17,$19,$6,$14}' | sed 's/[:,\\]//g' | sort -ru > ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt
		NodeNum=`wc -l ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | awk '{print $1}'`
		
		NodeTag=0
		for ((NodeNo=1;NodeNo<=$NodeNum;NodeNo++));
		do
			case $MetricName in
				ShardingCpuUsage)
					redis_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep "db-${NodeTag}" | awk '{print $1}'` ; let ProcNum++ # Maximum
					redis_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep "db-${NodeTag}" | awk '{print $2}'` ; let ProcNum++ # Average
				;;
				ShardingMemoryUsage)
					redis_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep "db-${NodeTag}" | awk '{print $1}'` ; let ProcNum++ # Maximum
					redis_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep "db-${NodeTag}" | awk '{print $2}'` ; let ProcNum++ # Average
				;;
				*) #ShardingConnectionUsage
					redis_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep "db-${NodeTag}" | awk '{print $1}'` ; let ProcNum++ # Maximum
					redis_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | grep "db-${NodeTag}" | awk '{print $2}'` ; let ProcNum++ # Average
				;;
			esac
			let NodeTag++
		done
	done
    if [ ${NodeNum} -eq 1 ]; then # 1分片
        CPU_Maximum=${redis_proc[1]}
        MEM_Maximum=${redis_proc[3]}
        CONNECT_Maximum=${redis_proc[5]}
	elif [ ${NodeNum} -eq 2 ]; then	# 2分片
		if [ `awk -v num1=${redis_proc[1]} -v num2=${redis_proc[7]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
			CPU_Maximum=${redis_proc[7]}
		else
			CPU_Maximum=${redis_proc[1]}
		fi
		if [ `awk -v num1=${redis_proc[3]} -v num2=${redis_proc[9]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
			MEM_Maximum=${redis_proc[9]}
		else
			MEM_Maximum=${redis_proc[3]}
		fi
		if [ `awk -v num1=${redis_proc[5]} -v num2=${redis_proc[11]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
			CONNECT_Maximum=${redis_proc[11]}
		else
			CONNECT_Maximum=${redis_proc[5]}
		fi
	elif [ ${NodeNum} -eq 4 ]; then	# 4分片
		if [ `awk -v num1=${redis_proc[1]} -v num2=${redis_proc[7]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
			if [ `awk -v num1=${redis_proc[7]} -v num2=${redis_proc[13]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
				if [ `awk -v num1=${redis_proc[13]} -v num2=${redis_proc[19]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					CPU_Maximum=${redis_proc[19]}
				else
					CPU_Maximum=${redis_proc[13]}
				fi
			else
				if [ `awk -v num1=${redis_proc[7]} -v num2=${redis_proc[19]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					CPU_Maximum=${redis_proc[19]}
				else
					CPU_Maximum=${redis_proc[7]}
				fi
			fi
		else
			if [ `awk -v num1=${redis_proc[1]} -v num2=${redis_proc[13]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
				if [ `awk -v num1=${redis_proc[13]} -v num2=${redis_proc[19]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					CPU_Maximum=${redis_proc[19]}
				else
					CPU_Maximum=${redis_proc[13]}
				fi
			else
				if [ `awk -v num1=${redis_proc[1]} -v num2=${redis_proc[19]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					CPU_Maximum=${redis_proc[19]}
				else
					CPU_Maximum=${redis_proc[1]}
				fi
			fi
		fi
		if [ `awk -v num1=${redis_proc[3]} -v num2=${redis_proc[9]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
			if [ `awk -v num1=${redis_proc[9]} -v num2=${redis_proc[15]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
				if [ `awk -v num1=${redis_proc[15]} -v num2=${redis_proc[21]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					MEM_Maximum=${redis_proc[21]}
				else
					MEM_Maximum=${redis_proc[15]}
				fi
			else
				if [ `awk -v num1=${redis_proc[9]} -v num2=${redis_proc[21]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					MEM_Maximum=${redis_proc[21]}
				else
					MEM_Maximum=${redis_proc[9]}
				fi
			fi
		else
			if [ `awk -v num1=${redis_proc[3]} -v num2=${redis_proc[15]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
				if [ `awk -v num1=${redis_proc[15]} -v num2=${redis_proc[21]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					MEM_Maximum=${redis_proc[21]}
				else
					MEM_Maximum=${redis_proc[15]}
				fi
			else
				if [ `awk -v num1=${redis_proc[3]} -v num2=${redis_proc[21]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					MEM_Maximum=${redis_proc[21]}
				else
					MEM_Maximum=${redis_proc[3]}
				fi
			fi
		fi
		if [ `awk -v num1=${redis_proc[5]} -v num2=${redis_proc[11]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
			if [ `awk -v num1=${redis_proc[11]} -v num2=${redis_proc[17]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
				if [ `awk -v num1=${redis_proc[17]} -v num2=${redis_proc[23]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					CONNECT_Maximum=${redis_proc[23]}
				else
					CONNECT_Maximum=${redis_proc[17]}
				fi
			else
				if [ `awk -v num1=${redis_proc[11]} -v num2=${redis_proc[23]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					CONNECT_Maximum=${redis_proc[23]}
				else
					CONNECT_Maximum=${redis_proc[11]}
				fi
			fi
		else
			if [ `awk -v num1=${redis_proc[5]} -v num2=${redis_proc[17]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
				if [ `awk -v num1=${redis_proc[17]} -v num2=${redis_proc[23]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					CONNECT_Maximum=${redis_proc[23]}
				else
					CONNECT_Maximum=${redis_proc[17]}
				fi
			else
				if [ `awk -v num1=${redis_proc[5]} -v num2=${redis_proc[23]} 'BEGIN{print (num1<num2)?"1":"0"}'` -eq 1 ]; then
					CONNECT_Maximum=${redis_proc[23]}
				else
					CONNECT_Maximum=${redis_proc[5]}
				fi
			fi
		fi		
	else
		echo "错误！！！Redis节点数统计不全"
        CPU_Maximum=-1
        MEM_Maximum=-1
        CONNECT_Maximum=-1
	fi

#   Cost
    Redis_Cost
    Cost_PutOut=$?

#   OutPut
    echo -e "${EndTime},${RegionId},${Label},,${ProductName},${InstanceId},${InstanceName},${CPU_Maximum},${MEM_Maximum},${CONNECT_Maximum},${Cost_PutOut}"
    echo "${EndTime},${RegionId},${Label},,${ProductName},${InstanceId},${InstanceName},${CPU_Maximum},${MEM_Maximum},${CONNECT_Maximum},${Cost_PutOut}" >> ${Workspace}/OutPut.csv
}

function Redis(){
# 	获取实例列表
	for PageNumber in ${Page[@]}
	do
		aliyun r-kvstore DescribeInstances --profile ${confname} --RegionId ${RegionId} --PageNumber ${PageNumber} --PageSize 50 --output cols=RegionId,InstanceId,InstanceName,InstanceClass,Tags rows=Instances.KVStoreInstance | sed s/[[:space:]]//g | sed s/\|/,/g | egrep -v "RegionId,InstanceId,InstanceName,InstanceClass,Tags|--------,----------,------------,-------------,----|^$" >> ${Tempspace}/${ProductName}_List_${confname}.txt
	done

#	查询实例监控数据
	Metric=(ShardingCpuUsage ShardingMemoryUsage ShardingConnectionUsage)
	ProductCode_Name=redisa
	for InstanceId in `cat ${Tempspace}/${ProductName}_List_${confname}.txt | awk -F ',' '{print $2}' | sort -ru`
	do
        InstanceClass=`cat ${Tempspace}/${ProductName}_List_${confname}.txt | grep ${InstanceId} | awk -F ',' '{print $4}' | sort -ru`
		Redis_Message
	done
}

### ECS
## 获取实例费用
function ECS_Cost(){
	Cost=`aliyun ecs DescribeRenewalPrice --profile ${confname} --RegionId ${RegionId} --ResourceId ${InstanceId} | grep "\"TradePrice\": " | awk -F ':' '{print $2}'`
	return ${Cost}
}

## 获取实例监控信息
function ECS_Massage(){
#   Message
    InstanceName=`cat ${Tempspace}/${ProductName}_List_${confname}.txt | grep ${InstanceId} | awk -F ',' '{print $3}' | sort -ru`
    Tag=`cat ${Tempspace}/${ProductName}_List_${confname}.txt | grep ${InstanceId} | awk -F ',' '{print $5}' | sort -ru`
    Label=`echo ${Tag} | sed 's/map\[TagKey:/\n/g' | grep "App_NameTagValue:" | awk -F ':' '{print $2}' | sed 's/\]//g'`
    case $Label in
        '')
            Label=None
        ;;
        *)
        ;;
    esac

#   Usage
	declare -a ecs_proc
	declare -i ecs_proc_end
	ProcNum=1
	for MetricName in ${Metric[@]}
	do
		aliyun cms DescribeMetricTop --profile ${confname} --RegionId ${RegionId} --Period 3600 --Namespace acs_ecs_dashboard --MetricName ${MetricName} --StartTime ${StartTime} --EndTime ${EndTime} --Dimensions [{"instanceId":"${InstanceId}"}] --Orderby Maximum | grep "\"Datapoints\":" | tr '{' '\n' | grep -v Datapoints | awk -F '"' '{print $13,$15,$17,$6}' | sed 's/[:,\\]//g' | sort -ru > ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt
		case $MetricName in
			CPUUtilization)
				ecs_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | awk '{print $1}'` ; let ProcNum++ # CPU_Miximum
				ecs_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | awk '{print $2}'` ; let ProcNum++ # CPU_Maximum
				ecs_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | awk '{print $3}'` ; let ProcNum++ # CPU_Average
			;;
			*) #memory_usedutilization
				ecs_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | awk '{print $1}'` ; let ProcNum++ # MEM_Miximum
				ecs_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | awk '{print $2}'` ; let ProcNum++ # MEM_Maximum
				ecs_proc[$ProcNum]=`cat ${Tempspace}/${ProductName}_${InstanceId}_${MetricName}.txt | awk '{print $3}'` ; let ProcNum++ # MEM_Average
			;;
		esac
	done
	CPU_Maximum=${ecs_proc[2]}
	MEM_Maximum=${ecs_proc[5]}
    case ${CPU_Maximum} in
        '')
            CPU_Maximum=-1
        ;;
        *)
        ;;
    esac
    case ${MEM_Maximum} in
        '')
            MEM_Maximum=-1
        ;;
        *)
        ;;
    esac
    case ${CONNECT_Maximum} in
        '')
            CONNECT_Maximum=-1
        ;;
        *)
        ;;
    esac

#   Cost
    ECS_Cost
    Cost_PutOut=$?

#   OutPut
    echo -e "${EndTime},${RegionId},${Label},,${ProductName},${InstanceId},${InstanceName},${CPU_Maximum},${MEM_Maximum},,${Cost_PutOut}"
    echo "${EndTime},${RegionId},${Label},,${ProductName},${InstanceId},${InstanceName},${CPU_Maximum},${MEM_Maximum},,${Cost_PutOut}" >> ${Workspace}/OutPut.csv
}

function ECS(){
# 	获取实例列表
	for PageNumber in ${Page[@]}
	do
		aliyun ecs DescribeInstances --profile ${confname} --RegionId ${RegionId} --PageNumber ${PageNumber} --PageSize 50 --output cols=RegionId,InstanceId,InstanceName,InstanceType,Tags rows=Instances.Instance | sed s/[[:space:]]//g | sed s/\|/,/g | egrep -v "RegionId,InstanceId,InstanceName,InstanceType,Tags|--------,----------,------------,------------,----|^$" >> ${Tempspace}/${ProductName}_List_${confname}.txt
	done

#	查询实例监控数据
	Metric=(CPUUtilization memory_usedutilization)
	ProductCode_Name=ecs
	for InstanceId in `cat ${Tempspace}/${ProductName}_List_${confname}.txt | egrep -v "ack.aliyun.com" | awk -F ',' '{print $2}' | sort -ru`
	do
		ECS_Massage
	done
}

### ACK
function ACK_Message(){
	mkdir -p ${Tempspace}/${ProductName}_${Cluster_Name}
	kubectl config use-context ${Cluster_Name} &> /dev/null

#	获取节点资源配置总和
	kubectl get nodes -A -o custom-columns=:.metadata.name,:.status.capacity.cpu,:.status.capacity.memory,:spec.providerID | tr -s '[:space:]' | tr ' ' ',' > ${Tempspace}/${ProductName}_${Cluster_Name}_Node.txt
	CPU_Total=0
	MEM_Total=0
	Node_Cost_Total=0
	for Result in `cat ${Tempspace}/${ProductName}_${Cluster_Name}_Node.txt | egrep -v '^,$' | sort -ru`
	do
		Node_CPU=`echo ${Result} | awk -F ',' '{print $2}'`
        Node_CPU_proc=`echo "${Node_CPU} * 1000" | bc`
        CPU_Total_proc=`echo "${Node_CPU_proc} + ${CPU_Total}" | bc`
		Node_MEM=`echo ${Result} | awk -F ',' '{print $3}'`
        Node_MEM_proc=`echo ${Node_MEM} | sed 's/[a-z,A-Z]//g'`
        MEM_Total_proc=`echo "${Node_MEM_proc} + ${MEM_Total}" | bc`
		CPU_Total=${CPU_Total_proc}
        MEM_Total=${MEM_Total_proc}
		InstanceId=`echo ${Result} | awk -F ',' '{print $4}' | awk -F '.' '{print $2}' | sort -ru`
		sleep 1
        ECS_Cost
		Node_Cost=$?
        Node_Cost_Total_1=`echo "${Node_Cost_Total} + ${Node_Cost}" | bc`
        Node_Cost_Total=${Node_Cost_Total_1}
	done
	Cluster_Unit_Total=`echo "${CPU_Total} + ${MEM_Total}" | bc`
	echo "${Cluster_Name} ${CPU_Total} ${MEM_Total} ${Cluster_Unit_Total} ${Node_Cost_Total}" > ${Tempspace}/${ProductName}_${Cluster_Name}_Node_Total.txt

#	获取各Namespace Request总和
	kubectl get namespaces -A -o 'custom-columns=:.metadata.name' | egrep -v 'arms-prom|default|kube-node-lease|kube-public|kube-system|kruise-system|^$' > ${Tempspace}/${ProductName}_${Cluster_Name}_Namespace_List.txt
	All_CPU_Request_Total=0
	All_MEM_Request_Total=0
	for Namespace in `cat ${Tempspace}/${ProductName}_${Cluster_Name}_Namespace_List.txt`
	do
		Namespace_CPU_Request_Total=0
		Namespace_MEM_Request_Total=0
		kubectl get deployment -n ${Namespace} -o 'custom-columns=:.metadata.namespace,:.metadata.name,:.spec.template.spec.containers[0].resources.requests.cpu,:.spec.template.spec.containers[0].resources.requests.memory,:.status.availableReplicas' | tr -s '[:space:]' | tr ' ' ',' > ${Tempspace}/${ProductName}_${Cluster_Name}_AllNamespace_Request.txt
		for Result in `cat ${Tempspace}/${ProductName}_${Cluster_Name}_AllNamespace_Request.txt | egrep -v '^,$'`
		do
			Deployment=`echo ${Result} | awk -F ',' '{print $2}'`
			Dep_CPU_Request=`echo ${Result} | awk -F ',' '{print $3}'`
			Dep_MEM_Request=`echo ${Result} | awk -F ',' '{print $4}'`
			Dep_Pod_Num=`echo ${Result} | awk -F ',' '{print $5}'`
			if [[ ${Dep_CPU_Request} =~ ^[0-9]+$ ]]; then
				Dep_CPU_Request_proc=`echo "${Dep_CPU_Request} * 1000" | bc`
			elif [[ ${Dep_CPU_Request} =~ ^[0-9]+m$ ]]; then
				Dep_CPU_Request_proc=`echo ${Dep_CPU_Request} | sed 's/[a-z,A-Z]//g'`
			elif [[ ${Dep_CPU_Request} =~ ^\<[a-z\|A-Z]+\>$ ]]; then
				Dep_CPU_Request_proc=0
			else
				echo "错误！！！Request取值错误"
			fi
			if [[ ${Dep_MEM_Request} =~ ^[0-9]+Mi$ ]]; then
				Dep_MEM_Request_proc=`echo ${Dep_MEM_Request} | sed 's/[a-z,A-Z]//g'`
			elif [[ ${Dep_MEM_Request} =~ ^[0-9]+Mi$ ]]; then
				Dep_MEM_Request_1=`echo ${Dep_MEM_Request} | sed 's/[a-z,A-Z]//g'`
				Dep_MEM_Request_proc=`echo "$Dep_MEM_Request_1 * 1024" | bc`
			elif [[ ${Dep_MEM_Request} =~ ^[0-9]+Gi$ ]]; then
				Dep_MEM_Request_1=`echo ${Dep_MEM_Request} | sed 's/[a-z,A-Z]//g'`
				Dep_MEM_Request_proc=`echo "${Dep_MEM_Request_1} * 1024 * 1024" | bc`
			elif [[ ${Dep_MEM_Request} =~ ^\<[a-z\|A-Z]+\>$ ]]; then
				Dep_MEM_Request_proc=0
			else
				echo "错误！！！Request取值错误"
			fi
			if [[ ${Dep_Pod_Num} =~ ^\<[a-z\|A-Z]+\>$ ]]; then
				Dep_Pod_Num_proc=0
			else
				Dep_Pod_Num_proc=${Dep_Pod_Num}
			fi
			Dep_CPU_Request_Total=`echo "${Dep_CPU_Request_proc} * ${Dep_Pod_Num_proc}" | bc`
			Dep_MEM_Request_Total=`echo "${Dep_MEM_Request_proc} * ${Dep_Pod_Num_proc}" | bc`
			Namespace_CPU_Request_Total_1=`echo "${Namespace_CPU_Request_Total} + ${Dep_CPU_Request_Total}" | bc`
			Namespace_MEM_Request_Total_1=`echo "${Namespace_MEM_Request_Total} + ${Dep_MEM_Request_Total}" | bc`
			Namespace_CPU_Request_Total=${Namespace_CPU_Request_Total_1}	# Namespace CPU Request总和
			Namespace_MEM_Request_Total=${Namespace_MEM_Request_Total_1}	# Namespace MEM Request总和
		done
		echo "${Namespace} ${Namespace_CPU_Request_Total} ${Namespace_MEM_Request_Total}" > ${Tempspace}/${ProductName}_${Cluster_Name}/${Namespace}_RequestTotal.txt
		All_CPU_Request_Total_1=`echo "${All_CPU_Request_Total} + ${Namespace_CPU_Request_Total}" | bc`
		All_MEM_Request_Total_1=`echo "${All_MEM_Request_Total} + ${Namespace_MEM_Request_Total}" | bc`
		All_CPU_Request_Total=${All_CPU_Request_Total_1}	# CPU Request总和
		All_MEM_Request_Total=${All_MEM_Request_Total_1}	# MEM Request总和
	done
	All_Request_Unit_Total=`echo "${All_CPU_Request_Total} + ${All_MEM_Request_Total}" | bc`
	echo "${Cluster_Name} ${All_CPU_Request_Total} ${All_MEM_Request_Total}" > ${Tempspace}/${ProductName}_${Cluster_Name}/ClusterRequestTotal.txt
	CPU_Leave=`echo "${CPU_Total} - ${All_CPU_Request_Total}" | bc`	# CPU 剩余资源
	MEM_Leave=`echo "${MEM_Total} - ${All_MEM_Request_Total}" | bc`	# MEM 剩余资源

#	计算冗余状态
	for Namespace in `cat ${Tempspace}/${ProductName}_${Cluster_Name}_Namespace_List.txt`
	do
		Namespace_Cost=0
		Namespace_CPU_Request_Total=`cat ${Tempspace}/${ProductName}_${Cluster_Name}/${Namespace}_RequestTotal.txt | awk '{print $2}'`
		Namespace_MEM_Request_Total=`cat ${Tempspace}/${ProductName}_${Cluster_Name}/${Namespace}_RequestTotal.txt | awk '{print $3}'`
		CPU_Mix=`awk -v num1=${Namespace_CPU_Request_Total} -v num2=${CPU_Leave} 'BEGIN{printf("%.10f",num1/num2)}'`
		MEM_Mix=`awk -v num1=${Namespace_MEM_Request_Total} -v num2=${MEM_Leave} 'BEGIN{printf("%.10f",num1/num2)}'`
		CPU_Usage=`echo "${CPU_Mix} * 100" | bc`	# Namespace CPU 资源情况
		MEM_Usage=`echo "${MEM_Mix} * 100" | bc`	# Namespace MEM 资源情况
		Namespace_Unit_Total=`echo "${Namespace_CPU_Request_Total} + ${Namespace_MEM_Request_Total}" | bc`
		Namespace_Percentage=`awk -v num1=${Namespace_Unit_Total} -v num2=${All_Request_Unit_Total} 'BEGIN{printf("%.10f",num1/num2)}'`
		Cost_PutOut=`echo "${Node_Cost_Total} * ${Namespace_Percentage}" | bc`
		Label=`echo ${Namespace} | awk -F '-' '{print $1}' | awk -F '_' '{print $1}'`

        echo -e "${EndTime},${RegionId},${Label},${Namespace},${ProductName},${Cluster_Id},${Cluster_Name}.${Namespace},${CPU_Usage},${MEM_Usage},,${Cost_PutOut}"
		echo "${EndTime},${RegionId},${Label},${Namespace},${ProductName},${Cluster_Id},${Cluster_Name}.${Namespace},${CPU_Usage},${MEM_Usage},,${Cost_PutOut}" >> ${Workspace}/OutPut.csv
	done
}

function ACK(){
#	获取集群列表
	aliyun cs GET /api/v1/clusters  --page_size 50 --page_number 1 --header "Content-Type=application/json;" --body "{}" --output cols=region_id,cluster_id,name,size rows=clusters | sed s/[[:space:]]//g | sed s/\|/,/g | egrep -v "region_id,cluster_id,name,size|---------,----------,----,----|^$" | grep "${RegionId}" >> ${Tempspace}/${ProductName}_List_${confname}.txt
	cp $Homespace/kubeconfig_example.txt $HOME/.kube/config

#	查询实例监控数据
	for Cluster_Id in `cat ${Tempspace}/${ProductName}_List_${confname}.txt | awk -F ',' '{print $2}' | sort -ru`
	do
		Cluster_Name=`cat ${Tempspace}/${ProductName}_List_${confname}.txt | grep ${Cluster_Id} | awk -F ',' '{print $3}' | sort -ru`
		ACK_Message
	done 
}

function Clean(){
	rm -fr ${Tempspace}
}

function main(){
	rm -fr ${Workspace}
	Init
    printf "\xEF\xBB\xBF" > ${Workspace}/OutPut.csv
	echo "Time,Region,Label,ACK-NameSpace,ProductName,InstanceId,InstanceName/Cluster.Namespace,CPU,MEM,CONNECT,Cost" >> ${Workspace}/OutPut.csv
	for RegionName in ${Region[@]}
	do
		AccessConfigure
		for ProductName in ${Product[@]}
		do
			GetMessage &
		done
        wait
	done
	Clean
	echo "结果输出在 【 ${Workspace}/OutPut.csv 】"
}

main
scp ${Workspace}/OutPut.csv op@172.16.0.128:/opt/apps/backend_realdata/files/ops.csv
exit 0
