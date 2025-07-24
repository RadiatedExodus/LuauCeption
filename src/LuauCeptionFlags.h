#include <string>

#include <emscripten.h>
#define EXPORT extern "C" EMSCRIPTEN_KEEPALIVE

EXPORT bool set_flag(std::string name, bool state);
EXPORT void set_all_flags(bool state);
EXPORT void reset_flags();