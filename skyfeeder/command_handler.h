#pragma once
#include <Arduino.h>
#include <PubSubClient.h>
void SF_registerCommandSubscriptions(PubSubClient& client);
void SF_onMqttMessage(char* topic, byte* payload, unsigned int len);
