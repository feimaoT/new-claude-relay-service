/**
 * API Key Templates Routes
 * API Key 模板管理路由
 */

const express = require('express')
const apiKeyTemplateService = require('../../services/apiKeyTemplateService')
const apiKeyService = require('../../services/apiKeyService')
const { authenticateAdmin } = require('../../middleware/auth')
const logger = require('../../utils/logger')

const router = express.Router()

// 获取所有模板
router.get('/api-key-templates', authenticateAdmin, async (req, res) => {
  try {
    const templates = await apiKeyTemplateService.getAllTemplates()

    return res.json({
      success: true,
      data: templates,
      total: templates.length
    })
  } catch (error) {
    logger.error('❌ Failed to get API Key templates:', error)
    return res.status(500).json({
      success: false,
      error: 'Failed to get templates',
      message: error.message
    })
  }
})

// 获取单个模板
router.get('/api-key-templates/:id', authenticateAdmin, async (req, res) => {
  try {
    const { id } = req.params

    const template = await apiKeyTemplateService.getTemplateById(id)

    if (!template) {
      return res.status(404).json({
        success: false,
        error: 'Template not found'
      })
    }

    return res.json({
      success: true,
      data: template
    })
  } catch (error) {
    logger.error('❌ Failed to get API Key template:', error)
    return res.status(500).json({
      success: false,
      error: 'Failed to get template',
      message: error.message
    })
  }
})

// 创建模板
router.post('/api-key-templates', authenticateAdmin, async (req, res) => {
  try {
    const templateData = {
      ...req.body,
      createdBy: req.admin?.username || 'admin'
    }

    const template = await apiKeyTemplateService.createTemplate(templateData)

    return res.json({
      success: true,
      message: 'Template created successfully',
      data: template
    })
  } catch (error) {
    logger.error('❌ Failed to create API Key template:', error)

    if (error.message.includes('required') || error.message.includes('must be')) {
      return res.status(400).json({
        success: false,
        error: 'Validation error',
        message: error.message
      })
    }

    return res.status(500).json({
      success: false,
      error: 'Failed to create template',
      message: error.message
    })
  }
})

// 更新模板
router.put('/api-key-templates/:id', authenticateAdmin, async (req, res) => {
  try {
    const { id } = req.params
    const updateData = req.body

    const template = await apiKeyTemplateService.updateTemplate(id, updateData)

    return res.json({
      success: true,
      message: 'Template updated successfully',
      data: template
    })
  } catch (error) {
    logger.error('❌ Failed to update API Key template:', error)

    if (error.message === 'Template not found') {
      return res.status(404).json({
        success: false,
        error: 'Template not found'
      })
    }

    if (error.message.includes('must be')) {
      return res.status(400).json({
        success: false,
        error: 'Validation error',
        message: error.message
      })
    }

    return res.status(500).json({
      success: false,
      error: 'Failed to update template',
      message: error.message
    })
  }
})

// 删除模板
router.delete('/api-key-templates/:id', authenticateAdmin, async (req, res) => {
  try {
    const { id } = req.params

    await apiKeyTemplateService.deleteTemplate(id)

    return res.json({
      success: true,
      message: 'Template deleted successfully'
    })
  } catch (error) {
    logger.error('❌ Failed to delete API Key template:', error)

    if (error.message === 'Template not found') {
      return res.status(404).json({
        success: false,
        error: 'Template not found'
      })
    }

    return res.status(500).json({
      success: false,
      error: 'Failed to delete template',
      message: error.message
    })
  }
})

// 从模板创建API Key
router.post('/api-key-templates/:id/create-key', authenticateAdmin, async (req, res) => {
  try {
    const { id } = req.params
    const { name, userId } = req.body

    // 验证key名称
    if (!name || name.trim().length === 0) {
      return res.status(400).json({
        success: false,
        error: 'Validation error',
        message: 'API Key name is required'
      })
    }

    // 获取模板参数
    const templateParams = await apiKeyTemplateService.getTemplateParams(id)

    // 创建API Key
    const apiKeyData = {
      name: name.trim(),
      userId: userId || null,
      ...templateParams,
      createdBy: req.admin?.username || 'admin'
    }

    const newApiKey = await apiKeyService.createApiKey(apiKeyData)

    logger.info(`✅ Created API Key from template: ${name} (template: ${id})`)

    return res.json({
      success: true,
      message: 'API Key created successfully from template',
      data: newApiKey
    })
  } catch (error) {
    logger.error('❌ Failed to create API Key from template:', error)

    if (error.message === 'Template not found') {
      return res.status(404).json({
        success: false,
        error: 'Template not found'
      })
    }

    if (error.message.includes('required') || error.message.includes('must be')) {
      return res.status(400).json({
        success: false,
        error: 'Validation error',
        message: error.message
      })
    }

    return res.status(500).json({
      success: false,
      error: 'Failed to create API Key from template',
      message: error.message
    })
  }
})

module.exports = router
