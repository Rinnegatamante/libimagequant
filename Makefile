STATICLIB=libimagequant.a
SHAREDLIB=libimagequant.$(SOLIBSUFFIX)
SOVER=0

JNILIB=libimagequant.jnilib
DLL=imagequant.dll
DLLIMP=imagequant_dll.a
DLLDEF=imagequant_dll.def
JNIDLL=libimagequant.dll
JNIDLLIMP=libimagequant_dll.a
JNIDLLDEF=libimagequant_dll.def

PREFIX  = arm-vita-eabi
CC      = $(PREFIX)-gcc
AR      = $(PREFIX)-ar

OBJS = pam.o mediancut.o blur.o mempool.o kmeans.o nearest.o libimagequant.o
SHAREDOBJS = $(subst .o,.lo,$(OBJS))

JAVACLASSES = org/pngquant/LiqObject.class org/pngquant/PngQuant.class org/pngquant/Image.class org/pngquant/Result.class
JAVAHEADERS = $(JAVACLASSES:.class=.h)
JAVAINCLUDE = -I'$(JAVA_HOME)/include' -I'$(JAVA_HOME)/include/linux' -I'$(JAVA_HOME)/include/win32' -I'$(JAVA_HOME)/include/darwin'

DISTFILES = $(OBJS:.o=.c) *.h README.md CHANGELOG COPYRIGHT Makefile configure
TARNAME = libimagequant-$(VERSION)
TARFILE = $(TARNAME)-src.tar.bz2
PKGCONFIG = imagequant.pc

all: static

static: $(STATICLIB)

shared: $(SHAREDLIB)

dll:
	$(MAKE) CFLAGS="$(CFLAGS) -DIMAGEQUANT_EXPORTS" $(DLL)

java: $(JNILIB)

java-dll:
	$(MAKE) CFLAGS="$(CFLAGS) -DIMAGEQUANT_EXPORTS" $(JNIDLL)

$(DLL) $(DLLIMP): $(OBJS)
	$(CC) -fPIC -shared -o $(DLL) $^ $(LDFLAGS) -Wl,--out-implib,$(DLLIMP),--output-def,$(DLLDEF)

$(STATICLIB): $(OBJS)
	$(AR) $(ARFLAGS) $@ $^

$(SHAREDOBJS):
	$(CC) -fPIC $(CFLAGS) -c $(@:.lo=.c) -o $@

libimagequant.so: $(SHAREDOBJS)
	$(CC) -shared -Wl,-soname,$(SHAREDLIB).$(SOVER) -o $(SHAREDLIB).$(SOVER) $^ $(LDFLAGS)
	ln -fs $(SHAREDLIB).$(SOVER) $(SHAREDLIB)
	sed -i "s#^prefix=.*#prefix=$(PREFIX)#" $(PKGCONFIG)
	sed -i "s#^Version:.*#Version: $(VERSION)#" $(PKGCONFIG)

libimagequant.dylib: $(SHAREDOBJS)
	$(CC) -shared -o $(SHAREDLIB).$(SOVER) $^ $(LDFLAGS)
	ln -fs $(SHAREDLIB).$(SOVER) $(SHAREDLIB)

$(OBJS): $(wildcard *.h)

$(JNILIB): $(JAVAHEADERS) $(STATICLIB) org/pngquant/PngQuant.c
	$(CC) -g $(CFLAGS) $(LDFLAGS) $(JAVAINCLUDE) -shared -o $@ $(STATICLIB) org/pngquant/PngQuant.c

$(JNIDLL) $(JNIDLLIMP): $(JAVAHEADERS) $(OBJS) org/pngquant/PngQuant.c
	$(CC) -fPIC -shared -I. $(JAVAINCLUDE) -o $(JNIDLL) $^ $(LDFLAGS) -Wl,--out-implib,$(JNIDLLIMP),--output-def,$(JNIDLLDEF)

$(JAVACLASSES): %.class: %.java
	javac $<

$(JAVAHEADERS): %.h: %.class
	javah -o $@ $(subst /,., $(patsubst %.class,%,$<)) && touch $@

dist: $(TARFILE) cargo

$(TARFILE): $(DISTFILES)
	rm -rf $(TARFILE) $(TARNAME)
	mkdir $(TARNAME)
	cp $(DISTFILES) $(TARNAME)
	tar -cjf $(TARFILE) --numeric-owner --exclude='._*' $(TARNAME)
	rm -rf $(TARNAME)
	-shasum $(TARFILE)

cargo:
	rm -rf msvc-dist
	git clone . -b msvc msvc-dist
	rm -rf msvc-dist/Cargo.toml msvc-dist/org msvc-dist/rust msvc-dist/README.md msvc-dist/COPYRIGHT
	cargo test

example: example.c lodepng.h lodepng.c $(STATICLIB)
	$(CC) -g $(CFLAGS) -Wall example.c $(STATICLIB) -o example

lodepng.h:
	curl -o lodepng.h -L https://raw.githubusercontent.com/lvandeve/lodepng/master/lodepng.h

lodepng.c:
	curl -o lodepng.c -L https://raw.githubusercontent.com/lvandeve/lodepng/master/lodepng.cpp

clean:
	rm -f $(OBJS) $(SHAREDOBJS) $(SHAREDLIB).$(SOVER) $(SHAREDLIB) $(STATICLIB) $(TARFILE) $(DLL) '$(DLLIMP)' '$(DLLDEF)'
	rm -f $(JAVAHEADERS) $(JAVACLASSES) $(JNILIB) example

install:
	[ -d $(DESTDIR)$(LIBDIR) ] || mkdir -p $(DESTDIR)$(LIBDIR)
	[ -d $(DESTDIR)$(PKGCONFIGDIR) ] || mkdir -p $(DESTDIR)$(PKGCONFIGDIR)
	[ -d $(DESTDIR)$(INCLUDEDIR) ] || mkdir -p $(DESTDIR)$(INCLUDEDIR)
	install $(SHAREDLIB).$(SOVER) $(DESTDIR)$(LIBDIR)/$(SHAREDLIB).$(SOVER)
	cp -P $(SHAREDLIB) $(DESTDIR)$(LIBDIR)/$(SHAREDLIB)
	install imagequant.pc $(DESTDIR)$(PKGCONFIGDIR)/imagequant.pc
	install libimagequant.h $(DESTDIR)$(INCLUDEDIR)/libimagequant.h

uninstall:
	rm -f $(DESTDIR)$(LIBDIR)/$(SHAREDLIB).$(SOVER)
	rm -f $(DESTDIR)$(LIBDIR)/$(SHAREDLIB)
	rm -f $(DESTDIR)$(PKGCONFIGDIR)/imagequant.pc
	rm -f $(DESTDIR)$(INCLUDEDIR)/libimagequant.h

.PHONY: all static shared clean dist distclean dll java cargo
.DELETE_ON_ERROR:
