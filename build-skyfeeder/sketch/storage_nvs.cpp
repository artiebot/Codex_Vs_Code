#line 1 "D:\\OneDrive\\Etsy\\Feeder-Project\\SW\\feeder-project\\ESP32\\Codex_Vs_Code\\skyfeeder\\storage_nvs.cpp"
#include "storage_nvs.h"
#include <Preferences.h>
#include <nvs_flash.h>
namespace {
bool ensureInit(){
  static bool ready=false;
  if(ready) return true;
  esp_err_t err=nvs_flash_init();
  if(err==ESP_ERR_NVS_NO_FREE_PAGES||err==ESP_ERR_NVS_NEW_VERSION_FOUND){ nvs_flash_erase(); err=nvs_flash_init(); }
  ready=(err==ESP_OK);
  return ready;
}
}
namespace SF { namespace Storage {
bool begin(){ return ensureInit(); }
bool getBytes(const char* ns,const char* key,void* out,size_t len){ if(!ensureInit()) return false; Preferences prefs; if(!prefs.begin(ns,true)) return false; size_t n=prefs.getBytes(key,out,len); prefs.end(); return n==len; }
bool setBytes(const char* ns,const char* key,const void* data,size_t len){ if(!ensureInit()) return false; Preferences prefs; if(!prefs.begin(ns,false)) return false; size_t n=prefs.putBytes(key,data,len); prefs.end(); return n==len; }
bool getInt32(const char* ns,const char* key,int32_t& out){ if(!ensureInit()) return false; Preferences prefs; if(!prefs.begin(ns,true)) return false; bool ok=prefs.isKey(key); if(ok) out=prefs.getInt(key,0); prefs.end(); return ok; }
bool setInt32(const char* ns,const char* key,int32_t value){ if(!ensureInit()) return false; Preferences prefs; if(!prefs.begin(ns,false)) return false; prefs.putInt(key,value); prefs.end(); return true; }
bool getFloat(const char* ns,const char* key,float& out){ if(!ensureInit()) return false; Preferences prefs; if(!prefs.begin(ns,true)) return false; bool ok=prefs.isKey(key); if(ok) out=prefs.getFloat(key,0.0f); prefs.end(); return ok; }
bool setFloat(const char* ns,const char* key,float value){ if(!ensureInit()) return false; Preferences prefs; if(!prefs.begin(ns,false)) return false; prefs.putFloat(key,value); prefs.end(); return true; }
}} // namespace SF::Storage
