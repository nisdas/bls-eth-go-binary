include ../mcl/common.mk
# ios
XCODEPATH=$(shell xcode-select -p)
IOS_CLANG=$(XCODEPATH)/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang
IOS_AR=${XCODEPATH}/Toolchains/XcodeDefault.xctoolchain/usr/bin/ar
PLATFORM?="iPhoneOS"
IOS_MIN_VERSION?=7.0
IOS_CFLAGS=-fembed-bitcode -fno-common -DPIC -fPIC -Dmcl_EXPORTS
IOS_CFLAGS+=-DMCL_USE_VINT -DMCL_VINT_FIXED_BUFFER -DMCL_DONT_USE_OPENSSL -DMCL_DONT_USE_XBYAK -DMCL_LLVM_BMI2=0 -DMCL_USE_LLVM=1 -DMCL_SIZEOF_UNIT=8 -std=c++11 -Wall -Wextra -Wformat=2 -Wcast-qual -Wcast-align -Wwrite-strings -Wfloat-equal -Wpointer-arith -O3 -DNDEBUG
IOS_CFLAGS+=-I../mcl/include -I../bls/include
IOS_CFLAGS+=-DBLS_ETH -DBLS_SWAP_G
IOS_LDFLAGS=-dynamiclib -Wl,-flat_namespace -Wl,-undefined -Wl,suppress
CURVE_BIT?=384_256
IOS_OBJS=$(IOS_OUTDIR)/fp.o $(IOS_OUTDIR)/base64.o $(IOS_OUTDIR)/bls_c$(CURVE_BIT).o
IOS_LIB=libbls$(CURVE_BIT)

GOMOBILE_ARCHS=armv7 arm64

MIN_CFLAGS=-std=c++03 -O3 -DNDEBUG -DMCL_DONT_USE_OPENSSL -DMCL_USE_VINT -DMCL_SIZEOF_UNIT=8 -DMCL_VINT_FIXED_BUFFER -DMCL_MAX_BIT_SIZE=384 -DCYBOZU_DONT_USE_EXCEPTION -DCYBOZU_DONT_USE_STRING -I../bls/include -I../mcl/include
MIN_CFLAGS+=-DBLS_ETH -DBLS_SWAP_G
OBJ_DIR=obj
all:
ifeq ($(CPU),x86-64)
	$(eval _ARCH=amd64)
ifeq ($(OS),mingw64)
	$(eval _OS=windows)
endif
ifeq ($(OS),Linux)
	$(eval _OS=linux)
	$(eval MIN_CFLAGS=$(MIN_CFLAGS) -fPIC)
endif
ifeq ($(OS),mac)
	$(eval _OS=darwin)
	$(eval MIN_CFLAGS=$(MIN_CFLAGS) -fPIC)
endif
endif
	$(eval LIB_DIR=bls/lib/$(_OS)/$(_ARCH))
	-mkdir -p $(LIB_DIR)
	$(CXX) -c -o $(OBJ_DIR)/fp.o ../mcl/src/fp.cpp $(MIN_CFLAGS)
	$(CXX) -c -o $(OBJ_DIR)/bls_c384_256.o ../bls/src/bls_c384_256.cpp $(MIN_CFLAGS)
	$(AR) $(LIB_DIR)/libbls384_256.a $(OBJ_DIR)/bls_c384_256.o $(OBJ_DIR)/fp.o

android:
	$(MAKE) -C android

ios:
	@for target in $(GOMOBILE_ARCHS); do \
		$(MAKE) each_ios ARCH=$$target PLATFORM="iPhoneOS"; \
	done

../mcl/src/base64.ll:
	$(MAKE) -C ../mcl src/base64.ll

each_ios: ../mcl/src/base64.ll
	@echo "Building iOS $(ARCH)..."
	$(eval IOS_OUTDIR=ios/$(ARCH))
	$(eval IOS_SDK_PATH=$(XCODEPATH)/Platforms/$(PLATFORM).platform/Developer/SDKs/$(PLATFORM).sdk)
	$(eval IOS_COMMON=-arch $(ARCH) -isysroot $(IOS_SDK_PATH) -mios-version-min=$(IOS_MIN_VERSION))
	@mkdir -p $(IOS_OUTDIR)
	$(IOS_CLANG) $(IOS_COMMON) $(IOS_CFLAGS) -c ../mcl/src/fp.cpp -o $(IOS_OUTDIR)/fp.o
	$(IOS_CLANG) $(IOS_COMMON) $(IOS_CFLAGS) -c ../mcl/src/base64.ll -o $(IOS_OUTDIR)/base64.o
	$(IOS_CLANG) $(IOS_COMMON) $(IOS_CFLAGS) -c ../bls/src/bls_c$(CURVE_BIT).cpp -o $(IOS_OUTDIR)/bls_c$(CURVE_BIT).o
	ar cru $(IOS_OUTDIR)/$(IOS_LIB).a $(IOS_OBJS)
	ranlib $(IOS_OUTDIR)/$(IOS_LIB).a

update:
	cp ../bls/include/bls/bls.h bls/include/bls/.
	cp ../bls/include/bls/bls384_256.h bls/include/bls/.
	cp ../mcl/include/mcl/bn.h bls/include/mcl/.
	cp ../mcl/include/mcl/bn_c384_256.h bls/include/mcl/.
	cp ../mcl/include/mcl/curve_type.h bls/include/mcl/.
	patch -o - -p0 ../bls/ffi/go/bls/mcl.go <patch/mcl.patch > bls/mcl.go
	patch -o - -p0 ../bls/ffi/go/bls/bls.go <patch/bls.patch > bls/bls.go

.PHONY: android ios each_ios
