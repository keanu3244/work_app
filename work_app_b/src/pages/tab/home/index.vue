<template>
  <view class="page">
    <view class="header">
      <view>
        <view class="title">消息</view>
        <view class="subtitle">企业内部沟通</view>
      </view>
      <u-button size="small" type="primary" text="创建群聊" @click="toggleGroupForm" />
    </view>

    <view v-if="showGroupForm" class="quick-card">
      <u-input v-model="groupName" placeholder="群名称" border="surround" />
      <u-input v-model="groupMembers" placeholder="成员 UID，逗号分隔" border="surround" />
      <u-button type="primary" text="创建" @click="createGroup" />
    </view>

    <view class="section-title">好友</view>
    <view v-if="friends.length > 0" class="list">
      <view
        v-for="friend in friends"
        :key="String(friend.uid)"
        class="chat-row"
        @click="openFriend(friend)"
      >
        <u-avatar
          :text="(friend.remark || friend.nick || '员').slice(0, 1)"
          :src="friend.portrait"
          size="48"
          custom-style="margin-right: 12px"
        />
        <view class="row-main">
          <view class="row-top">
            <text class="row-title">{{ friend.remark || friend.nick || `用户 ${friend.uid}` }}</text>
            <text class="row-time">{{ conversationTime(friendConversation(friend)?.last_msg?.create_time) }}</text>
          </view>
          <view class="row-bottom">
            <text class="row-preview">{{ messagePreview(friendConversation(friend)?.last_msg) }}</text>
            <view class="row-badge">
              <u-badge v-if="friendConversation(friend)?.unread_count" :value="friendConversation(friend)?.unread_count" />
            </view>
          </view>
        </view>
      </view>
    </view>
    <u-empty v-else-if="!loading" text="暂无好友" mode="list" />
  </view>
</template>

<script setup lang="ts">
import type { ChatMessage, Conversation, FriendItem } from '@/api/im';
import { IMApi } from '@/api';

const loading = ref(false);
const conversations = ref<Conversation[]>([]);
const friends = ref<FriendItem[]>([]);
const showGroupForm = ref(false);
const groupName = ref('');
const groupMembers = ref('');
let removePeerListener: (() => void) | null = null;
let removeGroupListener: (() => void) | null = null;
let removeFriendListener: (() => void) | null = null;

function friendConversation(friend: FriendItem) {
  return conversations.value.find(item => item.contact_type === 1 && peerUID(item) === String(friend.uid));
}

function peerUID(item: Conversation) {
  return String(item.peer_id || item.peer_user?.uid || '');
}

function messagePreview(message?: ChatMessage) {
  if (!message)
    return '暂无消息';
  if (message.status === 2)
    return '消息已撤回';
  return message.content.text_content?.content || '[非文本消息]';
}

function conversationTime(time?: number) {
  if (!time)
    return '';
  const date = new Date(time * 1000);
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

function openFriend(friend: FriendItem) {
  const contact = friendConversation(friend);
  const params = new URLSearchParams({
    contact_id: contact?.contact_id || '',
    type: '1',
    title: friend.remark || friend.nick || `用户 ${friend.uid}`,
    peer_id: String(friend.uid),
  });
  uni.navigateTo({ url: `/pages/common/chat/index?${params.toString()}` });
}

function parseUIDs(value: string) {
  const list = value.split(',').map(item => item.trim()).filter(Boolean);
  return list.every(item => /^\d+$/.test(item)) ? list : [];
}

function toggleGroupForm() {
  showGroupForm.value = !showGroupForm.value;
}

async function createGroup() {
  const name = groupName.value.trim();
  const member_uids = parseUIDs(groupMembers.value);
  if (!name)
    return uni.$u.toast('请输入群名称');
  if (!member_uids.length)
    return uni.$u.toast('请输入正确的成员 UID');
  try {
    const group = await IMApi.createGroup({ name, member_uids });
    groupName.value = '';
    groupMembers.value = '';
    showGroupForm.value = false;
    await loadHome();
    const params = new URLSearchParams({
      type: '2',
      title: group.name,
      peer_id: group.group_id,
    });
    uni.navigateTo({ url: `/pages/common/chat/index?${params.toString()}` });
  }
  catch (error: any) {
    uni.$u.toast(error?.message || '创建群聊失败');
  }
}

async function loadHome() {
  loading.value = true;
  try {
    const [conversationRes, friendRes] = await Promise.all([
      IMApi.conversations(),
      IMApi.friends(),
    ]);
    conversations.value = conversationRes.contacts;
    friends.value = friendRes.list;
  }
  finally {
    loading.value = false;
  }
}

function bindRealtime() {
  if (removePeerListener)
    return;
  const reload = () => loadHome();
  uni.$on('im.peer', reload);
  uni.$on('im.group', reload);
  uni.$on('im.friend', reload);
  removePeerListener = () => uni.$off('im.peer', reload);
  removeGroupListener = () => uni.$off('im.group', reload);
  removeFriendListener = () => uni.$off('im.friend', reload);
}

onShow(() => {
  bindRealtime();
  loadHome();
});

onUnload(() => {
  removePeerListener?.();
  removeGroupListener?.();
  removeFriendListener?.();
});
</script>

<style scoped lang="scss">
.page {
  min-height: 100vh;
  background: #f6f7fb;
}

.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  padding: calc(env(safe-area-inset-top) + 18px) 18px 14px;
}

.title {
  color: #172033;
  font-size: 24px;
  font-weight: 700;
}

.subtitle {
  margin-top: 4px;
  color: #7a8499;
  font-size: 13px;
}

.quick-card {
  display: grid;
  gap: 10px;
  margin: 0 12px 14px;
  padding: 12px;
  background: #fff;
  border-radius: 8px;
}

.section-title {
  margin: 18px 18px 8px;
  color: #172033;
  font-size: 16px;
  font-weight: 700;
}

.empty-tip {
  margin: 0 18px;
  color: #9aa3b5;
  font-size: 13px;
  line-height: 24px;
}

.list {
  overflow: hidden;
  margin: 0 12px;
  background: #fff;
  border-radius: 8px;
}

.chat-row {
  display: flex;
  align-items: center;
  min-height: 74px;
  padding: 10px 14px;
  background: #fff;
  box-sizing: border-box;
}

.chat-row + .chat-row {
  border-top: 1px solid #edf0f5;
}

.row-main {
  min-width: 0;
  flex: 1;
}

.row-top,
.row-bottom {
  display: flex;
  align-items: center;
  min-width: 0;
}

.row-top {
  margin-bottom: 6px;
}

.row-title {
  overflow: hidden;
  flex: 1;
  color: #172033;
  font-size: 16px;
  font-weight: 700;
  line-height: 20px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.row-time {
  margin-left: 8px;
  color: #b4bbc8;
  font-size: 12px;
}

.row-preview {
  overflow: hidden;
  flex: 1;
  color: #8a94a6;
  font-size: 13px;
  line-height: 18px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.row-badge {
  flex: 0 0 auto;
  margin-left: 8px;
}
</style>
