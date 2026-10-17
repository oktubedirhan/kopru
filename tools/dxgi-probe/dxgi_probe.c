// dxgi-probe: DirectX'e "hangi ekran kartı var, D3D11/D3D12 cihazı açılıyor mu?" diye sorar.
// Wine + D3DMetal altında GPU adı Apple çipi olarak görünürse çeviri katmanı devrede demektir.
// Derleme: tools/dxgi-probe/build.sh
#define COBJMACROS
#include <windows.h>
#include <stdio.h>
#include <dxgi1_4.h>
#include <d3d11.h>
#include <d3d12.h>

static void print_module_path(const char *name)
{
    char path[MAX_PATH];
    HMODULE mod = GetModuleHandleA(name);
    if (mod && GetModuleFileNameA(mod, path, sizeof(path)))
        printf("  %-10s -> %s\n", name, path);
    else
        printf("  %-10s -> (yüklenmedi)\n", name);
}

static int list_adapters(void)
{
    IDXGIFactory1 *factory = NULL;
    IDXGIAdapter1 *adapter = NULL;
    HRESULT hr = CreateDXGIFactory1(&IID_IDXGIFactory1, (void **)&factory);
    if (FAILED(hr)) {
        printf("CreateDXGIFactory1 başarısız: 0x%08lx\n", hr);
        return 0;
    }

    int count = 0;
    for (UINT i = 0; IDXGIFactory1_EnumAdapters1(factory, i, &adapter) != DXGI_ERROR_NOT_FOUND; i++) {
        DXGI_ADAPTER_DESC1 desc;
        IDXGIAdapter1_GetDesc1(adapter, &desc);
        printf("Ekran kartı %u: %ls\n", i, desc.Description);
        printf("  VendorId=0x%04x DeviceId=0x%04x\n", desc.VendorId, desc.DeviceId);
        printf("  Ayrılmış video belleği: %llu MB, paylaşılan: %llu MB\n",
               (unsigned long long)desc.DedicatedVideoMemory >> 20,
               (unsigned long long)desc.SharedSystemMemory >> 20);
        IDXGIAdapter1_Release(adapter);
        count++;
    }
    IDXGIFactory1_Release(factory);
    return count;
}

static void try_d3d11(void)
{
    /* Liste verilmezse D3D11 en fazla 11.0 ister; kartın gerçek sınırını görmek için 12.1'den başlıyoruz. */
    static const D3D_FEATURE_LEVEL wanted[] = {
        D3D_FEATURE_LEVEL_12_1, D3D_FEATURE_LEVEL_12_0, D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0,
    };
    ID3D11Device *device = NULL;
    D3D_FEATURE_LEVEL level = 0;
    HRESULT hr = D3D11CreateDevice(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, wanted,
                                   sizeof(wanted) / sizeof(wanted[0]),
                                   D3D11_SDK_VERSION, &device, &level, NULL);
    if (SUCCEEDED(hr)) {
        printf("D3D11 cihazı: TAMAM, feature level %u.%u\n", (level >> 12) & 0xf, (level >> 8) & 0xf);
        ID3D11Device_Release(device);
    } else {
        printf("D3D11 cihazı: başarısız, 0x%08lx\n", hr);
    }
}

static void try_d3d12(void)
{
    ID3D12Device *device = NULL;
    HRESULT hr = D3D12CreateDevice(NULL, D3D_FEATURE_LEVEL_11_0, &IID_ID3D12Device, (void **)&device);
    if (SUCCEEDED(hr)) {
        printf("D3D12 cihazı: TAMAM\n");
        ID3D12Device_Release(device);
    } else {
        printf("D3D12 cihazı: başarısız, 0x%08lx\n", hr);
    }
}

int main(void)
{
    setvbuf(stdout, NULL, _IONBF, 0);
    printf("== dxgi-probe ==\n");
    int adapters = list_adapters();
    try_d3d11();
    try_d3d12();
    printf("Yüklenen DirectX DLL'leri:\n");
    print_module_path("dxgi.dll");
    print_module_path("d3d11.dll");
    print_module_path("d3d12.dll");
    return adapters > 0 ? 0 : 1;
}
