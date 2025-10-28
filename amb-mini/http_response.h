#pragma once

#include <Arduino.h>

struct HttpResponse {
  String statusLine;
  String headers;
  String body;
};

