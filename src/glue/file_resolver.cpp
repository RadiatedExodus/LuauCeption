#include "file_resolver.h"

LUAUCEPTION_API VirtualFileResolver* luauception_analysis_fileresolver_create() {
    return new VirtualFileResolver();
}

LUAUCEPTION_API void luauception_analysis_fileresolver_free(VirtualFileResolver* resolver) {
    delete resolver;
}

LUAUCEPTION_API void luauception_analysis_fileresolver_add(VirtualFileResolver* resolver, const char* name, const char* source) {
    resolver->source[Luau::ModuleName(name)] = std::string(source);
}

LUAUCEPTION_API char** luauception_analysis_fileresolver_listnames(VirtualFileResolver* resolver) {
    size_t count = resolver->source.size();
    char** names = static_cast<char**>(std::malloc(sizeof(char*) * (count + 1)));
    size_t i = 0;
    for (const auto& pair : resolver->source)
    {
        const Luau::ModuleName& name = pair.first;
        size_t len = name.size();
        char* copy = static_cast<char*>(std::malloc(len + 1));
        std::memcpy(copy, name.c_str(), len);
        copy[len] = '\0';
        names[i++] = copy;
    }
    names[i] = nullptr;
    return names;
}

LUAUCEPTION_API const char* luauception_analysis_fileresolver_get(VirtualFileResolver* resolver, const char* n) {
    auto it = resolver->source.find(Luau::ModuleName(n));
    if (it == resolver->source.end())
        return nullptr;
    return it->second.c_str();
}

LUAUCEPTION_API int luauception_analysis_fileresolver_delete(VirtualFileResolver* resolver, const char* n) {
    size_t erased = resolver->source.erase(Luau::ModuleName(n));
    return erased != 0 ? 1 : 0;
}

LUAUCEPTION_API void luauception_analysis_fileresolver_clear(VirtualFileResolver* resolver) {
    resolver->source.clear();
}