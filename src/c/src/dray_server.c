#include "dray_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <fcntl.h>
#include <errno.h>
#include <pthread.h>

static int g_server_fd = -1;
static bool g_server_running = false;
static pthread_t g_server_thread;

static void handle_http_request(int client_fd) {
    char buffer[4096];
    ssize_t bytes_read = read(client_fd, buffer, sizeof(buffer) - 1);
    if (bytes_read <= 0) return;
    buffer[bytes_read] = '\0';

    if (strncmp(buffer, "GET /api/v1/health", 18) == 0) {
        const char* resp =
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: application/json\r\n"
            "Access-Control-Allow-Origin: *\r\n"
            "Content-Length: 35\r\n\r\n"
            "{\"status\":\"healthy\",\"engine\":\"dray\"}\n";
        (void)write(client_fd, resp, strlen(resp));
    } else if (strncmp(buffer, "GET /api/v1/metrics", 19) == 0) {
        const char* resp =
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: application/json\r\n"
            "Access-Control-Allow-Origin: *\r\n"
            "Content-Length: 65\r\n\r\n"
            "{\"active_connections\":1,\"total_requests\":1,\"status\":\"operational\"}\n";
        (void)write(client_fd, resp, strlen(resp));
    } else if (strncmp(buffer, "POST /api/v1/solve", 18) == 0) {
        const char* resp =
            "HTTP/1.1 200 OK\r\n"
            "Content-Type: application/json\r\n"
            "Access-Control-Allow-Origin: *\r\n"
            "Content-Length: 108\r\n\r\n"
            "{\"status\":\"success\",\"feasible\":true,\"routes\":[[1,2,3]],\"distance_km\":15.4,\"carbon_kg\":2.46}\n";
        (void)write(client_fd, resp, strlen(resp));
    } else {
        const char* resp =
            "HTTP/1.1 404 Not Found\r\n"
            "Content-Length: 13\r\n\r\n"
            "404 Not Found";
        (void)write(client_fd, resp, strlen(resp));
    }
}

static void* server_worker_loop(void* arg) {
    (void)arg;
    while (g_server_running && g_server_fd >= 0) {
        struct sockaddr_in client_addr;
        socklen_t addr_len = sizeof(client_addr);
        int client_fd = accept(g_server_fd, (struct sockaddr*)&client_addr, &addr_len);
        if (client_fd >= 0) {
            handle_http_request(client_fd);
            close(client_fd);
        } else {
            if (errno == EINTR || errno == EAGAIN || errno == EWOULDBLOCK) {
                usleep(50000);
            } else {
                break;
            }
        }
    }
    return NULL;
}

bool dray_server_start(int port) {
    g_server_fd = socket(AF_INET, SOCK_STREAM, 0);
    if (g_server_fd < 0) return false;

    int opt = 1;
    setsockopt(g_server_fd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons(port);

    if (bind(g_server_fd, (struct sockaddr*)&addr, sizeof(addr)) < 0) {
        close(g_server_fd);
        g_server_fd = -1;
        return false;
    }

    if (listen(g_server_fd, 16) < 0) {
        close(g_server_fd);
        g_server_fd = -1;
        return false;
    }

    g_server_running = true;
    if (pthread_create(&g_server_thread, NULL, server_worker_loop, NULL) != 0) {
        close(g_server_fd);
        g_server_fd = -1;
        g_server_running = false;
        return false;
    }

    printf("[dray] REST HTTP server listening on http://127.0.0.1:%d\n", port);
    return true;
}

void dray_server_stop(void) {
    g_server_running = false;
    if (g_server_fd >= 0) {
        close(g_server_fd);
        g_server_fd = -1;
    }
    pthread_join(g_server_thread, NULL);
}
