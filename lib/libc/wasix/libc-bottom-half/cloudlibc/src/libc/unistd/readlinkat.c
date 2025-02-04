// Copyright (c) 2015-2016 Nuxi, https://nuxi.nl/
//
// SPDX-License-Identifier: BSD-2-Clause

#include <common/errno.h>

#include <wasi/api.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>

ssize_t __wasilibc_nocwd_readlinkat(int fd, const char *restrict path, char *restrict buf,
                                    size_t bufsize) {
  __wasi_size_t bufused;
  // TODO: Remove the cast on `buf` once the witx is updated with char8 support.
  __wasi_errno_t error = __wasi_path_readlink(fd, path,
                                                      (uint8_t*)buf, bufsize, &bufused);
  if (error != 0) {
    errno = errno_fixup_directory(fd, error);
    return -1;
  }
  return bufused;
}
