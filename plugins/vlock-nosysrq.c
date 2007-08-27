/* vlock-nosysrq.c -- sysrq protection routine for vlock,
 *                   the VT locking program for linux
 *
 * This program is copyright (C) 2007 Frank Benkstein, and is free
 * software which is freely distributable under the terms of the
 * GNU General Public License version 2, included as the file COPYING in this
 * distribution.  It is NOT public domain software, and any
 * redistribution not permitted by the GNU General Public License is
 * expressly forbidden without prior written permission from
 * the author.
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "vlock_plugin.h"

const char *before[] = { "vlock-new", "vlock-all", NULL };
const char *depends[] = { "vlock-all", NULL };

#define SYSRQ_PATH "/proc/sys/kernel/sysrq"
#define SYSRQ_DISABLE_VALUE "0\n"

struct sysrq_context {
  FILE *file;
  char value[32];
};

int vlock_start(void **ctx_ptr) {
  struct sysrq_context *ctx;

  /* allocate the context */
  if ((ctx = malloc(sizeof *ctx)) == NULL)
    return -1;

  /* XXX: add optional PAM check here */

  /* open the sysrq sysctl file for reading and writing */
  if ((ctx->file = fopen(SYSRQ_PATH, "r+")) == NULL) {
    perror("vlock-nosysrq: could not open '" SYSRQ_PATH "'");
    goto err;
  }

  /* read the old value */
  if (fgets(ctx->value, sizeof ctx->value, ctx->file) == NULL) {
    perror("vlock-nosysrq: could not read from '" SYSRQ_PATH "'");
    goto err;
  }

  /* check whether all was read */
  if (feof(ctx->file) != 0) {
    fprintf(stderr, "vlock-nosysrq: sysrq buffer to small: %d\n", sizeof ctx->value);
    goto err;
  }

  /* disable sysrq */
  if (fseek(ctx->file, 0, SEEK_SET) < 0
      || ftruncate(fileno(ctx->file), 0) < 0
      || fputs(SYSRQ_DISABLE_VALUE, ctx->file) < 0
      || fflush(ctx->file) < 0) {
    perror("vlock-nosysrq: could not write disable value to '" SYSRQ_PATH "'");
    goto err;
  }

  *ctx_ptr = ctx;
  return 0;

err:
  free(ctx);
  return -1;
}


int vlock_end(void **ctx_ptr) {
  struct sysrq_context *ctx = *ctx_ptr;

  if (ctx == NULL)
    return 0;

  if (fseek(ctx->file, 0, SEEK_SET) < 0
      || ftruncate(fileno(ctx->file), 0) < 0
      || fputs(ctx->value, ctx->file) < 0
      || fflush(ctx->file) < 0)
    perror("vlock-nosysrq: could not restore old value to '" SYSRQ_PATH "'");

  free(ctx);
  return 0;
}