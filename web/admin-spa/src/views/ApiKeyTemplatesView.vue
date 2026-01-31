<template>
  <div class="min-h-screen bg-gray-50 p-6 dark:bg-gray-900">
    <!-- Header -->
    <div class="mb-6">
      <div class="mb-2 flex items-center gap-2">
        <button
          class="flex items-center gap-1 rounded-lg px-3 py-1.5 text-sm font-medium text-gray-600 transition-colors hover:bg-gray-100 hover:text-gray-900 dark:text-gray-400 dark:hover:bg-gray-800 dark:hover:text-gray-200"
          @click="$router.push('/api-keys')"
        >
          <i class="fas fa-arrow-left"></i>
          <span>返回 API Keys</span>
        </button>
      </div>
      <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
        <i class="fas fa-file-invoice mr-2 text-blue-600"></i>
        API Key 模板管理
      </h1>
      <p class="mt-1 text-sm text-gray-600 dark:text-gray-400">
        创建和管理 API Key 模板，快速生成配置相同的密钥
      </p>
    </div>

    <!-- Actions Bar -->
    <div class="mb-6 flex items-center justify-between">
      <div class="text-sm text-gray-600 dark:text-gray-400">共 {{ templates.length }} 个模板</div>
      <button
        class="rounded-lg bg-blue-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-blue-700"
        @click="openCreateModal"
      >
        <i class="fas fa-plus mr-2"></i>
        创建模板
      </button>
    </div>

    <!-- Loading -->
    <div v-if="loading" class="py-12 text-center">
      <div
        class="inline-block h-8 w-8 animate-spin rounded-full border-4 border-solid border-blue-600 border-r-transparent"
      ></div>
      <p class="mt-4 text-gray-500 dark:text-gray-400">正在加载...</p>
    </div>

    <!-- Empty State -->
    <div
      v-else-if="templates.length === 0"
      class="rounded-lg border-2 border-dashed border-gray-300 bg-white py-12 text-center dark:border-gray-700 dark:bg-gray-800"
    >
      <i class="fas fa-file-invoice fa-3x text-gray-300 dark:text-gray-600"></i>
      <p class="mt-4 text-lg text-gray-500 dark:text-gray-400">暂无模板</p>
      <p class="mt-2 text-sm text-gray-400">点击"创建模板"按钮添加您的第一个模板</p>
    </div>

    <!-- Templates Grid -->
    <div v-else class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
      <div
        v-for="template in templates"
        :key="template.id"
        class="rounded-lg border border-gray-200 bg-white p-5 shadow-sm transition-shadow hover:shadow-md dark:border-gray-700 dark:bg-gray-800"
      >
        <!-- Header -->
        <div class="mb-3 flex items-start justify-between">
          <div class="flex-1">
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
              {{ template.templateName }}
            </h3>
            <p v-if="template.description" class="mt-1 text-sm text-gray-600 dark:text-gray-400">
              {{ template.description }}
            </p>
          </div>
        </div>

        <!-- Tags -->
        <div class="mb-4 flex flex-wrap gap-2">
          <span
            v-if="template.dailyLimit"
            class="rounded-full bg-blue-100 px-2.5 py-0.5 text-xs font-medium text-blue-800 dark:bg-blue-900/30 dark:text-blue-300"
          >
            <i class="fas fa-calendar-day mr-1"></i>
            每日 {{ template.dailyLimit }}
          </span>
          <span
            v-if="template.concurrentLimit"
            class="rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800 dark:bg-green-900/30 dark:text-green-300"
          >
            <i class="fas fa-layer-group mr-1"></i>
            并发 {{ template.concurrentLimit }}
          </span>
          <span
            v-if="template.permissions && template.permissions.length > 0"
            class="rounded-full bg-purple-100 px-2.5 py-0.5 text-xs font-medium text-purple-800 dark:bg-purple-900/30 dark:text-purple-300"
          >
            <i class="fas fa-shield-alt mr-1"></i>
            {{ template.permissions.join(', ') }}
          </span>
        </div>

        <!-- Actions -->
        <div class="flex gap-2">
          <button
            class="flex-1 rounded-lg bg-green-600 px-3 py-2 text-sm font-medium text-white transition-colors hover:bg-green-700"
            @click="openCreateKeyModal(template)"
          >
            <i class="fas fa-magic mr-1"></i>
            创建 Key
          </button>
          <button
            class="rounded-lg bg-gray-200 px-3 py-2 text-sm font-medium text-gray-700 transition-colors hover:bg-gray-300 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
            @click="openEditModal(template)"
          >
            <i class="fas fa-edit"></i>
          </button>
          <button
            class="rounded-lg bg-red-100 px-3 py-2 text-sm font-medium text-red-700 transition-colors hover:bg-red-200 dark:bg-red-900/30 dark:text-red-400 dark:hover:bg-red-900/50"
            @click="deleteTemplate(template)"
          >
            <i class="fas fa-trash"></i>
          </button>
        </div>

        <!-- Meta -->
        <div class="mt-3 text-xs text-gray-500 dark:text-gray-400">
          创建于 {{ formatDate(template.createdAt) }}
        </div>
      </div>
    </div>

    <!-- Create/Edit Template Modal -->
    <CreateTemplateModal
      v-if="showModal"
      :accounts="accounts"
      :template="editingTemplate"
      @close="closeModal"
      @success="handleTemplateSuccess"
    />

    <!-- Create Key from Template Modal -->
    <div
      v-if="showCreateKeyModal"
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4"
      @click.self="showCreateKeyModal = false"
    >
      <div class="w-full max-w-md rounded-lg bg-white p-6 dark:bg-gray-800">
        <h2 class="mb-4 text-xl font-bold text-gray-900 dark:text-white">从模板创建 API Key</h2>

        <p class="mb-4 text-sm text-gray-600 dark:text-gray-400">
          模板：<span class="font-semibold">{{ selectedTemplate?.templateName }}</span>
        </p>

        <div class="mb-4">
          <label class="mb-1 block text-sm font-medium text-gray-700 dark:text-gray-300">
            Key 名称 *
          </label>
          <input
            v-model="newKeyName"
            class="w-full rounded-lg border border-gray-300 px-3 py-2 dark:border-gray-600 dark:bg-gray-700 dark:text-white"
            placeholder="输入 Key 名称"
            type="text"
            @keyup.enter="createKeyFromTemplate"
          />
        </div>

        <div class="flex justify-end gap-3">
          <button
            class="rounded-lg bg-gray-200 px-4 py-2 text-sm font-medium text-gray-700 transition-colors hover:bg-gray-300 dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600"
            @click="showCreateKeyModal = false"
          >
            取消
          </button>
          <button
            class="rounded-lg bg-green-600 px-4 py-2 text-sm font-medium text-white transition-colors hover:bg-green-700 disabled:cursor-not-allowed disabled:opacity-50"
            :disabled="!newKeyName.trim()"
            @click="createKeyFromTemplate"
          >
            创建
          </button>
        </div>
      </div>
    </div>

    <!-- New API Key Modal -->
    <NewApiKeyModal
      v-if="showNewApiKeyModal"
      :api-key="newApiKeyData"
      @close="showNewApiKeyModal = false"
    />
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { showToast } from '@/utils/tools'
import * as httpApis from '@/utils/http_apis'
import CreateTemplateModal from '@/components/apikeys/CreateTemplateModal.vue'
import NewApiKeyModal from '@/components/apikeys/NewApiKeyModal.vue'

// State
const templates = ref([])
const loading = ref(false)
const showModal = ref(false)
const showCreateKeyModal = ref(false)
const showNewApiKeyModal = ref(false)
const editingTemplate = ref(null)
const selectedTemplate = ref(null)
const newKeyName = ref('')
const newApiKeyData = ref(null)

// 账号数据
const accounts = ref({
  claude: [],
  gemini: [],
  openai: [],
  bedrock: [],
  droid: [],
  claudeGroups: [],
  geminiGroups: [],
  openaiGroups: [],
  droidGroups: []
})

// 加载账号数据
const loadAccounts = async () => {
  try {
    const [
      claudeData,
      claudeConsoleData,
      geminiData,
      geminiApiData,
      openaiData,
      openaiResponsesData,
      bedrockData,
      droidData,
      groupsData
    ] = await Promise.all([
      httpApis.getClaudeAccountsApi(),
      httpApis.getClaudeConsoleAccountsApi(),
      httpApis.getGeminiAccountsApi(),
      httpApis.getGeminiApiAccountsApi(),
      httpApis.getOpenAIAccountsApi(),
      httpApis.getOpenAIResponsesAccountsApi(),
      httpApis.getBedrockAccountsApi(),
      httpApis.getDroidAccountsApi(),
      httpApis.getAccountGroupsApi()
    ])

    // 合并Claude OAuth和Console账户
    const claudeAccounts = []
    if (claudeData.success) {
      claudeData.data?.forEach((account) => {
        claudeAccounts.push({
          ...account,
          platform: 'claude-oauth'
        })
      })
    }
    if (claudeConsoleData.success) {
      claudeConsoleData.data?.forEach((account) => {
        claudeAccounts.push({
          ...account,
          platform: 'claude-console'
        })
      })
    }

    // 合并Gemini OAuth和API账号
    const geminiAccounts = []
    if (geminiData.success) {
      geminiData.data?.forEach((account) => {
        geminiAccounts.push({
          ...account,
          platform: 'gemini'
        })
      })
    }
    if (geminiApiData.success) {
      geminiApiData.data?.forEach((account) => {
        geminiAccounts.push({
          ...account,
          platform: 'gemini-api'
        })
      })
    }

    // 合并OpenAI和OpenAI-Responses账号
    const openaiAccounts = []
    if (openaiData.success) {
      openaiData.data?.forEach((account) => {
        openaiAccounts.push({
          ...account,
          platform: 'openai'
        })
      })
    }
    if (openaiResponsesData.success) {
      openaiResponsesData.data?.forEach((account) => {
        openaiAccounts.push({
          ...account,
          platform: 'openai-responses'
        })
      })
    }

    accounts.value = {
      claude: claudeAccounts,
      gemini: geminiAccounts,
      openai: openaiAccounts,
      bedrock: bedrockData.success ? bedrockData.data || [] : [],
      droid: droidData.success
        ? (droidData.data || []).map((account) => ({
            ...account,
            platform: 'droid'
          }))
        : [],
      claudeGroups: groupsData.success
        ? (groupsData.data || []).filter((g) => g.platform === 'claude')
        : [],
      geminiGroups: groupsData.success
        ? (groupsData.data || []).filter((g) => g.platform === 'gemini')
        : [],
      openaiGroups: groupsData.success
        ? (groupsData.data || []).filter((g) => g.platform === 'openai')
        : [],
      droidGroups: groupsData.success
        ? (groupsData.data || []).filter((g) => g.platform === 'droid')
        : []
    }
  } catch (error) {
    console.error('加载账号数据失败:', error)
  }
}

// Load templates
const loadTemplates = async () => {
  loading.value = true
  try {
    const res = await httpApis.getApiKeyTemplatesApi()
    if (res.success) {
      templates.value = res.data || []
    } else {
      showToast('加载模板失败', 'error')
    }
  } catch (error) {
    console.error('加载模板失败:', error)
    showToast('加载模板失败', 'error')
  } finally {
    loading.value = false
  }
}

// Open create modal
const openCreateModal = () => {
  editingTemplate.value = null
  showModal.value = true
}

// Open edit modal
const openEditModal = (template) => {
  editingTemplate.value = template
  showModal.value = true
}

// Close modal
const closeModal = () => {
  showModal.value = false
  editingTemplate.value = null
}

// Handle template success
const handleTemplateSuccess = () => {
  loadTemplates()
}

// Delete template
const deleteTemplate = async (template) => {
  if (!confirm(`确定要删除模板"${template.templateName}"吗？`)) {
    return
  }

  try {
    const res = await httpApis.deleteApiKeyTemplateApi(template.id)
    if (res.success) {
      showToast('模板删除成功', 'success')
      await loadTemplates()
    } else {
      showToast(res.message || '删除失败', 'error')
    }
  } catch (error) {
    console.error('删除模板失败:', error)
    showToast('删除模板失败', 'error')
  }
}

// Open create key modal
const openCreateKeyModal = (template) => {
  selectedTemplate.value = template
  newKeyName.value = ''
  showCreateKeyModal.value = true
}

// Create key from template
const createKeyFromTemplate = async () => {
  if (!newKeyName.value.trim()) {
    showToast('请输入 Key 名称', 'error')
    return
  }

  try {
    const res = await httpApis.createKeyFromTemplateApi(selectedTemplate.value.id, {
      name: newKeyName.value.trim()
    })

    if (res.success) {
      showToast(`API Key "${newKeyName.value}" 创建成功`, 'success')
      showCreateKeyModal.value = false
      // 显示新创建的Key弹窗
      newApiKeyData.value = res.data
      showNewApiKeyModal.value = true
    } else {
      showToast(res.message || '创建失败', 'error')
    }
  } catch (error) {
    console.error('创建Key失败:', error)
    showToast('创建Key失败', 'error')
  }
}

// Format date
const formatDate = (dateString) => {
  if (!dateString) return ''
  return new Date(dateString).toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

// Load on mount
onMounted(async () => {
  await loadAccounts()
  await loadTemplates()
})
</script>
