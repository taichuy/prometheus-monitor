#!/bin/bash

# ==================================================
# 离线环境安装引导脚本 (Linux)
# ==================================================

set -e

echo "=========================================="
echo "开始离线安装流程..."
echo "=========================================="

# 切换到脚本所在目录 (images)
cd "$(dirname "$0")"

# 检查镜像文件是否存在
if [ ! -f "prometheus.tar" ] || [ ! -f "alertmanager.tar" ] || [ ! -f "grafana.tar" ]; then
    echo "❌ 错误: 当前目录下未找到镜像文件！"
    echo "请先运行 save-images.sh 保存镜像。"
    exit 1
fi

# 1. 加载镜像
echo "1. 正在加载 Docker 镜像 (可能需要几分钟)..."
docker load -i prometheus.tar
docker load -i alertmanager.tar
docker load -i grafana.tar
echo "✅ 镜像加载完成"

# 2. 调用主安装脚本
echo "2. 调用主安装脚本..."
cd ..

if [ -f "setup-monitoring.sh" ]; then
    chmod +x setup-monitoring.sh
    # 执行父级目录的安装脚本
    ./setup-monitoring.sh
else
    echo "❌ 错误: 在父级目录未找到 setup-monitoring.sh"
    exit 1
fi
