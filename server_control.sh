#!/bin/bash
#

#Перменные:
gateWay='192.168.50.1' #Адрес шлюза для проверки сетевого подключения
winaddr='192.168.50.203' #Адрес ВМ Windows
linaddr='192.168.50.201' #Адрес ВМ Linux
oracladdr='192.168.50.207' #Адрес ВМ БД
qmwinid='103' #Windows VM ID
qmlinid='101' #Linux VM ID
qmoraclid='107' #DB VM ID
lvGroupName='vg_drbd1' #Имя ВГ группы

#Логирование
echo -e "\nScript started at: `date` \nVariables are: \nGateWay is $gateWay\nwinaddr is $winaddr\nlinaddr is $linaddr\noracladdr is $oracladdr\nqmwinid is $qmwinid\nqmlinid is $qmlinid\nqmoraclid is $qmoraclid" >> /var/log/nodes_control.log

stop_vms(){     # Функция для остановки ВМ
		echo -e "$(date) Stop VMs" >> /var/log/nodes_control.log
		if [ "$(/usr/sbin/qm status "$qmwinid" | grep -c running)" -eq "1" ]
                then /usr/sbin/qm stop $qmwinid
        fi
        if [ "$(/usr/sbin/qm status "$qmlinid" | grep -c running)" -eq "1" ]
                then /usr/sbin/qm stop $qmlinid
        fi
        if [ "$(/usr/sbin/qm status "$qmoraclid" | grep -c running)" -eq "1" ]
                then /usr/sbin/qm stop $qmoraclid
        fi
}

start_vms(){  # Функция для старта ВМ
			echo -e "$(date) Start VMs" >> /var/log/nodes_control.log
			if [ "$(/usr/sbin/qm status "$qmwinid" | grep -c running)" -eq "0" ]
                then /usr/sbin/qm start $qmwinid
			fi
			if [ "$(/usr/sbin/qm status "$qmlinid" | grep -c running)" -eq "0" ]
                then /usr/sbin/qm start $qmlinid
			fi
			if [ "$(/usr/sbin/qm status "$qmoraclid" | grep -c running)" -eq "0" ]
                then /usr/sbin/qm start $qmoraclid
			fi
}

check_vms_and_network() {
    if [ "$(/usr/sbin/qm status "$qmlinid" | grep -c running)" -eq "1" ] && \
       [ "$(/usr/sbin/qm status "$qmwinid" | grep -c running)" -eq "1" ] && \
       [ "$(/usr/sbin/qm status "$qmoraclid" | grep -c running)" -eq "1" ] && \
       [ "$(ping -c5 -q "$linaddr" | grep transmitted | cut -d" " -f4)" -ge "3" ] && \
       [ "$(ping -c5 -q "$winaddr" | grep transmitted | cut -d" " -f4)" -ge "3" ] && \
       [ "$(ping -c5 -q "$oracladdr" | grep transmitted | cut -d" " -f4)" -ge "3" ]
    then
        return 0  # Успех
    else
        return 1  # Ошибка
    fi
}

check_vms_ping() {
    if [ "$(ping -c5 -q "$linaddr" | grep transmitted | cut -d" " -f4)" -ge "3" ] && \
       [ "$(ping -c5 -q "$winaddr" | grep transmitted | cut -d" " -f4)" -ge "3" ] && \
       [ "$(ping -c5 -q "$oracladdr" | grep transmitted | cut -d" " -f4)" -ge "3" ]
    then
        return 0  # Успех
    else
        return 1  # Ошибка
    fi
}

while true; do

  if [ "$(cat /proc/drbd | grep "cs:" | cut -d":" -f4 | cut -d" " -f1 | cut -d"/" -f1 | grep Primary | wc -l)" -eq "1" ] # Проверка
  then # Логика для Primary ноды    
    if check_vms_and_network
	then		
		if [ "$(ping -c5 -q "$gateWay" | grep transmitted | cut -d" " -f4)" -ge "3" ]
	  then
			echo -e "$(date) NTD, VMs working on THIS node" >> /var/log/nodes_control.log
	  else
			echo -e "$(date) Gatewau not pinging." >> /var/log/nodes_control.log
			stop_vms
			sleep 5
			/usr/sbin/lvchange -a n /dev/$lvGroupName
			sleep 5
			/usr/sbin/drbdadm secondary all
	  fi	      
    else      
		if check_vms_ping
		then
			echo -e "$(date)VMs working on ANOTHER node, stoping VMs" >> /var/log/nodes_control.log
			stop_vms
			sleep 5
			/usr/sbin/lvchange -a n /dev/$lvGroupName
			sleep 5
			/usr/sbin/drbdadm secondary all
		else
			echo -e "$(date) VMs is down on THIS node, trying to start..." >> /var/log/nodes_control.log
			start_vms
			
			sleep 40
			
			if check_vms_and_network
			then
				echo -e "$(date) NTD, VMs successfully started on ANOTHER node" >> /var/log/nodes_control.log
			else
				echo -e "$(date) VMs not started. Use Slave node" >> /var/log/nodes_control.log
				stop_vms
				sleep 5
				/usr/sbin/lvchange -a n /dev/$lvGroupName
				sleep 5
				/usr/sbin/drbdadm secondary all
			fi
		fi
    fi
  else # Логика для Secondary ноды    
    if check_vms_ping
	then           
		echo -e "$(date) NTD, VMs working in ANOTHER node" >> /var/log/nodes_control.log	
    else
      if [ "$(ping -c5 -q "$gateWay" | grep transmitted | cut -d" " -f4)" -ge "3" ]
	  then
		sleep 100
		if check_vms_ping
		then 
			echo -e "$(date) NTD, VMs successfully started on ANOTHER node" >> /var/log/nodes_control.log
		else
   echo -e "$(date) become primary and start vms" >> /var/log/nodes_control.log  			
			/usr/sbin/drbdadm primary all
			sleep 5
			/usr/sbin/lvchange -a y /dev/$lvGroupName
			sleep 5
			start_vms
			sleep 40
		fi	  
	  else
		echo -e "$(date) GeteWay is down, NTD" >> /var/log/nodes_control.log 
	  fi
    fi
  fi 

echo -e "$(date) Start new iteration" >> /var/log/nodes_control.log
done


