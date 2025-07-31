#!/usr/bin/env python3
"""
OpenCV TrackerCSRTV2 修改文件迁移脚本

此脚本用于将TrackerCSRTV2的修改从源目录复制到目标OpenCV目录结构。

使用方法:
    python migrate_opencv_modifications.py --source /path/to/source --target /path/to/target [--dry-run]

参数:
    --source: 源OpenCV目录路径 (包含修改的文件)
    --target: 目标OpenCV目录路径 (新的目录结构)
    --dry-run: 仅显示将要执行的操作，不实际复制文件
    --backup: 在覆盖前备份目标文件

作者: Cascade AI Assistant
日期: 2025-07-24
版本: 1.0
"""

import os
import sys
import shutil
import argparse
from pathlib import Path
from datetime import datetime

class OpenCVMigrator:
    def __init__(self, source_root, target_root, dry_run=False, backup=False):
        self.source_root = Path(source_root)
        self.target_root = Path(target_root)
        self.dry_run = dry_run
        self.backup = backup
        self.operations = []
        
        # 定义文件映射关系
        self.file_mappings = [
            {
                'source': 'opencv_contrib-4.10.0/modules/tracking/include/opencv2/tracking.hpp',
                'target': 'opencv_contrib-4.10.0/modules/tracking/include/opencv2/tracking.hpp',
                'description': 'TrackerCSRTV2类定义头文件'
            },
            {
                'source': 'opencv_contrib-4.10.0/modules/tracking/src/trackerCSRT.cpp',
                'target': 'opencv_contrib-4.10.0/modules/tracking/src/trackerCSRT.cpp',
                'description': 'TrackerCSRTV2实现文件'
            }
        ]
    
    def validate_paths(self):
        """验证源目录和目标目录的有效性"""
        print("🔍 验证目录结构...")
        
        # 检查源目录
        if not self.source_root.exists():
            raise FileNotFoundError(f"源目录不存在: {self.source_root}")
        
        # 检查目标目录
        if not self.target_root.exists():
            raise FileNotFoundError(f"目标目录不存在: {self.target_root}")
        
        # 验证源文件存在
        missing_files = []
        for mapping in self.file_mappings:
            source_file = self.source_root / mapping['source']
            if not source_file.exists():
                missing_files.append(str(source_file))
        
        if missing_files:
            print("❌ 以下源文件不存在:")
            for file in missing_files:
                print(f"   - {file}")
            raise FileNotFoundError("源文件缺失")
        
        # 验证目标目录结构
        expected_dirs = [
            'opencv-4.10.0',
            'opencv_contrib-4.10.0',
            'opencv_contrib-4.10.0/modules',
            'opencv_contrib-4.10.0/modules/tracking',
            'opencv_contrib-4.10.0/modules/tracking/include',
            'opencv_contrib-4.10.0/modules/tracking/include/opencv2',
            'opencv_contrib-4.10.0/modules/tracking/src'
        ]
        
        missing_dirs = []
        for dir_path in expected_dirs:
            full_path = self.target_root / dir_path
            if not full_path.exists():
                missing_dirs.append(str(full_path))
        
        if missing_dirs:
            print("⚠️  以下目标目录不存在，将自动创建:")
            for dir_path in missing_dirs:
                print(f"   - {dir_path}")
        
        print("✅ 目录结构验证完成")
    
    def create_backup(self, target_file):
        """创建目标文件的备份"""
        if not target_file.exists():
            return None
        
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_file = target_file.with_suffix(f".backup_{timestamp}{target_file.suffix}")
        
        if not self.dry_run:
            shutil.copy2(target_file, backup_file)
        
        return backup_file
    
    def copy_file(self, source_file, target_file, description):
        """复制单个文件"""
        operation = {
            'action': 'copy',
            'source': source_file,
            'target': target_file,
            'description': description,
            'backup': None
        }
        
        # 创建目标目录
        target_dir = target_file.parent
        if not target_dir.exists():
            operation['create_dir'] = target_dir
            if not self.dry_run:
                target_dir.mkdir(parents=True, exist_ok=True)
        
        # 备份现有文件
        if self.backup and target_file.exists():
            backup_file = self.create_backup(target_file)
            operation['backup'] = backup_file
        
        # 复制文件
        if not self.dry_run:
            shutil.copy2(source_file, target_file)
            # 设置文件权限
            os.chmod(target_file, 0o644)
        
        self.operations.append(operation)
        return operation
    
    def migrate_files(self):
        """执行文件迁移"""
        print(f"📁 开始迁移文件 ({'预览模式' if self.dry_run else '执行模式'})...")
        
        for mapping in self.file_mappings:
            source_file = self.source_root / mapping['source']
            target_file = self.target_root / mapping['target']
            
            print(f"\n📄 处理文件: {mapping['description']}")
            print(f"   源文件: {source_file}")
            print(f"   目标文件: {target_file}")
            
            if self.dry_run:
                print("   操作: [预览] 将复制文件")
                if target_file.exists():
                    print("   注意: 目标文件已存在，将被覆盖")
                if self.backup and target_file.exists():
                    print("   备份: 将创建备份文件")
            else:
                operation = self.copy_file(source_file, target_file, mapping['description'])
                
                if 'create_dir' in operation:
                    print(f"   ✅ 创建目录: {operation['create_dir']}")
                
                if operation['backup']:
                    print(f"   💾 备份文件: {operation['backup']}")
                
                print("   ✅ 文件复制完成")
    
    def verify_modifications(self):
        """验证修改是否正确应用"""
        if self.dry_run:
            return
        
        print("\n🔍 验证修改...")
        
        # 检查TrackerCSRTV2类是否存在于头文件中
        header_file = self.target_root / 'opencv_contrib-4.10.0/modules/tracking/include/opencv2/tracking.hpp'
        if header_file.exists():
            content = header_file.read_text(encoding='utf-8')
            if 'TrackerCSRTV2' in content:
                print("   ✅ TrackerCSRTV2类定义已添加到头文件")
            else:
                print("   ❌ 头文件中未找到TrackerCSRTV2类定义")
        
        # 检查实现文件中的TrackerCSRTV2Impl
        impl_file = self.target_root / 'opencv_contrib-4.10.0/modules/tracking/src/trackerCSRT.cpp'
        if impl_file.exists():
            content = impl_file.read_text(encoding='utf-8')
            if 'TrackerCSRTV2Impl' in content:
                print("   ✅ TrackerCSRTV2Impl实现已添加到源文件")
            else:
                print("   ❌ 源文件中未找到TrackerCSRTV2Impl实现")
            
            if 'getLastPSRValue' in content:
                print("   ✅ PSR访问方法已添加")
            else:
                print("   ❌ 未找到PSR访问方法")
    
    def generate_report(self):
        """生成迁移报告"""
        print("\n📊 迁移报告")
        print("=" * 50)
        
        if self.dry_run:
            print("模式: 预览模式 (未实际执行操作)")
        else:
            print("模式: 执行模式")
        
        print(f"源目录: {self.source_root}")
        print(f"目标目录: {self.target_root}")
        print(f"处理文件数: {len(self.file_mappings)}")
        
        if not self.dry_run:
            print(f"执行操作数: {len(self.operations)}")
            
            backup_count = sum(1 for op in self.operations if op.get('backup'))
            if backup_count > 0:
                print(f"备份文件数: {backup_count}")
        
        print("\n处理的文件:")
        for i, mapping in enumerate(self.file_mappings, 1):
            print(f"  {i}. {mapping['description']}")
            print(f"     {mapping['source']} -> {mapping['target']}")
        
        if not self.dry_run:
            print("\n✅ 迁移完成!")
            print("\n下一步操作:")
            print("1. 进入目标目录进行OpenCV编译")
            print("2. 在项目中将cv::TrackerCSRT替换为cv::TrackerCSRTV2")
            print("3. 测试新的PSR访问功能")
        else:
            print("\n💡 这是预览模式，如需实际执行请移除 --dry-run 参数")

def main():
    parser = argparse.ArgumentParser(
        description='OpenCV TrackerCSRTV2 修改文件迁移脚本',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例用法:
  # 预览模式
  python migrate_opencv_modifications.py \\
    --source "d:/workspace/T3/src3rd.mv/opencv-4.10.0" \\
    --target "/mnt/d/workspace/T3/src/opencv_src" \\
    --dry-run
  
  # 执行迁移
  python migrate_opencv_modifications.py \\
    --source "d:/workspace/T3/src3rd.mv/opencv-4.10.0" \\
    --target "/mnt/d/workspace/T3/src/opencv_src" \\
    --backup
        """
    )
    
    parser.add_argument('--source', required=True,
                       help='源OpenCV目录路径 (包含修改的文件)')
    parser.add_argument('--target', required=True,
                       help='目标OpenCV目录路径 (新的目录结构)')
    parser.add_argument('--dry-run', action='store_true',
                       help='仅显示将要执行的操作，不实际复制文件')
    parser.add_argument('--backup', action='store_true',
                       help='在覆盖前备份目标文件')
    
    args = parser.parse_args()
    
    try:
        print("🚀 OpenCV TrackerCSRTV2 修改文件迁移脚本")
        print("=" * 50)
        
        migrator = OpenCVMigrator(
            source_root=args.source,
            target_root=args.target,
            dry_run=args.dry_run,
            backup=args.backup
        )
        
        migrator.validate_paths()
        migrator.migrate_files()
        migrator.verify_modifications()
        migrator.generate_report()
        
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
