#include "mqtt_client.h"
#include "led_service.h"
#include "ws2812_service.h"
#include "telemetry_service.h"
#include "power_manager.h"
#include "weight_service.h"
#include "config.h"
void setup(){
  Serial.begin(115200); delay(150);
  SF::led.begin(LED_PIN);
  SF::ws2812.begin(NEOPIXEL_PIN, NEOPIXEL_COUNT);
  SF::power.begin();
  SF::weight.begin();
  SF::mqtt.begin();
  SF::telemetry.begin(2000);
}
void loop(){
  SF::mqtt.loop();
  SF::power.loop();
  SF::weight.loop();
  SF::telemetry.loop();
  delay(10);
}