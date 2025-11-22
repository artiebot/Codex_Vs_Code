#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\command_handler.h"
#pragma once
#include <Arduino.h>
#include <stdint.h>
#include <PubSubClient.h>
void SF_registerCommandSubscriptions(PubSubClient& client);
void SF_onMqttMessage(char* topic, byte* payload, unsigned int len);
void SF_commandHandlerLoop();
const char* SF_miniState();
bool SF_miniSettled();

bool SF_captureEvent(uint8_t snapshotCount, uint16_t videoSeconds, const char* trigger = nullptr, float weightG = 0.0f);
void SF_armForMotion();
void SF_visitStart(float delta);
void SF_visitEnd(unsigned long durationMs, float peakDelta);


