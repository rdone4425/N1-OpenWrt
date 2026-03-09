#!/bin/bash

# OpenWrt 编译优化脚本
# 用途：处理常见的编译问题，特别是 Rust 相关的网络错误

set -e

echo "========================================="
echo "OpenWrt 编译优化脚本"
echo "========================================="

cd "$(dirname "$0")/../../.." || exit 1

# 1. 禁用 Rust CI LLVM 下载（防止网络 404）
optimize_rust_config() {
    echo "[1/3] 优化 Rust 配置..."

    RUST_BOOTSTRAP="feeds/packages/lang/rust/bootstrap.toml"

    if [ ! -f "$RUST_BOOTSTRAP" ]; then
        echo "⚠️  未找到 Rust bootstrap.toml，跳过优化"
        return 0
    fi

    # 检查是否已经禁用
    if grep -q "download-ci-llvm.*false" "$RUST_BOOTSTRAP"; then
        echo "✓ Rust CI LLVM 已禁用"
        return 0
    fi

    # 备份原文件
    cp "$RUST_BOOTSTRAP" "$RUST_BOOTSTRAP.bak"

    # 禁用 CI LLVM 下载
    if grep -q "^\[llvm\]" "$RUST_BOOTSTRAP"; then
        # [llvm] 部分已存在，修改或添加配置
        sed -i '/^\[llvm\]/,/^\[/s/download-ci-llvm = true/download-ci-llvm = false/' "$RUST_BOOTSTRAP"
        if ! grep -q "download-ci-llvm.*false" "$RUST_BOOTSTRAP"; then
            # 如果仍未生效，直接添加
            sed -i '/^\[llvm\]/a\download-ci-llvm = false' "$RUST_BOOTSTRAP"
        fi
    else
        # 添加新的 [llvm] 部分
        echo -e "\n[llvm]\ndownload-ci-llvm = false" >> "$RUST_BOOTSTRAP"
    fi

    echo "✓ Rust CI LLVM 已禁用"
}

# 2. 优化编译器缓存
optimize_ccache() {
    echo "[2/3] 配置编译器缓存..."

    # 启用 ccache 以加速重复编译
    export CCACHE_DIR="$(pwd)/.ccache"
    mkdir -p "$CCACHE_DIR"

    # 设置缓存大小限制（10GB）
    ccache -M 10G 2>/dev/null || true

    echo "✓ ccache 已配置"
}

# 3. 清理过期的下载
cleanup_dl() {
    echo "[3/3] 清理过期的下载..."

    if [ -d "dl" ]; then
        # 删除小于 1KB 的文件（通常是损坏的下载）
        find dl -type f -size -1k -delete
        echo "✓ 已清理过期的下载"
    fi
}

# 执行优化
optimize_rust_config
optimize_ccache
cleanup_dl

echo "========================================="
echo "✓ 优化完成！"
echo "========================================="
