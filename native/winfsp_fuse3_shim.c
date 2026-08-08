/*
 * WinFsp FUSE-compatible shim for RepoDrive (Windows).
 * Requires WinFsp development package; include path typically:
 *   C:\Program Files (x86)\WinFsp\inc\fuse
 * Link against winfsp-x64.lib (or ARM64).
 *
 * Build note: if WinFsp headers are missing, this file provides a stub
 * rd_fuse_main that prints install instructions and returns 1.
 */
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <fcntl.h>

#if defined(REPODRIVE_HAVE_WINFSP)
#define FUSE_USE_VERSION 31
#include <fuse.h>
#include <sys/stat.h>

extern int rd_getattr(const char *path, long *size, int *is_dir);
extern int rd_readdir(const char *path, void *buf,
                      int (*filler)(void *, const char *, int is_dir));
extern int rd_read(const char *path, char *buf, unsigned long size, long offset);

struct fill_ctx {
    void *buf;
    fuse_fill_dir_t filler;
};

static int fill_cb(void *buf, const char *name, int is_dir) {
    struct fill_ctx *ctx = (struct fill_ctx *)buf;
    struct stat st;
    memset(&st, 0, sizeof(st));
    st.st_mode = is_dir ? (S_IFDIR | 0555) : (S_IFREG | 0444);
    return ctx->filler(ctx->buf, name, &st, 0, 0);
}

static int rd_fuse_getattr(const char *path, struct stat *stbuf) {
    memset(stbuf, 0, sizeof(struct stat));
    long size = 0;
    int is_dir = 0;
    int rc = rd_getattr(path, &size, &is_dir);
    if (rc == -2) return -ENOENT;
    if (rc != 0) return -EIO;
    if (is_dir) {
        stbuf->st_mode = S_IFDIR | 0555;
        stbuf->st_nlink = 2;
    } else {
        stbuf->st_mode = S_IFREG | 0444;
        stbuf->st_nlink = 1;
        stbuf->st_size = size;
    }
    return 0;
}

static int rd_fuse_readdir(const char *path, void *buf, fuse_fill_dir_t filler,
                           off_t offset, struct fuse_file_info *fi) {
    (void)offset;
    (void)fi;
    filler(buf, ".", NULL, 0);
    filler(buf, "..", NULL, 0);
    struct fill_ctx ctx;
    ctx.buf = buf;
    ctx.filler = filler;
    int rc = rd_readdir(path, &ctx, fill_cb);
    if (rc != 0) return -EIO;
    return 0;
}

static int rd_fuse_open(const char *path, struct fuse_file_info *fi) {
    long size = 0;
    int is_dir = 0;
    int rc = rd_getattr(path, &size, &is_dir);
    if (rc == -2) return -ENOENT;
    if (rc != 0 || is_dir) return -EIO;
    if ((fi->flags & O_ACCMODE) != O_RDONLY) return -EACCES;
    return 0;
}

static int rd_fuse_read(const char *path, char *buf, size_t size, off_t offset,
                        struct fuse_file_info *fi) {
    (void)fi;
    int n = rd_read(path, buf, (unsigned long)size, (long)offset);
    if (n == -2) return -ENOENT;
    if (n < 0) return -EIO;
    return n;
}

static struct fuse_operations rd_ops = {
    .getattr = rd_fuse_getattr,
    .readdir = rd_fuse_readdir,
    .open = rd_fuse_open,
    .read = rd_fuse_read,
};

int rd_fuse_main(int argc, char **argv) {
    return fuse_main(argc, argv, &rd_ops, NULL);
}

#else

/* Stub when WinFsp SDK is not available at compile time. */
int rd_fuse_main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    fprintf(stderr,
        "RepoDrive: WinFsp SDK not detected at build time.\n"
        "Install WinFsp from https://winfsp.dev/ and rebuild with -DREPODRIVE_HAVE_WINFSP\n"
        "and include/lib paths for the WinFsp FUSE layer.\n"
        "Meanwhile use: repodrive ls <path> for virtual listings without a mount.\n");
    return 1;
}

#endif
