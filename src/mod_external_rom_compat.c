#include <string.h>
#if defined(SNESRECOMP_ENABLE_MODS) && SNESRECOMP_ENABLE_MODS
#include "mod_runtime.h"
#include "recomp_launcher.h"
#endif

/* The package catalog and its verified resource provider are desktop-only.
 * When mods are disabled (as in the native Switch build), there is no external
 * ROM resource to resolve. Do not reference recomp-ui's launcher ABI. */
const char *snes_mod_external_rom_path(const char *package_id,
                                     const char *feature_id,
                                     const char *resource_id)
{
#if defined(SNESRECOMP_ENABLE_MODS) && SNESRECOMP_ENABLE_MODS
    static RecompLauncherCModResource resource;
    const RecompLauncherCModProvider *provider =
        snes_mod_runtime_launcher_provider_c();
    if (!package_id || !feature_id || !resource_id || !provider ||
        !provider->feature_resource_count || !provider->feature_resource_get ||
        !snes_mod_runtime_feature_enabled_c(package_id, feature_id)) return NULL;
    int count = provider->feature_resource_count(provider->ctx, package_id,
                                                  feature_id);
    for (int i = 0; i < count; ++i) {
        memset(&resource, 0, sizeof(resource));
        if (provider->feature_resource_get(provider->ctx, package_id, feature_id,
                                            i, &resource) &&
            strcmp(resource.id, resource_id) == 0 && resource.verified)
            return resource.path[0] ? resource.path : NULL;
    }
#else
    (void)package_id;
    (void)feature_id;
    (void)resource_id;
#endif
    return NULL;
}
