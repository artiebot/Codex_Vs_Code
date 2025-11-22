#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\camera_service_esp.cpp"
#include "camera_service_esp.h"
#include <esp_camera.h>
#include <mbedtls/base64.h>
#include <memory>
#include <string.h>
#include "config.h"
#include "topics.h"
#include "mqtt_client.h"
namespace {
const unsigned long SNAP_TIMEOUT_MS=10000;
void writeErr(char* err,size_t len,const char* msg){ if(!err||len==0) return; strncpy(err,msg,len); err[len-1]='\0'; }
}
namespace SF {
CameraServiceEsp cameraEsp;
void CameraServiceEsp::begin(){ setStatus("idle"); camera_ready_=false; sleeping_=false; snap_pending_=false; }
void CameraServiceEsp::setStatus(const char* s){ if(!s) s="unknown"; strncpy(status_,s,sizeof(status_)); status_[sizeof(status_)-1]='\0'; }
bool CameraServiceEsp::initCamera(){
  camera_config_t config={};
  config.ledc_channel=LEDC_CHANNEL_0;
  config.ledc_timer=LEDC_TIMER_0;
  config.pin_d0=CAM_PIN_D0;
  config.pin_d1=CAM_PIN_D1;
  config.pin_d2=CAM_PIN_D2;
  config.pin_d3=CAM_PIN_D3;
  config.pin_d4=CAM_PIN_D4;
  config.pin_d5=CAM_PIN_D5;
  config.pin_d6=CAM_PIN_D6;
  config.pin_d7=CAM_PIN_D7;
  config.pin_xclk=CAM_PIN_XCLK;
  config.pin_pclk=CAM_PIN_PCLK;
  config.pin_vsync=CAM_PIN_VSYNC;
  config.pin_href=CAM_PIN_HREF;
  config.pin_sscb_sda=CAM_PIN_SIOD;
  config.pin_sscb_scl=CAM_PIN_SIOC;
  config.pin_pwdn=CAM_PIN_PWDN;
  config.pin_reset=CAM_PIN_RESET;
  config.xclk_freq_hz=CAM_XCLK_FREQ;
  config.pixel_format=PIXFORMAT_JPEG;
  config.frame_size=CAM_FRAME_SIZE;
  config.jpeg_quality=CAM_JPEG_QUALITY;
  config.fb_count=CAM_FB_COUNT;
#if defined(CAMERA_GRAB_LATEST)
  config.grab_mode=CAMERA_GRAB_LATEST;
#endif
  config.fb_location=CAMERA_FB_IN_PSRAM;
  esp_err_t err=esp_camera_init(&config);
  if(err!=ESP_OK){ camera_ready_=false; setStatus("init_fail"); return false; }
  camera_ready_=true; sleeping_=false; setStatus("idle");
  if(CAM_PIN_FLASH>=0) pinMode(CAM_PIN_FLASH, OUTPUT);
  return true;
}
void CameraServiceEsp::shutdownCamera(){ if(camera_ready_){ esp_camera_deinit(); camera_ready_=false; } sleeping_=true; }
bool CameraServiceEsp::ensureAwake(){ if(camera_ready_) return true; return initCamera(); }
bool CameraServiceEsp::captureAndPublish(){ if(!camera_ready_) return false; camera_fb_t* fb=esp_camera_fb_get(); if(!fb){ setStatus("snap_error"); return false; }
  size_t out_len = 4 * ((fb->len + 2) / 3);
  std::unique_ptr<char[]> encoded(new (std::nothrow) char[out_len + 1]);
  if(!encoded){ esp_camera_fb_return(fb); setStatus("snap_error"); return false; }
  size_t produced=0;
  int rc=mbedtls_base64_encode(reinterpret_cast<unsigned char*>(encoded.get()), out_len + 1, &produced, fb->buf, fb->len);
  if(rc!=0){ esp_camera_fb_return(fb); setStatus("snap_error"); return false; }
  encoded.get()[produced]='\0';
  String payload;
  payload.reserve(produced + 96);
  payload += '{';
  payload += "\"ts\":";
  payload += millis();
  payload += ",\"size\":";
  payload += fb->len;
  payload += ",\"base64\":\"data:image/jpeg;base64,";
  payload += encoded.get();
  payload += "\"}";
  bool published=SF::mqtt.raw().publish(SF::Topics::eventCameraSnapshot(), payload.c_str(), false);
  esp_camera_fb_return(fb);
  return published;
}
bool CameraServiceEsp::handleCommand(JsonVariantConst cmd,char* err,size_t errLen){ if(err&&errLen>0) err[0]='\0'; const char* action=nullptr;
  if(cmd.is<const char*>()) action=cmd.as<const char*>();
  else if(cmd.containsKey("action")) action=cmd["action"].as<const char*>();
  else if(cmd.containsKey("snap") && cmd["snap"].as<bool>()) action="snap";
  else if(cmd.containsKey("sleep") && cmd["sleep"].as<bool>()) action="sleep";
  else if(cmd.containsKey("wake") && cmd["wake"].as<bool>()) action="wake";
  if(!action){ writeErr(err,errLen,"no_action"); return false; }
  if(strcmp(action,"sleep")==0){ shutdownCamera(); setStatus("sleep"); return true; }
  if(strcmp(action,"wake")==0){ if(!ensureAwake()){ writeErr(err,errLen,"init_fail"); return false; } setStatus("idle"); return true; }
  if(strcmp(action,"snap")==0){ if(!ensureAwake()){ writeErr(err,errLen,"init_fail"); return false; }
    snap_pending_=true; snap_deadline_=millis()+SNAP_TIMEOUT_MS; setStatus("snap_pending");
    bool ok=captureAndPublish();
    snap_pending_=false;
    setStatus(ok?"idle":"snap_error");
    return ok;
  }
  writeErr(err,errLen,"action_unknown"); return false;
}
void CameraServiceEsp::loop(){ if(snap_pending_){ unsigned long now=millis(); if((long)(snap_deadline_-now)<=0){ snap_pending_=false; setStatus("snap_timeout"); } } }
} // namespace SF
