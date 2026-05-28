#include <iostream>
#include <filesystem>
#include <fstream>
#include <unordered_map>
#include <vector>
#include <string>
#include <iomanip>
#include <openssl/sha.h>

namespace fs = std::filesystem;

// Функция для вычисления SHA-256 файла (чтение блоками для экономии ОЗУ)
std::string compute_hash(const fs::path& filepath) {
    std::ifstream file(filepath, std::ios::binary);
    if (!file) {
        throw std::runtime_error("Не удалось открыть файл для чтения");
    }

    SHA256_CTX sha256;
    SHA256_Init(&sha256);
    
    char buffer[8192];
    while (file.read(buffer, sizeof(buffer))) {
        SHA256_Update(&sha256, buffer, file.gcount());
    }
    // Дописываем остаток
    if (file.gcount() > 0) {
        SHA256_Update(&sha256, buffer, file.gcount());
    }

    unsigned char hash[SHA256_DIGEST_LENGTH];
    SHA256_Final(hash, &sha256);

    std::stringstream ss;
    for (int i = 0; i < SHA256_DIGEST_LENGTH; i++) {
        ss << std::hex << std::setw(2) << std::setfill('0') << (int)hash[i];
    }
    return ss.str();
}

void deduplicate_directory(const fs::path& dir_path) {
    // Хранит хэш файла и путь к первому найденному экземпляру
    std::unordered_map<std::string, fs::path> hash_map;

    try {
        for (const auto& entry : fs::recursive_directory_iterator(dir_path)) {
            if (fs::is_regular_file(entry.status())) {
                try {
                    std::string file_hash = compute_hash(entry.path());
                    auto it = hash_map.find(file_hash);

                    if (it != hash_map.end()) {
                        // Если файлы уже являются жесткими ссылками на один и тот же inode, пропускаем
                        if (!fs::equivalent(entry.path(), it->second)) {
                            fs::remove(entry.path()); // Удаляем дубликат
                            fs::create_hard_link(it->second, entry.path()); // Создаем жесткую ссылку на оригинал
                            
                            std::cout << "[LINKED] " << entry.path() << " -> " << it->second << "\n";
                        }
                    } else {
                        // Сохраняем первый экземпляр уникального файла
                        hash_map[file_hash] = entry.path();
                    }
                } catch (const std::exception& e) {
                    std::cerr << "Ошибка обработки файла " << entry.path() << ": " << e.what() << "\n";
                }
            }
        }
    } catch (const fs::filesystem_error& e) {
        std::cerr << "Ошибка доступа к директории: " << e.what() << "\n";
    }
}

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cerr << "Использование: " << argv[0] << " <путь_к_каталогу>\n";
        return 1;
    }

    fs::path target_dir = argv[1];
    if (!fs::exists(target_dir) || !fs::is_directory(target_dir)) {
        std::cerr << "Указан неверный путь или каталог не существует.\n";
        return 1;
    }

    deduplicate_directory(target_dir);
    
    std::cout << "Дедупликация завершена.\n";
    return 0;
}