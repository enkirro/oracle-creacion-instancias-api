#!/bin/bash

# Cargar variables del archivo telegram.env
ENV_FILE="$HOME/oci-arm-host-capacity/telegram.env"
if [[ -f "$ENV_FILE" ]]; then
    export $(grep -v '^#' "$ENV_FILE" | xargs)
else
    echo "$ENV_FILE no encontrado"
    exit 1
fi

LOG_FILE="/$HOME/oci-arm-host-capacity/oci.log"

# Verificar que el token esta configurado
if [[ -z "$BOT_TOKEN" ]]; then
    echo "BOT_TOKEN no esta definido"
    exit 1
fi

# Buscamos el texto en el fichero de log, si existe, manda mensaje
if grep -qi 'already have an instance' "$LOG_FILE"; then
    MESSAGE="La instancia gratuita de Oracle se ha creado"
    curl -s -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
         -d chat_id="$CHAT_ID" --data-urlencode "text=$MESSAGE"
else
    echo "Texto no encontrado en el log. No se envia mensaje."
fi