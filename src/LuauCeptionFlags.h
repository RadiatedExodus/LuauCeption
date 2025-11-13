#include <string>

#include <emscripten.h>
#define LC_API extern "C" EMSCRIPTEN_KEEPALIVE

LC_API bool set_flag(std::string name, bool state);
LC_API void set_all_flags(bool state);
LC_API void reset_flags();