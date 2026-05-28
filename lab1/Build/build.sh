#!/bin/sh

# Проверка наличия аргумента
if [ "$#" -ne 1 ]; then
    echo "Использование: $0 <исходный_файл>" >&2
    exit 1
fi

SRC_FILE="$1"

if [ ! -f "$SRC_FILE" ]; then
    echo "Ошибка: файл '$SRC_FILE' не найден." >&2
    exit 2
fi

# Абсолютный путь к каталогу исходного файла
SRC_DIR="$(cd "$(dirname "$SRC_FILE")" && pwd)"
SRC_BASENAME="$(basename "$SRC_FILE")"

# 1. Создание временного каталога
TMPDIR=$(mktemp -d)
if [ $? -ne 0 ]; then
    echo "Ошибка: не удалось создать временный каталог mktemp." >&2
    exit 3
fi

# 2. Настройка ловушки для удаления временного каталога при любом исходе
trap 'rm -rf "$TMPDIR"' EXIT
# Перехват сигналов прерывания: вызов exit спровоцирует срабатывание trap EXIT
trap 'exit 1' HUP INT QUIT TERM

# 3. Поиск имени конечного файла (по ключевому слову 'Output:')
# awk находит 'Output:' и берет следующее за ним слово
OUTPUT_NAME=$(awk '{for(i=1;i<=NF;i++) if($i=="Output:" && $(i+1)!="") {print $(i+1); exit}}' "$SRC_FILE")

if [ -z "$OUTPUT_NAME" ]; then
    echo "Ошибка: в файле не найден комментарий 'Output: <имя_файла>'." >&2
    exit 4
fi

# 4. Определение типа файла и сборка
EXT="${SRC_FILE##*.}"

case "$EXT" in
    c)
        gcc "$SRC_FILE" -o "$TMPDIR/$OUTPUT_NAME"
        COMPILATION_STATUS=$?
        ;;
    cpp|cc|cxx)
        g++ "$SRC_FILE" -o "$TMPDIR/$OUTPUT_NAME"
        COMPILATION_STATUS=$?
        ;;
    tex)
        # Копируем файл во временную директорию, чтобы там остались все побочные файлы (.aux, .log и т.д.)
        cp "$SRC_FILE" "$TMPDIR/$SRC_BASENAME"
        cd "$TMPDIR" || exit 5
        # pdflatex использует jobname для задания имени выходного файла (без расширения)
        JOBNAME="${OUTPUT_NAME%.*}"
        pdflatex -interaction=nonstopmode -jobname="$JOBNAME" "$SRC_BASENAME"
        COMPILATION_STATUS=$?
        cd - >/dev/null || exit 5
        ;;
    *)
        echo "Ошибка: неподдерживаемое расширение файла ($EXT)." >&2
        exit 6
        ;;
esac

# 5. Проверка кода возврата компилятора
if [ "$COMPILATION_STATUS" -ne 0 ]; then
    echo "Ошибка: компиляция завершилась с кодом $COMPILATION_STATUS." >&2
    exit 7
fi

# Проверка фактического создания файла
if [ ! -f "$TMPDIR/$OUTPUT_NAME" ]; then
    echo "Ошибка: выходной файл '$OUTPUT_NAME' не был сгенерирован компилятором." >&2
    exit 8
fi

# 6. Перемещение результата в исходный каталог (попутные файлы удалятся вместе с TMPDIR)
mv "$TMPDIR/$OUTPUT_NAME" "$SRC_DIR/"
if [ $? -ne 0 ]; then
    echo "Ошибка: не удалось переместить выходной файл." >&2
    exit 9
fi

echo "Успешно: $SRC_DIR/$OUTPUT_NAME"
exit 0