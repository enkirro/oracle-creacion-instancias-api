#!/bin/bash

# Cargar variables del archivo telegram.env
ENV_FILE="~/oci-arm-host-capacity/telegram.env"
if [[ -f "$ENV_FILE" ]]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "$ENV_FILE no encontrado"
    exit 1
fi

LOG_FILE="~/oci-arm-host-capacity/oci.log"

# Verificar que el token esta configurado
if [[ -z "$BOT_TOKEN" ]]; then
    echo "BOT_TOKEN no esta definido"
    exit 1
fi

BLOCK=""
FOUND_LIMIT_EXCEEDED=false

while read -r line; do
    BLOCK+="$line"$'\n'

    if [[ "$line" == "}" ]]; then
        if echo "$BLOCK" | grep -q '"code": "LimitExceeded"'; then
            FOUND_LIMIT_EXCEEDED=true
            break
        fi
        BLOCK=""
    fi
done < "$LOG_FILE"

# Solo enviar mensaje si se ha encontrado
if $FOUND_LIMIT_EXCEEDED; then
    MESSAGE="La instancia gratuita de Oracle se ha creado"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
         -d chat_id="$CHAT_ID" --data-urlencode "text=$MESSAGE"
fi