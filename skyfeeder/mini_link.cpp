#include "mini_link.h"

#include <cstring>

#include "logging.h"
#include "pins_board.h"

namespace {
constexpr unsigned long STATUS_STALE_MS = 15000;
}  // namespace

namespace SF {

MiniLink miniLink;

void MiniLink::begin(unsigned long baud) {
  serial_ = &Pins::miniSerial();
  serial_->begin(baud, SERIAL_8N1, Pins::MiniUartRx, Pins::MiniUartTx);
  rxLen_ = 0;
  state_[0] = '\0';
  lastReason_[0] = '\0';
  lastStatusRaw_[0] = '\0';
  lastStatusMs_ = 0;
  awaitingStatus_ = false;
  lastTxMs_ = 0;

  if (Pins::MiniPowerEnable >= 0) {
    pinMode(Pins::MiniPowerEnable, OUTPUT);
    digitalWrite(Pins::MiniPowerEnable, HIGH);
  }
  if (Pins::MiniWake >= 0) {
    pinMode(Pins::MiniWake, OUTPUT);
    digitalWrite(Pins::MiniWake, HIGH);
  }

  SF::Log::info("mini", "UART link ready (rx=%d tx=%d)", Pins::MiniUartRx, Pins::MiniUartTx);
}

bool MiniLink::sendOp(const char* op) {
  if (!serial_ || !op || !op[0]) return false;

  StaticJsonDocument<96> doc;
  doc["op"] = op;
  char buf[96];
  size_t n = serializeJson(doc, buf, sizeof(buf));
  if (n == 0 || n >= sizeof(buf) - 1) return false;

  buf[n] = '\0';
  Serial.print(F("[mini] >> "));
  Serial.println(buf);
  serial_->write(reinterpret_cast<const uint8_t*>(buf), n);
  serial_->write('\n');
  awaitingStatus_ = true;
  lastTxMs_ = millis();
  return true;
}

bool MiniLink::sendWake() {
  if (Pins::MiniWake >= 0) {
    digitalWrite(Pins::MiniWake, HIGH);
  }
  return sendOp("wake");
}

bool MiniLink::sendSleep() {
  bool ok = sendOp("sleep");
  if (Pins::MiniWake >= 0) {
    digitalWrite(Pins::MiniWake, LOW);
  }
  return ok;
}

bool MiniLink::requestStatus() {
  return sendOp("status");
}

void MiniLink::loop() {
  if (!serial_) return;
  while (serial_->available()) {
    int c = serial_->read();
    if (c < 0) {
      break;
    }
    char ch = static_cast<char>(c);
    if (ch == '\r') continue;
    if (ch == '\n') {
      if (rxLen_ == 0) continue;
      rxBuf_[rxLen_] = '\0';
      processLine(rxBuf_);
      rxLen_ = 0;
    } else {
      if (rxLen_ + 1 < sizeof(rxBuf_)) {
        rxBuf_[rxLen_++] = ch;
      } else {
        rxLen_ = 0;
      }
    }
  }

  if (awaitingStatus_ && (millis() - lastTxMs_) > STATUS_STALE_MS) {
    awaitingStatus_ = false;
    SF::Log::warn("mini", "Timeout waiting for status");
  }
}

bool MiniLink::hasRecentStatus(unsigned long maxAgeMs) const {
  if (lastStatusMs_ == 0) return false;
  return millis() - lastStatusMs_ <= maxAgeMs;
}

void MiniLink::processLine(const char* line) {
  if (!line || !line[0]) return;
  Serial.print(F("[mini] << "));
  Serial.println(line);

  StaticJsonDocument<192> doc;
  auto err = deserializeJson(doc, line);
  if (err) {
    SF::Log::warn("mini", "Bad JSON from mini (%s)", err.c_str());
    return;
  }

  const char* type = doc["type"] | "";
  if (std::strcmp(type, "status") == 0) {
    const char* state = doc["state"] | "unknown";
    const char* reason = doc["reason"] | "";
    updateState(state, reason);

    lastStatusMs_ = millis();
    awaitingStatus_ = false;
    strlcpy(lastStatusRaw_, line, sizeof(lastStatusRaw_));
  } else if (std::strcmp(type, "log") == 0) {
    const char* level = doc["level"] | "info";
    const char* msg = doc["msg"] | "";
    SF::Log::info("mini", "[%s] %s", level, msg);
  } else if (std::strcmp(type, "error") == 0) {
    const char* msg = doc["msg"] | "mini_error";
    SF::Log::warn("mini", "Error from mini: %s", msg);
  }
}

void MiniLink::updateState(const char* state, const char* reason) {
  if (!state) state = "unknown";
  strlcpy(state_, state, sizeof(state_));
  if (reason && reason[0]) {
    strlcpy(lastReason_, reason, sizeof(lastReason_));
  } else {
    lastReason_[0] = '\0';
  }
  SF::Log::info("mini", "state=%s reason=%s", state_, lastReason_);
}

void MiniLink::writeErr(char* err, size_t errLen, const char* msg) {
  if (!err || errLen == 0) return;
  if (!msg) msg = "mini_err";
  strlcpy(err, msg, errLen);
}

bool MiniLink::handleCommand(JsonVariantConst cmd, char* err, size_t errLen) {
  if (err && errLen > 0) err[0] = '\0';
  const char* op = nullptr;
  if (cmd.is<const char*>()) {
    op = cmd.as<const char*>();
  } else if (cmd.containsKey("op")) {
    op = cmd["op"].as<const char*>();
  } else if (cmd.containsKey("action")) {
    op = cmd["action"].as<const char*>();
  }

  if (!op) {
    writeErr(err, errLen, "no_op");
    return false;
  }

  if (std::strcmp(op, "wake") == 0) {
    return sendWake();
  }
  if (std::strcmp(op, "sleep") == 0) {
    return sendSleep();
  }
  if (std::strcmp(op, "status") == 0) {
    return requestStatus();
  }

  writeErr(err, errLen, "bad_op");
  return false;
}

}  // namespace SF

