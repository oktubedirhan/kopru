/*
 * d3d-window: pencere açar, D3D11 ya da D3D12 swapchain kurar ve pencereyi her saniye
 * başka bir renge boyar (kırmızı -> yeşil -> mavi). Amaç D3DMetal'in pencereye gerçekten
 * çizip çizmediğini görmek (dxgi-probe pencere açmıyordu).
 *
 * Kullanım: d3d-window.exe [--d3d12] [saniye]   (varsayılan D3D11, 10 sn; Esc ile erken kapanır)
 */
#define COBJMACROS
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <d3d11.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* Her API için aynı üç adım: kur, bir kareyi verilen renge boya ve ekrana ver, kapat. */
struct renderer
{
    const char *name;
    HRESULT (*init)(HWND hwnd);
    HRESULT (*draw)(const float rgba[4]);
    void (*cleanup)(void);
};

/* ---------------------------------------------------------------- D3D11 */

static IDXGISwapChain *d3d11_swapchain;
static ID3D11Device *d3d11_device;
static ID3D11DeviceContext *d3d11_context;
static ID3D11RenderTargetView *d3d11_rtv;

/* Önce oyunların çoğunun kullandığı modern "flip" modelini, olmazsa eski modeli dener. */
static HRESULT d3d11_init(HWND hwnd)
{
    static const D3D_FEATURE_LEVEL wanted[] = {
        D3D_FEATURE_LEVEL_12_1, D3D_FEATURE_LEVEL_12_0, D3D_FEATURE_LEVEL_11_1,
        D3D_FEATURE_LEVEL_11_0, D3D_FEATURE_LEVEL_10_1, D3D_FEATURE_LEVEL_10_0,
    };
    static const struct { DXGI_SWAP_EFFECT effect; const char *name; } effects[] = {
        { DXGI_SWAP_EFFECT_FLIP_DISCARD, "FLIP_DISCARD" },
        { DXGI_SWAP_EFFECT_DISCARD, "DISCARD" },
    };
    D3D_FEATURE_LEVEL level = 0;
    ID3D11Texture2D *backbuffer;
    HRESULT hr = E_FAIL;
    int i;

    for (i = 0; i < 2; i++) {
        DXGI_SWAP_CHAIN_DESC desc = {0};
        desc.BufferDesc.Format = DXGI_FORMAT_R8G8B8A8_UNORM; /* genişlik/yükseklik 0 = pencere boyutu */
        desc.SampleDesc.Count = 1;
        desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
        desc.BufferCount = 2;
        desc.OutputWindow = hwnd;
        desc.Windowed = TRUE;
        desc.SwapEffect = effects[i].effect;

        hr = D3D11CreateDeviceAndSwapChain(NULL, D3D_DRIVER_TYPE_HARDWARE, NULL, 0, wanted,
                                           sizeof(wanted) / sizeof(wanted[0]), D3D11_SDK_VERSION,
                                           &desc, &d3d11_swapchain, &d3d11_device, &level, &d3d11_context);
        if (SUCCEEDED(hr)) {
            printf("Swapchain: TAMAM (%s)\n", effects[i].name);
            break;
        }
        printf("Swapchain (%s): başarısız, 0x%08lx\n", effects[i].name, hr);
    }
    if (FAILED(hr))
        return hr;
    printf("D3D11 feature level %u.%u\n", (level >> 12) & 0xf, (level >> 8) & 0xf);

    hr = IDXGISwapChain_GetBuffer(d3d11_swapchain, 0, &IID_ID3D11Texture2D, (void **)&backbuffer);
    if (FAILED(hr))
        return hr;
    hr = ID3D11Device_CreateRenderTargetView(d3d11_device, (ID3D11Resource *)backbuffer, NULL, &d3d11_rtv);
    ID3D11Texture2D_Release(backbuffer);
    return hr;
}

static HRESULT d3d11_draw(const float rgba[4])
{
    ID3D11DeviceContext_OMSetRenderTargets(d3d11_context, 1, &d3d11_rtv, NULL);
    ID3D11DeviceContext_ClearRenderTargetView(d3d11_context, d3d11_rtv, rgba);
    return IDXGISwapChain_Present(d3d11_swapchain, 1, 0); /* 1 = ekran yenilemesini bekle (vsync) */
}

static void d3d11_cleanup(void)
{
    if (d3d11_rtv) ID3D11RenderTargetView_Release(d3d11_rtv);
    if (d3d11_context) ID3D11DeviceContext_Release(d3d11_context);
    if (d3d11_swapchain) IDXGISwapChain_Release(d3d11_swapchain);
    if (d3d11_device) ID3D11Device_Release(d3d11_device);
}

/* ---------------------------------------------------------------- D3D12 */

/* D3D12 alt seviye: komut listesini, kaynak durumlarını ve GPU ile eşzamanlamayı (fence)
 * program kendisi yönetir. Elden Ring gibi DX12 oyunları bu yolu kullanır. */
#define D3D12_BUFFERS 2

static ID3D12Device *d3d12_device;
static ID3D12CommandQueue *d3d12_queue;
static IDXGISwapChain3 *d3d12_swapchain;
static ID3D12DescriptorHeap *d3d12_rtv_heap;
static D3D12_CPU_DESCRIPTOR_HANDLE d3d12_rtv_start;
static UINT d3d12_rtv_size;
static ID3D12Resource *d3d12_buffers[D3D12_BUFFERS];
static ID3D12CommandAllocator *d3d12_allocator;
static ID3D12GraphicsCommandList *d3d12_list;
static ID3D12Fence *d3d12_fence;
static UINT64 d3d12_fence_value;
static HANDLE d3d12_fence_event;

static HRESULT d3d12_init(HWND hwnd)
{
    D3D12_COMMAND_QUEUE_DESC queue_desc = {0};
    D3D12_DESCRIPTOR_HEAP_DESC heap_desc = {0};
    DXGI_SWAP_CHAIN_DESC1 desc = {0};
    IDXGIFactory4 *factory = NULL;
    IDXGISwapChain1 *swapchain1 = NULL;
    HRESULT hr;
    UINT i;

#define CHECK(call) do { hr = (call); if (FAILED(hr)) { printf("%s: başarısız, 0x%08lx\n", #call, hr); goto done; } } while (0)
    CHECK(CreateDXGIFactory2(0, &IID_IDXGIFactory4, (void **)&factory));
    CHECK(D3D12CreateDevice(NULL, D3D_FEATURE_LEVEL_11_0, &IID_ID3D12Device, (void **)&d3d12_device));

    queue_desc.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
    CHECK(ID3D12Device_CreateCommandQueue(d3d12_device, &queue_desc, &IID_ID3D12CommandQueue, (void **)&d3d12_queue));

    desc.Format = DXGI_FORMAT_R8G8B8A8_UNORM;
    desc.SampleDesc.Count = 1;
    desc.BufferUsage = DXGI_USAGE_RENDER_TARGET_OUTPUT;
    desc.BufferCount = D3D12_BUFFERS;
    desc.SwapEffect = DXGI_SWAP_EFFECT_FLIP_DISCARD; /* D3D12 yalnızca flip modelini destekler */
    CHECK(IDXGIFactory4_CreateSwapChainForHwnd(factory, (IUnknown *)d3d12_queue, hwnd, &desc, NULL, NULL, &swapchain1));
    CHECK(IDXGISwapChain1_QueryInterface(swapchain1, &IID_IDXGISwapChain3, (void **)&d3d12_swapchain));
    printf("Swapchain: TAMAM (D3D12, FLIP_DISCARD)\n");

    /* Her arka tampon için bir "render target view" (GPU'ya 'buraya çiz' tarifi). */
    heap_desc.Type = D3D12_DESCRIPTOR_HEAP_TYPE_RTV;
    heap_desc.NumDescriptors = D3D12_BUFFERS;
    CHECK(ID3D12Device_CreateDescriptorHeap(d3d12_device, &heap_desc, &IID_ID3D12DescriptorHeap, (void **)&d3d12_rtv_heap));
    d3d12_rtv_size = ID3D12Device_GetDescriptorHandleIncrementSize(d3d12_device, D3D12_DESCRIPTOR_HEAP_TYPE_RTV);
    /* Yapı döndüren COM metodu: C'de vtable üzerinden, sonucu çıktı parametresiyle almak gerekiyor. */
    d3d12_rtv_heap->lpVtbl->GetCPUDescriptorHandleForHeapStart(d3d12_rtv_heap, &d3d12_rtv_start);
    for (i = 0; i < D3D12_BUFFERS; i++) {
        D3D12_CPU_DESCRIPTOR_HANDLE handle = { d3d12_rtv_start.ptr + i * d3d12_rtv_size };
        CHECK(IDXGISwapChain3_GetBuffer(d3d12_swapchain, i, &IID_ID3D12Resource, (void **)&d3d12_buffers[i]));
        ID3D12Device_CreateRenderTargetView(d3d12_device, d3d12_buffers[i], NULL, handle);
    }

    CHECK(ID3D12Device_CreateCommandAllocator(d3d12_device, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                              &IID_ID3D12CommandAllocator, (void **)&d3d12_allocator));
    CHECK(ID3D12Device_CreateCommandList(d3d12_device, 0, D3D12_COMMAND_LIST_TYPE_DIRECT, d3d12_allocator, NULL,
                                         &IID_ID3D12GraphicsCommandList, (void **)&d3d12_list));
    CHECK(ID3D12GraphicsCommandList_Close(d3d12_list));
    CHECK(ID3D12Device_CreateFence(d3d12_device, 0, D3D12_FENCE_FLAG_NONE, &IID_ID3D12Fence, (void **)&d3d12_fence));
    d3d12_fence_event = CreateEventW(NULL, FALSE, FALSE, NULL);
#undef CHECK

done:
    if (swapchain1) IDXGISwapChain1_Release(swapchain1);
    if (factory) IDXGIFactory4_Release(factory);
    return hr;
}

static void d3d12_transition(ID3D12Resource *resource, D3D12_RESOURCE_STATES before, D3D12_RESOURCE_STATES after)
{
    D3D12_RESOURCE_BARRIER barrier = {0};
    barrier.Type = D3D12_RESOURCE_BARRIER_TYPE_TRANSITION;
    barrier.Transition.pResource = resource;
    barrier.Transition.Subresource = D3D12_RESOURCE_BARRIER_ALL_SUBRESOURCES;
    barrier.Transition.StateBefore = before;
    barrier.Transition.StateAfter = after;
    ID3D12GraphicsCommandList_ResourceBarrier(d3d12_list, 1, &barrier);
}

static HRESULT d3d12_draw(const float rgba[4])
{
    UINT index = IDXGISwapChain3_GetCurrentBackBufferIndex(d3d12_swapchain);
    D3D12_CPU_DESCRIPTOR_HANDLE rtv = { d3d12_rtv_start.ptr + index * d3d12_rtv_size };
    HRESULT hr;

    ID3D12CommandAllocator_Reset(d3d12_allocator);
    ID3D12GraphicsCommandList_Reset(d3d12_list, d3d12_allocator, NULL);
    d3d12_transition(d3d12_buffers[index], D3D12_RESOURCE_STATE_PRESENT, D3D12_RESOURCE_STATE_RENDER_TARGET);
    ID3D12GraphicsCommandList_ClearRenderTargetView(d3d12_list, rtv, rgba, 0, NULL);
    d3d12_transition(d3d12_buffers[index], D3D12_RESOURCE_STATE_RENDER_TARGET, D3D12_RESOURCE_STATE_PRESENT);
    ID3D12GraphicsCommandList_Close(d3d12_list);
    ID3D12CommandQueue_ExecuteCommandLists(d3d12_queue, 1, (ID3D12CommandList **)&d3d12_list);

    hr = IDXGISwapChain3_Present(d3d12_swapchain, 1, 0);

    /* Basit tutmak için her karede GPU'nun bitirmesini bekle (komut ayırıcıyı yeniden kullanabilmek için). */
    ID3D12CommandQueue_Signal(d3d12_queue, d3d12_fence, ++d3d12_fence_value);
    if (ID3D12Fence_GetCompletedValue(d3d12_fence) < d3d12_fence_value) {
        ID3D12Fence_SetEventOnCompletion(d3d12_fence, d3d12_fence_value, d3d12_fence_event);
        WaitForSingleObject(d3d12_fence_event, 5000);
    }
    return hr;
}

static void d3d12_cleanup(void)
{
    UINT i;
    if (d3d12_fence_event) CloseHandle(d3d12_fence_event);
    if (d3d12_fence) ID3D12Fence_Release(d3d12_fence);
    if (d3d12_list) ID3D12GraphicsCommandList_Release(d3d12_list);
    if (d3d12_allocator) ID3D12CommandAllocator_Release(d3d12_allocator);
    for (i = 0; i < D3D12_BUFFERS; i++)
        if (d3d12_buffers[i]) ID3D12Resource_Release(d3d12_buffers[i]);
    if (d3d12_rtv_heap) ID3D12DescriptorHeap_Release(d3d12_rtv_heap);
    if (d3d12_swapchain) IDXGISwapChain3_Release(d3d12_swapchain);
    if (d3d12_queue) ID3D12CommandQueue_Release(d3d12_queue);
    if (d3d12_device) ID3D12Device_Release(d3d12_device);
}

/* ---------------------------------------------------------------- pencere ve döngü */

static const struct renderer renderers[] = {
    { "D3D11", d3d11_init, d3d11_draw, d3d11_cleanup },
    { "D3D12", d3d12_init, d3d12_draw, d3d12_cleanup },
};

static LRESULT CALLBACK window_proc(HWND hwnd, UINT msg, WPARAM wparam, LPARAM lparam)
{
    if (msg == WM_DESTROY) {
        PostQuitMessage(0);
        return 0;
    }
    if (msg == WM_KEYDOWN && wparam == VK_ESCAPE) {
        DestroyWindow(hwnd);
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wparam, lparam);
}

static HWND create_window(const char *api)
{
    WCHAR title[64];
    WNDCLASSW wc = {0};
    wc.lpfnWndProc = window_proc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.hCursor = LoadCursorW(NULL, (LPCWSTR)IDC_ARROW);
    wc.lpszClassName = L"KopruD3DWindow";
    RegisterClassW(&wc);

    swprintf(title, ARRAYSIZE(title), L"Köprü %hs pencere testi", api);
    HWND hwnd = CreateWindowW(wc.lpszClassName, title, WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT,
                              800, 600, NULL, NULL, wc.hInstance, NULL);
    if (hwnd) {
        ShowWindow(hwnd, SW_SHOW);
        UpdateWindow(hwnd);
    }
    return hwnd;
}

int main(int argc, char **argv)
{
    static const struct { float rgba[4]; const char *name; } colors[] = {
        { { 0.85f, 0.10f, 0.10f, 1.0f }, "KIRMIZI" },
        { { 0.10f, 0.75f, 0.20f, 1.0f }, "YEŞİL" },
        { { 0.10f, 0.30f, 0.90f, 1.0f }, "MAVİ" },
    };
    const struct renderer *r = &renderers[0];
    int seconds = 10;
    int i;

    for (i = 1; i < argc; i++) {
        if (!strcmp(argv[i], "--d3d12"))
            r = &renderers[1];
        else if (atoi(argv[i]) > 0)
            seconds = atoi(argv[i]);
    }

    setvbuf(stdout, NULL, _IONBF, 0);
    printf("== d3d-window: %s, %d sn ==\n", r->name, seconds);

    HWND hwnd = create_window(r->name);
    if (!hwnd) {
        printf("Pencere açılamadı: %lu\n", GetLastError());
        return 1;
    }
    if (FAILED(r->init(hwnd))) {
        r->cleanup();
        return 2;
    }

    ULONGLONG start = GetTickCount64();
    unsigned frames = 0, present_errors = 0;
    int last_color = -1, running = 1;
    HRESULT hr, first_present_error = S_OK;

    while (running) {
        MSG msg;
        while (PeekMessageW(&msg, NULL, 0, 0, PM_REMOVE)) {
            if (msg.message == WM_QUIT)
                running = 0;
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
        ULONGLONG elapsed = GetTickCount64() - start;
        if (!running || elapsed >= (ULONGLONG)seconds * 1000)
            break;

        int color = (int)(elapsed / 1000) % 3;
        if (color != last_color) {
            printf("  %2llu. sn: %s\n", elapsed / 1000 + 1, colors[color].name);
            last_color = color;
        }

        hr = r->draw(colors[color].rgba);
        if (FAILED(hr) && present_errors++ == 0)
            first_present_error = hr;
        frames++;
    }

    double secs = (GetTickCount64() - start) / 1000.0;
    printf("Kare: %u, süre: %.1f sn, ortalama %.1f FPS\n", frames, secs, frames / secs);
    if (present_errors)
        printf("Present hatası: %u kez (ilki 0x%08lx)\n", present_errors, first_present_error);
    else
        printf("Present: hatasız\n");

    r->cleanup();
    if (IsWindow(hwnd))
        DestroyWindow(hwnd);
    return present_errors ? 4 : 0;
}
