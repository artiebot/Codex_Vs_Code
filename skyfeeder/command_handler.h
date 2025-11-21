#pragma once
#include <Arduino.h>
#include <stdint.h>
#include <PubSubClient.h>
void SF_registerCommandSubscriptions(PubSubClient& client);
void SF_onMqttMessage(char* topic, byte* payload, unsigned int len);
void SF_commandHandlerLoop();
const char* SF_miniState();
bool SF_miniSettled();

bool SF_captureStart(const char* trigger = nullptr, float weightG = 0.0f);
bool SF_capturePhoto(uint8_t index);
bool SF_captureStop(uint8_t total_photos);
void SF_armForMotion();
void SF_visitStart(float delta);
void SF_visitEnd(unsigned long durationMs, float peakDelta);

