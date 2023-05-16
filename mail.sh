#!/bin/bash

# Definició d'usuaris i correus electrónics
declare -A users=(
["8002"]="carlos.sanchez@daca.com"
["8001"]="david.izquierdo@daca.com"
  ["7001"]="alejandro.maldonado@daca.com"
  ["7002"]="jose.generoso@daca.com"
  ["default"]="daca@daca.com"
)

# Definició de directoris a monitoritzar
declare -a dirs=(
"/var/spool/asterisk/voicemail/default/8002/INBOX"
"/var/spool/asterisk/voicemail/default/8001/INBOX"
  "/var/spool/asterisk/voicemail/default/7001/INBOX"
  "/var/spool/asterisk/voicemail/default/7002/INBOX"
)

# Funció per enviar correu electrónic amb arxius adjunts
send_email() {
  sleep 30
  IFS='/' read -ra path <<< "$1"
  user="${path[-3]}"
  dest="${users[$user]}"
  hora=$(date +"%T")
  cuerpo="Tens un nou missatge en la bustia de veu - Hora en la que li han deixat el missatge = $hora"
  echo "$cuerpo" | mailx -s "Mensaje de voz" -A "$1" "$dest"
}

# Monitorització de directoris
inotifywait -m -e create --format '%w%f' "${dirs[@]}" | while read file
do
  send_email "$file"
done
