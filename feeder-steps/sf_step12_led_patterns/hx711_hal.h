#pragma once
#include <Arduino.h>
struct WeightRawSample {
  long raw;
  bool ok;
};
void hx711_begin(uint8_t dout_pin, uint8_t sck_pin);
bool hx711_ready();
bool hx711_read(long& raw);
void hx711_sleep();