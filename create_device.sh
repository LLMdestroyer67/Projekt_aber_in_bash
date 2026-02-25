#!/usr/bin/env bash


DEVICE_DIR='devices'
mkdir -p $DEVICE_DIR
echo 'device folder has been created'


read -p 'Enter the device ID: ' DEVICE_ID
echo 'device ID='$DEVICE_ID

if [[ $DEVICE_ID =~ ^[+-]?[0-9]+$ ]]; then
    echo "->Einzelgerät"
    DEVICE_count=1 #-> einzelnes gerät
else
    echo "->Sammeleintrag"
    DEVICE_count=2 #-> mehrere, -> anderer modus

fi

countdevice=$(ls "$DEVICE_DIR" | grep -cFx "$DEVICE_ID.txt")
if [ "$countdevice" -eq 0 ]; then
    echo 'device '$DEVICE_ID' does not exist'
    touch $DEVICE_DIR/$DEVICE_ID.txt
    echo 'device '$DEVICE_ID' has been created'
else
    echo 'device '$DEVICE_ID' already exists'
    exit 1
fi

complete_one_device() {
    read -p 'Beschreibung des Geräts: ' DEVICE_DESC
    echo 'device description='$DEVICE_DESC
    echo 'Beschreibung='$DEVICE_DESC > $DEVICE_DIR/$DEVICE_ID.txt      

    read -p 'Location des Geräts: ' DEVICE_LOC
    echo 'device location='$DEVICE_LOC
    echo 'Location='$DEVICE_LOC >> $DEVICE_DIR/$DEVICE_ID.txt

    read -p 'Status des Geräts : ' DEVICE_STATUS
    echo 'device status='$DEVICE_STATUS
    echo 'Status='$DEVICE_STATUS >> $DEVICE_DIR/$DEVICE_ID.txt
}

complete_more_device() {
    read -p 'Beschreibung des Geräts: ' DEVICE_DESC
    echo 'device description='$DEVICE_DESC
    echo 'Beschreibung='$DEVICE_DESC > $DEVICE_DIR/$DEVICE_ID.txt      

    read -p 'Anzahl: ' DEVICE_CT
    echo 'device Count='$DEVICE_CT
    echo 'Anzahl='$DEVICE_CT >> $DEVICE_DIR/$DEVICE_ID.txt
}

if [ "$DEVICE_count" -eq 1 ]; then 
    complete_one_device
elif [ "$DEVICE_count" -eq 2 ]; then
    complete_more_device
else
    echo 'ERROR'
    exit 1
fi


#schleife?
#diesdas