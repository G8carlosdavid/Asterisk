#!/bin/bash

# Funció per crear un nou usuari en el sistema
create_user() {
    # Preguntar por el nombre de usuario usando Zenity
    username=$(zenity --entry --text="Introdueix el nom d'usuari (nom.cognom):")

    # Comprova si existeix
    if id "$username" >/dev/null 2>&1; then
        zenity --error --text="L'usuari ja existeix en el sistema."
        return 1
    fi

    # Pregunta pel password
    password=$(zenity --password --title="Crear Usuari" --text="Introdueix la contrasenya:")

    # Preguntar si l'usuario vol continuar
    if ! zenity --question --title="Confirmar" --text="¿Esta segur de crea l'usuari? Es reiniciaran els servidors."; then
        return 1
    fi

    # Crear usuari
    sudo useradd -m -s /sbin/nologin "$username"
    echo "$username:$password" | sudo chpasswd
    echo "Usuario $username creado."

    # Afegeix l'extensió en sip.conf
    extension=$(zenity --entry --text="Introdueix la extensió (4 números):")

    # Comprova si la extensió ja existeix
    if grep -q "\[$extension\]" /etc/asterisk/sip.conf; then
        zenity --error --text="La extensió ja existeix en sip.conf."
        return 1
    fi

    sudo sh -c "cat >> /etc/asterisk/sip.conf" << EOF
[$extension]
type=friend
host=dynamic
secret=$extension
context=internal
mailbox=$extension@internal

EOF

    zenity --info --text="Extensió $extension afegida en sip.conf."

    # Afegeix la extensió en extensions.conf
    sudo sh -c "cat >> /etc/asterisk/extensions.conf" << EOF
exten => $extension,1,Answer()
 same => n,Dial(SIP/$extension,10)
 same => n,Wait(1)
 same => n,Playback(PIP)
 same => n,Wait(1)
 same => n,Record(/var/spool/asterisk/voicemail/default/$extension/INBOX/msg\${STRFTIME(\${EPOCH},,\%Y\%m\%d-\%H\%M\%S)}.wav,0,60,k)
 same => n,Playback(vm-message-recording)
 same => n,Wait(1)
 same => n,Hangup()
 
EOF

    zenity --info --text="Extensió $extension afegida en extensions.conf."

    # Afegeix la direcció de correu electrónic en mail.sh
    email=$(zenity --entry --text="Introdueix la direcció de correu electrónic (nom.cognom@daca.com):")

    # Comprova si la extensió ja té una direcció de correo electrónico associada
    if grep -q "$extension" /usr/local/bin/mail.sh; then
        zenity --error --text="La extensió ja té una direcció de correu electrónic associada."
        return 1
    fi

    sudo sh -c "sed -i '/declare -A users=/a [\"$extension\"]=\"$email\"' /usr/local/bin/mail.sh"

    sudo sh -c "sed -i '/declare -a dirs=/a \"/var/spool/asterisk/voicemail/default/$extension/INBOX\"' /usr/local/bin/mail.sh"

    zenity --info --text="Direcció de correu electrónic $email associada a la extensió $extension en mail.sh."

    # Reiniciem els serveis que hem modificat i creem els directoris a monitoritzar
    sudo systemctl restart asterisk.service
    sudo mkdir -p /var/spool/asterisk/voicemail/default/$extension/INBOX
    sudo chown asterisk:asterisk /var/spool/asterisk/voicemail/default/$extension/INBOX
    sudo systemctl restart mail.service
}

delete_user() {
    # Obtenim una llista d'usuaris del sistema que tinuin un directori d'inici (/home) y emmagtzemar-la en la variable "users"
    users=$(awk -F':' '/\/home/{print $1}' /etc/passwd)

    # Mostra la lista de usuaris utilizant Zenity
    username=$(zenity --list --title="Eliminar usuari" --text="Seleccioni l'usuario que vol eliminar:" --column=Usuarios $users)

    if [ -z "$username" ]; then
        zenity --warning --text="Ha de seleccionar un usuari."
        return
    fi

    zenity --question --title="Eliminar usuari" --width=400 --text="Está segur d'eliminar  l'usuari $username del sistema? Al eliminar l'usuari s'eliminarà també el correu associat i tota la seva configuració"

    if [ "$?" -eq 0 ]; then
        sudo userdel -r "$username"
        zenity --info --text="L'usuario $username s'ha eliminat correctament del sistema."

        # Demanar a l'usuari que introdueixi la extensió que desitgi eliminar
        extension=$(zenity --entry --title="Eliminar extensió" --text="Introdueixi la extensió que vol eliminar:")

        # Si se ha especificat una extensió, procedeix a la eliminació
        if [ -n "$extension" ]; then
            # Crea un arxiu temporal de /etc/asterisk/extensions.conf
            temp_file=$(mktemp /etc/asterisk/extensions.conf.XXXXXX)

            # Copiar el contingut de /etc/asterisk/extensions.conf al arxiu temporal, eliminant la extensió proporcionada
            awk -v ext="$extension" '{ if ($0 ~ ext && !flag) { flag=1 }; if (!flag) print $0; if ($0 ~ /^$/ && flag) flag=0 }' /etc/asterisk/extensions.conf > "$temp_file"

            # Mou l'arxiu temporal a /etc/asterisk/extensions.conf
            sudo mv "$temp_file" /etc/asterisk/extensions.conf

            # Crea un archivo temporal de /etc/asterisk/sip.conf
            temp_file=$(mktemp /etc/asterisk/sip.conf.XXXXXX)

            # Copia el contingut de /etc/asterisk/sip.conf a l'arxiu temporal, eliminant la secció corresponent a la extensió proporcionada
            awk -v ext="$extension" 'BEGIN{flag=0} { if ($0 ~ ext) { flag=1 } else if ($0 ~ /^$/ && flag) { flag=0 } else if (!flag) { print $0 } }' /etc/asterisk/sip.conf > "$temp_file"

            # Mou l'arxiu temporal a /etc/asterisk/sip.conf
            sudo mv "$temp_file" /etc/asterisk/sip.conf

            # Eliminar totes les línies en las que es faci referencia a la extensió a eliminar en /usr/local/bin/mail.sh
            sudo sed -i "/$extension/d" /usr/local/bin/mail.sh

            # Informar a l'usuari de la eliminació exitosa
            zenity --info --text="S'ha eliminat correctament l'usuari $username i totes les entrades en els arxiu de configuració que fan referencia a la extensió $extension."
        fi

    else
        zenity --info --text="No s'ha eliminat l'usuari $username."
    fi
}
# Menú gràfic per escollir opcioó
while true
do
    option=$(zenity --list --title="Opcions" --text="Seleccioni una opció:" --column=Opción "Crear un nuevo usuari" "Veure usuaris del sistema" "Eliminar un usuari" "Sortir")

    case "$option" in
        "Crear un nuevo usuari")
            create_user
            ;;
        "Veure usuaris del sistema")
            users=$(awk -F':' '/\/home/{print $1}' /etc/passwd)
            zenity --list --title="Usuaris del sistema" --text="Llista d'usuaris:" --column=Usuarios $users
            ;;
        "Eliminar un usuari")
            delete_user
            ;;
        "Sortir")
            zenity --info --text="Sortint del programa."
            exit 0
            ;;
        *)
            zenity --error --text="Opció no valida. Seleccioni una opció válida."
            ;;
    esac
done
