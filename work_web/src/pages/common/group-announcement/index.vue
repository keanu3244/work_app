<template>
  <view class="page">
    <view class="header">
      <view class="author">
        <u-avatar :text="authorName.slice(0, 1)" size="42" />
        <view class="author-main">
          <text class="author-name">{{ authorName }}</text>
          <text class="author-time">{{ currentTime }}</text>
        </view>
      </view>
      <u-button size="small" text="编辑群公告" @click="editing = true" />
    </view>

    <view v-if="!editing" class="content">
      <text v-if="announcement" class="announcement-text">{{ announcement }}</text>
      <u-empty v-else text="暂无群公告" mode="list" />
    </view>

    <view v-else class="editor">
      <textarea
        v-model="draft"
        class="announcement-input"
        placeholder="填写群公告"
        :maxlength="500"
      />
      <view class="editor-actions">
        <u-button text="取消" @click="cancelEdit" />
        <u-button type="primary" text="发布" @click="saveAnnouncement" />
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { IMApi } from '@/api';
import { getSession } from '@/utils/auth';

const groupId = ref('');
const groupTitle = ref('');
const announcement = ref('');
const draft = ref('');
const editing = ref(false);
const session = computed(() => getSession());
const authorName = computed(() => session.value?.nick || '我');
const currentTime = computed(() => {
  const date = new Date();
  return `${date.getFullYear()}.${String(date.getMonth() + 1).padStart(2, '0')}.${String(date.getDate()).padStart(2, '0')} ${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
});

function cancelEdit() {
  draft.value = announcement.value;
  editing.value = false;
}

async function saveAnnouncement() {
  const value = draft.value.trim();
  if (!value)
    return uni.$u.toast('请输入群公告');
  await IMApi.updateGroup({ group_id: groupId.value, announcement: value });
  announcement.value = value;
  editing.value = false;
  uni.$u.toast('已发布');
}

onLoad((query) => {
  groupId.value = String(query?.group_id || '');
  groupTitle.value = String(query?.title || '');
  announcement.value = String(query?.announcement || '');
  draft.value = announcement.value;
  uni.setNavigationBarTitle({ title: `“${groupTitle.value}”的群公告` });
});
</script>

<style scoped lang="scss">
.page {
  min-height: 100vh;
  background: #fff;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: 18px 16px;
  border-bottom: 1px solid #eef0f4;
  box-sizing: border-box;
}

.author {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 10px;
}

.author-main {
  display: grid;
  gap: 4px;
}

.author-name {
  color: #172033;
  font-size: 16px;
  font-weight: 700;
}

.author-time {
  color: #9aa3b5;
  font-size: 13px;
}

.content {
  padding: 24px 16px;
}

.announcement-text {
  color: #172033;
  font-size: 16px;
  line-height: 1.7;
  white-space: pre-wrap;
  word-break: break-word;
}

.editor {
  display: grid;
  gap: 14px;
  padding: 16px;
}

.announcement-input {
  width: 100%;
  min-height: 220px;
  padding: 12px;
  color: #172033;
  font-size: 16px;
  line-height: 1.6;
  background: #f6f7fb;
  border: 0;
  border-radius: 8px;
  box-sizing: border-box;
}

.editor-actions {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px;
}
</style>
