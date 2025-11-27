#!/usr/bin/env bash

# Конфигурация
source .env
FOLDER_ID=$YANDEXGPT_FOLDER_ID
API_KEY=$YANDEXGPT_API_KEY
API_URL="https://llm.api.cloud.yandex.net/foundationModels/v1/completion"

wrap_for_yandexgpt() {
  local text="$1"

  jq -n \
    --arg text "$text" \
    --arg folder "$FOLDER_ID" \
    '{
      "modelUri": "gpt://\($folder)/yandexgpt-lite",
      "completionOptions": {
        "stream": false,
        "temperature": 0.3,
        "maxTokens": "2000"
      },
    "messages": [
    {
      "role": "user",
      "text": $text
    }
  ]
}'
}

# Функция для отправки запроса
create_post_excerpt() {
  local content="$1"
  local prompt="Сделай краткое метаописание статьи (до 60 слов):\n\n$content"
  local json_payload
  json_payload=$(wrap_for_yandexgpt "$prompt")

  # Выполняем запрос и сохраняем ответ в переменную
  local response
  response=$(curl -s -w "\nHTTPSTATUS:%{http_code}" -X POST -H "Content-Type: application/json" -H "Authorization: Api-Key $API_KEY" -H "x-folder-id: $FOLDER_ID" -d "$json_payload" $API_URL)

  # Проверяем, что curl выполнился успешно
  if [ $? -ne 0 ]; then
    echo "Ошибка выполнения curl" >&2
    return 1
  fi

  # Извлекаем HTTP код и тело ответа
  local http_code
  local body
  http_code=$(echo "$response" | sed -n 's/HTTPSTATUS://p')
  body=$(echo "$response" | sed '$d')

  # Проверяем HTTP-код
  if [ "$http_code" -ne 200 ]; then
    echo "ошибка HTTP: $http_code" >&2
    return 1
  fi

  # Проверяем наличие ошибки в теле ответа
  if echo "$body" | jq -e '.error' >/dev/null 2>&1; then
    local error_msg
    error_msg=$(echo "$body" | jq -r '.error.message // .error')
    echo "ошибка API: $error_msg" >&2
    return 1
  fi  

  # Извлекаем текст
  local result
  result=$(echo "$body" | jq -r '.result.alternatives[0].message.text // empty')

  if [ -z "$result" ]; then
    echo "пустой ответ от API" >&2
    return 1
  fi

  local status
  status=$(echo "$body" | jq -r '.result.alternatives[0].status // empty')

  if [ "$status" == "ALTERNATIVE_STATUS_CONTENT_FILTER" ]; then
    echo "[cencored]"
    return 1
  fi

  echo "$result"
  return 0
}

update_post_excerpt() {
  local post_id=$1
  local excerpt="$2"
  wp --allow-root post update "$post_id" --post_excerpt="$excerpt"
}

get_post_excerpt() {
  local post_id=$1
  wp --allow-root post get "$post_id" --field=post_excerpt
}

get_post_title() {
  local posts_data="$1"
  local post_id="$2"

  echo "$posts_data" | jq ".[] | select(.ID==$post_id) | .post_title"
}

get_post_content() {
  local posts_data="$1"
  local post_id="$2"

  echo "$posts_data" | jq ".[] | select(.ID==$post_id) | .post_content"
}


cd /usr/local/www/wordpress || exit

posts_data=$(wp post list --allow-root --post_type=post --fields=ID,post_title,post_content,post_excerpt --format=json --post_status=publish | jq 'map(select(.post_excerpt=="" or .post_excerpt==null))')

post_ids=$(echo "$posts_data" | jq .[].ID)

for post_id in $post_ids; do
  title=$(get_post_title "$posts_data" "$post_id")
  echo "ЗАГОЛОВОК: $title"
  content=$(get_post_content "$posts_data" "$post_id")
  post_excerpt=$(create_post_excerpt "$content")
  exit_code=$?

  if [ $exit_code -ne 0 ]; then
    echo "ОШИБКА ПОЛУЧЕНИЯ ЦИТАТЫ: $post_excerpt"
    echo
    continue
  fi

  echo "ЦИТАТА: \"$post_excerpt\""

  while true; do
    read -r -n1 -p "Обновить цитату? (y - да, n - пропустить, q - выход) " choice
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
    echo

    case $choice in
      y)
        update_post_excerpt "$post_id" "$post_excerpt"
        break
        ;;
      n)
        break
        ;;
      q)
        exit 0
        ;;
      *)
        continue
        ;;
    esac
  done

  echo
done

cd - || exit

