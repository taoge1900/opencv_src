#!/bin/bash
#------------------ build_opencv_trackercsrtv2_fixed.sh -----------------#

# OpenCV 4.10.0 + TrackerCSRTV2 静态库编译脚本 (修正版)
# 支持ARM交叉编译 (Cortex-A7 + NEON)
# 
# 作者: Cascade AI Assistant
# 日期: 2025-07-24

set -e  # 遇到错误立即退出

echo "========================================"
echo "OpenCV 4.10.0 + TrackerCSRTV2 编译脚本"
echo "========================================"

# 设置基本变量
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
OPENCV_VER="4.10.0"
SOURCE_DIR="$SCRIPT_DIR/opencv-${OPENCV_VER}"
CONTRIB_DIR="$SCRIPT_DIR/opencv_contrib-${OPENCV_VER}"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALL_DIR="$SCRIPT_DIR/install"
BUILDROOT_DIR="/T3/buildroot-2025.02"

echo "脚本目录: $SCRIPT_DIR"
echo "OpenCV版本: $OPENCV_VER"
echo "源码目录: $SOURCE_DIR"
echo "Contrib目录: $CONTRIB_DIR"
echo "构建目录: $BUILD_DIR"
echo "安装目录: $INSTALL_DIR"

# 检查源码目录
if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ 错误: OpenCV源码目录不存在: $SOURCE_DIR"
    exit 1
fi

if [ ! -d "$CONTRIB_DIR" ]; then
    echo "❌ 错误: OpenCV Contrib目录不存在: $CONTRIB_DIR"
    exit 1
fi

# 验证TrackerCSRTV2修改
echo ""
echo "正在验证TrackerCSRTV2修改..."

TRACKING_HEADER="$CONTRIB_DIR/modules/tracking/include/opencv2/tracking.hpp"
TRACKING_SOURCE="$CONTRIB_DIR/modules/tracking/src/trackerCSRT.cpp"

if [ ! -f "$TRACKING_HEADER" ]; then
    echo "❌ 错误: tracking.hpp文件不存在: $TRACKING_HEADER"
    exit 1
fi

if [ ! -f "$TRACKING_SOURCE" ]; then
    echo "❌ 错误: trackerCSRT.cpp文件不存在: $TRACKING_SOURCE"
    exit 1
fi

# 检查TrackerCSRTV2类定义
if ! grep -q "class CV_EXPORTS_W TrackerCSRTV2" "$TRACKING_HEADER"; then
    echo "❌ 错误: 未找到TrackerCSRTV2类定义，请确认修改已正确应用"
    exit 1
fi

# 检查TrackerCSRTV2实现
if ! grep -q "TrackerCSRTV2Impl" "$TRACKING_SOURCE"; then
    echo "❌ 错误: 未找到TrackerCSRTV2Impl实现，请确认修改已正确应用"
    exit 1
fi

echo "✅ TrackerCSRTV2修改验证通过"

# 检查是否为交叉编译环境
CROSS_COMPILE=false
if [ -n "$BUILDROOT_DIR" ] && [ -d "$BUILDROOT_DIR" ]; then
    echo ""
    echo "检测到Buildroot环境，启用ARM交叉编译..."
    CROSS_COMPILE=true
    
    # Buildroot环境变量
    export SYSROOT="${BUILDROOT_DIR}/output/host/arm-buildroot-linux-gnueabihf/sysroot"
    export TOOLCHAIN_BIN="${BUILDROOT_DIR}/output/host/bin"
    export TOOLCHAIN_PREFIX="arm-buildroot-linux-gnueabihf-"
    export CC="${TOOLCHAIN_BIN}/${TOOLCHAIN_PREFIX}gcc"
    export CXX="${TOOLCHAIN_BIN}/${TOOLCHAIN_PREFIX}g++"
    export PKG_CONFIG_PATH="${SYSROOT}/usr/lib/pkgconfig:${SYSROOT}/usr/share/pkgconfig"
    
    INSTALL_DIR="$SYSROOT"
    
    echo "交叉编译工具链: $TOOLCHAIN_BIN/${TOOLCHAIN_PREFIX}gcc"
    echo "Sysroot: $SYSROOT"
else
    echo ""
    echo "未检测到Buildroot环境，使用本地编译..."
fi

# 清理并创建构建目录
if [ -d "$BUILD_DIR" ]; then
    echo ""
    echo "清理旧的构建目录..."
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
mkdir -p "$INSTALL_DIR"

cd "$BUILD_DIR"

# 生成工具链配置文件（仅在交叉编译时）
if [ "$CROSS_COMPILE" = true ]; then
    echo ""
    echo "生成交叉编译工具链配置..."
    
    cat <<EOF > toolchain-arm.cmake
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR armv7)

# 工具链设置
set(TOOLCHAIN_BIN "${TOOLCHAIN_BIN}")
set(TOOLCHAIN_PREFIX "${TOOLCHAIN_PREFIX}")

# 编译器设置
set(CMAKE_C_COMPILER "\${TOOLCHAIN_BIN}/\${TOOLCHAIN_PREFIX}gcc" CACHE FILEPATH "C compiler" FORCE)
set(CMAKE_CXX_COMPILER "\${TOOLCHAIN_BIN}/\${TOOLCHAIN_PREFIX}g++" CACHE FILEPATH "C++ compiler" FORCE)
set(CMAKE_AR "\${TOOLCHAIN_BIN}/\${TOOLCHAIN_PREFIX}ar" CACHE FILEPATH "Archiver" FORCE)
set(CMAKE_RANLIB "\${TOOLCHAIN_BIN}/\${TOOLCHAIN_PREFIX}ranlib" CACHE FILEPATH "Ranlib" FORCE)
set(CMAKE_STRIP "\${TOOLCHAIN_BIN}/\${TOOLCHAIN_PREFIX}strip" CACHE FILEPATH "Strip" FORCE)

# Sysroot设置
set(CMAKE_SYSROOT "${SYSROOT}")
set(CMAKE_FIND_ROOT_PATH "\${CMAKE_SYSROOT}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# ARM Cortex-A7 + NEON优化
set(CMAKE_C_FLAGS "-mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -mthumb -O3" CACHE STRING "C flags" FORCE)
set(CMAKE_CXX_FLAGS "\${CMAKE_C_FLAGS}" CACHE STRING "C++ flags" FORCE)

# pkg-config设置
set(ENV{PKG_CONFIG_PATH} "${PKG_CONFIG_PATH}")
set(ENV{PKG_CONFIG_LIBDIR} "\${CMAKE_SYSROOT}/usr/lib/pkgconfig:\${CMAKE_SYSROOT}/usr/share/pkgconfig")
set(ENV{PKG_CONFIG_SYSROOT_DIR} "\${CMAKE_SYSROOT}")
EOF

    TOOLCHAIN_FILE="./toolchain-arm.cmake"
    CMAKE_INSTALL_PREFIX="/usr"
else
    TOOLCHAIN_FILE=""
    CMAKE_INSTALL_PREFIX="$INSTALL_DIR"
fi

# 构建CMake命令
CMAKE_ARGS=(
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_INSTALL_PREFIX="$CMAKE_INSTALL_PREFIX"
    -DOPENCV_EXTRA_MODULES_PATH="$CONTRIB_DIR/modules"
    
    # 静态库配置
    -DBUILD_SHARED_LIBS=OFF
    -DBUILD_STATIC_LIBS=ON
    -DENABLE_PIC=ON
    -DENABLE_STATIC=ON
    
    # 模块选择（包含tracking）
    -DBUILD_LIST=core,highgui,video,videoio,videostab,imgproc,tracking,calib3d,features2d,objdetect,ml,dnn,photo,imgcodecs
    -DBUILD_opencv_tracking=ON
    -DBUILD_opencv_core=ON
    -DBUILD_opencv_imgproc=ON
    -DBUILD_opencv_highgui=ON
    -DBUILD_opencv_video=ON
    -DBUILD_opencv_videoio=ON
    -DBUILD_opencv_imgcodecs=ON
    
    # 禁用不需要的组件
    -DBUILD_opencv_world=OFF
    -DBUILD_TESTS=OFF
    -DBUILD_PERF_TESTS=OFF
    -DBUILD_EXAMPLES=OFF
    -DBUILD_opencv_apps=OFF
    -DBUILD_DOCS=OFF
    -DBUILD_PACKAGE=OFF
    -DBUILD_JAVA=OFF
    -DBUILD_opencv_python2=OFF
    -DBUILD_opencv_python3=OFF
    
    # 第三方库配置
    -DWITH_JPEG=ON
    -DWITH_PNG=ON
    -DWITH_PROTOBUF=ON
    -DWITH_OPENMP=ON
    -DWITH_FFMPEG=OFF
    -DWITH_GSTREAMER=OFF
    -DWITH_GTK=OFF
    -DWITH_OPENCL=OFF
    -DWITH_CUDA=OFF
    
    # 优化设置
    -DENABLE_FAST_MATH=ON
    -DOPENCV_ENABLE_NONFREE=ON
    -DOPENCV_GENERATE_PKGCONFIG=ON
    -DCMAKE_VERBOSE_MAKEFILE=ON
)

# 添加交叉编译特定参数
if [ "$CROSS_COMPILE" = true ]; then
    CMAKE_ARGS+=(
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE"
        -DCPU_BASELINE="NEON"
        -DCPU_DISPATCH="NEON"
        -DWITH_NEON=ON
        -DOPENCV_FORCE_NEON=ON
        -DCMAKE_C_COMPILER_LAUNCHER=ccache
        -DCMAKE_CXX_COMPILER_LAUNCHER=ccache
    )
fi

# 添加源码目录
CMAKE_ARGS+=("$SOURCE_DIR")

echo ""
echo "正在配置CMake..."
echo "CMake参数:"
printf '%s\n' "${CMAKE_ARGS[@]}" | sed 's/^/  /'

# 执行CMake配置
cmake "${CMAKE_ARGS[@]}"

if [ $? -ne 0 ]; then
    echo "❌ CMake配置失败!"
    exit 1
fi

echo ""
echo "✅ CMake配置成功"

# 编译
echo ""
echo "开始编译OpenCV (这可能需要30-60分钟)..."
echo "编译开始时间: $(date)"

NPROC=$(nproc)
echo "使用 $NPROC 个并行任务进行编译..."

make -j$NPROC

if [ $? -ne 0 ]; then
    echo "❌ 编译失败!"
    exit 1
fi

echo ""
echo "✅ 编译成功"
echo "编译完成时间: $(date)"

# 安装
echo ""
echo "正在安装OpenCV库文件..."

if [ "$CROSS_COMPILE" = true ]; then
    make install DESTDIR="$INSTALL_DIR"
else
    make install
fi

if [ $? -ne 0 ]; then
    echo "❌ 安装失败!"
    exit 1
fi

echo "✅ 安装成功"

# 验证安装结果
echo ""
echo "正在验证TrackerCSRTV2编译结果..."

if [ "$CROSS_COMPILE" = true ]; then
    LIB_DIR="$INSTALL_DIR/usr/lib"
    INCLUDE_DIR="$INSTALL_DIR/usr/include"
else
    LIB_DIR="$INSTALL_DIR/lib"
    INCLUDE_DIR="$INSTALL_DIR/include"
fi

# 检查库文件
if ls "$LIB_DIR"/libopencv_tracking*.a >/dev/null 2>&1; then
    echo "✅ tracking模块静态库已生成"
    ls -la "$LIB_DIR"/libopencv_tracking*.a
else
    echo "⚠️  警告: 未找到tracking模块静态库文件"
fi

# 检查头文件
if [ -f "$INCLUDE_DIR/opencv2/tracking.hpp" ]; then
    echo "✅ tracking头文件已安装"
    if grep -q "TrackerCSRTV2" "$INCLUDE_DIR/opencv2/tracking.hpp"; then
        echo "✅ TrackerCSRTV2类定义已包含在安装的头文件中"
    else
        echo "⚠️  警告: TrackerCSRTV2类定义未在安装的头文件中找到"
    fi
else
    echo "⚠️  警告: 未找到安装的tracking头文件"
fi

# 清理构建目录（可选）
# rm -rf "$BUILD_DIR"

echo ""
echo "========================================"
echo "🎉 OpenCV + TrackerCSRTV2 编译完成！"
echo "========================================"
echo ""
if [ "$CROSS_COMPILE" = true ]; then
    echo "安装路径: $INSTALL_DIR/usr"
    echo "库文件路径: $INSTALL_DIR/usr/lib"
    echo "头文件路径: $INSTALL_DIR/usr/include"
else
    echo "安装路径: $INSTALL_DIR"
    echo "库文件路径: $INSTALL_DIR/lib"
    echo "头文件路径: $INSTALL_DIR/include"
fi
echo ""
echo "下一步:"
echo "1. 在你的项目中包含头文件路径"
echo "2. 链接必要的静态库文件"
echo "3. 使用 cv::tracking::TrackerCSRTV2::create() 创建跟踪器"
echo ""
echo "参考使用示例: TrackerCSRTV2_Documentation/TrackerCSRTV2_Usage_Example.cpp"
echo ""

echo "🎯 TrackerCSRTV2新功能:"
echo "- getTrackingScore(): 获取标准化跟踪质量分数 (0-1)"
echo "- getRawPSR(): 获取原始PSR值"
echo "- isTargetLost(): 检查目标是否丢失"
echo "- getTrackingStats(): 获取详细跟踪统计信息"
echo ""
