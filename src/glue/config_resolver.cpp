#include "config_resolver.h"

LUAUCEPTION_API VirtualConfigResolver* luauception_analysis_configresolver_create() {
    return new VirtualConfigResolver();
}

LUAUCEPTION_API void luauception_analysis_configresolver_free(VirtualConfigResolver* resolver) {
    delete resolver;
}

LUAUCEPTION_API void luauception_analysis_configresolver_setstrict(VirtualConfigResolver* resolver, int strict) {
    resolver->config.mode = strict ? Luau::Mode::Strict : Luau::Mode::Nonstrict;
}