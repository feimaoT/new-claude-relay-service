<template>
  <Teleport to="body">
    <div v-if="show" class="modal fixed inset-0 z-50 flex items-center justify-center p-4">
      <div
        class="modal-content mx-auto w-full max-w-md rounded-2xl bg-white p-6 shadow-xl dark:bg-gray-800"
      >
        <!-- 关闭按钮 -->
        <button
          class="absolute right-4 top-4 flex h-8 w-8 items-center justify-center rounded-full text-gray-400 transition-colors hover:bg-gray-100 hover:text-gray-600 dark:hover:bg-gray-700 dark:hover:text-gray-300"
          @click="$emit('close')"
        >
          <i class="fas fa-times text-lg" />
        </button>

        <!-- 标题 -->
        <div class="mb-6 text-center">
          <div
            class="mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full bg-gradient-to-br from-green-400 to-green-500"
          >
            <i class="fab fa-weixin text-3xl text-white" />
          </div>
          <h3 class="mb-2 text-xl font-bold text-gray-900 dark:text-white">加入微信交流群</h3>
          <p class="text-sm text-gray-600 dark:text-gray-400">扫描二维码加入我们的微信群</p>
        </div>

        <!-- 二维码区域 -->
        <div class="mb-6 flex justify-center">
          <div
            class="rounded-2xl border-4 border-gray-100 bg-white p-4 shadow-inner dark:border-gray-700 dark:bg-gray-900"
          >
            <img
              v-if="qrcodeUrl"
              alt="微信群二维码"
              class="h-64 w-64 object-contain"
              :src="qrcodeUrl"
            />
            <div
              v-else
              class="flex h-64 w-64 items-center justify-center bg-gray-50 dark:bg-gray-800"
            >
              <div class="text-center">
                <i class="fas fa-qrcode mb-2 text-4xl text-gray-300 dark:text-gray-600" />
                <p class="text-sm text-gray-500 dark:text-gray-400">二维码加载中...</p>
              </div>
            </div>
          </div>
        </div>

        <!-- 提示信息 -->
        <div
          class="mb-6 rounded-xl bg-blue-50 p-4 text-sm text-blue-800 dark:bg-blue-900/20 dark:text-blue-200"
        >
          <div class="flex items-start gap-2">
            <i class="fas fa-info-circle mt-0.5 flex-shrink-0" />
            <div>
              <p class="mb-1 font-medium">温馨提示：</p>
              <ul class="list-inside list-disc space-y-1 text-xs">
                <li>使用微信扫描二维码即可加入群聊</li>
                <li>群内可交流使用经验和技术问题</li>
                <li>获取最新功能更新和优惠信息</li>
              </ul>
            </div>
          </div>
        </div>

        <!-- 底部按钮 -->
        <div class="flex gap-3">
          <button
            class="flex-1 rounded-xl bg-gradient-to-r from-green-500 to-green-600 px-4 py-3 font-medium text-white shadow-sm transition-all hover:from-green-600 hover:to-green-700 hover:shadow-md"
            @click="$emit('close')"
          >
            <i class="fas fa-check mr-2" />
            我知道了
          </button>
        </div>

        <!-- 不再显示选项 -->
        <div class="mt-4 text-center">
          <label
            class="inline-flex cursor-pointer items-center text-sm text-gray-600 dark:text-gray-400"
          >
            <input
              v-model="dontShowAgain"
              class="mr-2 h-4 w-4 rounded border-gray-300 text-green-600 focus:ring-2 focus:ring-green-500 dark:border-gray-600 dark:bg-gray-700"
              type="checkbox"
              @change="handleDontShowAgain"
            />
            不再显示此提示
          </label>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
import { ref } from 'vue'

defineProps({
  show: {
    type: Boolean,
    required: true
  },
  qrcodeUrl: {
    type: String,
    default: ''
  }
})

defineEmits(['close'])

const dontShowAgain = ref(false)

const handleDontShowAgain = () => {
  if (dontShowAgain.value) {
    localStorage.setItem('hideWechatQrcodeModal', 'true')
  } else {
    localStorage.removeItem('hideWechatQrcodeModal')
  }
}
</script>

<style scoped>
.modal {
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(8px);
  animation: fadeIn 0.3s ease-out;
}

:global(.dark) .modal {
  background: rgba(0, 0, 0, 0.7);
  backdrop-filter: blur(8px);
}

.modal-content {
  animation: slideUp 0.3s ease-out;
  position: relative;
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}
</style>
