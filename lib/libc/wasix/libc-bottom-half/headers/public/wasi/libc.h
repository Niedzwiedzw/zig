#ifndef __wasi_libc_h
#define __wasi_libc_h

#include <wasi/api.h>
#include <__typedef_off_t.h>
#include <__struct_timespec.h>

#ifdef __cplusplus
extern "C" {
#endif

struct stat;
struct timespec;

/// Register the given pre-opened file descriptor under the given path.
///
/// This function does not take ownership of `prefix` (it makes its own copy).
int __wasilibc_register_preopened_fd(int fd, const char *prefix);

/// Renumber `fd` to `newfd`; similar to `dup2` but does a move rather than a
/// copy.
int __wasilibc_fd_renumber(int fd, int newfd)
    __attribute__((__warn_unused_result__));

/// Like `unlinkat`, but without depending on `__wasi_path_remove_directory`.
int __wasilibc_unlinkat(int fd, const char *path)
    __attribute__((__warn_unused_result__));

/// An `*at` version of rmdir.
int __wasilibc_rmdirat(int fd, const char *path)
    __attribute__((__warn_unused_result__));

/// Like `open`, but without the varargs in the signature.
int __wasilibc_open_nomode(const char *path, int oflag);

/// Like `openat`, but without the varargs in the signature.
int __wasilibc_openat_nomode(int fd, const char *path, int oflag);

// Initialize the library environ
void __wasilibc_initialize_environ(void);

/// Used for accessing the stack pointers
void* __wasilibc_get_stack_pointer(void);
void __wasilibc_set_stack_pointer(void *val);
void __wasilibc_init_tls(void *val);
void* __wasilibc_get_tls_base(void);
void __wasilibc_set_tls_base(void *val);
unsigned long long __wasilibc_tls_size(void);
unsigned long long __wasilibc_tls_align(void);
int __wasilibc_setjmp(__wasi_stack_snapshot_t * buf);
_Noreturn void __wasilibc_longjmp(__wasi_stack_snapshot_t * buf, int val);

/// Futex implemenation
void __wasilibc_futex_wait(int* futex, int expected);
void __wasilibc_futex_wake(int* futex, int cnt);

/// Return the current file offset. Like `lseek(fd, 0, SEEK_CUR)`, but without
/// depending on `lseek`.
off_t __wasilibc_tell(int fd)
    __attribute__((__warn_unused_result__));

/* Non-`at` forms of various `*at` functions. */
int __wasilibc_access(const char *pathname, int mode, int flags)
    __attribute__((__warn_unused_result__));
int __wasilibc_stat(const char *__restrict pathname, struct stat *__restrict statbuf, int flags)
    __attribute__((__warn_unused_result__));
int __wasilibc_utimens(const char *pathname, const struct timespec times[2], int flags)
    __attribute__((__warn_unused_result__));
int __wasilibc_link(const char *oldpath, const char *newpath, int flags)
    __attribute__((__warn_unused_result__));
int __wasilibc_link_oldat(int olddirfd, const char *oldpath, const char *newpath, int flags)
    __attribute__((__warn_unused_result__));
int __wasilibc_link_newat(const char *oldpath, int newdirfd, const char *newpath, int flags)
    __attribute__((__warn_unused_result__));
int __wasilibc_rename_oldat(int olddirfd, const char *oldpath, const char *newpath)
    __attribute__((__warn_unused_result__));
int __wasilibc_rename_newat(const char *oldpath, int newdirfd, const char *newpath)
    __attribute__((__warn_unused_result__));

#ifdef __cplusplus
}
#endif

#endif
