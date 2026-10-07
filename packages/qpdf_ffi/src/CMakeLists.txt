# qpdf_ffi's native build (DK-0391): a superbuild of zlib and libjpeg-turbo
# (static) and qpdf (shared, native crypto only: no OpenSSL, no GnuTLS), from
# source archives pinned by SHA-256 (docs/versions.md). hook/build.dart runs
# it through native_toolchain_cmake, which passes the target's toolchain; we
# forward it to each sub-build.
cmake_minimum_required(VERSION 3.16)
project(qpdf_ffi NONE)
include(ExternalProject)
if(POLICY CMP0135) # extracted files get the extraction time (CMake 3.24+)
  cmake_policy(SET CMP0135 NEW)
endif()

set(DEPS ${CMAKE_BINARY_DIR}/deps) # where the three sub-builds install
set(FORWARD
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_INSTALL_PREFIX=${DEPS}
  -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5)
foreach(var CMAKE_TOOLCHAIN_FILE CMAKE_SYSTEM_NAME CMAKE_SYSTEM_PROCESSOR
    ANDROID_PLATFORM ANDROID_ABI ANDROID_STL ANDROID_ARM_NEON
    PLATFORM DEPLOYMENT_TARGET ENABLE_BITCODE ENABLE_ARC ENABLE_VISIBILITY
    ENABLE_STRICT_TRY_COMPILE)
  if(DEFINED ${var})
    list(APPEND FORWARD -D${var}=${${var}})
  endif()
endforeach()

if(ANDROID_ABI)
  # 16 KB pages (Android 15+; tools/check.py --apk checks it, DK-0018).
  list(APPEND FORWARD -DCMAKE_SHARED_LINKER_FLAGS=-Wl,-z,max-page-size=16384)
endif()

if(MSVC OR CMAKE_GENERATOR MATCHES "Visual Studio")
  set(ZLIB_LIB ${DEPS}/lib/zs.lib)
  set(JPEG_LIB ${DEPS}/lib/jpeg-static.lib)
else()
  set(ZLIB_LIB ${DEPS}/lib/libz.a)
  set(JPEG_LIB ${DEPS}/lib/libjpeg.a)
endif()

ExternalProject_Add(zlib
  URL https://github.com/madler/zlib/releases/download/v1.3.2/zlib-1.3.2.tar.gz
  URL_HASH SHA256=bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16
  CMAKE_ARGS ${FORWARD}
    -DZLIB_BUILD_SHARED=OFF -DZLIB_BUILD_STATIC=ON -DZLIB_BUILD_TESTING=OFF)

ExternalProject_Add(libjpeg_turbo
  URL https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.1.4.1/libjpeg-turbo-3.1.4.1.tar.gz
  URL_HASH SHA256=ecae8008e2cc9ade2f2c1bb9d5e6d4fb73e7c433866a056bd82980741571a022
  # ponytail: no SIMD (it needs NASM); qpdf only decodes JPEG for --decode-level=all, which we don't use.
  CMAKE_ARGS ${FORWARD}
    -DENABLE_SHARED=OFF -DENABLE_STATIC=ON -DWITH_SIMD=OFF -DWITH_TURBOJPEG=OFF
    -DWITH_TOOLS=OFF -DWITH_TESTS=OFF -DCMAKE_INSTALL_LIBDIR=lib)

ExternalProject_Add(qpdf
  DEPENDS zlib libjpeg_turbo
  URL https://github.com/qpdf/qpdf/releases/download/v12.3.2/qpdf-12.3.2.tar.gz
  URL_HASH SHA256=6cba2f9f2cd887d905faeb99e0e51a307b217920d1bbf3e9cfbb2e8178a2deda
  CMAKE_ARGS ${FORWARD}
    -DBUILD_SHARED_LIBS=ON -DBUILD_STATIC_LIBS=OFF
    -DREQUIRE_CRYPTO_NATIVE=ON -DUSE_IMPLICIT_CRYPTO=OFF
    -DBUILD_DOC=OFF -DINSTALL_MANUAL=OFF -DINSTALL_EXAMPLES=OFF
    -DINSTALL_PKGCONFIG=OFF -DINSTALL_CMAKE_PACKAGE=OFF
    -DZLIB_H_PATH=${DEPS}/include -DZLIB_LIB_PATH=${ZLIB_LIB}
    -DLIBJPEG_H_PATH=${DEPS}/include -DLIBJPEG_LIB_PATH=${JPEG_LIB}
    # Android packages lib*.so only: no libqpdf.so.30.
    -DCMAKE_PLATFORM_NO_VERSIONED_SONAME=ON
  BUILD_COMMAND ${CMAKE_COMMAND} --build <BINARY_DIR> --config $<CONFIG> --target libqpdf
  # The library is component "lib" where it is a LIBRARY (Android, iOS) and
  # "Unspecified" where it is a RUNTIME DLL (Windows).
  INSTALL_COMMAND ${CMAKE_COMMAND} --install <BINARY_DIR> --config $<CONFIG> --component lib
    COMMAND ${CMAKE_COMMAND} --install <BINARY_DIR> --config $<CONFIG> --component Unspecified)

# The hook picks the library up from here (lib/ for every platform).
install(DIRECTORY ${DEPS}/bin/ ${DEPS}/lib/ DESTINATION lib
  FILES_MATCHING PATTERN "qpdf*.dll" PATTERN "libqpdf*.so" PATTERN "libqpdf*.dylib")
