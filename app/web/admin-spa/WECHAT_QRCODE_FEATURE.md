# 微信群二维码弹框功能说明

## 功能概述

在 API Key 使用统计页面（`/api-stats`）添加了微信群二维码弹框，用户首次访问页面时会自动显示，引导用户加入微信交流群。

## 实现的功能

### 1. 自动弹窗
- 页面加载后延迟1秒自动显示弹框
- 用户可以选择"不再显示此提示"
- 使用 localStorage 记录用户选择

### 2. 弹框特性
- ✅ 响应式设计，支持手机、平板、桌面设备
- ✅ 完整的暗黑模式支持
- ✅ 优雅的动画效果（淡入 + 上滑）
- ✅ 玻璃态背景模糊效果
- ✅ 微信品牌色渐变按钮
- ✅ 关闭按钮（右上角）
- ✅ 温馨提示信息
- ✅ "不再显示"选项

### 3. 用户体验
- 弹框居中显示
- 点击背景或关闭按钮可关闭
- 勾选"不再显示"后，下次访问不会再弹出
- 二维码区域有加载状态提示

## 文件清单

### 新增文件
1. `src/components/common/WechatQrcodeModal.vue` - 微信群二维码弹框组件
2. `src/assets/images/README.md` - 图片资源说明文档

### 修改文件
1. `src/views/ApiStatsView.vue` - 集成弹框组件

## 使用步骤

### 1. 准备二维码图片
```bash
# 将您的微信群二维码图片命名为 wechat-qrcode.png
# 放置到以下目录：
src/assets/images/wechat-qrcode.png
```

**图片要求：**
- 文件名：`wechat-qrcode.png`
- 格式：PNG（推荐）或 JPG
- 尺寸：建议 500x500 像素或更大
- 内容：清晰的微信群二维码

### 2. 安装依赖（如果还没安装）
```bash
cd app/web/admin-spa
npm install
```

### 3. 开发模式测试
```bash
npm run dev
```

访问：`http://localhost:5173/admin/` （或您配置的端口）

### 4. 生产构建
```bash
npm run build
```

## 功能测试

### 测试清单
- [ ] 页面加载后1秒自动显示弹框
- [ ] 二维码图片正常显示
- [ ] 点击关闭按钮可以关闭弹框
- [ ] 点击背景可以关闭弹框
- [ ] 勾选"不再显示"后，刷新页面不再弹出
- [ ] 清除 localStorage 后，弹框重新显示
- [ ] 暗黑模式下样式正常
- [ ] 明亮模式下样式正常
- [ ] 手机端显示正常
- [ ] 平板端显示正常
- [ ] 桌面端显示正常

### 测试命令
```bash
# 清除 localStorage（在浏览器控制台执行）
localStorage.removeItem('hideWechatQrcodeModal')

# 查看当前设置
localStorage.getItem('hideWechatQrcodeModal')
```

## 自定义配置

### 修改延迟时间
在 `src/views/ApiStatsView.vue` 中修改：
```javascript
setTimeout(() => {
  showWechatModal.value = true
}, 1000) // 修改这里的数值（毫秒）
```

### 修改二维码图片路径
在 `src/views/ApiStatsView.vue` 中修改：
```javascript
import.meta.glob('@/assets/images/wechat-qrcode.png')
// 改为您的图片路径
```

### 修改弹框文案
在 `src/components/common/WechatQrcodeModal.vue` 中修改：
- 标题：`<h3>` 标签内容
- 副标题：`<p>` 标签内容
- 提示信息：`<ul>` 列表内容

### 禁用自动弹窗
在 `src/views/ApiStatsView.vue` 中注释掉以下代码：
```javascript
// 检查是否需要显示微信群二维码弹窗
const hideWechatModal = localStorage.getItem('hideWechatQrcodeModal')
if (!hideWechatModal) {
  setTimeout(() => {
    showWechatModal.value = true
  }, 1000)
}
```

## 样式说明

### 颜色方案
- **微信绿色**：`from-green-400 to-green-500`
- **背景模糊**：`backdrop-filter: blur(8px)`
- **暗黑模式**：自动适配 `dark:` 前缀样式

### 动画效果
- **淡入动画**：`fadeIn 0.3s ease-out`
- **上滑动画**：`slideUp 0.3s ease-out`

## 故障排除

### 问题1：二维码不显示
**原因**：图片路径不正确或图片不存在
**解决**：
1. 确认图片文件名为 `wechat-qrcode.png`
2. 确认图片在 `src/assets/images/` 目录下
3. 重新启动开发服务器

### 问题2：弹框不显示
**原因**：localStorage 中已设置不再显示
**解决**：
```javascript
// 在浏览器控制台执行
localStorage.removeItem('hideWechatQrcodeModal')
// 刷新页面
```

### 问题3：暗黑模式样式异常
**原因**：主题未正确初始化
**解决**：检查 `themeStore.initTheme()` 是否在 `onMounted` 中调用

### 问题4：构建失败
**原因**：依赖未安装
**解决**：
```bash
cd app/web/admin-spa
npm install
npm run build
```

## 后续优化建议

1. **多语言支持**：添加 i18n 国际化
2. **动态配置**：从后端API获取二维码URL
3. **统计功能**：记录弹框显示和关闭次数
4. **A/B测试**：测试不同的弹窗时机和文案
5. **多二维码**：支持显示多个社群二维码

## 技术栈

- Vue 3 Composition API
- Tailwind CSS 4
- Vite
- Font Awesome 图标

## 兼容性

- ✅ Chrome 90+
- ✅ Firefox 88+
- ✅ Safari 14+
- ✅ Edge 90+
- ✅ 移动端浏览器

## 维护说明

定期更新二维码图片，确保群二维码有效期内及时更换。建议每3个月检查一次。
