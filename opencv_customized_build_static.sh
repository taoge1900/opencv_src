#!/bin/bash
# build_opencv4.9-t3-neon-openmp-on.sh

source build.config
source common.config

# 输出变量值函数
print_var() {
    echo "$1: ${!1}"
}

# 设置工作目录
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
# SOURCE_DIR="/T3/buildroot-2025.02/output/build/opencv4-4.10.0"
# CONTRIB_DIR="/T3/buildroot-2025.02/output/build/opencv4-contrib-4.10.0"
SOURCE_DIR="/mnt/d/workspace/T3/src/opencv_src/opencv-${OPENCV_VER}"
CONTRIB_DIR="/mnt/d/workspace/T3/src/opencv_src/opencv_contrib-${OPENCV_VER}"
BUILD_DIR="$SCRIPT_DIR/build"

# 清理并创建构建目录
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# ==========================================
# Buildroot 与 sysroot 设置
export BUILDROOT_DIR="/T3/buildroot-2025.02"
export SYSROOT="${BUILDROOT_DIR}/output/host/arm-buildroot-linux-gnueabihf/sysroot"

# # 工具链环境变量
export TOOLCHAIN_BIN="${BUILDROOT_DIR}/output/host/bin"
export TOOLCHAIN_PREFIX="arm-buildroot-linux-gnueabihf-"
export CC="${TOOLCHAIN_BIN}/${TOOLCHAIN_PREFIX}gcc"
export CXX="${TOOLCHAIN_BIN}/${TOOLCHAIN_PREFIX}g++"
export CMAKE_C_COMPILER="${TOOLCHAIN_BIN}/${TOOLCHAIN_PREFIX}gcc"
export CMAKE_CXX_COMPILER="${TOOLCHAIN_BIN}/${TOOLCHAIN_PREFIX}g++"

export PKG_CONFIG_PATH="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig"

export PKG_CONFIG_USE_CMAKE_PREFIX_PATH=1
# 安装目录（与 sysroot 保持一致）
export INSTALL_DIR="$SYSROOT"
# 提示：当你设置 -DCMAKE_INSTALL_PREFIX="/usr" 时，opencv4.pc 文件中的 prefix 被设置为 /usr，这意味着所有相对于该前缀的路径都将基于 /usr 目录。
# 当你使用 make install DESTDIR="$INSTALL_DIR" 命令时，实际上是在告诉 make 将文件安装到一个临时的位置 $INSTALL_DIR，而不仅仅是改变 prefix 的值。这意味着：
# 如果你在 CMake 配置阶段设置了 -DCMAKE_INSTALL_PREFIX="/usr"，那么 opencv4.pc 文件的内容将仍然包含 prefix=/usr，但是由于 DESTDIR 的存在，最终这些文件会被放置在 $INSTALL_DIR/usr 下面。
# 这种方式对于打包和分发特别有用，因为它允许你在不改变软件包内部路径的情况下，将整个目录结构复制到目标系统上的正确位置。

# ==========================================

# 生成临时工具链配置文件 toolchain-tmp.cmake
cat <<EOF > toolchain-tmp.cmake
set(CMAKE_SYSTEM_NAME Linux)

# 工具链路径与前缀
set(TOOLCHAIN_BIN "${TOOLCHAIN_BIN}")
set(TOOLCHAIN_PREFIX "${TOOLCHAIN_PREFIX}")

# 指定交叉编译工具链及工具
set(CMAKE_C_COMPILER "\${TOOLCHAIN_BIN}/\${TOOLCHAIN_PREFIX}gcc" CACHE FILEPATH "C compiler" FORCE)
set(CMAKE_CXX_COMPILER "\${TOOLCHAIN_BIN}/\${TOOLCHAIN_PREFIX}g++" CACHE FILEPATH "C++ compiler" FORCE)
set(CMAKE_AR "\${TOOLCHAIN_BIN}/\${TOOLCHAIN_PREFIX}ar" CACHE FILEPATH "Archiver" FORCE)
set(CMAKE_RANLIB "\${TOOLCHAIN_BIN}/\${TOOLCHAIN_PREFIX}ranlib" CACHE FILEPATH "Ranlib" FORCE)
set(CMAKE_STRIP "\${TOOLCHAIN_BIN}/\${TOOLCHAIN_PREFIX}strip" CACHE FILEPATH "Strip" FORCE)

# 设置 sysroot 及查找路径模式
set(CMAKE_SYSROOT "${SYSROOT}")
set(CMAKE_FIND_ROOT_PATH "\${CMAKE_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# 设置编译标志（NEON、目标处理器、优化等级）
set(CMAKE_C_FLAGS "-mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -mthumb -O3" CACHE STRING "C flags" FORCE)
set(CMAKE_CXX_FLAGS "\${CMAKE_C_FLAGS}" CACHE STRING "C++ flags" FORCE)
set(CMAKE_SYSTEM_PROCESSOR "armv7" CACHE STRING "Target processor" FORCE)
set(CMAKE_SYSTEM_NAME "Linux" CACHE STRING "System name" FORCE)
set(CMAKE_SYSTEM_VERSION "1" CACHE STRING "System version" FORCE)

# 配置 pkg-config 环境
set(ENV{PKG_CONFIG_PATH} "${PKG_CONFIG_PATH}")
set(ENV{PKG_CONFIG_LIBDIR} "\${CMAKE_SYSROOT}/usr/lib/pkgconfig:\${CMAKE_SYSROOT}/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "\${CMAKE_SYSROOT}")

message(STATUS "CMAKE_C_COMPILER: \${CMAKE_C_COMPILER}")
message(STATUS "CMAKE_CXX_COMPILER: \${CMAKE_CXX_COMPILER}")
EOF

# 配置 CMake（去除重复设置，保留必要参数）
cmake \
    -DCMAKE_TOOLCHAIN_FILE="./toolchain-tmp.cmake" \
    -DCMAKE_INSTALL_PREFIX="/usr" \
    -DOPENCV_EXTRA_MODULES_PATH="$CONTRIB_DIR/modules" \
    -DBUILD_LIST=core,highgui,video,videoio,videostab,imgproc,tracking,calib3d,features2d,objdetect,ml,dnn,dnn_objdetect,photo \
    -DBUILD_SHARED_LIBS=OFF \
    -DBUILD_opencv_world=OFF \
    -DBUILD_opencv_core=ON \
    -DBUILD_opencv_highgui=ON \
    -DBUILD_opencv_imgproc=ON \
    -DBUILD_opencv_videoio=ON \
    -DBUILD_opencv_tracking=ON \
    -DBUILD_opencv_video=ON \
    -DBUILD_opencv_imgcodecs=ON \
    -DBUILD_opencv_videostab=ON \
    -DBUILD_opencv_stitching=ON \
    -DBUILD_TESTS=OFF \
    -DBUILD_PERF_TESTS=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_opencv_apps=OFF \
    -DBUILD_DOCS=OFF \
    -DBUILD_PACKAGE=OFF \
    -DBUILD_WITH_DEBUG_INFO=OFF \
    -DBUILD_JAVA=OFF \
    -DBUILD_opencv_python2=OFF \
    -DBUILD_opencv_python3=OFF \
    -DWITH_OPENMP=ON \
    -DWITH_PROTOBUF=ON \
    -DWITH_JPEG=ON \
    -DWITH_PNG=ON \
    -DBUILD_opencv_photo=ON \
    -DWITH_WEBP=OFF \
    -DWITH_OPENJPEG=OFF \
    -DWITH_JASPER=OFF \
    -DWITH_FFMPEG=OFF \
    -DOPENCV_FFMPEG_SKIP_DEMUXERS="aac,adts" \
    -DOPENCV_FFMPEG_SKIP_MUXERS="aac,adts" \
    -DWITH_X264=OFF \
    -DWITH_X265=OFF \
    -DWITH_GSTREAMER=OFF \
    -DWITH_GTK=OFF \
    -DWITH_TIFF=OFF \
    -DWITH_LZMA=OFF \
    -DWITH_ITT=OFF \
    -DWITH_DC1394=OFF \
    -DENABLE_PIC=ON \
    -DENABLE_STATIC=ON \
    -DOPENCV_SKIP_VISIBILITY_HIDDEN=ON \
    -DOPENCV_ENABLE_NONFREE=ON \
    -DCMAKE_VERBOSE_MAKEFILE=ON \
    -DCMAKE_BUILD_TYPE=Release \
    -DPKG_CONFIG_EXECUTABLE=$(which pkg-config) \
    -DOPENCV_GENERATE_PKGCONFIG=ON \
    -DCPU_BASELINE="NEON" \
    -DCPU_DISPATCH="NEON" \
    -DENABLE_FAST_MATH=ON \
    -DWITH_NEON=ON \
    -DOPENCV_FORCE_NEON=ON \
    -DWITH_DNN=ON \
    -DBUILD_opencv_dnn=ON \
    -DBUILD_opencv_dnn_objdetect=ON \
    -DBUILD_opencv_dnn_superres=ON \
    -DWITH_ONNX=ON \
    -DOPENCV_DNN_ONNX_PROTOBUF=ON \
    -DWITH_OPENCL=OFF \
    -DWITH_CUDA=OFF \
    -DENABLE_PRECOMPILED_HEADERS=OFF \
    ${SOURCE_DIR} \
    -DCMAKE_C_FLAGS="-mfpu=neon-vfpv4 -mcpu=cortex-a7 -mfloat-abi=hard" \
    -DCMAKE_CXX_FLAGS="-mfpu=neon-vfpv4 -mcpu=cortex-a7 -mfloat-abi=hard" \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=ccache

if [ $? -ne 0 ]; then
    echo "CMake configuration failed!"
    exit 1
fi

echo "Building OpenCV..."
make -j$(nproc)

echo "Installing OpenCV to $INSTALL_DIR..."
make install DESTDIR="$INSTALL_DIR"

rm -rf "$BUILD_DIR"
