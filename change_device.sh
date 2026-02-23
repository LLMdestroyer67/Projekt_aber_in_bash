#!/usr/bin/env bash
DEVICE_DIR='devices'

read -p 'Enter the device ID=' DEVICE_ID
echo 'device ID='$DEVICE_ID

countdevice=$(ls "$DEVICE_DIR" | grep -cFx "$DEVICE_ID.txt")
if [ "$countdevice" -eq 0 ]; then
    echo 'device '$DEVICE_ID' does not exist'
    exit 1
else
    echo 'Found device: '$DEVICE_ID' - ready to change'
fi
echo '------------------------------'
cat -n $DEVICE_DIR/$DEVICE_ID.txt
echo '------------------------------'
### auch wenn er es nicht findet, macht er trotzdem weiter und erstellt das gerät dann mit der änderung
##Absicht? eigentlich nicht aber mal schauen dann geht alles weniger kaputt
read -p 'was wird geädert? ((1)Beschreibung, (2)Location, (3)Status): ' CHANGENR #1,2,3
if [ "$CHANGENR" -eq 1 ]; then
    echo 'changing description'
    CHANGE='Beschreibung='
elif [ "$CHANGENR" -eq 2 ]; then
    echo 'changing location'
    CHANGE='Location='
elif [ "$CHANGENR" -eq 3 ]; then
    echo 'Changing status'
    CHANGE='Status='
else
    echo 'invalid input'
    exit 1
fi

#CHANGING=$(sed -n ''$CHANGENR'p' $DEVICE_DIR/$DEVICE_ID.txt)
CHANGING=$(grep -m 1 "$CHANGE" $DEVICE_DIR/$DEVICE_ID.txt)
echo '------->>>>'$CHANGING'<<<-------'
if [ -z "$CHANGING" ]; then #leere Zeile --> muss man noch machen
    echo 'could not find the line to change, adding it anyway'
    read -p 'neuer Inhalt=' NEWCHANGE
    echo "$CHANGE""$NEWCHANGE" >> "$DEVICE_DIR/$DEVICE_ID.txt"
    exit 0
fi

read -p 'neuer Inhalt=' NEWCHANGE

echo 'ändere "'$CHANGING'" zu "'$CHANGE' '$NEWCHANGE'"'
FINALCHANGE=$CHANGE''$NEWCHANGE
echo 'final change: '$FINALCHANGE

sed -i "s/$CHANGING/$FINALCHANGE/" "$DEVICE_DIR/$DEVICE_ID.txt"

###docker umgabung starten
