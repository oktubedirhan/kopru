/*
 * Köprü D3DMetal kancası.
 *
 * CrossOver'ın ntdll'i (dlls/ntdll/unix/loader.c, "CW Hack 24067") süreç açılırken kendi
 * klasöründeki `cxcompatdb.so` dosyasını dlopen ediyor. CrossOver'da o dosya kapalı kaynak;
 * D3DMetal açıkken DLL arama listesinin başına D3DMetal klasörünü ekliyor.
 *
 * Bu, aynı kancaya takılan kendi küçük kütüphanemiz:
 *   KOPRU_D3DMETAL_DLLPATH=<.../redist/lib/wine> ayarlıysa, ntdll'in dışa açtığı
 *   prepend_dll_path() ile o klasörü listenin başına koyar. Böylece d3d11/d3d12/dxgi
 *   Wine'ın kendi (wined3d) sürümü yerine D3DMetal'inkinden yüklenir.
 *   Değişken yoksa hiçbir şey yapmaz; Wine kendi DLL'leriyle çalışır.
 *
 * Derleme: tools/d3dmetal-hook/build.sh  (çıktı: <runtime>/lib/wine/x86_64-unix/cxcompatdb.so)
 */
#include <dlfcn.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static void log_msg(const char *msg, const char *arg)
{
    if (getenv("KOPRU_HOOK_DEBUG"))
        fprintf(stderr, "kopru-hook: %s%s\n", msg, arg ? arg : "");
}

__attribute__((constructor))
static void kopru_d3dmetal_init(void)
{
    const char *dir = getenv("KOPRU_D3DMETAL_DLLPATH");
    char ntdll_path[PATH_MAX];
    void (*prepend_dll_path)(const char *);
    Dl_info info;
    void *ntdll;
    char *slash;

    if (!dir || !*dir) {
        log_msg("KOPRU_D3DMETAL_DLLPATH yok, Wine'ın kendi DLL'leri kullanılacak", NULL);
        return;
    }

    /* ntdll.so bu dosyayla aynı klasörde; zaten yüklü olduğu için RTLD_NOLOAD ile tutamak alıyoruz. */
    if (!dladdr((void *)kopru_d3dmetal_init, &info) || strlen(info.dli_fname) >= sizeof(ntdll_path))
        return;
    strcpy(ntdll_path, info.dli_fname);
    if (!(slash = strrchr(ntdll_path, '/')) || slash - ntdll_path + sizeof("/ntdll.so") > sizeof(ntdll_path))
        return;
    strcpy(slash, "/ntdll.so");

    if (!(ntdll = dlopen(ntdll_path, RTLD_NOLOAD | RTLD_LAZY))) {
        log_msg("ntdll.so bulunamadı: ", dlerror());
        return;
    }
    if (!(prepend_dll_path = (void (*)(const char *))dlsym(ntdll, "prepend_dll_path"))) {
        log_msg("prepend_dll_path yok (CrossOver tabanlı Wine değil mi?)", NULL);
        return;
    }
    prepend_dll_path(strdup(dir)); /* ntdll işaretçiyi saklıyor, kopyası kalıcı olmalı */
    log_msg("D3DMetal DLL yolu başa eklendi: ", dir);
}
