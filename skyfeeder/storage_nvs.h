#pragma once
#include <stddef.h>
#include <stdint.h>
namespace SF { namespace Storage {
bool begin();
bool getBytes(const char* ns, const char* key, void* out, size_t len);
bool setBytes(const char* ns, const char* key, const void* data, size_t len);
bool getInt32(const char* ns, const char* key, int32_t& out);
bool setInt32(const char* ns, const char* key, int32_t value);
bool getFloat(const char* ns, const char* key, float& out);
bool setFloat(const char* ns, const char* key, float value);
}} // namespace SF::Storage
