# Wake camera on AMB82-Mini via MQTT
mosquitto_pub -h 10.0.0.4 -u dev1 -P dev1pass -t "skyfeeder/dev1/amb/camera/cmd" -f "$PSScriptRoot\wake.json"
