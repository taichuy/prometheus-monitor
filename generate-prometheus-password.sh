#!/bin/bash

# generate-prometheus-password.sh

echo "生成 Prometheus Basic Auth 密码"
echo "================================"

read -sp "请输入密码: " PASSWORD
echo
read -sp "请确认密码: " PASSWORD_CONFIRM
echo

if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
    echo "错误: 两次输入的密码不匹配"
    exit 1
fi

echo "正在生成哈希..."

# 尝试使用 Python 生成 bcrypt 哈希
if command -v python3 &> /dev/null && python3 -c "import bcrypt" 2>/dev/null; then
    HASH=$(python3 -c "
import bcrypt
import sys
password = sys.argv[1]
hashed = bcrypt.hashpw(password.encode('utf-8'), bcrypt.gensalt())
print(hashed.decode('utf-8'))
" "$PASSWORD")
    
    echo "✅ 使用 Python bcrypt 生成成功"
elif command -v docker &> /dev/null; then
    # 使用 Docker 容器生成
    HASH=$(docker run --rm prom/prometheus:latest htpasswd -nB admin <<< "$PASSWORD" | cut -d: -f2)
    
    # 转义 $ 符号
    HASH=$(echo "$HASH" | sed 's/\$/\$\$/g')
    echo "✅ 使用 Docker 容器生成成功"
else
    # 使用 openssl 生成 apr1 哈希
    HASH=$(openssl passwd -apr1 "$PASSWORD" | sed 's/\$/\$\$/g')
    echo "⚠️  使用 openssl 生成（可能不兼容最新版 Prometheus）"
fi

echo ""
echo "生成的哈希值:"
echo "$HASH"
echo ""
echo "请更新 web-config.yml 文件:"
echo "=========================="
echo "basic_auth_users:"
echo "  admin: $HASH"
echo ""
echo "然后重启 Prometheus:"
echo "docker-compose restart prometheus"