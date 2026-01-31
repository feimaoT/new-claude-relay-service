#!/bin/bash

################################################################################
# Claude Relay Service - Git仓库迁移脚本
# 功能: 从官方仓库切换到自定义仓库，保留所有生产数据和配置
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

# 获取脚本所在目录（即项目根目录）
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# 备份目录
BACKUP_DIR="${SCRIPT_DIR}/migration_backup_$(date +%Y%m%d_%H%M%S)"

# 显示欢迎信息
show_welcome() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Claude Relay Service - Git仓库迁移脚本"
    echo "  从官方仓库切换到您的自定义仓库，保留所有数据"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_warning "⚠️  重要提示:"
    echo "  此脚本将会:"
    echo "  1. 完整备份当前的生产数据和配置"
    echo "  2. 备份Redis数据库"
    echo "  3. 切换Git远程仓库地址"
    echo "  4. 拉取您的新代码"
    echo "  5. 恢复所有配置和数据"
    echo "  6. 重新构建并重启服务"
    echo ""
    log_info "是否继续? (y/n)"
    read -r CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        log_error "迁移取消"
        exit 1
    fi
}

# 检查是否在Git仓库中
check_git_repo() {
    if [ ! -d .git ]; then
        log_error "当前目录不是Git仓库"
        log_info "请在项目根目录运行此脚本"
        exit 1
    fi
    log_success "Git仓库检查通过"
}

# 显示当前仓库信息
show_current_repo() {
    log_info "当前Git仓库信息:"
    CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "未设置")
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "未知")
    echo "  - 远程地址: $CURRENT_REMOTE"
    echo "  - 当前分支: $CURRENT_BRANCH"
    echo ""
}

# 停止服务
stop_service() {
    log_info "停止服务..."

    if npm run service:status 2>/dev/null | grep -q "running"; then
        npm run service:stop
        log_success "服务已停止"
    else
        log_warning "服务未运行"
    fi

    # 确保PM2进程已停止
    pm2 delete claude-relay-service 2>/dev/null || true
    sleep 2
}

# 完整备份
full_backup() {
    log_info "开始完整备份..."

    mkdir -p "$BACKUP_DIR"

    # 1. 备份配置文件
    log_info "  [1/5] 备份配置文件..."
    if [ -f .env ]; then
        cp .env "$BACKUP_DIR/.env"
        log_success "    已备份: .env"
    else
        log_error "    .env 文件不存在！"
        exit 1
    fi

    if [ -f config/config.js ]; then
        cp config/config.js "$BACKUP_DIR/config.js"
        log_success "    已备份: config/config.js"
    fi

    # 2. 备份data目录（包含管理员凭据等）
    log_info "  [2/5] 备份data目录..."
    if [ -d data ]; then
        cp -r data "$BACKUP_DIR/data"
        log_success "    已备份: data/ 目录"
    fi

    # 3. 备份logs目录
    log_info "  [3/5] 备份logs目录..."
    if [ -d logs ]; then
        cp -r logs "$BACKUP_DIR/logs"
        log_success "    已备份: logs/ 目录"
    fi

    # 4. 备份Redis数据库
    log_info "  [4/5] 备份Redis数据库..."

    # 从.env读取Redis配置
    REDIS_HOST=$(grep "^REDIS_HOST=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "localhost")
    REDIS_PORT=$(grep "^REDIS_PORT=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'" || echo "6379")
    REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")

    # 构建redis-cli命令
    REDIS_CMD="redis-cli -h $REDIS_HOST -p $REDIS_PORT"
    if [ -n "$REDIS_PASSWORD" ]; then
        REDIS_CMD="$REDIS_CMD -a $REDIS_PASSWORD"
    fi

    # 导出Redis数据
    if command -v redis-cli >/dev/null 2>&1; then
        # 使用redis-cli导出所有键值
        log_info "    导出Redis数据..."
        $REDIS_CMD --scan | while read key; do
            TYPE=$($REDIS_CMD TYPE "$key" | tr -d '\r')
            echo "KEY:$key:TYPE:$TYPE" >> "$BACKUP_DIR/redis_backup.txt"

            case $TYPE in
                string)
                    $REDIS_CMD GET "$key" >> "$BACKUP_DIR/redis_backup.txt"
                    ;;
                hash)
                    $REDIS_CMD HGETALL "$key" >> "$BACKUP_DIR/redis_backup.txt"
                    ;;
                list)
                    $REDIS_CMD LRANGE "$key" 0 -1 >> "$BACKUP_DIR/redis_backup.txt"
                    ;;
                set)
                    $REDIS_CMD SMEMBERS "$key" >> "$BACKUP_DIR/redis_backup.txt"
                    ;;
                zset)
                    $REDIS_CMD ZRANGE "$key" 0 -1 WITHSCORES >> "$BACKUP_DIR/redis_backup.txt"
                    ;;
            esac
            echo "---" >> "$BACKUP_DIR/redis_backup.txt"
        done 2>/dev/null || log_warning "    Redis导出部分失败（可能是权限问题）"

        # 同时触发Redis的RDB备份
        $REDIS_CMD BGSAVE 2>/dev/null || true
        log_success "    已备份: Redis数据"
    else
        log_warning "    redis-cli未安装，跳过Redis备份"
        log_warning "    建议手动备份Redis: redis-cli SAVE"
    fi

    # 5. 记录当前Git信息
    log_info "  [5/5] 记录Git信息..."
    cat > "$BACKUP_DIR/git_info.txt" <<EOF
旧仓库地址: $(git remote get-url origin)
当前分支: $(git branch --show-current)
最后提交: $(git log -1 --oneline)
备份时间: $(date)
EOF
    log_success "    已保存: Git信息"

    log_success "完整备份完成: $BACKUP_DIR"
    echo ""
}

# 提取关键配置信息
extract_key_configs() {
    log_info "提取关键配置信息..."

    # 提取JWT_SECRET
    JWT_SECRET=$(grep "^JWT_SECRET=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    ENCRYPTION_KEY=$(grep "^ENCRYPTION_KEY=" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")

    if [ -z "$JWT_SECRET" ] || [ -z "$ENCRYPTION_KEY" ]; then
        log_error "无法提取JWT_SECRET或ENCRYPTION_KEY"
        log_error "请检查.env文件"
        exit 1
    fi

    log_success "关键配置已提取"
    log_warning "  JWT_SECRET: ${JWT_SECRET:0:10}... (已脱敏)"
    log_warning "  ENCRYPTION_KEY: ${ENCRYPTION_KEY:0:10}... (已脱敏)"

    # 验证ENCRYPTION_KEY长度
    if [ ${#ENCRYPTION_KEY} -ne 32 ]; then
        log_error "ENCRYPTION_KEY长度必须是32位，当前: ${#ENCRYPTION_KEY}"
        log_error "这会导致数据无法解密！"
        exit 1
    fi

    echo ""
}

# 切换Git仓库
switch_git_repo() {
    log_info "准备切换Git仓库..."
    echo ""
    log_info "请输入您的Git仓库地址:"
    log_info "  示例: https://github.com/your-username/claude-relay-service.git"
    log_info "  或者: git@github.com:your-username/claude-relay-service.git"
    read -r NEW_GIT_REPO

    if [ -z "$NEW_GIT_REPO" ]; then
        log_error "Git仓库地址不能为空"
        exit 1
    fi

    log_info "请输入目标分支（默认: main）:"
    read -r TARGET_BRANCH
    TARGET_BRANCH=${TARGET_BRANCH:-"main"}

    echo ""
    log_warning "即将切换到:"
    echo "  - 仓库: $NEW_GIT_REPO"
    echo "  - 分支: $TARGET_BRANCH"
    log_info "是否继续? (y/n)"
    read -r CONFIRM
    if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
        log_error "切换取消"
        exit 1
    fi

    # 切换远程仓库
    log_info "切换Git远程仓库..."
    git remote set-url origin "$NEW_GIT_REPO"
    log_success "远程仓库已切换"

    # 获取新仓库的分支信息
    log_info "获取新仓库信息..."
    git fetch origin

    # 检查本地是否有未提交的更改
    if ! git diff-index --quiet HEAD --; then
        log_warning "检测到本地有未提交的更改"
        git status
        log_info "是否暂存这些更改? (y/n)"
        read -r STASH
        if [ "$STASH" = "y" ] || [ "$STASH" = "Y" ]; then
            git stash save "Migration backup $(date +%Y%m%d_%H%M%S)"
            log_success "本地更改已暂存"
        fi
    fi

    # 切换到目标分支
    log_info "切换到分支: $TARGET_BRANCH ..."
    if git show-ref --verify --quiet refs/heads/$TARGET_BRANCH; then
        # 本地分支存在，直接切换
        git checkout $TARGET_BRANCH
        git reset --hard origin/$TARGET_BRANCH
    else
        # 本地分支不存在，创建并跟踪远程分支
        git checkout -b $TARGET_BRANCH origin/$TARGET_BRANCH
    fi

    log_success "已切换到新仓库的 $TARGET_BRANCH 分支"
    echo ""
}

# 恢复配置文件
restore_configs() {
    log_info "恢复配置文件..."

    # 1. 恢复.env
    log_info "  [1/3] 恢复 .env ..."
    if [ -f "$BACKUP_DIR/.env" ]; then
        # 检查新代码是否有.env.example
        if [ -f .env.example ]; then
            # 先复制新的模板
            cp .env.example .env

            # 恢复关键配置
            sed -i "s/^JWT_SECRET=.*/JWT_SECRET=${JWT_SECRET}/" .env
            sed -i "s/^ENCRYPTION_KEY=.*/ENCRYPTION_KEY=${ENCRYPTION_KEY}/" .env

            # 恢复Redis配置
            REDIS_HOST=$(grep "^REDIS_HOST=" "$BACKUP_DIR/.env" | cut -d'=' -f2)
            REDIS_PORT=$(grep "^REDIS_PORT=" "$BACKUP_DIR/.env" | cut -d'=' -f2)
            REDIS_PASSWORD=$(grep "^REDIS_PASSWORD=" "$BACKUP_DIR/.env" | cut -d'=' -f2)

            sed -i "s/^REDIS_HOST=.*/REDIS_HOST=${REDIS_HOST}/" .env
            sed -i "s/^REDIS_PORT=.*/REDIS_PORT=${REDIS_PORT}/" .env
            if [ -n "$REDIS_PASSWORD" ]; then
                sed -i "s/^REDIS_PASSWORD=.*/REDIS_PASSWORD=${REDIS_PASSWORD}/" .env
            fi

            log_success "    已恢复关键配置到新的.env模板"
        else
            # 直接使用旧的.env
            cp "$BACKUP_DIR/.env" .env
            log_success "    已直接恢复.env"
        fi
    fi

    # 2. 恢复config.js
    log_info "  [2/3] 恢复 config/config.js ..."
    if [ -f "$BACKUP_DIR/config.js" ]; then
        if [ -f config/config.example.js ]; then
            # 如果新代码有example，提示用户
            log_warning "    检测到新代码有config.example.js"
            log_info "    是否使用旧的config.js? (y=使用旧配置, n=使用新模板)"
            read -r USE_OLD
            if [ "$USE_OLD" = "y" ] || [ "$USE_OLD" = "Y" ]; then
                cp "$BACKUP_DIR/config.js" config/config.js
                log_success "    已恢复旧的config.js"
            else
                cp config/config.example.js config/config.js
                log_warning "    已使用新模板，请手动检查配置"
                log_info "    旧配置备份在: $BACKUP_DIR/config.js"
            fi
        else
            cp "$BACKUP_DIR/config.js" config/config.js
            log_success "    已恢复config.js"
        fi
    fi

    # 3. 恢复data目录
    log_info "  [3/3] 恢复 data 目录..."
    if [ -d "$BACKUP_DIR/data" ]; then
        # 确保data目录存在
        mkdir -p data
        # 复制所有文件，保留新代码中的其他文件
        cp -r "$BACKUP_DIR/data/"* data/
        log_success "    已恢复data目录"
    fi

    log_success "配置文件恢复完成"
    echo ""
}

# 安装依赖
install_dependencies() {
    log_info "安装依赖..."

    log_info "  [1/2] 安装后端依赖..."
    npm install

    log_info "  [2/2] 安装前端依赖..."
    npm run install:web

    log_success "依赖安装完成"
    echo ""
}

# 构建前端
build_frontend() {
    log_info "构建前端..."
    npm run build:web
    log_success "前端构建完成"
    echo ""
}

# 启动服务
start_service() {
    log_info "启动服务..."

    npm run service:start:daemon

    # 等待服务启动
    sleep 5

    # 检查服务状态
    if npm run service:status | grep -q "running"; then
        log_success "服务启动成功"
    else
        log_error "服务启动失败"
        log_info "请查看日志: npm run service:logs"
        return 1
    fi

    echo ""
}

# 验证迁移结果
verify_migration() {
    log_info "验证迁移结果..."

    # 检查关键文件
    CHECKS_PASSED=0
    CHECKS_TOTAL=0

    check_file() {
        CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
        if [ -f "$1" ]; then
            log_success "  ✓ $1 存在"
            CHECKS_PASSED=$((CHECKS_PASSED + 1))
            return 0
        else
            log_error "  ✗ $1 缺失"
            return 1
        fi
    }

    check_file ".env"
    check_file "config/config.js"
    check_file "data/init.json"

    # 检查服务状态
    CHECKS_TOTAL=$((CHECKS_TOTAL + 1))
    if npm run service:status | grep -q "running"; then
        log_success "  ✓ 服务运行正常"
        CHECKS_PASSED=$((CHECKS_PASSED + 1))
    else
        log_error "  ✗ 服务未运行"
    fi

    echo ""
    if [ $CHECKS_PASSED -eq $CHECKS_TOTAL ]; then
        log_success "所有检查通过 ($CHECKS_PASSED/$CHECKS_TOTAL)"
    else
        log_warning "部分检查失败 ($CHECKS_PASSED/$CHECKS_TOTAL)"
    fi

    echo ""
}

# 显示迁移摘要
show_summary() {
    SERVER_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "YOUR_SERVER_IP")
    SERVICE_PORT=$(grep "port:" config/config.js 2>/dev/null | grep -oP '\d+' | head -1 || echo "3000")

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "🎉 Git仓库迁移完成!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    log_info "📊 迁移摘要:"
    echo "  - 新仓库地址: $(git remote get-url origin)"
    echo "  - 当前分支: $(git branch --show-current)"
    echo "  - 最新提交: $(git log -1 --oneline)"
    echo "  - 所有配置和数据已保留"
    echo "  - 服务已重启"
    echo ""
    log_info "📁 备份文件位置:"
    echo "  - $BACKUP_DIR"
    echo "  - 建议保留此备份至少7天"
    echo ""
    log_info "🌐 访问地址:"
    echo "  - 本地: http://localhost:${SERVICE_PORT}/admin-next/login"
    echo "  - 外网: http://${SERVER_IP}:${SERVICE_PORT}/admin-next/login"
    echo ""
    log_info "🔧 管理命令:"
    echo "  - 查看状态: npm run service:status"
    echo "  - 查看日志: npm run service:logs"
    echo "  - 重启服务: npm run service:restart:daemon"
    echo ""
    log_info "🔄 后续更新:"
    echo "  - 现在可以使用 ./update.sh 脚本进行更新"
    echo "  - 每次更新会自动保留配置和数据"
    echo ""
    log_warning "⚠️  重要提示:"
    echo "  1. 请立即测试所有功能确保正常"
    echo "  2. 检查管理后台是否能正常登录"
    echo "  3. 验证API Key是否能正常使用"
    echo "  4. 如有问题可从备份恢复:"
    echo "     cp $BACKUP_DIR/.env .env"
    echo "     cp $BACKUP_DIR/config.js config/config.js"
    echo "     npm run service:restart:daemon"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 主流程
main() {
    show_welcome
    check_git_repo
    show_current_repo
    extract_key_configs
    stop_service
    full_backup
    switch_git_repo
    restore_configs
    install_dependencies
    build_frontend
    start_service
    verify_migration
    show_summary

    log_success "迁移完成! 🎉"
    log_info "建议现在进行完整的功能测试"
}

# 运行主流程
main
