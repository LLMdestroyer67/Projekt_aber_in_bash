#!/usr/bin/env bash


DEVICE_DIR='devices'
mkdir -p $DEVICE_DIR
echo 'device folder has been created'


read -p 'Enter the device ID: ' DEVICE_ID
echo 'device ID='$DEVICE_ID


countdevice=$(ls "$DEVICE_DIR" | grep -cFx "$DEVICE_ID.txt")
if [ "$countdevice" -eq 0 ]; then
    echo 'device '$DEVICE_ID' does not exist'
    touch $DEVICE_DIR/$DEVICE_ID.txt
    echo 'device '$DEVICE_ID' has been created'
else
    echo 'device '$DEVICE_ID' already exists'
    exit 1
fi


read -p 'Beschreibung des Geräts: ' DEVICE_DESC
echo 'device description='$DEVICE_DESC
echo 'Beschreibung='$DEVICE_DESC > $DEVICE_DIR/$DEVICE_ID.txt      

read -p 'Location des Geräts: ' DEVICE_LOC
echo 'device location='$DEVICE_LOC
echo 'Location='$DEVICE_LOC >> $DEVICE_DIR/$DEVICE_ID.txt

read -p 'Status des Geräts : ' DEVICE_STATUS
echo 'device status='$DEVICE_STATUS
echo 'Status='$DEVICE_STATUS >> $DEVICE_DIR/$DEVICE_ID.txt

#schleife?
#diesdas