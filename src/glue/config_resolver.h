#include <Luau/ConfigResolver.h>

struct VirtualConfigResolver : Luau::ConfigResolver {
    Luau::Config config;

    VirtualConfigResolver() {
        config.mode = Luau::Mode::Strict;
    }

    virtual const Luau::Config& getConfig(const Luau::ModuleName& name, const Luau::TypeCheckLimits& limits) const override {
        return config;
    }
};

LUAUCEPTION_API VirtualConfigResolver* luauception_analysis_configresolver_create();
LUAUCEPTION_API void luauception_analysis_configresolver_free(VirtualConfigResolver* resolver);
LUAUCEPTION_API void luauception_analysis_configresolver_setstrict(VirtualConfigResolver* resolver, int strict);