#include "mqtt_client.h"
#include "led_service.h"
#include "ws2812_service.h"
#include "telemetry_service.h"
#include "power_manager.h"
#include "weight_service.h"
#include "motion_service.h"
#include "visit_service.h"
#include "led_ux.h"
#include "camera_service_esp.h"
#include "provisioning.h"
#include "topics.h"
#include "config.h"
void setup(){
  Serial.begin(115200); delay(150);
  SF::led.begin(LED_PIN);
  SF::ws2812.begin(NEOPIXEL_PIN, NEOPIXEL_COUNT);
  SF::ledUx.begin();
  SF::power.begin();
  SF::weight.begin();
  SF::motion.begin(PIR_MOTION_PIN);
  SF::visit.begin();
  SF::cameraEsp.begin();
  SF::provisioning.begin();
  if(SF::provisioning.isReady()){
    SF::mqtt.begin();
    SF::telemetry.begin(2000);
  }
}
void loop(){
  SF::provisioning.loop();
  SF::power.loop();
  SF::weight.loop();
  SF::motion.loop();
  SF::visit.loop();
  SF::cameraEsp.loop();
  SF::ledUx.loop();
  SF::ws2812.update();
  if(!SF::provisioning.isReady()){ delay(20); return; }
  SF::mqtt.loop();
  SF::telemetry.loop();
  delay(10);
}
