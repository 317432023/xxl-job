#!/bin/bash

# 编写shell脚本时，遇到 let: not found 错误 的解决办法：
# sudo dpkg-reconfigure dash 选择 “否”, 表示用bash代替dash
# 修改脚本首行为 #!/bin/bash

BOOT_JAR_NAME=xxl-job-admin
VERSION=-2.4.1-SNAPSHOT
# PIDFILE=/data/application/nwp-be/$BOOT_JAR_NAME.pid
PIDFILE=$BOOT_JAR_NAME.pid

# 运行端口号
PORT=8080

# Java 运行参数
JAVA_OPT="-server -Duser.timezone=GMT+08 -Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"
JAVA_OPT="$JAVA_OPT -XX:MetaspaceSize=512m"
JAVA_OPT="$JAVA_OPT -XX:MaxMetaspaceSize=512m"
JAVA_OPT="$JAVA_OPT -Xms1024m"
JAVA_OPT="$JAVA_OPT -Xmx1024m"
# 新生代一般设置为整个堆空间的1/3到1/4左右最合适
JAVA_OPT="$JAVA_OPT -Xmn256m"
JAVA_OPT="$JAVA_OPT -Xss256k"
JAVA_OPT="$JAVA_OPT -XX:SurvivorRatio=8"
# openjdk不支持此参数
#JAVA_OPT="$JAVA_OPT -XX:+UseConcMarkSweepGC"

# 系统参数
SYS_PRO=
SYS_PRO="$SYS_PRO -DserverId=$BOOT_JAR_NAME"

# SpringBoot 启动参数
BOOT_PAR=
BOOT_PAR="$BOOT_PAR --server.port=$PORT --server.tomcat.protocol_header=x-forwarded-proto --server.use-forward-headers=true"
# Tomcat优化参数
## 线程池的最小备用线程数，tomcat启动时的初始化的线程数
BOOT_PAR="$BOOT_PAR --server.tomcat.min-spare-threads=30"
## 线程池的最大线程数
BOOT_PAR="$BOOT_PAR --server.tomcat.max-threads=100"
## 最大连接数
BOOT_PAR="$BOOT_PAR --server.tomcat.max-connections=500"
## 排队数
BOOT_PAR="$BOOT_PAR --server.tomcat.accept-count=200"
## 最长等待时间
BOOT_PAR="$BOOT_PAR --server.tomcat.connection-timeout=10000ms"


EXEC="java $JAVA_OPT $SYS_PRO -jar $BOOT_JAR_NAME$VERSION.jar $BOOT_JAR_NAME.pid $BOOT_PAR"

# 试运行
TESTRUN=$EXEC

# 正式运行
START="nohup $EXEC > /dev/null 2>&1 &"

# 正式运行(生成运行日志 nohup.out)
STARTWITHLOG="nohup $EXEC > nohup.out &"


print_parm() {
    echo "JAVA_OPT=$JAVA_OPT"
    echo ""
    echo "SYS_PRO=$SYS_PRO"
    echo ""
    echo "BOOT_PAR=$BOOT_PAR"
}
stop_app() {
    if [ ! -f $PIDFILE ]
    then
        echo "$PIDFILE does not exist, process is not running"
        return 1
    else
        PID=$(cat $PIDFILE)
        echo "Stopping ..."

        # 有参数并且第一个参数等于1
        #if (( $# > 0 )) && (( $1 == 1 ))
        if [[ "$#" -gt 0 && "$1" -eq 1 ]];then
            # kill -9 ${PID}
            cat $PIDFILE | xargs kill
        else
            # sudo apt-get update
            # sudo apt install curl
            curl -X POST http://127.0.0.1:$PORT/shutDownContext
        fi

        # RETVAL="$?"
        # sleep 1
        # return "$RETVAL"

        count=0
        while [ -x /proc/${PID} ]
        do
            echo "Waiting for $BOOT_JAR_NAME to shutdown ..."
            sleep 1

            let count+=1

            # 12 秒后没有停止应用则尝试强制结束进程
            if [ $count -eq 12 ]
            then
                echo '结束程序超时，强制结束进程...'
                cat $PIDFILE | xargs kill
                sleep 1
                if [ $(lsof -i:${PORT}|wc -l) -gt 0 ]
                then
                    echo '强制结束进程成功。'
                fi
                break
            fi

        done
        echo "$BOOT_JAR_NAME stopped"

        # 删除进程文件
        rm -f $PIDFILE

        return 1
    fi
}

start_app() {
    # Start the daemon/service
    #
    # Returns:
    #   0 if daemon has been started
    #   1 if daemon was already running
    #   2 if daemon could not be started
    if [ -f $PIDFILE ]
    then
        echo "$PIDFILE exists, process is already running or crashed"
        return 1
    else
        echo "Starting $BOOT_JAR_NAME..."

        sleep 1

        if [[ "$#" -gt 0 && "$1" -eq 1 ]];then
            nohup $EXEC > /dev/null 2>&1 &
        else
            nohup $EXEC > nohup.out &
	    sleep 1
	    tail -f nohup.out
        fi

        sleep 10
        if [ -f $PIDFILE ];then

            PID=$(cat $PIDFILE)
            if [ -x /proc/${PID} ];then
                return 0
            else
                return 2
            fi
        else
            return 2
        fi

        # tail -f /data/applogs/${BOOT_JAR_NAME}*/logs/info.log
    fi
}

case "$1" in
    testrun)
        if [ -f $PIDFILE ]
        then
            echo "$PIDFILE exists, process is already running or crashed"
        else
            echo "Test Run $BOOT_JAR_NAME..."

            print_parm

            sleep 1

            # 试运行
            $EXEC
        fi
        ;;
    start)
        start_app 1
        case "$?" in
            0)
                echo 'ok'
                ;;
            1)
                echo 'Old process is still running'
                ;;
            *)
                echo 'Failed to start'
                ;;
        esac
        ;;
    startwithlog)
        start_app 2
        ;;
    stop)
        stop_app 2
        ;;

    restart)
        stop_app 2
        case "$?" in
            0|1)
                start_app 1
                case "$?" in
                    0)
                        echo 'ok'
                        ;;
                    1)
                        echo 'Old process is still running'
                        ;;
                    *)
                        echo 'Failed to start'
                        ;;
                esac
                ;;
            *)
                echo 'Failed to stop'
                ;;
         esac
         ;;

    *)
        echo "Please use start or stop as first argument"
        ;;

esac


echo 按任意键退出
read -n 1
