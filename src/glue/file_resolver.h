#include "Luau/FileResolver.h"

struct VirtualFileResolver : Luau::FileResolver {
    std::unordered_map<Luau::ModuleName, std::string> source;

    std::optional<Luau::SourceCode> readSource(const Luau::ModuleName& name) override {
        auto it = source.find(name);
        if (it == source.end())
            return std::nullopt;
        return Luau::SourceCode{it->second, Luau::SourceCode::Module};
    }

    std::optional<Luau::ModuleInfo> resolveModule(const Luau::ModuleInfo* context, Luau::AstExpr* expr, const Luau::TypeCheckLimits& limits) override {
        if (Luau::AstExprGlobal* g = expr->as<Luau::AstExprGlobal>())
            return Luau::ModuleInfo{g->name.value};
        return std::nullopt;
    }

    std::string getHumanReadableModuleName(const Luau::ModuleName& name) const override {
        return name;
    }

    std::optional<std::string> getEnvironmentForModule(const Luau::ModuleName& name) const override {
        return std::nullopt;
    }
};

LUAUCEPTION_API VirtualFileResolver* luauception_analysis_fileresolver_create();
LUAUCEPTION_API void luauception_analysis_fileresolver_free(VirtualFileResolver* resolver);
LUAUCEPTION_API void luauception_analysis_fileresolver_add(VirtualFileResolver* resolver, const char* name, const char* source);
LUAUCEPTION_API char** luauception_analysis_fileresolver_listnames(VirtualFileResolver* resolver);
LUAUCEPTION_API const char* luauception_analysis_fileresolver_get(VirtualFileResolver* resolver, const char* n);
LUAUCEPTION_API int luauception_analysis_fileresolver_delete(VirtualFileResolver* resolver, const char* n);
LUAUCEPTION_API void luauception_analysis_fileresolver_clear(VirtualFileResolver* resolver);