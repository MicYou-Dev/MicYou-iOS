SHELL := /bin/bash
.SHELLFLAGS = -ec
$(VERBOSE).SILENT:

SOURCEDIR   := $(shell pwd)
OUTPUTDIR   := $(SOURCEDIR)/artifacts
WORKINGDIR  := $(SOURCEDIR)/Natives/build
DETECTPLAT  := $(shell uname -s)
DETECTARCH  := $(shell uname -m)
VERSION     := 1.0
BRANCH      := $(shell git branch --show-current 2>/dev/null || echo "unknown")
COMMIT      := $(shell git log --oneline 2>/dev/null | sed '2,10000000d' | cut -b 1-7 || echo "unknown")
PLATFORM    ?= 2

RELEASE ?= 0

ifeq (1,$(RELEASE))
CMAKE_BUILD_TYPE := Release
else
CMAKE_BUILD_TYPE := Debug
endif

ifeq ($(DETECTPLAT),Darwin)
OSVER       := $(shell sw_vers -productVersion 2>/dev/null | cut -b 1-2 || echo "0")
ifeq ($(shell sw_vers -productName 2>/dev/null),macOS)
IOS         := 0
SDKPATH     ?= $(shell xcrun --sdk iphoneos --show-sdk-path)
$(warning Building on macOS.)
else
IOS         := 1
SDKPATH     ?= /usr/share/SDKs/iPhoneOS.sdk
$(warning Building on iOS.)
endif
else ifeq ($(DETECTPLAT),Linux)
IOS         := 0
SDKPATH     ?=
$(warning Building on Linux.)
else
$(error This platform is not currently supported for building MicYou.)
endif

PLATFORM_NAME := ios
BUNDLE_DIR    := $(OUTPUTDIR)/MicYou.app

METHOD_DEPCHECK   = $(shell $(1) >/dev/null 2>&1 && echo 1)

METHOD_DIRCHECK   = \
	if [ ! -d '$(1)' ]; then \
		mkdir -p $(1); \
	else \
		rm -rf $(1)/*; \
	fi

ifndef SDKPATH
$(error You need to specify SDKPATH to the path of iPhoneOS.sdk. The SDK version should be 14.0 or newer.)
endif

JOBS ?= $(shell sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 2)

all: clean native kmp assets payload package dsym

help:
	echo 'Makefile to compile MicYou iOS'
	echo ''
	echo 'Usage:'
	echo '    make              Makes everything under all'
	echo '    make help         Displays this message'
	echo '    make all          Builds the entire app'
	echo '    make native       Builds the native app'
	echo '    make kmp          Builds the KMP shared framework'
	echo '    make assets       Compiles Assets.xcassets'
	echo '    make payload      Makes Payload/MicYou.app'
	echo '    make package      Builds ipa of MicYou'
	echo '    make dsym         Generate debug symbol files'
	echo '    make clean        Cleans build directories'

native:
	echo '[MicYou v$(VERSION)] native - start'
	mkdir -p $(WORKINGDIR)
	cd $(WORKINGDIR) && cmake \
		-DCMAKE_BUILD_TYPE=$(CMAKE_BUILD_TYPE) \
		-DCMAKE_CROSSCOMPILING=true \
		-DCMAKE_SYSTEM_NAME=Darwin \
		-DCMAKE_SYSTEM_PROCESSOR=aarch64 \
		-DCMAKE_OSX_SYSROOT="$(SDKPATH)" \
		-DCMAKE_OSX_ARCHITECTURES=arm64 \
		-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
		-DCMAKE_C_FLAGS="-arch arm64" \
		-DCMAKE_CXX_FLAGS="-arch arm64" \
		-DCONFIG_BRANCH="$(BRANCH)" \
		-DCONFIG_COMMIT="$(COMMIT)" \
		-DCONFIG_RELEASE=$(RELEASE) \
		..
	cmake --build $(WORKINGDIR) --config $(CMAKE_BUILD_TYPE) -j$(JOBS)
	echo '[MicYou v$(VERSION)] native - end'

kmp:
	echo '[MicYou v$(VERSION)] kmp - start'
	if [ -f $(SOURCEDIR)/KMP/gradlew ]; then \
		cd $(SOURCEDIR)/KMP && ./gradlew :linkDebugFrameworkIosArm64 || ./gradlew :linkReleaseFrameworkIosArm64; \
	elif command -v gradle >/dev/null 2>&1; then \
		cd $(SOURCEDIR)/KMP && gradle :linkDebugFrameworkIosArm64 || gradle :linkReleaseFrameworkIosArm64; \
	else \
		echo 'Warning: Gradle not found, skipping KMP build'; \
	fi
	mkdir -p $(WORKINGDIR)/MicYou.app/Frameworks
	cp -R $(SOURCEDIR)/KMP/build/bin/iosArm64/*Framework/MicYouProtocol.framework $(WORKINGDIR)/MicYou.app/Frameworks/ || true
	echo '[MicYou v$(VERSION)] kmp - end'

assets:
	echo '[MicYou v$(VERSION)] assets - start'
	if [ '$(IOS)' = '0' ] && [ '$(DETECTPLAT)' = 'Darwin' ]; then \
		mkdir -p $(WORKINGDIR)/MicYou.app/Base.lproj; \
		xcrun actool $(SOURCEDIR)/Natives/Resources/Assets.xcassets \
			--compile $(SOURCEDIR)/Natives/Resources \
			--platform iphoneos \
			--minimum-deployment-target 11.0 \
			--app-icon AppIcon \
			--output-partial-info-plist /dev/null || exit 1; \
	else \
		echo 'Warning: xcrun actool not available, skipping asset compilation.'; \
	fi
	echo '[MicYou v$(VERSION)] assets - end'

payload: native kmp assets
	echo '[MicYou v$(VERSION)] payload - start'
	$(call METHOD_DIRCHECK,$(OUTPUTDIR)/Payload)
	cp -R $(WORKINGDIR)/MicYou.app $(OUTPUTDIR)/Payload/
	cp -R $(SOURCEDIR)/Natives/Resources/Base.lproj $(OUTPUTDIR)/Payload/MicYou.app/ || true
	find $(SOURCEDIR)/Natives/Resources -not -name 'Assets.xcassets' -not -name 'Base.lproj' -mindepth 1 -maxdepth 1 -exec cp -R {} $(OUTPUTDIR)/Payload/MicYou.app/ \; || true
	ldid -S $(OUTPUTDIR)/Payload/MicYou.app || true
	ldid -S$(SOURCEDIR)/Natives/entitlements.sideload.xml $(OUTPUTDIR)/Payload/MicYou.app/MicYou || true
	chmod -R 755 $(OUTPUTDIR)/Payload
	echo '[MicYou v$(VERSION)] payload - end'

package: payload
	echo '[MicYou v$(VERSION)] package - start'
	cd $(OUTPUTDIR) && zip --symlinks -r $(OUTPUTDIR)/MicYou-$(VERSION)-$(PLATFORM_NAME).ipa Payload
	echo '[MicYou v$(VERSION)] package - end'

dsym: payload
	echo '[MicYou v$(VERSION)] dsym - start'
	dsymutil --arch arm64 $(OUTPUTDIR)/Payload/MicYou.app/MicYou || true
	rm -rf $(OUTPUTDIR)/MicYou.dSYM
	mv $(OUTPUTDIR)/Payload/MicYou.app/MicYou.dSYM $(OUTPUTDIR)/MicYou.dSYM || true
	echo '[MicYou v$(VERSION)] dsym - end'

clean:
	echo '[MicYou v$(VERSION)] clean - start'
	rm -rf $(WORKINGDIR)
	rm -rf $(OUTPUTDIR)
	rm -rf $(SOURCEDIR)/KMP/build
	echo '[MicYou v$(VERSION)] clean - end'

.PHONY: all clean help native kmp assets payload package dsym
