__declspec(dllimport) int runtime_value(void);
__declspec(dllexport) int worker_value(void) { return runtime_value(); }
