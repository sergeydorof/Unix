#!/bin/sh

SHARED_DIR="/shared"
LOCK_FILE="$SHARED_DIR/.sync.lock"

# Генерация случайного идентификатора контейнера (8 hex символов)
CONTAINER_ID=$(od -vAn -N4 -tx1 < /dev/urandom | tr -d ' \n')
SEQ_NUM=1

# Создание директории, если она не существует
mkdir -p "$SHARED_DIR"

# Открытие файлового дескриптора 9 для управления блокировками
exec 9>> "$LOCK_FILE"

while true; do
    # --- НАЧАЛО АТОМАРНОЙ ОПЕРАЦИИ ---
    # Эксклюзивная блокировка
    flock -x 9
    
    i=1
    while true; do
        FILENAME=$(printf "%03d" "$i")
        FILEPATH="$SHARED_DIR/$FILENAME"
        
        # Поиск первого незанятого имени
        if [ ! -e "$FILEPATH" ]; then
            echo "$CONTAINER_ID $SEQ_NUM" > "$FILEPATH"
            break
        fi
        i=$((i + 1))
    done
    
    # Снятие блокировки
    flock -u 9
    # --- КОНЕЦ АТОМАРНОЙ ОПЕРАЦИИ ---

    # Задержка в 1 секунду
    sleep 1

    # Удаление файла
    rm -f "$FILEPATH"

    # Увеличение порядкового номера для следующей итерации
    SEQ_NUM=$((SEQ_NUM + 1))
done