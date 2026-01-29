# Prometheus 监控系统部署脚本

本项目提供了一套简便的脚本，用于快速部署 Prometheus + Grafana + Alertmanager 监控系统，以及在 Ubuntu 客户端节点上安装 Node Exporter。

## 目录结构

- `setup-monitoring.sh`: 服务端一键部署脚本（Docker Compose）
- `generate-prometheus-password.sh`: Prometheus Basic Auth 密码生成工具
- `node_exporter/`: 客户端安装相关文件
  - `install_node_exporter.sh`: Node Exporter 安装脚本（仅支持 Ubuntu）
  - `uninstall_node_exporter.sh`: 卸载脚本（安装后生成）
  - `manage_node_exporter.sh`: 服务管理脚本（安装后生成）

## 🚀 服务端部署 (监控中心)

### 前置要求
- Docker
- Docker Compose

### 在线部署 (联网环境)

1. 运行部署脚本：
   ```bash
   ./setup-monitoring.sh
   ```

2. 脚本会自动完成以下工作：
   - 清理旧容器
   - 创建必要的目录结构并设置权限
   - 生成配置文件 (Prometheus, Grafana, Alertmanager)
   - 启动 Docker 容器

3. 访问服务：
   - **Grafana**: `http://<服务器IP>:3000` (默认账号: `admin` / `admin`)
   - **Prometheus**: `http://<服务器IP>:9090` (默认账号: `admin` / `Taichu@2026`)
   - **Alertmanager**: `http://<服务器IP>:9093`

### 离线部署 (无网环境)

如果服务器无法访问互联网，请按照以下步骤进行离线部署：

#### 1. 准备镜像 (在有网机器上操作)

进入 `images` 目录，运行保存镜像脚本：

- **Windows**: 双击运行 `images/save-images.bat`
- **Linux**: 运行 `bash images/save-images.sh`

脚本会自动拉取所需的 Docker 镜像并保存到 `images` 目录下（生成 .tar 文件）。

#### 2. 上传文件

将整个项目文件夹（包含 `images` 目录下的 .tar 文件）上传到离线服务器。

#### 3. 执行离线安装

进入 `images` 目录，运行离线安装脚本：

- **Linux**:
  ```bash
  cd images
  sh offline-install.sh
  ```
- **Windows**: 双击运行 `images/offline-install.bat`

该脚本会自动加载本地镜像，然后调用上级目录的主安装脚本 `setup-monitoring.sh` 完成部署。

### 修改 Prometheus 密码

默认的 Prometheus Basic Auth 密码为 `Taichu@2026`。如需修改：

1. 运行密码生成脚本：
   ```bash
   ./generate-prometheus-password.sh
   ```
2. 按照提示输入新密码，脚本会生成对应的哈希值。
3. 将生成的哈希值替换到 `prometheus/config/web-config.yml` 文件中。
4. 重启 Prometheus：
   ```bash
   docker-compose restart prometheus
   ```

---

## 💻 客户端部署 (被监控节点)

目前客户端安装脚本 **仅支持 Ubuntu** 系统。

### 安装步骤

1. **下载 Node Exporter**
   
   请前往官方发布页下载 `v1.10.2` 版本的安装包（或其他兼容版本）：
   🔗 [Node Exporter v1.10.2 Releases](https://github.com/prometheus/node_exporter/releases/tag/v1.10.2)
   
   下载对应的 Linux 版本（通常是 `node_exporter-1.10.2.linux-amd64.tar.gz`）。

2. **准备安装文件**
   
   将下载好的 `.tar.gz` 压缩包放置到本项目的 `node_exporter/` 目录下。该目录下应该包含 `install_node_exporter.sh` 和你下载的压缩包。

   ```text
   node_exporter/
   ├── install_node_exporter.sh
   └── node_exporter-1.10.2.linux-amd64.tar.gz
   ```

3. **执行安装**
   
   将 `node_exporter` 目录上传到目标服务器，进入目录并运行：
   ```bash
   cd node_exporter
   chmod +x install_node_exporter.sh
   sudo ./install_node_exporter.sh
   ```

4. **验证安装**
   
   安装完成后，脚本会输出服务状态。你可以通过以下命令检查：
   ```bash
   systemctl status node_exporter
   # 或者访问 metrics 接口
   curl http://localhost:9100/metrics | head
   ```

### 接入 Prometheus

在服务端修改 `prometheus/config/prometheus.yml`，在 `scrape_configs` 下添加新的 `job` 或在现有 `job` 中添加 `targets`：

```yaml
  - job_name: 'node_exporter'
    static_configs:
      - targets: ['<客户端IP>:9100']
        labels:
          instance: '<节点名称>'
```

修改后重启 Prometheus 生效。

---

## 📊 Grafana 看板

本项目使用的 Node Exporter 看板基于社区优秀模板进行修改。

- **源看板地址**: [Node Exporter Dashboard 20240520 通用JOB分组版 (ID: 16098)](https://grafana.com/grafana/dashboards/16098-node-exporter-dashboard-20240520-job/)
- **说明**: 该看板提供了丰富的系统资源监控图表，包括 CPU、内存、磁盘、网络等指标的详细展示。

---

## 🛠️ 常用维护命令

**服务端:**
- 查看日志: `docker-compose logs -f`
- 停止服务: `docker-compose down`
- 重启服务: `docker-compose restart`

**客户端 (Node Exporter):**
- 启动/停止/重启: `systemctl start/stop/restart node_exporter`
- 查看日志: `journalctl -u node_exporter -f`
