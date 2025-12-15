#!/usr/bin/env bash

# Конфигурация
source ~/.env
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
create_post_keywords() {
  local content="$1"
  local prompt="Составь несколько ключевых слов из статьи для SEO одной строкой через запятую (7-10 слов максимум):\n\n$content"
  local json_payload
  json_payload=$(wrap_for_yandexgpt "$prompt")

  response=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Api-Key $API_KEY" \
    -H "x-folder-id: $FOLDER_ID" \
    -d "$json_payload" \
    "$API_URL")

  echo "$response" | jq -r '.result.alternatives[0].message.text'
}

update_post_keywords() {
  local post_id=$1
  local keywords="$2"
  wp --allow-root post meta update "$post_id" "b2k_post_keywords" "$keywords"
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

posts_data=$(wp post list --allow-root --post_type=post --fields=ID,post_title,post_content --format=json --post_status=publish)

post_ids=$(echo "$posts_data" | jq .[].ID)

for post_id in $post_ids; do
  title=$(get_post_title "$posts_data" "$post_id")
  echo "ЗАГОЛОВОК: \"$title\""
  content=$(get_post_content "$posts_data" "$post_id")
  post_keywords=$(create_post_keywords "$content")
  echo "КЛЮЧЕВЫЕ СЛОВА: \"$post_keywords\""

  while true; do
    read -r -n1 -p "Обновить цитату? (y - да, n - пропустить, q - выход) " choice
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
    echo

    case $choice in
      y)
        update_post_keywords "$post_id" "$post_keywords"
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

