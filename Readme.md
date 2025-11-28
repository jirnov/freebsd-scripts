Текущий репозиторий содержит скрипты для моего сайта.
Это два генератора, которые получают содержимое постов с помощью wp-cli и отправляют его в YandexGPT для обработки

* `keywords_generator.sh` - генератор ключевых слов
* `meta_generator.sh` - генератор короткого описания

Настройки хранятся в файле `.env`, пример:
```
YANDEXGPT_FOLDER_ID=your_folder_id
YANDEXGPT_API_KEY=your_api_key
```

