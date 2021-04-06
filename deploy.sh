#!/bin/bash

#타겟 서버에 배포 디렉토리(/home/ec2-user/app/dist)를 생성합니다.
#scp 명령어로 로컬 build 디렉터리에서 jar파일을 타겟서버 배포 디렉터리로 전송합니다.
#전송한 jar파일에 대한 심볼릭 링크를 생성합니다.
#배포시 버전에 따른 Jar파일명을 하나의 이름으로만 관리함으로써 Jar실행시 최신 버전의 Jar파일 이름을 알아내야할 필요가 없게 해주는 용도입니다.
#현재 실행중인 서버를 조회합니다. 8083이 띄워져 있으면 새로 업데이트된 jar파일로 8084로 서버를 한대 더 실행합니다.
#신규 서버 스타트가 완료되면(health체크를 5초마다 실행) 기존에 실행되고 있던 서버는 종료합니다.
#위에서 Gracefully shutdown을 적용했으므로 연결되어있던 커넥션은 모두 처리되고 서버가 종료됩니다.
#서버리스트에 여러개의 서버가 나열되어 있었다면 위의 작업이 서버수만큼 반복됩니다.

#deploy shell은 인자로 profile을 받습니다. $ ./deploy.sh alpha
#위에서 생성한 배포 환경의 디렉토리로 PROJECT관련 정보를 세팅합니다.
#PROJECT_HOME은 배포에 필요한 여러가지 파일이나 정보를 모아두는 배포 홈 디렉터리 입니다.
#SVR_LIST는 server_alpha.list파일을 읽어서 배포 대상 서버 리스트를 가져옵니다.
#DEPLOY_PATH는 배포 대상 서버에 생성되는 디렉토리입니다. 각자의 환경에 맞게 변경합니다. AWS_ID도 환경에 맞게 변경합니다.
#그외 현재 일자, JVM설정 옵션, PEM파일 위치 등을 세팅합니다.

PROFILE=$1
PROJECT=SpringRestApi
PROJECT_HOME=/Users/test/deploy/${PROJECT}
JAR_PATH=${PROJECT_HOME}/build/libs/api-gradle-0.0.1-SNAPSHOT.jar
SVR_LIST=server_${PROFILE}.list
SERVERS=`cat $SVR_LIST`
DEPLOY_PATH=/home/ec2-user/app
AWS_ID=ec2-user
DATE=`date +%Y-%m-%d-%H-%M-%S`
JAVA_OPTS="-XX:MaxMetaspaceSize=128m -XX:+UseG1GC -Xss1024k -Xms128m -Xmx128m -Dfile.encoding=UTF-8"
PEM=AwsFreetierKeyPair.pem
PORT=8083

echo Deploy Start
for server in $SERVERS; do
    echo Target server - $server
    # Target Server에 배포 디렉터리 생성
    ssh -i $PEM $AWS_ID@$server "mkdir -p $DEPLOY_PATH/dist"
    # Target Server에 jar 이동
    echo 'Executable Jar Copying...'
    scp -i $PEM $JAR_PATH $AWS_ID@$server:~/app/dist/$PROJECT-$DATE.jar
    # 이동한 jar파일의 바로가기(SymbolicLink)생성
    ssh -i $PEM $AWS_ID@$server "ln -Tfs $DEPLOY_PATH/dist/$PROJECT-$DATE.jar $DEPLOY_PATH/$PROJECT"
    echo 'Executable Jar Copyed'
    # 현재 실행중인 서버 PID 조회
    runPid=$(ssh -i $PEM $AWS_ID@$server pgrep -f $PROJECT)
    if [ -z $runPid ]; then
        echo "No servers are running"
    fi
    # 현재 실행중인 서버의 포트를 조회. 추가로 실행할 서버의 포트 선정
    runPortCount=$(ssh -i $PEM $AWS_ID@$server ps -ef | grep $PROJECT | grep -v grep | grep $PORT | wc -l)
    if [ $runPortCount -gt 0 ]; then
        PORT=8084
    fi
    echo "Server $PORT Starting..."
    # 새로운 서버 실행
    ssh -i $PEM $AWS_ID@$server "nohup java -jar -Dserver.port=$PORT -Dspring.profiles.active=$PROFILE $JAVA_OPTS $DEPLOY_PATH/$PROJECT < /dev/null > std.out 2> std.err &amp;"
    # 새롭게 실행한 서버의 health check
    echo "Health check $PORT"
    for retry in {1..10}
    do
        health=$(ssh -i $PEM $AWS_ID@$server curl -s http://localhost:$PORT/actuator/health)
        checkCount=$(echo $health | grep 'UP' | wc -l)
        echo "Check count - $checkCount"
        if [ $checkCount -ge 1 ]; then
            echo "Server $PORT Started Normaly"
#           # 기존 서버 Stop
#           if [ $runPid -gt 0 ]; then
#                echo "Server $runPid Stopping..."
#                ssh -i $PEM $AWS_ID@$server "kill -TERM $runPid"
#                sleep 5
#                echo "Server $runPid Stopped"
#           fi
            if [ $runPid -gt 0 ]; then
                echo "Server $runPid Stop"
                ssh -i $PEM $AWS_ID@$server "kill -TERM $runPid"
                sleep 5
                echo "Nginx Port Change"
        ssh -i $PEM $AWS_ID@$server "echo 'set \$service_addr http://127.0.0.1:$PORT;' | sudo tee /etc/nginx/conf.d/service_addr.inc"
                echo "Nginx reload"
        ssh -i $PEM $AWS_ID@$server "sudo service nginx reload"
            fi
            break;
        else
            echo "Check - false"
        fi
        sleep 5
    done
    if [ $retry -eq 10 ]; then
        echo "Deploy Fail"
    fi
done
echo Deploy End