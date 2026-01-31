#!/bin/bash

################################################################################
# Claude Relay Service - 一键部署脚本
# 支持: Ubuntu/Debian, CentOS/RHEL
# 功能: 自动安装依赖、配置环境、构建服务
################################################################################

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检测操作系统
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif type lsb_release >/dev/null 2>&1; then
        OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
        OS_VERSION=$(lsb_release -sr)
    else
        log_error "无法检测操作系统类型"
        exit 1
    fi

    log_info "检测到操作系统: $OS $OS_VERSION"
}

# 检查是否以root运行
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 用户或 sudo 运行此脚本"
        exit 1
    fi
}

# 安装Node.js
install_nodejs() {
    log_info "检查 Node.js 版本..."

    if command -v node >/dev/null 2>&1; then
        NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 18 ]; then
            log_success "Node.js 已安装 (版本: $(node -v))"
            return 0
        else
            log_warning "Node.js 版本过低 (当前: $(node -v)), 需要升级到 18+"
        fi
    fi

    log_info "开始安装 Node.js 18..."

    case "$OS" in
        ubuntu|debian)
            curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
            apt-get install -y nodejs
            ;;
        centos|rhel|rocky|almalinux)
            curl -fsSL https://rpm.nodesource.com/setup_18.x | bash -
            yum install -y nodejs
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    log_success "Node.js 安装完成 (版本: $(node -v))"
}

# 安装Redis
install_redis() {
    log_info "检查 Redis..."

    if command -v redis-server >/dev/null 2>&1; then
        log_success "Redis 已安装"
        return 0
    fi

    log_info "开始安装 Redis..."

    case "$OS" in
        ubuntu|debian)
            apt-get update
            apt-get install -y redis-server
            systemctl enable redis-server
            systemctl start redis-server
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y epel-release
            yum install -y redis
            systemctl enable redis
            systemctl start redis
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    log_success "Redis 安装并启动完成"
}

# 安装PM2
install_pm2() {
    log_info "检查 PM2..."

    if command -v pm2 >/dev/null 2>&1; then
        log_success "PM2 已安装"
        return 0
    fi

    log_info "开始安装 PM2..."
    npm install -g pm2
    pm2 startup systemd -u root --hp /root

    log_success "PM2 安装完成"
}

# 安装Git
install_git() {
    log_info "检查 Git..."

    if command -v git >/dev/null 2>&1; then
        log_success "Git 已安装"
        return 0
    fi

    log_info "开始安装 Git..."

    case "$OS" in
        ubuntu|debian)
            apt-get install -y git
            ;;
        centos|rhel|rocky|almalinux)
            yum install -y git
            ;;
        *)
            log_error "不支持的操作系统: $OS"
            exit 1
            ;;
    esac

    log_success "Git 安装完成"
}

# 克隆代码仓库
clone_repository() {
    log_info "请输入您的 Git 仓库地址 (默认: https://github.com/Wei-Shaw/claude-relay-service.git):"
    read -r GIT_REPO
    GIT_REPO=${GIT_REPO:-"https://github.com/Wei-Shaw/claude-relay-service.git"}

    log_info "请输入安装目录 (默认: /opt/claude-relay-service):"
    read -r INSTALL_DIR
    INSTALL_DIR=${INSTALL_DIR:-"/opt/claude-relay-service"}

    if [ -d "$INSTALL_DIR" ]; then
        log_warning "目录 $INSTALL_DIR 已存在"
        log_info "是否删除并重新克隆? (y/n)"
        read -r CONFIRM
        if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
            rm -rf "$INSTALL_DIR"
        else
            log_error "安装取消"
            exit 1
        fi
    fi

    log_info "克隆代码到 $INSTALL_DIR ..."
    git clone "$GIT_REPO" "$INSTALL_DIR"
    cd "$INSTALL_DIR"

    log_success "代码克隆完成"
}

# 生成随机密钥
generate_secret() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# 配置环境变量
configure_env() {
    log_info "配置环境变量..."

    if [ -f .env ]; then
        log_warning ".env 文件已存在,是否保留现有配置? (y/n)"
        read -r KEEP_ENV
        if [ "$KEEP_ENV" = "y" ] || [ "$KEEP_ENV" = "Y" ]; then
            log_success "保留现有 .env 配置"
            return 0
        fi
    fi

    cp .env.example .env

    # 生成随机密钥
    JWT_SECRET=$(generate_secret)
    ENCRYPTION_KEY=$(generate_secret)

    # 替换密钥
    sed -i "s/your-super-secret-jwt-key-change-this/${JWT_SECRET}/" .env
    sed -i "s/32-char-encryption-key-change/${ENCRYPTION_KEY}/" .env

    # 配置Redis
    log_info "Redis 配置:"
    log_info "  Redis 地址 (默认: localhost):"
    read -r REDIS_HOST
    REDIS_HOST=${REDIS_HOST:-"localhost"}

    log_info "  Redis 端口 (默认: 6379):"
    read -r REDIS_PORT
    REDIS_PORT=${REDIS_PORT:-"6379"}

    log_info "  Redis 密码 (默认: 无密码,直接回车跳过):"
    read -r REDIS_PASSWORD

    sed -i "s/REDIS_HOST=localhost/REDIS_HOST=${REDIS_HOST}/" .env
    sed -i "s/REDIS_PORT=6379/REDIS_PORT=${REDIS_PORT}/" .env
    if [ -n "$REDIS_PASSWORD" ]; then
        sed -i "s/REDIS_PASSWORD=/REDIS_PASSWORD=${REDIS_PASSWORD}/" .env
    fi

    # 配置端口
    log_info "  服务端口 (默认: 3000):"
    read -r SERVICE_PORT
    SERVICE_PORT=${SERVICE_PORT:-"3000"}

    # 更新config.js中的端口
    if [ -f config/config.example.js ]; then
        cp config/config.example.js config/config.js
        sed -i "s/port: 3000/port: ${SERVICE_PORT}/" config/config.js
    fi

    log_success "环境变量配置完成"
    log_info "  JWT_SECRET: ${JWT_SECRET}"
    log_info "  ENCRYPTION_KEY: ${ENCRYPTION_KEY}"
    log_warning "请妥善保管这些密钥,丢失后将无法解密现有数据!"
}

# 安装依赖
install_dependencies() {
    log_info "安装后端依赖..."
    npm install

    log_info "安装前端依赖..."
    npm run install:web

    log_success "依赖安装完成"
}

# 构建前端
build_frontend() {
    log_info "构建前端..."
    npm run build:web
    log_success "前端构建完成"
}

# 初始化服务
initialize_service() {
    log_info "初始化服务..."
    npm run setup
    log_success "服务初始化完成"
}

# 启动服务
start_service() {
    log_info "启动服务..."
    npm run service:start:daemon

    # 等待服务启动
    sleep 3

    # 检查服务状态
    if npm run service:status | grep -q "running"; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败,请检查日志"
        return 1
    fi
}

# 显示访问信息
show_access_info() {
    SERVICE_PORT=${SERVICE_PORT:-"3000"}
    SERVER_IP=$(hostname -I | awk '{print $1}')

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "🎉 Claude Relay Service 部署完成!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "📍 访问地址:"
    echo "  - 本地访问: http://localhost:${SERVICE_PORT}/admin-next/login"
    echo "  - 外网访问: http://${SERVER_IP}:${SERVICE_PORT}/admin-next/login"
    echo ""
    log_info "🔑 管理员凭据:"
    echo "  - 查看方式: cat ${INSTALL_DIR}/data/init.json"
    echo ""
    log_info "📊 服务管理命令:"
    echo "  - 查看状态: npm run service:status"
    echo "  - 查看日志: npm run service:logs"
    echo "  - 重启服务: npm run service:restart:daemon"
    echo "  - 停止服务: npm run service:stop"
    echo ""
    log_info "🔄 更新服务:"
    echo "  - 使用更新脚本: cd ${INSTALL_DIR} && bash update.sh"
    echo ""
    log_warning "⚠️  重要提示:"
    echo "  1. 请妥善保管 .env 文件中的密钥"
    echo "  2. 建议配置防火墙,仅开放必要端口"
    echo "  3. 生产环境建议使用 Nginx/Caddy 反向代理"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 主流程
main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Claude Relay Service - 一键部署脚本"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    check_root
    detect_os

    log_info "开始安装依赖..."
    install_git
    install_nodejs
    install_redis
    install_pm2

    clone_repository
    configure_env
    install_dependencies
    build_frontend
    initialize_service
    start_service
    show_access_info

    log_success "部署完成! 🎉"
}

# 运行主流程
main
