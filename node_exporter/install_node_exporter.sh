#!/bin/bash
# node_exporter安装脚本 (本地模式)
# 版本: 1.1
# 功能: 解压node_exporter压缩包，安装到当前目录的bin子目录，配置systemd服务
# 注意: 仅 systemd 服务文件会创建在 /etc/systemd/system，其余文件均在脚本当前目录下

set -e

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "开始安装 node_exporter (本地模式)"
echo "安装根目录: $SCRIPT_DIR"
echo "=========================================="

# 检查是否以root运行(为了创建服务文件)
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  需要 root 权限来创建 systemd 服务文件"
    echo "请尝试: sudo $0"
    exit 1
fi

# 检查压缩包是否存在
TAR_FILE=$(ls -1 node_exporter-*.tar.gz 2>/dev/null | head -1)

if [ -z "$TAR_FILE" ]; then
    echo "错误: 未找到 node_exporter 压缩包"
    echo "请确保脚本目录中存在 node_exporter-*.tar.gz 文件"
    exit 1
fi

echo "找到压缩包: $TAR_FILE"

# 检查是否已安装tar
if ! command -v tar &> /dev/null; then
    echo "安装 tar 工具..."
    apt-get update && apt-get install -y tar || yum install -y tar
fi

# 定义本地安装目录
INSTALL_DIR="$SCRIPT_DIR/bin"
TEXTFILE_DIR="$SCRIPT_DIR/textfile_collector"

# 解压压缩包
echo "解压压缩包..."
tar -xzf "$TAR_FILE" -C /tmp/

# 查找解压后的目录
EXTRACTED_DIR=$(ls -d /tmp/node_exporter-* 2>/dev/null | head -1)

if [ -z "$EXTRACTED_DIR" ]; then
    echo "错误: 解压后未找到 node_exporter 目录"
    exit 1
fi

echo "解压目录: $EXTRACTED_DIR"

# 创建本地安装目录
echo "创建本地安装目录: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# 复制文件
echo "复制文件到安装目录..."
cp "$EXTRACTED_DIR/node_exporter" "$INSTALL_DIR/"
# 仅修改当前目录下的文件权限
chmod +x "$INSTALL_DIR/node_exporter"

# 创建systemd服务文件 (这是唯一写入系统目录的操作)
echo "创建systemd服务文件..."
cat > /etc/systemd/system/node_exporter.service << EOF
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=$INSTALL_DIR/node_exporter \\
  --web.listen-address=:9100 \\
  --collector.disable-defaults \\
  --collector.cpu \\
  --collector.meminfo \\
  --collector.diskstats \\
  --collector.netdev \\
  --collector.filesystem \\
  --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|run|boot)(\$\$|/) \\
  --collector.systemd \\
  --collector.systemd.unit-include="(docker|ssh|nginx|mysql|postgresql).service" \\
  --collector.textfile.directory=$TEXTFILE_DIR \\
  --collector.loadavg \\
  --collector.uname \\
  --collector.stat \\
  --collector.vmstat \\
  --collector.time \\
  --collector.netstat \\
  --collector.filefd \\
  --collector.ntp \\
  --collector.interrupts \\
  --collector.edac \\
  --collector.hwmon \\
  --collector.bonding \\
  --collector.arp \\
  --collector.conntrack \\
  --collector.sockstat \\
  --collector.processes \\
  --collector.tcpstat \\
  --collector.buddyinfo \\
  --collector.ksmd \\
  --collector.zfs \\
  --collector.xfs \\
  --collector.btrfs \\
  --collector.ipvs
  
Restart=always
RestartSec=5
StandardOutput=null
StandardError=null
SyslogIdentifier=node_exporter

# 安全设置
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=true

[Install]
WantedBy=multi-user.target
EOF

# 创建文本文件收集器目录
echo "创建文本文件收集器目录..."
mkdir -p "$TEXTFILE_DIR"
# 仅修改当前目录下的文件权限
chmod 755 "$TEXTFILE_DIR"

# 重新加载systemd配置
echo "重新加载systemd配置..."
systemctl daemon-reload

# 启用并启动服务
echo "启用并启动node_exporter服务..."
systemctl enable node_exporter.service
systemctl start node_exporter.service

# 等待服务启动
echo "等待服务启动..."
sleep 3

# 检查服务状态
echo "检查服务状态..."
if systemctl is-active --quiet node_exporter; then
    echo "✅ node_exporter 服务启动成功"
else
    echo "⚠️  服务启动可能有问题，检查日志: journalctl -u node_exporter"
    systemctl status node_exporter --no-pager
fi

# 检查端口监听
echo "检查端口监听..."
if netstat -tlnp | grep -q ":9100"; then
    echo "✅ node_exporter 正在监听端口 9100"
    
    # 测试HTTP访问
    if curl -s http://localhost:9100/metrics > /dev/null; then
        echo "✅ HTTP访问正常"
    else
        echo "⚠️  HTTP访问异常"
    fi
else
    echo "❌ node_exporter 未监听端口 9100"
fi

# 创建Prometheus配置示例
echo ""
echo "=========================================="
echo "🎯 Prometheus 配置示例"
echo "=========================================="
cat << EOF
在 Prometheus 的 prometheus.yml 中添加以下配置：

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['$(hostname -I | awk '{print $1}'):9100']
        labels:
          instance: '$(hostname)'
          role: 'node'
    scrape_interval: 15s
    scrape_timeout: 10s

EOF

# 创建卸载脚本
echo "创建卸载脚本..."
cat > "$SCRIPT_DIR/uninstall_node_exporter.sh" << EOF
#!/bin/bash
# node_exporter卸载脚本

echo "停止并禁用node_exporter服务..."
systemctl stop node_exporter.service 2>/dev/null || true
systemctl disable node_exporter.service 2>/dev/null || true

echo "删除systemd服务文件..."
rm -f /etc/systemd/system/node_exporter.service

echo "删除本地安装目录..."
rm -rf "$INSTALL_DIR"
rm -rf "$TEXTFILE_DIR"

echo "重新加载systemd配置..."
systemctl daemon-reload

echo "✅ node_exporter 已卸载 (相关文件已从当前目录移除)"
EOF

chmod +x "$SCRIPT_DIR/uninstall_node_exporter.sh"

# 创建管理脚本
echo "创建管理脚本..."
cat > "$SCRIPT_DIR/manage_node_exporter.sh" << 'EOF'
#!/bin/bash
# node_exporter管理脚本

case "$1" in
    start)
        systemctl start node_exporter
        echo "启动node_exporter服务"
        ;;
    stop)
        systemctl stop node_exporter
        echo "停止node_exporter服务"
        ;;
    restart)
        systemctl restart node_exporter
        echo "重启node_exporter服务"
        ;;
    status)
        systemctl status node_exporter --no-pager
        ;;
    logs)
        journalctl -u node_exporter -f
        ;;
    enable)
        systemctl enable node_exporter
        echo "启用开机自启动"
        ;;
    disable)
        systemctl disable node_exporter
        echo "禁用开机自启动"
        ;;
    reload)
        systemctl daemon-reload
        systemctl restart node_exporter
        echo "重新加载配置并重启服务"
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|logs|enable|disable|reload}"
        exit 1
        ;;
esac
EOF

chmod +x "$SCRIPT_DIR/manage_node_exporter.sh"

echo ""
echo "=========================================="
echo "✅ node_exporter 安装完成！"
echo "=========================================="
echo ""
echo "安装信息:"
echo "- 安装目录: $INSTALL_DIR"
echo "- 配置文件: /etc/systemd/system/node_exporter.service"
echo "- 收集器目录: $TEXTFILE_DIR"
echo "- 服务端口: 9100"
echo ""
echo "清理临时文件..."
rm -rf "$EXTRACTED_DIR"

echo "✅ 所有操作完成！"
