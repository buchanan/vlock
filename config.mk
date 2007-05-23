# should we build against pam?
USE_PAM = y
USE_ROOT_PASS = y
PREFIX = /usr/local
DESTDIR =

CC = gcc
CFLAGS = -O2
INSTALL = install

ifneq ($(USE_ROOT_PASS),y)
	CFLAGS += -DNO_ROOT_PASS
endif

ifeq ($(USE_PAM),y)
	CFLAGS += -DUSE_PAM
	LDFLAGS += -ldl -lpam -lpam_misc
else
	CFLAGS += -DSHADOW_PWD
	LDFLAGS += -lcrypt
endif