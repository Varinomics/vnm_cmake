#include <windows.h>
#include <stdio.h>
#include <stdlib.h>

int main(int argc, char** argv)
{
    if (argc != 3) {
        fprintf(stderr, "Expected a worker path and result value.\n");
        return 1;
    }
    HMODULE worker = LoadLibraryA(argv[1]);
    if (!worker) {
        fprintf(stderr, "Worker load failed: %lu\n", GetLastError());
        return 1;
    }
    int (*value)(void) = (int (*)(void))GetProcAddress(worker, "worker_value");
    int result = value && value() == atoi(argv[2]) ? 0 : 1;
    if (result) {
        fprintf(stderr, "The worker did not return the staged runtime's value.\n");
    }
    FreeLibrary(worker);
    return result;
}
