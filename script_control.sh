#!/bin/bash

fix_mode='0'  # 0 - штатная работа скрипта; 1 - сервис мод, скрипт не работает 
if [ "$fix_mode" -eq "0" ]
then
        control=$(ps aux | grep "/usr/local/sbin/server_control.sh" | wc -l)

        if [ "$control" -lt "2" ]
        then                
                kill -9 $(ps aux | grep "/usr/local/sbin/server_control.sh" | awk '{print $2}')
                /usr/local/sbin/server_control.sh
        else
                echo 'allok'
        fi
else
        kill -9 $(ps aux | grep "/usr/local/sbin/server_control.sh" | awk '{print $2}')
fi