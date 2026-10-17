/*
 * net-probe: Wine'ın HTTPS yolunu (WinHTTP -> schannel -> GnuTLS) sınar.
 * Varsayılan olarak Steam'in bağlanacağı sunucu listesini (CM list) ister.
 *
 * Kullanım: net-probe.exe [https://adres/yol]
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <winhttp.h>
#include <stdio.h>
#include <wchar.h>

static const WCHAR default_url[] =
    L"https://api.steampowered.com/ISteamDirectory/GetCMListForConnect/v1/?cellid=0&format=json";

static void fail(const char *step)
{
    printf("%s: başarısız, hata %lu\n", step, GetLastError());
}

int wmain(int argc, WCHAR **argv)
{
    const WCHAR *url = argc > 1 ? argv[1] : default_url;
    WCHAR host[256], path[2048];
    URL_COMPONENTS parts = { sizeof(parts) };
    HINTERNET session = NULL, connection = NULL, request = NULL;
    DWORD status = 0, size = sizeof(status), read = 0, total = 0;
    char buffer[4096];
    int ret = 1;

    setvbuf(stdout, NULL, _IONBF, 0);
    printf("== net-probe ==\nAdres: %ls\n", url);

    parts.lpszHostName = host;
    parts.dwHostNameLength = ARRAYSIZE(host);
    parts.lpszUrlPath = path;
    parts.dwUrlPathLength = ARRAYSIZE(path);
    if (!WinHttpCrackUrl(url, 0, 0, &parts)) { fail("WinHttpCrackUrl"); return 1; }

    if (!(session = WinHttpOpen(L"Kopru-net-probe/1.0", WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                                WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0)))
        { fail("WinHttpOpen"); goto done; }
    if (!(connection = WinHttpConnect(session, host, parts.nPort, 0)))
        { fail("WinHttpConnect"); goto done; }
    if (!(request = WinHttpOpenRequest(connection, L"GET", path, NULL, WINHTTP_NO_REFERER,
                                       WINHTTP_DEFAULT_ACCEPT_TYPES,
                                       parts.nScheme == INTERNET_SCHEME_HTTPS ? WINHTTP_FLAG_SECURE : 0)))
        { fail("WinHttpOpenRequest"); goto done; }

    /* TLS el sıkışması burada olur: sertifika doğrulama hatası 12175 (SECURE_FAILURE) olarak döner. */
    if (!WinHttpSendRequest(request, WINHTTP_NO_ADDITIONAL_HEADERS, 0, WINHTTP_NO_REQUEST_DATA, 0, 0, 0))
        { fail("WinHttpSendRequest (bağlantı + TLS)"); goto done; }
    if (!WinHttpReceiveResponse(request, NULL))
        { fail("WinHttpReceiveResponse"); goto done; }

    WinHttpQueryHeaders(request, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
                        WINHTTP_HEADER_NAME_BY_INDEX, &status, &size, WINHTTP_NO_HEADER_INDEX);
    printf("HTTP durum kodu: %lu\n", status);

    while (WinHttpReadData(request, buffer, sizeof(buffer) - 1, &read) && read) {
        if (total < 400) {
            buffer[read] = 0;
            printf("%.*s", (int)(400 - total < read ? 400 - total : read), buffer);
        }
        total += read;
    }
    printf("\n... toplam %lu bayt\n", total);
    ret = status == 200 ? 0 : 2;

done:
    if (request) WinHttpCloseHandle(request);
    if (connection) WinHttpCloseHandle(connection);
    if (session) WinHttpCloseHandle(session);
    return ret;
}
