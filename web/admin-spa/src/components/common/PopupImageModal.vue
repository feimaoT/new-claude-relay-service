<template>
  <Teleport to="body">
    <div
      v-if="show"
      class="modal fixed inset-0 z-50 flex items-center justify-center p-4"
      @click.self="handleClose"
    >
      <div
        class="modal-content relative mx-auto flex max-h-[90vh] w-auto max-w-[90vw] flex-col overflow-hidden rounded-2xl bg-white shadow-2xl dark:bg-gray-800"
      >
        <!-- 关闭按钮 -->
        <button
          class="absolute right-4 top-4 z-10 flex h-10 w-10 items-center justify-center rounded-full bg-black/50 text-white backdrop-blur-sm transition-all hover:scale-110 hover:bg-black/70"
          @click="handleClose"
        >
          <i class="fas fa-times text-lg" />
        </button>

        <!-- 图片容器 -->
        <div class="flex flex-1 items-center justify-center overflow-auto p-6">
          <img
            alt="启动弹窗"
            class="h-auto max-h-full w-auto max-w-full object-contain"
            :src="imageUrl"
            @error="handleImageError"
          />
        </div>

        <!-- 底部操作按钮 -->
        <div class="border-t border-gray-200 bg-gray-50 p-4 dark:border-gray-700 dark:bg-gray-900">
          <div class="flex flex-col gap-3 sm:flex-row sm:justify-center">
            <button
              class="flex-1 rounded-xl bg-gray-100 px-6 py-2.5 font-medium text-gray-700 transition-colors hover:bg-gray-200 dark:bg-gray-700 dark:text-gray-200 dark:hover:bg-gray-600 sm:flex-none"
              @click="handleClose"
            >
              <i class="fas fa-times mr-2" />
              关闭
            </button>
            <button
              class="flex-1 rounded-xl bg-gradient-to-r from-blue-500 to-blue-600 px-6 py-2.5 font-medium text-white shadow-sm transition-all hover:from-blue-600 hover:to-blue-700 sm:flex-none"
              @click="handleDontShowAgain"
            >
              <i class="fas fa-ban mr-2" />
              3天不再弹出
            </button>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup>
defineProps({
  show: {
    type: Boolean,
    required: true
  },
  imageUrl: {
    type: String,
    required: true
  }
})

const emit = defineEmits(['close', 'dont-show-again', 'error'])

const handleClose = () => {
  emit('close')
}

const handleDontShowAgain = () => {
  emit('dont-show-again')
}

const handleImageError = () => {
  emit('error')
}
</script>

<style scoped>
.modal {
  background: rgba(0, 0, 0, 0.75);
  backdrop-filter: blur(8px);
  animation: fadeIn 0.2s ease-out;
}

.modal-content {
  animation: slideUp 0.3s ease-out;
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
    transform: translateY(20px) scale(0.95);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

/* 滚动条样式 */
.modal-content ::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

.modal-content ::-webkit-scrollbar-track {
  background: transparent;
}

.modal-content ::-webkit-scrollbar-thumb {
  background: rgba(0, 0, 0, 0.2);
  border-radius: 4px;
}

.modal-content ::-webkit-scrollbar-thumb:hover {
  background: rgba(0, 0, 0, 0.3);
}

.dark .modal-content ::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
}

.dark .modal-content ::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}
</style>
