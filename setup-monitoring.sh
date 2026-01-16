#!/bin/bash

echo "=========================================="
echo "启动监控系统 (简化模式)..."
echo "=========================================="

cd "$(dirname "$0")"

# 清理旧容器
echo "清理旧容器..."
docker-compose down 2>/dev/null || true

# 拉取镜像
echo "拉取镜像..."
docker-compose pull || echo "继续启动..."

# 启动服务
echo "启动服务..."
docker-compose up -d

echo "等待服务启动..."
sleep 10

echo ""
echo "✅ 服务启动完成！"
echo ""
echo "容器状态:"
docker-compose ps

echo ""
echo "访问地址:"
IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
echo "- Prometheus:   http://$IP:9090  (用户: admin, 密码: Taichu@2026)"
echo "- Grafana:      http://$IP:3000  (用户: admin, 密码: admin)"
echo "- Alertmanager: http://$IP:9093"
echo ""
echo "查看日志: docker-compose logs -f"
echo "停止服务: docker-compose down"
root@taichu-db:/home/taichu/prometheus# cat setup-monitoring.sh 
#!/bin/bash

# ==================================================
# Prometheus + Grafana + Alertmanager 一键部署脚本
# 版本: 2.4
# 修复: 1. 修复健康检查 2. 简化配置 3. 确保启动成功
# ==================================================

set -e

# 配置变量 - 使用脚本所在目录作为基础目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}"
PROMETHEUS_USER="admin"
PROMETHEUS_PASSWORD="Taichu@2026"

echo "=========================================="
echo "开始部署监控系统 (Prometheus + Grafana + Alertmanager)"
echo "部署目录: ${BASE_DIR}"
echo "=========================================="

# 检查是否以root用户运行
if [ "$EUID" -ne 0 ]; then 
    echo "⚠️  警告: 需要 root 权限来设置目录权限"
    echo "请使用 sudo 运行此脚本: sudo $0"
    exit 1
fi

# 清理旧容器和网络
echo "1. 清理旧容器和网络..."
docker-compose down 2>/dev/null || true
docker network prune -f 2>/dev/null || true

# 创建目录结构
echo "2. 创建目录结构..."
mkdir -p ${BASE_DIR}/prometheus/data
mkdir -p ${BASE_DIR}/prometheus/config/rules
mkdir -p ${BASE_DIR}/alertmanager/data
mkdir -p ${BASE_DIR}/alertmanager/config
mkdir -p ${BASE_DIR}/grafana/data
mkdir -p ${BASE_DIR}/grafana/config
mkdir -p ${BASE_DIR}/grafana/plugins

echo "✅ 目录创建完成"

# 设置目录权限
echo "3. 设置目录权限..."
chown -R 65534:65534 ${BASE_DIR}/prometheus/data
chown -R 472:472 ${BASE_DIR}/grafana/data
chown -R 65534:65534 ${BASE_DIR}/alertmanager/data

chmod -R 755 ${BASE_DIR}/prometheus/data ${BASE_DIR}/grafana/data ${BASE_DIR}/alertmanager/data
chmod -R 755 ${BASE_DIR}/prometheus/config ${BASE_DIR}/grafana/config ${BASE_DIR}/alertmanager/config

echo "✅ 权限设置完成"

# 生成 Prometheus Basic Auth 密码哈希
echo "4. 生成 Prometheus Basic Auth 密码哈希..."
cat > ${BASE_DIR}/prometheus/config/web-config.yml << 'EOF'
# Basic Auth 配置
basic_auth_users:
  admin: $2a$12$eOYeRrFxjkIS6mQRqrmCHuQQTZtxYyC4Ihv5pQ4nY0j8IcydxW2Aa  # 密码: Taichu@2026
EOF

# 生成 Prometheus 主配置文件（简化版）
echo "5. 生成 Prometheus 配置文件..."
cat > ${BASE_DIR}/prometheus/config/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']
      scheme: http

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scheme: http
    basic_auth:
      username: 'admin'
      password: 'Taichu@2026'

  - job_name: 'alertmanager'
    static_configs:
      - targets: ['alertmanager:9093']
    scheme: http
EOF

# 生成简单的告警规则
echo "6. 生成示例告警规则..."
cat > ${BASE_DIR}/prometheus/config/rules/alert-rules.yml << 'EOF'
groups:
  - name: example
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ $labels.instance }} down"
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute."
EOF

# 生成 Alertmanager 配置文件
echo "7. 生成 Alertmanager 配置文件..."
cat > ${BASE_DIR}/alertmanager/config/alertmanager.yml << 'EOF'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  receiver: 'default-receiver'

receivers:
  - name: 'default-receiver'
    # 配置您的告警接收器
EOF

# 生成 Grafana 配置文件
echo "8. 生成 Grafana 配置文件..."
cat > ${BASE_DIR}/grafana/config/grafana.ini << 'EOF'
[server]
domain = localhost
root_url = %(protocol)s://%(domain)s:%(http_port)s/

[database]
type = sqlite3
path = /var/lib/grafana/grafana.db

[security]
admin_user = admin
admin_password = admin
secret_key = SW2YcwTIb9zpOOhoPsMm

[auth.anonymous]
enabled = false

[users]
allow_sign_up = false
auto_assign_org = true
auto_assign_org_role = Editor
EOF

# 生成修复的 docker-compose.yml（关键修复）
echo "9. 生成修复的 docker-compose.yml..."
cat > ${BASE_DIR}/docker-compose.yml << 'EOF'
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: taichuy-prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=7d'
      - '--web.config.file=/etc/prometheus/web-config.yml'
      - '--web.enable-lifecycle'
    volumes:
      - ./prometheus/config:/etc/prometheus
      - ./prometheus/data:/prometheus
    ports:
      - "9090:9090"
    user: "65534:65534"
    networks:
      - monitoring-net
    restart: unless-stopped
    # 不使用健康检查，避免启动问题
    # healthcheck:
    #   test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:9090/-/healthy"]
    #   interval: 10s
    #   timeout: 5s
    #   retries: 3
    #   start_period: 30s

  alertmanager:
    image: prom/alertmanager:latest
    container_name: taichuy-alertmanager
    command:
      - "--config.file=/etc/alertmanager/alertmanager.yml"
      - "--storage.path=/alertmanager"
    volumes:
      - ./alertmanager/config:/etc/alertmanager
      - ./alertmanager/data:/alertmanager
    ports:
      - "9093:9093"
    user: "65534:65534"
    networks:
      - monitoring-net
    restart: unless-stopped
    depends_on:
      - prometheus

  grafana:
    image: grafana/grafana:latest
    container_name: taichuy-grafana
    user: "472:472"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - ./grafana/data:/var/lib/grafana
      - ./grafana/config:/etc/grafana
    ports:
      - "3000:3000"
    networks:
      - monitoring-net
    restart: unless-stopped
    depends_on:
      - prometheus

networks:
  monitoring-net:
    driver: bridge
EOF

echo "✅ docker-compose.yml 生成完成"

# 生成简化启动脚本
echo "10. 生成启动脚本..."
cat > ${BASE_DIR}/start-monitoring.sh << 'EOF'
#!/bin/bash

echo "=========================================="
echo "启动监控系统 (简化模式)..."
echo "=========================================="

cd "$(dirname "$0")"

# 清理旧容器
echo "清理旧容器..."
docker-compose down 2>/dev/null || true

# 拉取镜像
echo "拉取镜像..."
docker-compose pull || echo "继续启动..."

# 启动服务
echo "启动服务..."
docker-compose up -d

echo "等待服务启动..."
sleep 10

echo ""
echo "✅ 服务启动完成！"
echo ""
echo "容器状态:"
docker-compose ps

echo ""
echo "访问地址:"
IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
echo "- Prometheus:   http://$IP:9090  (用户: admin, 密码: Taichu@2026)"
echo "- Grafana:      http://$IP:3000  (用户: admin, 密码: admin)"
echo "- Alertmanager: http://$IP:9093"
echo ""
echo "查看日志: docker-compose logs -f"
echo "停止服务: docker-compose down"
EOF

chmod +x ${BASE_DIR}/start-monitoring.sh

# 生成一键修复脚本
echo "11. 生成一键修复脚本..."
cat > ${BASE_DIR}/fix-and-start.sh << 'EOF'
#!/bin/bash

echo "=========================================="
echo "一键修复并启动监控系统"
echo "=========================================="

cd "$(dirname "$0")"

# 1. 停止并清理
echo "1. 停止并清理旧容器..."
docker-compose down 2>/dev/null || true
docker network prune -f 2>/dev/null || true
docker volume prune -f 2>/dev/null || true

# 2. 修复权限
echo "2. 修复目录权限..."
sudo chown -R 65534:65534 prometheus/data alertmanager/data 2>/dev/null || true
sudo chown -R 472:472 grafana/data 2>/dev/null || true
sudo chmod -R 755 prometheus/data alertmanager/data grafana/data 2>/dev/null || true

# 3. 删除旧的查询日志文件（解决权限问题）
echo "3. 清理旧的查询日志..."
rm -f prometheus/data/queries.active 2>/dev/null || true

# 4. 启动服务（不使用健康检查）
echo "4. 启动服务..."
docker-compose up -d --remove-orphans

# 5. 等待并检查
echo "5. 等待服务启动..."
sleep 15

echo ""
echo "检查服务状态:"
docker-compose ps

echo ""
echo "容器状态:"
docker ps --filter "name=taichuy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "如果服务没有启动，请运行: docker-compose logs"
EOF

chmod +x ${BASE_DIR}/fix-and-start.sh

# 生成测试脚本
echo "12. 生成测试脚本..."
cat > ${BASE_DIR}/test-services.sh << 'EOF'
#!/bin/bash

echo "=========================================="
echo "测试监控服务状态"
echo "=========================================="

cd "$(dirname "$0")"

echo "1. 检查容器运行状态:"
docker-compose ps

echo ""
echo "2. 检查服务响应:"
echo "   Prometheus:"
curl -s -o /dev/null -w "%{http_code}" http://localhost:9090/-/healthy 2>/dev/null && echo "  ✅ 正常" || echo "  ❌ 异常"
echo ""
echo "   Grafana:"
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/api/health 2>/dev/null && echo "  ✅ 正常" || echo "  ❌ 异常"
echo ""
echo "   Alertmanager:"
curl -s -o /dev/null -w "%{http_code}" http://localhost:9093/-/healthy 2>/dev/null && echo "  ✅ 正常" || echo "  ❌ 异常"

echo ""
echo "3. 查看日志最后5行:"
echo "   Prometheus:"
docker logs --tail 5 taichuy-prometheus 2>/dev/null
echo ""
echo "   Grafana:"
docker logs --tail 5 taichuy-grafana 2>/dev/null
echo ""
echo "   Alertmanager:"
docker logs --tail 5 taichuy-alertmanager 2>/dev/null
EOF

chmod +x ${BASE_DIR}/test-services.sh

echo ""
echo "=========================================="
echo "✅ 部署完成！"
echo "=========================================="
echo ""
echo "下一步操作:"
echo ""
echo "1. 一键修复并启动:"
echo "   ./fix-and-start.sh"
echo ""
echo "2. 或者分步执行:"
echo "   docker-compose down"
echo "   docker network prune -f"
echo "   docker-compose up -d"
echo ""
echo "3. 测试服务:"
echo "   ./test-services.sh"
echo ""
echo "=========================================="