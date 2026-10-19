создать разделяемый том:  
docker volume create shared_vol

собрать образ:  
docker build -t concurrent-manager .

запустить 1 контейнер на основе образа, с папкой shared внутри контейнера, к которой подключить созданный том:  
docker run -d --name container-1 -v shared_vol:/shared concurrent-manager

запустить 10 контейнеров:  
for i in $(seq 1 10); do  
    docker run -d --name "container-10-$i" -v shared_vol:/shared concurrent-manager  
done

запуск 50 контейнеров аналогичен

остановить и удалить первый контейнер:  
docker stop container-1  
docker rm container-1

остановить и удалить 10 контейнеров:  
docker stop $(docker ps -q --filter name=container-10-)  
docker rm $(docker ps -aq --filter name=container-10-)

50 аналогично

стереть образ:  
docker rmi concurrent-manager

стереть том:  
docker volume rm shared_vol
