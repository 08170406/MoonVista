#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <wchar.h>
#include "moonbit.h"

MOONBIT_FFI_EXPORT
int moonvista_console_read_line(moonbit_bytes_t buffer, int capacity) {
  if (buffer == NULL || capacity < 2) {
    return -1;
  }
  char *line = fgets((char *)buffer, capacity, stdin);
  if (line == NULL) {
    return -1;
  }
  size_t length = strlen(line);
  if (length > 0 && line[length - 1] == '\n') {
    line[--length] = '\0';
    if (length > 0 && line[length - 1] == '\r') {
      line[--length] = '\0';
    }
    return (int)length;
  }
  if (length > 0 && line[length - 1] == '\r') {
    line[--length] = '\0';
    int next = getchar();
    if (next != '\n' && next != EOF) {
      while (next != '\n' && next != EOF) {
        next = getchar();
      }
      return -2;
    }
    return (int)length;
  }
  if ((int)length == capacity - 1) {
    int next = getchar();
    if (next == EOF || next == '\n') {
      return (int)length;
    }
    if (next == '\r') {
      next = getchar();
      if (next == EOF || next == '\n') {
        return (int)length;
      }
    }
    while (next != '\n' && next != EOF) {
      next = getchar();
    }
    return -2;
  }
  return (int)length;
}

#ifdef _WIN32
MOONBIT_FFI_EXPORT
int moonvista_console_write_new_file(moonbit_string_t path,
                                     moonbit_bytes_t content, int length) {
  FILE *file = _wfopen((const wchar_t *)path, L"wbx");
#else
MOONBIT_FFI_EXPORT
int moonvista_console_write_new_file(moonbit_bytes_t path,
                                     moonbit_bytes_t content, int length) {
  FILE *file = fopen((const char *)path, "wbx");
#endif
  if (file == NULL) {
    return errno == EEXIST ? 1 : -1;
  }
  if (length < 0 || fwrite(content, 1, (size_t)length, file) != (size_t)length) {
    fclose(file);
    return -1;
  }
  int flush_status = fflush(file);
  int close_status = fclose(file);
  if (flush_status != 0 || close_status != 0) {
    return -1;
  }
  return 0;
}
