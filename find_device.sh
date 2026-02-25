#!/usr/bin/env bash
DEVICE_DIR='devices'

find_by_id() {
    read -p 'Find device by ID: ' DEVICE_ID
    echo 'device ID: '$DEVICE_ID
    countdevice=$(ls "$DEVICE_DIR" | grep -c "$DEVICE_ID.txt")
    if [ "$countdevice" -eq 0 ]; then
        echo 'device '$DEVICE_ID' does not exist'
        exit 1
    else
        echo 'Found device: '$DEVICE_ID
        cat -n $DEVICE_DIR/$DEVICE_ID.txt
    fi
}

find_by_description() {
    read -p 'Find device by description: ' DEVICE_DESC
    echo 'Beschreibung='$DEVICE_DESC
    countdevice=$(grep -lEi "Beschreibung=.*$DEVICE_DESC" "$DEVICE_DIR"/*.txt | wc -l)
    if [ "$countdevice" -eq 0 ]; then
        echo 'device with description '$DEVICE_DESC' does not exist'
        exit 1
    else   
        for file in $(grep -lEi "Beschreibung=.*$DEVICE_DESC" "$DEVICE_DIR"/*.txt); do
        echo "----- $file -----"
        cat -n "$file"
        done
    fi
}

find_by_location() {
    read -p 'Find device by location: ' DEVICE_LOC
    echo 'Location='$DEVICE_LOC
    countdevice=$(grep -lEi "Location=.*$DEVICE_LOC" "$DEVICE_DIR"/*.txt | wc -l)
    if [ "$countdevice" -eq 0 ]; then
        echo 'device with location '$DEVICE_LOC' does not exist'
        exit 1
    else   
        for file in $(grep -lEi "Location=.*$DEVICE_LOC" "$DEVICE_DIR"/*.txt); do
        echo "----- $file -----"
        cat -n "$file"
        done 
    fi
}

find_by_status() {
    read -p 'Find device by status: ' DEVICE_STATUS
    echo 'Status='$DEVICE_STATUS
    countdevice=$(grep -lEi "Status=.*$DEVICE_STATUS" "$DEVICE_DIR"/*.txt | wc -l)
    if [ "$countdevice" -eq 0 ]; then
        echo 'device with status '$DEVICE_STATUS' does not exist'
        exit 1
    else   
        for file in $(grep -lEi "Status=.*$DEVICE_STATUS" "$DEVICE_DIR"/*.txt); do
        echo "----- $file -----"
        cat -n "$file"
        done 
    fi
}

read -p 'Find device by (1)ID, (2)description, (3)location, (4)status: ' FINDNR #1,2,3,4
if [ "$FINDNR" -eq 1 ]; then
    find_by_id
elif [ "$FINDNR" -eq 2 ]; then
    find_by_description
elif [ "$FINDNR" -eq 3 ]; then
    find_by_location
elif [ "$FINDNR" -eq 4 ]; then
    find_by_status
else
    echo 'invalid input'
    exit 1
fi