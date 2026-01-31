#!/bin/bash

################################################################################
# Claude Relay Service - 服务更新脚本
# 功能: 拉取最新代码、保留配置、重新构建、重启服务
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

# 获取脚本所在目录
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 备份目录
BACKUP_DIR="${SCRIPT_DIR}/backup_$(date +%Y%m%d_%H%M%S)"

# 显示欢迎信息
show_welcome() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Claude Relay Service - 服务更新脚本"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 检查Git仓库
check_git_repo() {
    if [ ! -d .git ]; then
        log_error "当前目录不是Git仓库"
        log_info "请在项目根目录运行此脚本"
        exit 1
    fi
    log_success "Git仓库检查通过"
}

# 备份配置文件
backup_configs() {
    log_info "备份配置文件..."

    mkdir -p "$BACKUP_DIR"

    # 备份重要文件
    if [ -f .env ]; then
        cp .env "$BACKUP_DIR/.env"
        log_success "已备份: .env"
    fi

    if [ -f config/config.js ]; then
        cp config/config.js "$BACKUP_DIR/config.js"
        log_success "已备份: config/config.js"
    fi

    if [ -d data ]; then
        cp -r data "$BACKUP_DIR/data"
        log_success "已备份: data 目录"
    fi

    log_success "配置文件备份完成: $BACKUP_DIR"
}

# 检查未提交的更改
check_uncommitted_changes() {
    if ! git diff-index --quiet HEAD --; then
        log_warning "检测到未提交的本地更改"
        log_info "是否继续更新? (y/n)"
        read -r CONFIRM
        if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
            log_error "更新取消"
            exit 1
        fi
    fi
}

# 拉取最新代码
pull_latest_code() {
    log_info "拉取最新代码..."

    # 保存当前分支
    CURRENT_BRANCH=$(git branch --show-current)
    log_info "当前分支: $CURRENT_BRANCH"

    # 拉取代码
    git fetch origin

    # 处理package-lock.json冲突
    if git diff origin/$CURRENT_BRANCH --name-only | grep -q "package-lock.json"; then
        log_warning "检测到 package-lock.json 可能冲突"
        git checkout --theirs package-lock.json 2>/dev/null || true
    fi

    # 拉取并合并
    if git pull origin "$CURRENT_BRANCH"; then
        log_success "代码更新成功"
    else
        log_error "代码拉取失败,请手动解决冲突"
        log_info "备份文件位于: $BACKUP_DIR"
        exit 1
    fi
}

# 恢复配置文件
restore_configs() {
    log_info "恢复配置文件..."

    # 恢复.env文件
    if [ -f "$BACKUP_DIR/.env" ]; then
        # 比对差异
        if [ -f .env ] && ! diff -q .env "$BACKUP_DIR/.env" >/dev/null; then
            log_warning ".env 文件有变化"
            log_info "是否使用备份的配置? (y/n)"
            read -r USE_BACKUP
            if [ "$USE_BACKUP" = "y" ] || [ "$USE_BACKUP" = "Y" ]; then
                cp "$BACKUP_DIR/.env" .env
                log_success "已恢复: .env"
            else
                log_warning "保留新的 .env 文件,请手动检查配置"
                log_info "  备份文件: $BACKUP_DIR/.env"
                log_info "  当前文件: .env"
            fi
        else
            cp "$BACKUP_DIR/.env" .env
            log_success "已恢复: .env"
        fi
    fi

    # 恢复config.js
    if [ -f "$BACKUP_DIR/config.js" ]; then
        if [ -f config/config.js ] && ! diff -q config/config.js "$BACKUP_DIR/config.js" >/dev/null; then
            log_warning "config/config.js 文件有变化"
            log_info "是否使用备份的配置? (y/n)"
            read -r USE_BACKUP
            if [ "$USE_BACKUP" = "y" ] || [ "$USE_BACKUP" = "Y" ]; then
                cp "$BACKUP_DIR/config.js" config/config.js
                log_success "已恢复: config/config.js"
            else
                log_warning "保留新的 config.js 文件,请手动检查配置"
                log_info "  备份文件: $BACKUP_DIR/config.js"
                log_info "  当前文件: config/config.js"
            fi
        else
            cp "$BACKUP_DIR/config.js" config/config.js
            log_success "已恢复: config/config.js"
        fi
    fi

    log_success "配置文件恢复完成"
}

# 检查关键配置
verify_configs() {
    log_info "验证配置文件..."

    # 检查.env
    if [ ! -f .env ]; then
        log_error ".env 文件不存在"
        exit 1
    fi

    # 检查关键变量
    if ! grep -q "JWT_SECRET" .env || ! grep -q "ENCRYPTION_KEY" .env; then
        log_error ".env 文件缺少关键配置"
        log_info "请检查 JWT_SECRET 和 ENCRYPTION_KEY 是否存在"
        exit 1
    fi

    # 检查密钥长度
    ENCRYPTION_KEY=$(grep "^ENCRYPTION_KEY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    if [ ${#ENCRYPTION_KEY} -ne 32 ]; then
        log_warning "ENCRYPTION_KEY 长度不是32位,可能导致加密问题"
        log_info "当前长度: ${#ENCRYPTION_KEY}"
    fi

    log_success "配置验证通过"
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

# 重启服务
restart_service() {
    log_info "重启服务..."

    # 检查服务是否运行
    if npm run service:status | grep -q "running"; then
        npm run service:restart:daemon
        log_success "服务重启成功"
    else
        log_warning "服务未运行,尝试启动..."
        npm run service:start:daemon
        log_success "服务启动成功"
    fi

    # 等待服务启动
    sleep 3

    # 验证服务状态
    if npm run service:status | grep -q "running"; then
        log_success "服务运行正常"
    else
        log_error "服务启动失败,请检查日志"
        log_info "查看日志: npm run service:logs"
        return 1
    fi
}

# 显示更新摘要
show_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "🎉 服务更新完成!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "📊 更新摘要:"
    echo "  - 代码已更新到最新版本"
    echo "  - 配置文件已保留"
    echo "  - 服务已重启"
    echo ""
    log_info "📁 备份文件位置:"
    echo "  - $BACKUP_DIR"
    echo ""
    log_info "🔍 验证更新:"
    echo "  - 查看服务状态: npm run service:status"
    echo "  - 查看运行日志: npm run service:logs"
    echo "  - 访问管理界面确认功能正常"
    echo ""
    log_warning "⚠️  如遇问题:"
    echo "  1. 检查日志文件: logs/ 目录"
    echo "  2. 恢复备份: cp -r $BACKUP_DIR/.env .env"
    echo "  3. 重启服务: npm run service:restart:daemon"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 清理旧备份
cleanup_old_backups() {
    log_info "清理旧备份文件..."

    # 保留最近5个备份
    BACKUP_COUNT=$(find . -maxdepth 1 -name "backup_*" -type d | wc -l)
    if [ "$BACKUP_COUNT" -gt 5 ]; then
        log_info "发现 $BACKUP_COUNT 个备份,保留最近5个..."
        find . -maxdepth 1 -name "backup_*" -type d | sort -r | tail -n +6 | xargs rm -rf
        log_success "旧备份已清理"
    fi
}

# 主流程
main() {
    show_welcome

    check_git_repo
    backup_configs
    check_uncommitted_changes
    pull_latest_code
    restore_configs
    verify_configs
    install_dependencies
    build_frontend
    restart_service
    cleanup_old_backups
    show_summary

    log_success "更新完成! 🎉"
}

# 运行主流程
main
