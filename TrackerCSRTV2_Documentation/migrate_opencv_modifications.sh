#!/bin/bash

# OpenCV TrackerCSRTV2 修改文件迁移脚本 (Linux/WSL版本)
#
# 此脚本用于将TrackerCSRTV2的修改从源目录复制到目标OpenCV目录结构
#
# 使用方法:
#     ./migrate_opencv_modifications.sh <source_path> <target_path> [backup]
#
# 参数:
#     source_path: 源OpenCV目录路径 (包含修改的文件)
#     target_path: 目标OpenCV目录路径 (新的目录结构)
#     backup: 可选参数，如果指定则在覆盖前备份目标文件
#
# 作者: Cascade AI Assistant
# 日期: 2025-07-24
# 版本: 1.0

set -e  # 遇到错误时退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查参数
if [ $# -lt 2 ]; then
    print_error "参数不足"
    echo "使用方法: $0 <source_path> <target_path> [backup]"
    echo ""
    echo "示例:"
    echo "  $0 /mnt/d/workspace/T3/src3rd.mv/opencv-4.10.0 /mnt/d/workspace/T3/src/opencv_src"
    echo "  $0 /mnt/d/workspace/T3/src3rd.mv/opencv-4.10.0 /mnt/d/workspace/T3/src/opencv_src backup"
    exit 1
fi

SOURCE_ROOT="$1"
TARGET_ROOT="$2"
BACKUP_MODE="$3"

echo "========================================"
echo "OpenCV TrackerCSRTV2 修改文件迁移脚本"
echo "========================================"
echo ""

# 验证源目录
if [ ! -d "$SOURCE_ROOT" ]; then
    print_error "源目录不存在: $SOURCE_ROOT"
    exit 1
fi

# 验证目标目录
if [ ! -d "$TARGET_ROOT" ]; then
    print_error "目标目录不存在: $TARGET_ROOT"
    exit 1
fi

print_info "源目录: $SOURCE_ROOT"
print_info "目标目录: $TARGET_ROOT"
if [ "$BACKUP_MODE" = "backup" ]; then
    print_info "备份模式: 启用"
else
    print_info "备份模式: 禁用"
fi
echo ""

# 定义文件映射
declare -a SOURCE_FILES=(
    "$SOURCE_ROOT/opencv_contrib-4.10.0/modules/tracking/include/opencv2/tracking.hpp"
    "$SOURCE_ROOT/opencv_contrib-4.10.0/modules/tracking/src/trackerCSRT.cpp"
)

declare -a TARGET_FILES=(
    "$TARGET_ROOT/opencv_contrib-4.10.0/modules/tracking/include/opencv2/tracking.hpp"
    "$TARGET_ROOT/opencv_contrib-4.10.0/modules/tracking/src/trackerCSRT.cpp"
)

declare -a DESCRIPTIONS=(
    "TrackerCSRTV2类定义头文件"
    "TrackerCSRTV2实现文件"
)

# 验证源文件
print_info "验证源文件..."
for i in "${!SOURCE_FILES[@]}"; do
    if [ ! -f "${SOURCE_FILES[$i]}" ]; then
        print_error "源文件不存在: ${SOURCE_FILES[$i]}"
        exit 1
    fi
    print_success "${DESCRIPTIONS[$i]}"
done
echo ""

# 创建目标目录结构
print_info "创建目标目录结构..."
TARGET_INCLUDE_DIR="$TARGET_ROOT/opencv_contrib-4.10.0/modules/tracking/include/opencv2"
TARGET_SRC_DIR="$TARGET_ROOT/opencv_contrib-4.10.0/modules/tracking/src"

mkdir -p "$TARGET_INCLUDE_DIR"
if [ $? -eq 0 ]; then
    print_success "确保目录存在: $TARGET_INCLUDE_DIR"
else
    print_error "创建目录失败: $TARGET_INCLUDE_DIR"
    exit 1
fi

mkdir -p "$TARGET_SRC_DIR"
if [ $? -eq 0 ]; then
    print_success "确保目录存在: $TARGET_SRC_DIR"
else
    print_error "创建目录失败: $TARGET_SRC_DIR"
    exit 1
fi
echo ""

# 复制文件
print_info "开始复制文件..."
for i in "${!SOURCE_FILES[@]}"; do
    echo "处理文件: ${DESCRIPTIONS[$i]}"
    echo "  源文件: ${SOURCE_FILES[$i]}"
    echo "  目标文件: ${TARGET_FILES[$i]}"
    
    # 备份现有文件
    if [ "$BACKUP_MODE" = "backup" ] && [ -f "${TARGET_FILES[$i]}" ]; then
        TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
        BACKUP_FILE="${TARGET_FILES[$i]}.backup_$TIMESTAMP"
        cp "${TARGET_FILES[$i]}" "$BACKUP_FILE"
        if [ $? -eq 0 ]; then
            print_success "备份文件: $BACKUP_FILE"
        else
            print_warning "备份失败，继续执行..."
        fi
    fi
    
    # 复制文件
    cp "${SOURCE_FILES[$i]}" "${TARGET_FILES[$i]}"
    if [ $? -eq 0 ]; then
        print_success "文件复制完成"
    else
        print_error "文件复制失败"
        exit 1
    fi
    echo ""
done

# 验证修改
print_info "验证修改..."

# 检查TrackerCSRTV2类是否存在于头文件中
if grep -q "TrackerCSRTV2" "${TARGET_FILES[0]}"; then
    print_success "TrackerCSRTV2类定义已添加到头文件"
else
    print_error "头文件中未找到TrackerCSRTV2类定义"
fi

# 检查实现文件中的TrackerCSRTV2Impl
if grep -q "TrackerCSRTV2Impl" "${TARGET_FILES[1]}"; then
    print_success "TrackerCSRTV2Impl实现已添加到源文件"
else
    print_error "源文件中未找到TrackerCSRTV2Impl实现"
fi

if grep -q "getLastPSRValue" "${TARGET_FILES[1]}"; then
    print_success "PSR访问方法已添加"
else
    print_error "未找到PSR访问方法"
fi
echo ""

# 生成报告
echo "========================================"
echo "迁移报告"
echo "========================================"
echo "模式: 执行模式"
echo "源目录: $SOURCE_ROOT"
echo "目标目录: $TARGET_ROOT"
echo "处理文件数: ${#SOURCE_FILES[@]}"
echo ""
echo "处理的文件:"
for i in "${!DESCRIPTIONS[@]}"; do
    echo "  $((i+1)). ${DESCRIPTIONS[$i]}"
done
echo ""
print_success "迁移完成!"
echo ""
echo "下一步操作:"
echo "1. 进入目标目录进行OpenCV编译"
echo "2. 在项目中将cv::TrackerCSRT替换为cv::TrackerCSRTV2"
echo "3. 测试新的PSR访问功能"
echo ""

# 显示编译命令示例
print_info "OpenCV编译命令示例:"
echo "cd $TARGET_ROOT"
echo "mkdir build && cd build"
echo "cmake -DCMAKE_BUILD_TYPE=Release \\"
echo "      -DOPENCV_EXTRA_MODULES_PATH=../opencv_contrib-4.10.0/modules \\"
echo "      -DBUILD_SHARED_LIBS=OFF \\"
echo "      ../opencv-4.10.0"
echo "make -j\$(nproc)"
echo ""

print_success "脚本执行完成!"
