#include <string>
#include "Luau/Frontend.h"
#include "Luau/BuiltinDefinitions.h"
#include "flags.h"
#include "file_resolver.h"
#include "config_resolver.h"

LUAUCEPTION_API Luau::Frontend* luauception_analysis_frontend_create(VirtualFileResolver* fileResolver, VirtualConfigResolver* configResolver) {
    Luau::FrontendOptions options;
    return new Luau::Frontend(fileResolver, configResolver, options);
}

LUAUCEPTION_API void luauception_analysis_frontend_free(Luau::Frontend* frontend) {
    delete frontend;
}

LUAUCEPTION_API void luauception_analysis_frontend_reset(Luau::Frontend* frontend) {
    frontend->clear();
}

LUAUCEPTION_API void luauception_analysis_frontend_registerglobals(Luau::Frontend* frontend) {
    Luau::unfreeze(frontend->globals.globalTypes);
    Luau::registerBuiltinGlobals(*frontend, (*frontend).globals);
    Luau::freeze(frontend->globals.globalTypes);
}

LUAUCEPTION_API void luauception_analysis_frontend_setsolvermode(Luau::Frontend* frontend, int newSolver) {
    frontend->setLuauSolverMode(newSolver ? Luau::SolverMode::New : Luau::SolverMode::Old);
}

LUAUCEPTION_API const char* luauception_analysis_frontend_check(Luau::Frontend* frontend, const char* n, size_t* outLen) {
    std::string finalCheckResult;
    Luau::CheckResult checkResult = frontend->check(std::string(n));
    for (const Luau::TypeError& err : checkResult.errors) {
        finalCheckResult += std::to_string(err.location.begin.line + 1);
        finalCheckResult += ": ";
        finalCheckResult += Luau::toString(err);
        finalCheckResult += "\n";
    }
    
    if (finalCheckResult.empty())
        return nullptr;

    size_t len = finalCheckResult.size();
    char* allocRes = static_cast<char*>(std::malloc(len + 1));
    std::memcpy(allocRes, finalCheckResult.c_str(), len);
    allocRes[len] = '\0';
    *outLen = len;

    return allocRes;
}

int main() {
    VirtualFileResolver* fileResolver = luauception_analysis_fileresolver_create();
    luauception_analysis_fileresolver_clear(fileResolver);
    luauception_analysis_fileresolver_add(fileResolver, "main", "print'a'");

    VirtualConfigResolver* configResolver = luauception_analysis_configresolver_create();
    luauception_analysis_configresolver_setstrict(configResolver, 1);

    size_t outLen;
    Luau::Frontend* frontend = luauception_analysis_frontend_create(fileResolver, configResolver);
    luauception_analysis_frontend_registerglobals(frontend);
    luauception_analysis_frontend_setsolvermode(frontend, 1);
    luauception_analysis_frontend_reset(frontend);
    luauception_analysis_frontend_check(frontend, "main", &outLen);

    luauception_analysis_frontend_free(frontend);
    luauception_analysis_fileresolver_free(fileResolver);
    luauception_analysis_configresolver_free(configResolver);
    return 0;
}