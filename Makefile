# vlock makefile

include config.mk

VPATH = src

VLOCK_VERSION = 2.3-alpha1

PROGRAMS = vlock vlock-main

.PHONY: all
all: $(PROGRAMS)

.PHONY: debug
debug:
	@$(MAKE) DEBUG=y

ifeq ($(ENABLE_PLUGINS),yes)
all: plugins
endif

.PHONY: plugins
plugins: modules scripts

.PHONY: modules
modules:
	@$(MAKE) -C modules

.PHONY: scripts
scripts:
	@$(MAKE) -C scripts

.PHONY: check memcheck
check memcheck:
	@$(MAKE) -C tests $@

.PHONY: uncrustify
uncrustify:
	uncrustify -c .uncrustify.cfg --mtime --no-backup $(wildcard src/*.c src/*.h)

### configuration ###

config.mk:
	$(info )
	$(info ###################################################)
	$(info # Creating default configuration.                 #)
	$(info # Run ./configure or edit config.mk to customize. #)
	$(info ###################################################)
	$(info )
	@./configure --quiet

### installation rules ###

.PHONY: install
install: install-programs install-man

ifeq ($(ENABLE_PLUGINS),yes)
install: install-plugins
endif

.PHONY: install-programs
install-programs: $(PROGRAMS)
	$(MKDIR_P) -m 755 $(DESTDIR)$(PREFIX)/bin
	$(INSTALL) -m 755 -o root -g $(ROOT_GROUP) vlock $(DESTDIR)$(BINDIR)/vlock
	$(MKDIR_P) -m 755 $(DESTDIR)$(PREFIX)/sbin
	$(INSTALL) -m 4711 -o root -g $(ROOT_GROUP) vlock-main $(DESTDIR)$(SBINDIR)/vlock-main

.PHONY: install-plugins
install-plugins: install-modules install-scripts

.PHONY: install-modules
install-modules:
	@$(MAKE) -C modules install

.PHONY: install-scripts
install-scripts:
	@$(MAKE) -C scripts install

.PHONY: install-man
install-man:
	$(MKDIR_P) -m 755 $(DESTDIR)$(MANDIR)/man1
	$(INSTALL) -m 644 -o root -g $(ROOT_GROUP) man/vlock.1 $(DESTDIR)$(MANDIR)/man1/vlock.1
	$(MKDIR_P) -m 755 $(DESTDIR)$(MANDIR)/man8
	$(INSTALL) -m 644 -o root -g $(ROOT_GROUP) man/vlock-main.8 $(DESTDIR)$(MANDIR)/man8/vlock-main.8
	$(MKDIR_P) -m 755 $(DESTDIR)$(MANDIR)/man5
	$(INSTALL) -m 644 -o root -g $(ROOT_GROUP) man/vlock-plugins.5 $(DESTDIR)$(MANDIR)/man5/vlock-plugins.5


### build rules ###

vlock: vlock.sh config.mk Makefile
	$(BOURNE_SHELL) -n $<
	sed \
		-e 's,%BOURNE_SHELL%,$(BOURNE_SHELL),' \
		-e 's,%PREFIX%,$(PREFIX),' \
		-e 's,%VLOCK_VERSION%,$(VLOCK_VERSION),' \
		-e 's,%VLOCK_ENABLE_PLUGINS%,$(ENABLE_PLUGINS),' \
		$< > $@.tmp
	mv -f $@.tmp $@

override CFLAGS += -Isrc

VLOCK_MAIN_SOURCES = \
	vlock-main.c \
	prompt.c \
	auth-$(AUTH_METHOD).c \
	console_switch.c \
	signals.c \
	terminal.c \
	util.c \
	logging.c

VLOCK_MAIN_OBJECTS = $(VLOCK_MAIN_SOURCES:.c=.o)

ifeq ($(ENABLE_PLUGINS),yes)
VLOCK_MAIN_SOURCES += plugins.c plugin.c module.c process.c script.c tsort.c

# -rdynamic is needed so that the all plugin can access the symbols from console_switch.o
vlock-main : override LDFLAGS += -rdynamic
vlock-main : override LDLIBS += $(DL_LIB)
vlock-main.o : override CFLAGS += -DUSE_PLUGINS

module.o : override CFLAGS += -DVLOCK_MODULE_DIR="\"$(MODULEDIR)\""
script.o : override CFLAGS += -DVLOCK_SCRIPT_DIR="\"$(SCRIPTDIR)\""
endif

ifneq ($(ENABLE_ROOT_PASSWORD),yes)
vlock-main.o : override CFLAGS += -DNO_ROOT_PASS
endif

ifeq ($(AUTH_METHOD),pam)
vlock-main : override LDLIBS += $(PAM_LIBS)
endif

ifeq ($(AUTH_METHOD),shadow)
vlock-main : override LDLIBS += $(CRYPT_LIB)
endif

vlock-main: $(VLOCK_MAIN_OBJECTS)

# dependencies generated by gcc
.deps.mk: $(VLOCK_MAIN_SOURCES)
	$(info Regenerating dependencies ...)
	@$(CC) $(CFLAGS) -MM $^ > $@

include .deps.mk

.PHONY: realclean
realclean: clean
	$(RM) config.mk

.PHONY: clean
clean:
	$(RM) $(PROGRAMS) $(VLOCK_MAIN_OBJECTS) .deps.mk
	@$(MAKE) -C modules clean
	@$(MAKE) -C scripts clean
	@$(MAKE) -C tests clean
