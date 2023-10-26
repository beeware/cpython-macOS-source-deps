#
# Useful targets:
# - all             - build everything
# - BZip2           - build BZip2
# - XZ              - build XZ
# - OpenSSL         - build OpenSSL

# Current directory
PROJECT_DIR=$(shell pwd)

# Supported OS and products
PRODUCTS=BZip2 XZ OpenSSL
OS_LIST=macOS

# The versions to compile by default.
# In practice, these should be
# This can be overwritten at build time:
# e.g., `make BZip2 BZIP2_VERSION=1.2.3`

BUILD_NUMBER=custom

BZIP2_VERSION=1.0.8

XZ_VERSION=5.4.4

# Preference is to use OpenSSL 3; however, Cryptography 3.4.8 (and
# probably some other packages as well) only works with 1.1.1, so
# we need to preserve the ability to build the older OpenSSL (for now...)
OPENSSL_VERSION=3.0.12
# OPENSSL_VERSION=1.1.1w
# The Series is the first 2 digits of the version number. (e.g., 1.1.1w -> 1.1)
OPENSSL_SERIES=$(shell echo $(OPENSSL_VERSION) | grep -Eo "\d+\.\d+")

CURL_FLAGS=--disable --fail --location --create-dirs --progress-bar

# macOS targets
TARGETS-macOS=macosx.x86_64 macosx.arm64
VERSION_MIN-macOS=11.0
CFLAGS-macOS=-mmacosx-version-min=$(VERSION_MIN-macOS)

# The architecture of the machine doing the build
HOST_ARCH=$(shell uname -m)

# Force the path to be minimal. This ensures that anything in the user environment
# (in particular, homebrew and user-provided Python installs) aren't inadvertently
# linked into the support package.
PATH=/usr/bin:/bin:/usr/sbin:/sbin:/Library/Apple/usr/bin

# Build all products
all: $(OS_LIST)

.PHONY: \
	all clean distclean vars \
	$(foreach product,$(PRODUCTS),$(product) clean-$(product)) \
	$(foreach target,$(TARGETS),$(product)-$(target) clean-$(product)-$(target)) \
	$(foreach sdk,$(sort $(basename $(TARGETS))),$(product)-$(sdk) clean-$(product)-$(sdk))

# Clean all builds
clean:
	rm -rf build install dist

# Full clean - includes all downloaded products
distclean: clean
	rm -rf downloads

###########################################################################
# Setup: BZip2
###########################################################################

# Download original BZip2 source code archive.
downloads/bzip2-$(BZIP2_VERSION).tar.gz:
	@echo ">>> Download BZip2 sources"
	curl $(CURL_FLAGS) -o $@ \
		https://sourceware.org/pub/bzip2/$(notdir $@)

###########################################################################
# Setup: XZ (LZMA)
###########################################################################

# Download original XZ source code archive.
downloads/xz-$(XZ_VERSION).tar.gz:
	@echo ">>> Download XZ sources"
	curl $(CURL_FLAGS) -o $@ \
		https://tukaani.org/xz/$(notdir $@)

###########################################################################
# Setup: OpenSSL
# These build instructions adapted from the scripts developed by
# Felix Shchulze (@x2on) https://github.com/x2on/OpenSSL-for-iPhone
###########################################################################

# Download original OpenSSL source code archive.
downloads/openssl-$(OPENSSL_VERSION).tar.gz:
	@echo ">>> Download OpenSSL sources"
	curl $(CURL_FLAGS) -o $@ \
		https://openssl.org/source/$(notdir $@) \
		|| curl $(CURL_FLAGS) -o $@ \
			https://openssl.org/source/old/$(basename $(OPENSSL_VERSION))/$(notdir $@)

###########################################################################
# Build for specified target (from $(TARGETS-*))
###########################################################################
#
# Parameters:
# - $1 - target (e.g., iphonesimulator.x86_64, iphoneos.arm64)
# - $2 - OS (e.g., iOS, tvOS)
#
###########################################################################
define build-target
target=$1
os=$2

OS_LOWER-$(target)=$(shell echo $(os) | tr '[:upper:]' '[:lower:]')

# $(target) can be broken up into is composed of $(SDK).$(ARCH)
SDK-$(target)=$$(basename $(target))
ARCH-$(target)=$$(subst .,,$$(suffix $(target)))

TARGET_TRIPLE-$(target)=$$(ARCH-$(target))-apple-darwin

SDK_ROOT-$(target)=$$(shell xcrun --sdk $$(SDK-$(target)) --show-sdk-path)
CC-$(target)=xcrun --sdk $$(SDK-$(target)) clang -target $$(TARGET_TRIPLE-$(target))
CFLAGS-$(target)=\
	--sysroot=$$(SDK_ROOT-$(target)) \
	$$(CFLAGS-$(os))
LDFLAGS-$(target)=\
	-isysroot $$(SDK_ROOT-$(target)) \
	$$(CFLAGS-$(os))

###########################################################################
# Target: BZip2
###########################################################################

BZIP2_SRCDIR-$(target)=build/$(os)/$(target)/bzip2-$(BZIP2_VERSION)
BZIP2_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/bzip2-$(BZIP2_VERSION)
BZIP2_LIB-$(target)=$$(BZIP2_INSTALL-$(target))/lib/libbz2.a

$$(BZIP2_SRCDIR-$(target))/Makefile: downloads/bzip2-$(BZIP2_VERSION).tar.gz
	@echo ">>> Unpack BZip2 sources for $(target)"
	mkdir -p $$(BZIP2_SRCDIR-$(target))
	tar zxf $$< --strip-components 1 -C $$(BZIP2_SRCDIR-$(target))
	# Touch the makefile to ensure that Make identifies it as up to date.
	touch $$(BZIP2_SRCDIR-$(target))/Makefile

$$(BZIP2_LIB-$(target)): $$(BZIP2_SRCDIR-$(target))/Makefile
	@echo ">>> Build BZip2 for $(target)"
	cd $$(BZIP2_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		make install \
			PREFIX="$$(BZIP2_INSTALL-$(target))" \
			CC="$$(CC-$(target))" \
			CFLAGS="$$(CFLAGS-$(target))" \
			LDFLAGS="$$(LDFLAGS-$(target))" \
			2>&1 | tee -a ../bzip2-$(BZIP2_VERSION).build.log

BZip2-$(target): $$(BZIP2_LIB-$(target))

###########################################################################
# Target: XZ (LZMA)
###########################################################################

XZ_SRCDIR-$(target)=build/$(os)/$(target)/xz-$(XZ_VERSION)
XZ_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/xz-$(XZ_VERSION)
XZ_LIB-$(target)=$$(XZ_INSTALL-$(target))/lib/liblzma.a

$$(XZ_SRCDIR-$(target))/configure: downloads/xz-$(XZ_VERSION).tar.gz
	@echo ">>> Unpack XZ sources for $(target)"
	mkdir -p $$(XZ_SRCDIR-$(target))
	tar zxf $$< --strip-components 1 -C $$(XZ_SRCDIR-$(target))
	# Touch the configure script to ensure that Make identifies it as up to date.
	touch $$(XZ_SRCDIR-$(target))/configure

$$(XZ_SRCDIR-$(target))/Makefile: $$(XZ_SRCDIR-$(target))/configure
	# Configure the build
	cd $$(XZ_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		./configure \
			CC="$$(CC-$(target))" \
			CFLAGS="$$(CFLAGS-$(target))" \
			LDFLAGS="$$(LDFLAGS-$(target))" \
			--disable-shared \
			--enable-static \
			--host=$$(TARGET_TRIPLE-$(target)) \
			--build=$(HOST_ARCH)-apple-darwin \
			--prefix="$$(XZ_INSTALL-$(target))" \
			2>&1 | tee -a ../xz-$(XZ_VERSION).config.log

$$(XZ_LIB-$(target)): $$(XZ_SRCDIR-$(target))/Makefile
	@echo ">>> Build and install XZ for $(target)"
	cd $$(XZ_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		make install \
			2>&1 | tee -a ../xz-$(XZ_VERSION).build.log

XZ-$(target): $$(XZ_LIB-$(target))


###########################################################################
# Target: OpenSSL
###########################################################################

OPENSSL_SRCDIR-$(target)=build/$(os)/$(target)/openssl-$(OPENSSL_VERSION)
OPENSSL_INSTALL-$(target)=$(PROJECT_DIR)/install/$(os)/$(target)/openssl-$(OPENSSL_VERSION)
OPENSSL_SSL_LIB-$(target)=$$(OPENSSL_INSTALL-$(target))/lib/libssl.a
OPENSSL_CRYPTO_LIB-$(target)=$$(OPENSSL_INSTALL-$(target))/lib/libcrypto.a

$$(OPENSSL_SRCDIR-$(target))/Configure: downloads/openssl-$(OPENSSL_VERSION).tar.gz
	@echo ">>> Unpack and configure OpenSSL sources for $(target)"
	mkdir -p $$(OPENSSL_SRCDIR-$(target))
	tar zxf $$< --strip-components 1 -C $$(OPENSSL_SRCDIR-$(target))

$$(OPENSSL_SRCDIR-$(target))/is_configured: $$(OPENSSL_SRCDIR-$(target))/Configure
	# Configure the OpenSSL build
	cd $$(OPENSSL_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		CC="$$(CC-$(target)) $$(CFLAGS-$(target))" \
		./Configure darwin64-$$(ARCH-$(target))-cc no-tests \
			--prefix="$$(OPENSSL_INSTALL-$(target))" \
			--openssldir=/etc/ssl \
			2>&1 | tee -a ../openssl-$(OPENSSL_VERSION).config.log

	# The OpenSSL Makefile is... interesting. Invoking `make all` or `make
	# install` *modifies the Makefile*. Therefore, we can't use the Makefile as
	# a build dependency, because building/installing dirties the target that
	# was used as a dependency. To compensate, create a dummy file as a marker
	# for whether OpenSSL has been configured, and use *that* as a reference.
	date > $$(OPENSSL_SRCDIR-$(target))/is_configured

$$(OPENSSL_SRCDIR-$(target))/libssl.a: $$(OPENSSL_SRCDIR-$(target))/is_configured
	@echo ">>> Build OpenSSL for $(target)"
	# OpenSSL's `all` target modifies the Makefile;
	# use the raw targets that make up all and it's dependencies
	cd $$(OPENSSL_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		CC="$$(CC-$(target)) $$(CFLAGS-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		make build_sw \
			2>&1 | tee -a ../openssl-$(OPENSSL_VERSION).build.log

$$(OPENSSL_SSL_LIB-$(target)) $$(OPENSSL_CRYPTO_LIB-$(target)): $$(OPENSSL_SRCDIR-$(target))/libssl.a
	@echo ">>> Install OpenSSL for $(target)"
	# Install just the software (not the docs)
	cd $$(OPENSSL_SRCDIR-$(target)) && \
		PATH="$(PROJECT_DIR)/install/$(os)/bin:$(PATH)" \
		CC="$$(CC-$(target)) $$(CFLAGS-$(target))" \
		CROSS_TOP="$$(dir $$(SDK_ROOT-$(target))).." \
		CROSS_SDK="$$(notdir $$(SDK_ROOT-$(target)))" \
		make install_sw \
			2>&1 | tee -a ../openssl-$(OPENSSL_VERSION).install.log

OpenSSL-$(target): $$(OPENSSL_SSL_LIB-$(target))

###########################################################################
# Target: Debug
###########################################################################

vars-$(target):
	@echo ">>> Environment variables for $(target)"
	@echo "SDK-$(target): $$(SDK-$(target))"
	@echo "ARCH-$(target): $$(ARCH-$(target))"
	@echo "TARGET_TRIPLE-$(target): $$(TARGET_TRIPLE-$(target))"
	@echo "SDK_ROOT-$(target): $$(SDK_ROOT-$(target))"
	@echo "CC-$(target): $$(CC-$(target))"
	@echo "CFLAGS-$(target): $$(CFLAGS-$(target))"
	@echo "LDFLAGS-$(target): $$(LDFLAGS-$(target))"
	@echo "BZIP2_SRCDIR-$(target): $$(BZIP2_SRCDIR-$(target))"
	@echo "BZIP2_INSTALL-$(target): $$(BZIP2_INSTALL-$(target))"
	@echo "BZIP2_LIB-$(target): $$(BZIP2_LIB-$(target))"
	@echo "XZ_SRCDIR-$(target): $$(XZ_SRCDIR-$(target))"
	@echo "XZ_INSTALL-$(target): $$(XZ_INSTALL-$(target))"
	@echo "XZ_LIB-$(target): $$(XZ_LIB-$(target))"
	@echo "OPENSSL_SRCDIR-$(target): $$(OPENSSL_SRCDIR-$(target))"
	@echo "OPENSSL_INSTALL-$(target): $$(OPENSSL_INSTALL-$(target))"
	@echo "OPENSSL_SSL_LIB-$(target): $$(OPENSSL_SSL_LIB-$(target))"
	@echo "OPENSSL_CRYPTO_LIB-$(target): $$(OPENCRYPTO_SSL_LIB-$(target))"
	@echo

endef # build-target

###########################################################################
# Build for specified sdk (extracted from the base names in $(TARGETS-*))
###########################################################################
#
# Parameters:
# - $1 sdk (e.g., iphoneos, iphonesimulator)
# - $2 OS (e.g., iOS, tvOS)
#
###########################################################################
define build-sdk
sdk=$1
os=$2

OS_LOWER-$(sdk)=$(shell echo $(os) | tr '[:upper:]' '[:lower:]')

WHEEL_TAG-$(sdk)=py3-none-$$(shell echo $$(OS_LOWER-$(sdk))_$$(VERSION_MIN-$(os))_$(sdk) | sed "s/\./_/g")

SDK_TARGETS-$(sdk)=$$(filter $(sdk).%,$$(TARGETS-$(os)))
SDK_ARCHES-$(sdk)=$$(sort $$(subst .,,$$(suffix $$(SDK_TARGETS-$(sdk)))))

###########################################################################
# SDK: Macro Expansions
###########################################################################

# Expand the build-target macro for target on this OS
$$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(eval $$(call build-target,$$(target),$(os))))

###########################################################################
# SDK: BZip2
###########################################################################

BZIP2_INSTALL-$(sdk)=$(PROJECT_DIR)/install/$(os)/$(sdk)/bzip2-$(BZIP2_VERSION)
BZIP2_LIB-$(sdk)=$$(BZIP2_INSTALL-$(sdk))/lib/libbz2.a
BZIP2_DIST-$(sdk)=dist/bzip2-$(BZIP2_VERSION)-$(BUILD_NUMBER)-$(sdk).tar.gz

$$(BZIP2_LIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(BZIP2_LIB-$$(target)))
	@echo ">>> Build Fat BZip2 library for $(sdk)"
	mkdir -p $$(BZIP2_INSTALL-$(sdk))/lib
	lipo -create -output $$@ $$^ \
		2>&1 | tee -a install/$(os)/$(sdk)/bzip2-$(BZIP2_VERSION).lipo.log
	# Copy headers from the first target associated with the $(sdk) SDK
	cp -r $$(BZIP2_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/include $$(BZIP2_INSTALL-$(sdk))


$$(BZIP2_DIST-$(sdk)): $$(BZIP2_LIB-$(sdk))
	@echo ">>> Build BZip2 distribution for $(sdk)"
	mkdir -p dist
	cd $$(BZIP2_INSTALL-$(sdk)) && tar zcvf $(PROJECT_DIR)/$$(BZIP2_DIST-$(sdk)) lib include

BZip2-$(sdk): $$(BZIP2_DIST-$(sdk))

###########################################################################
# SDK: XZ
###########################################################################

XZ_INSTALL-$(sdk)=$(PROJECT_DIR)/install/$(os)/$(sdk)/xz-$(XZ_VERSION)
XZ_LIB-$(sdk)=$$(XZ_INSTALL-$(sdk))/lib/liblzma.a
XZ_DIST-$(sdk)=dist/xz-$(XZ_VERSION)-$(BUILD_NUMBER)-$(sdk).tar.gz

$$(XZ_LIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(XZ_LIB-$$(target)))
	@echo ">>> Build Fat XZ library for $(sdk)"
	mkdir -p $$(XZ_INSTALL-$(sdk))/lib
	lipo -create -output $$@ $$^ \
		2>&1 | tee -a install/$(os)/$(sdk)/xz-$(XZ_VERSION).lipo.log
	# Copy headers from the first target associated with the $(sdk) SDK
	cp -r $$(XZ_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/include $$(XZ_INSTALL-$(sdk))

$$(XZ_DIST-$(sdk)): $$(XZ_LIB-$(sdk))
	@echo ">>> Build XZ distribution for $(sdk)"
	mkdir -p dist
	cd $$(XZ_INSTALL-$(sdk)) && tar zcvf $(PROJECT_DIR)/$$(XZ_DIST-$(sdk)) lib include

XZ-$(sdk): $$(XZ_DIST-$(sdk))

###########################################################################
# SDK: OpenSSL
###########################################################################

OPENSSL_INSTALL-$(sdk)=$(PROJECT_DIR)/install/$(os)/$(sdk)/openssl-$(OPENSSL_VERSION)
OPENSSL_SSL_LIB-$(sdk)=$$(OPENSSL_INSTALL-$(sdk))/lib/libssl.a
OPENSSL_CRYPTO_LIB-$(sdk)=$$(OPENSSL_INSTALL-$(sdk))/lib/libcrypto.a
OPENSSL_DIST-$(sdk)=dist/openssl-$(OPENSSL_VERSION)-$(BUILD_NUMBER)-$(sdk).tar.gz

$$(OPENSSL_SSL_LIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(OPENSSL_SSL_LIB-$$(target)))
	@echo ">>> Build Fat OpenSSL SSL library for $(sdk)"
	mkdir -p $$(OPENSSL_INSTALL-$(sdk))/lib
	lipo -create -output $$@ $$^ \
		2>&1 | tee -a install/$(os)/$(sdk)/libssl-$(OPENSSL_VERSION).lipo.log

	# Copy headers from the first target associated with the $(sdk) SDK
	cp -r $$(OPENSSL_INSTALL-$$(firstword $$(SDK_TARGETS-$(sdk))))/include $$(OPENSSL_INSTALL-$(sdk))

$$(OPENSSL_CRYPTO_LIB-$(sdk)): $$(foreach target,$$(SDK_TARGETS-$(sdk)),$$(OPENSSL_CRYPTO_LIB-$$(target)))
	@echo ">>> Build Fat OpenSSL Crypto library for $(sdk)"
	mkdir -p $$(OPENSSL_INSTALL-$(sdk))/lib
	lipo -create -output $$@ $$^ \
		2>&1 | tee -a install/$(os)/$(sdk)/libssl-$(OPENSSL_VERSION).lipo.log

$$(OPENSSL_DIST-$(sdk)): $$(OPENSSL_SSL_LIB-$(sdk)) $$(OPENSSL_CRYPTO_LIB-$(sdk))
	@echo ">>> Build OpenSSL distribution for $(sdk)"
	mkdir -p dist
	cd $$(OPENSSL_INSTALL-$(sdk)) && tar zcvf $(PROJECT_DIR)/$$(OPENSSL_DIST-$(sdk)) lib include

OpenSSL-$(sdk): $$(OPENSSL_DIST-$(sdk))

###########################################################################
# SDK: Debug
###########################################################################

vars-$(sdk):
	@echo ">>> Environment variables for $(sdk)"
	@echo "SDK_TARGETS-$(sdk): $$(SDK_TARGETS-$(sdk))"
	@echo "SDK_ARCHES-$(sdk): $$(SDK_ARCHES-$(sdk))"
	@echo "BZIP2_INSTALL-$(sdk): $$(BZIP2_INSTALL-$(sdk))"
	@echo "BZIP2_LIB-$(sdk): $$(BZIP2_LIB-$(sdk))"
	@echo "BZIP2_DIST-$(sdk): $$(BZIP2_DIST-$(sdk))"
	@echo "XZ_INSTALL-$(sdk): $$(XZ_INSTALL-$(sdk))"
	@echo "XZ_LIB-$(sdk): $$(XZ_LIB-$(sdk))"
	@echo "XZ_DIST-$(sdk): $$(XZ_DIST-$(sdk))"
	@echo "OPENSSL_INSTALL-$(sdk): $$(OPENSSL_INSTALL-$(sdk))"
	@echo "OPENSSL_SSL_LIB-$(sdk): $$(OPENSSL_SSL_LIB-$(sdk))"
	@echo "OPENCRYPTO_SSL_LIB-$(sdk): $$(OPENSSL_CRYPTO_LIB-$(sdk))"
	@echo "OPENSSL_DIST-$(sdk): $$(OPENSSL_DIST-$(sdk))"
	@echo

endef # build-sdk

###########################################################################
# Build for specified OS (from $(OS_LIST))
###########################################################################
#
# Parameters:
# - $1 - OS (e.g., iOS, tvOS)
#
###########################################################################
define build
os=$1

SDKS-$(os)=$$(sort $$(basename $$(TARGETS-$(os))))

# Expand the build-sdk macro for all the sdks on this OS (e.g., iphoneos, iphonesimulator)
$$(foreach sdk,$$(SDKS-$(os)),$$(eval $$(call build-sdk,$$(sdk),$(os))))

###########################################################################
# Build: Macro Expansions
###########################################################################

BZip2-$(os): $$(foreach sdk,$$(SDKS-$(os)),BZip2-$$(sdk))
XZ-$(os): $$(foreach sdk,$$(SDKS-$(os)),XZ-$$(sdk))
OpenSSL-$(os): $$(foreach sdk,$$(SDKS-$(os)),OpenSSL-$$(sdk))

clean-BZip2-$(os):
	@echo ">>> Clean BZip2 build products on $(os)"
	rm -rf \
		build/$(os)/*/bzip2-$(BZIP2_VERSION) \
		build/$(os)/*/bzip2-$(BZIP2_VERSION).*.log \
		install/$(os)/*/bzip2-$(BZIP2_VERSION) \
		install/$(os)/*/bzip2-$(BZIP2_VERSION).*.log \
		dist/bzip2-$(BZIP2_VERSION)-*

clean-XZ-$(os):
	@echo ">>> Clean XZ build products on $(os)"
	rm -rf \
		build/$(os)/*/xz-$(XZ_VERSION) \
		build/$(os)/*/xz-$(XZ_VERSION).*.log \
		install/$(os)/*/xz-$(XZ_VERSION) \
		install/$(os)/*/xz-$(XZ_VERSION).*.log \
		dist/xz-$(XZ_VERSION)-*

clean-OpenSSL-$(os):
	@echo ">>> Clean OpenSSL build products on $(os)"
	rm -rf \
		build/$(os)/*/openssl-$(OPENSSL_VERSION) \
		build/$(os)/*/openssl-$(OPENSSL_VERSION).*.log \
		install/$(os)/*/openssl-$(OPENSSL_VERSION) \
		install/$(os)/*/openssl-$(OPENSSL_VERSION).*.log \
		dist/openssl-$(OPENSSL_VERSION)-*

$(os): BZip2-$(os) XZ-$(os) OpenSSL-$(os)

###########################################################################
# Build: Debug
###########################################################################

vars-$(os): $$(foreach target,$$(TARGETS-$(os)),vars-$$(target)) $$(foreach sdk,$$(SDKS-$(os)),vars-$$(sdk))
	@echo ">>> Environment variables for $(os)"
	@echo "SDKS-$(os): $$(SDKS-$(os))"
	@echo

endef # build

# Dump environment variables (for debugging purposes)
vars: $(foreach os,$(OS_LIST),vars-$(os))

# Expand the targets for each product
BZip2: $(foreach os,$(OS_LIST),BZip2-$(os))
XZ: $(foreach os,$(OS_LIST),XZ-$(os))
OpenSSL: $(foreach os,$(OS_LIST),OpenSSL-$(os))

clean-BZip2: $(foreach os,$(OS_LIST),clean-BZip2-$(os))
clean-XZ: $(foreach os,$(OS_LIST),clean-XZ-$(os))
clean-OpenSSL: $(foreach os,$(OS_LIST),clean-OpenSSL-$(os))

# Expand the build macro for every OS
$(foreach os,$(OS_LIST),$(eval $(call build,$(os))))
