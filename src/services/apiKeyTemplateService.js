/**
 * API Key Template Service
 * 管理API Key创建模板
 */

const redis = require('../models/redis')
const logger = require('../utils/logger')
const crypto = require('crypto')

class ApiKeyTemplateService {
  /**
   * 生成模板ID
   */
  generateTemplateId() {
    return `tpl_${crypto.randomBytes(16).toString('hex')}`
  }

  /**
   * 创建模板
   */
  async createTemplate(templateData) {
    const {
      templateName,
      description = '',
      dailyLimit,
      concurrentLimit,
      rateLimit,
      permissions = [],
      allowedClientTypes = [],
      blockedModels = [],
      quotaCardId = null,
      bindingAccounts = [],
      serviceRates = {},
      tags = [],
      expiresIn = null,
      concurrentRequestQueueEnabled = false,
      concurrentRequestQueueMaxSize = 3,
      concurrentRequestQueueTimeoutMs = 10000,
      createdBy = 'admin'
    } = templateData

    // 验证必填字段
    if (!templateName || templateName.trim().length === 0) {
      throw new Error('Template name is required')
    }

    if (templateName.length > 100) {
      throw new Error('Template name must be less than 100 characters')
    }

    // 生成模板ID
    const templateId = this.generateTemplateId()

    // 构建模板对象
    const template = {
      id: templateId,
      templateName: templateName.trim(),
      description: description.trim(),
      dailyLimit: dailyLimit || null,
      concurrentLimit: concurrentLimit || null,
      rateLimit: rateLimit || null,
      permissions: Array.isArray(permissions) ? permissions : [],
      allowedClientTypes: Array.isArray(allowedClientTypes) ? allowedClientTypes : [],
      blockedModels: Array.isArray(blockedModels) ? blockedModels : [],
      quotaCardId,
      bindingAccounts: Array.isArray(bindingAccounts) ? bindingAccounts : [],
      serviceRates: serviceRates || {},
      tags: Array.isArray(tags) ? tags : [],
      expiresIn,
      concurrentRequestQueueEnabled: concurrentRequestQueueEnabled === true,
      concurrentRequestQueueMaxSize: concurrentRequestQueueMaxSize || 3,
      concurrentRequestQueueTimeoutMs: concurrentRequestQueueTimeoutMs || 10000,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      createdBy
    }

    // 保存到Redis
    const client = redis.getClient()
    await client.set(`api_key_template:${templateId}`, JSON.stringify(template))

    logger.info(`✅ Created API Key template: ${templateName} (${templateId})`)

    return template
  }

  /**
   * 更新模板
   */
  async updateTemplate(templateId, updateData) {
    const client = redis.getClient()
    const key = `api_key_template:${templateId}`

    // 获取现有模板
    const existingData = await client.get(key)
    if (!existingData) {
      throw new Error('Template not found')
    }

    const existingTemplate = JSON.parse(existingData)

    // 合并更新数据
    const updatedTemplate = {
      ...existingTemplate,
      ...updateData,
      id: templateId, // 确保ID不被修改
      createdAt: existingTemplate.createdAt, // 保持创建时间
      createdBy: existingTemplate.createdBy, // 保持创建者
      updatedAt: new Date().toISOString()
    }

    // 验证
    if (updatedTemplate.templateName && updatedTemplate.templateName.length > 100) {
      throw new Error('Template name must be less than 100 characters')
    }

    // 保存更新
    await client.set(key, JSON.stringify(updatedTemplate))

    logger.info(`✅ Updated API Key template: ${updatedTemplate.templateName} (${templateId})`)

    return updatedTemplate
  }

  /**
   * 删除模板
   */
  async deleteTemplate(templateId) {
    const client = redis.getClient()
    const key = `api_key_template:${templateId}`

    // 检查模板是否存在
    const existingData = await client.get(key)
    if (!existingData) {
      throw new Error('Template not found')
    }

    const template = JSON.parse(existingData)

    // 删除
    await client.del(key)

    logger.info(`🗑️ Deleted API Key template: ${template.templateName} (${templateId})`)

    return { success: true }
  }

  /**
   * 获取单个模板
   */
  async getTemplateById(templateId) {
    const client = redis.getClient()
    const data = await client.get(`api_key_template:${templateId}`)

    if (!data) {
      return null
    }

    return JSON.parse(data)
  }

  /**
   * 获取所有模板
   */
  async getAllTemplates() {
    const client = redis.getClient()
    const keys = await client.keys('api_key_template:*')

    if (keys.length === 0) {
      return []
    }

    // 批量获取
    const templates = await Promise.all(
      keys.map(async (key) => {
        const data = await client.get(key)
        return data ? JSON.parse(data) : null
      })
    )

    // 过滤null并按创建时间排序
    return templates
      .filter((t) => t !== null)
      .sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt))
  }

  /**
   * 从模板获取创建Key的参数
   */
  async getTemplateParams(templateId) {
    const template = await this.getTemplateById(templateId)
    if (!template) {
      throw new Error('Template not found')
    }

    // 返回创建API Key需要的参数（排除模板专用字段）
    return {
      dailyLimit: template.dailyLimit,
      concurrentLimit: template.concurrentLimit,
      rateLimit: template.rateLimit,
      permissions: template.permissions,
      allowedClientTypes: template.allowedClientTypes,
      blockedModels: template.blockedModels,
      quotaCardId: template.quotaCardId,
      bindingAccounts: template.bindingAccounts,
      serviceRates: template.serviceRates,
      tags: template.tags,
      expiresIn: template.expiresIn,
      concurrentRequestQueueEnabled: template.concurrentRequestQueueEnabled,
      concurrentRequestQueueMaxSize: template.concurrentRequestQueueMaxSize,
      concurrentRequestQueueTimeoutMs: template.concurrentRequestQueueTimeoutMs
    }
  }
}

module.exports = new ApiKeyTemplateService()
