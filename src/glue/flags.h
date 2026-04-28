#include <string>
#include "Luau/Common.h"
#include "Luau/ExperimentalFlags.h"

LUAUCEPTION_API bool luauception_flags_set(std::string name, bool state);
LUAUCEPTION_API void luauception_flags_setall(bool state);
LUAUCEPTION_API void luauception_flags_reset();