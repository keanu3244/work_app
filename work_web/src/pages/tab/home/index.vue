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
      <view class="member-picker">
        <view
          v-for="friend in friends"
          :key="String(friend.uid)"
          class="member-row"
          @click="toggleGroupMember(friend)"
        >
          <u-avatar
            :text="(friend.remark || friend.nick || '员').slice(0, 1)"
            :src="friend.portrait"
            size="36"
            custom-style="margin-right: 10px"
          />
          <text class="member-name">{{ friend.remark || friend.nick || `用户 ${friend.uid}` }}</text>
          <view class="check-dot" :class="{ checked: isGroupMemberSelected(friend) }" />
        </view>
      </view>
      <u-empty v-if="friends.length === 0" text="暂无好友可选" mode="list" />
      <u-button type="primary" :text="createGroupButtonText" @click="createGroup" />
    </view>

    <view class="section-title">消息</view>
    <view v-if="homeItems.length > 0" class="list">
      <view
        v-for="item in homeItems"
        :key="item.key"
        class="chat-row"
        @click="openHomeItem(item)"
      >
        <u-avatar
          :text="item.avatarText"
          :src="item.avatar"
          size="48"
          custom-style="margin-right: 12px"
        />
        <view class="row-main">
          <view class="row-top">
            <text class="row-title">{{ item.title }}</text>
            <text class="row-time">{{ conversationTime(item.conversation?.last_msg?.create_time) }}</text>
          </view>
          <view class="row-bottom">
            <text class="row-preview">{{ messagePreview(item.conversation?.last_msg) }}</text>
            <view class="row-badge">
              <u-badge v-if="item.conversation?.unread_count" :value="item.conversation?.unread_count" />
            </view>
          </view>
        </view>
      </view>
    </view>
    <u-empty v-else-if="!loading" text="暂无消息" mode="list" />
  </view>
</template>

<script setup lang="ts">
import type { ChatMessage, Conversation, FriendItem, GroupInfo } from '@/api/im';
import { IMApi } from '@/api';

const loading = ref(false);
const conversations = ref<Conversation[]>([]);
const friends = ref<FriendItem[]>([]);
const groups = ref<GroupInfo[]>([]);
const showGroupForm = ref(false);
const selectedGroupMemberUIDs = ref<string[]>([]);
let removePeerListener: (() => void) | null = null;
let removeGroupListener: (() => void) | null = null;
let removeFriendListener: (() => void) | null = null;
const createGroupButtonText = computed(() => `创建群聊${selectedGroupMemberUIDs.value.length ? `(${selectedGroupMemberUIDs.value.length})` : ''}`);
const homeItems = computed(() => {
  const friendItems = friends.value.map(friend => ({
    key: `friend-${friend.uid}`,
    type: 'friend' as const,
    title: friendName(friend),
    avatar: friend.portrait,
    avatarText: (friendName(friend) || '员').slice(0, 1),
    peerId: String(friend.uid),
    conversation: friendConversation(friend),
  }));
  const groupItems = groups.value.map(group => ({
    key: `group-${group.group_id}`,
    type: 'group' as const,
    title: group.name,
    avatar: group.portrait,
    avatarText: (group.name || '群').slice(0, 1),
    peerId: group.group_id,
    conversation: groupConversation(group),
  }));
  return [...friendItems, ...groupItems].sort((a, b) => (b.conversation?.last_msg?.create_time || 0) - (a.conversation?.last_msg?.create_time || 0));
});

function friendConversation(friend: FriendItem) {
  return conversations.value.find(item => item.contact_type === 1 && peerUID(item) === String(friend.uid));
}

function groupConversation(group: GroupInfo) {
  return conversations.value.find(item => item.contact_type === 2 && String(item.peer_id || item.group?.group_id || '') === group.group_id);
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
  openChat({
    contactId: contact?.contact_id || '',
    type: '1',
    title: friendName(friend),
    peerId: String(friend.uid),
  });
}

function openChat(data: { contactId?: string; type: '1' | '2'; title: string; peerId: string }) {
  const params = new URLSearchParams({
    contact_id: data.contactId || '',
    type: data.type,
    title: data.title,
    peer_id: data.peerId,
  });
  uni.navigateTo({ url: `/pages/common/chat/index?${params.toString()}` });
}

function openHomeItem(item: HomeItem) {
  openChat({
    contactId: item.conversation?.contact_id || '',
    type: item.type === 'group' ? '2' : '1',
    title: item.title,
    peerId: item.peerId,
  });
}

function toggleGroupForm() {
  showGroupForm.value = !showGroupForm.value;
}

function toggleGroupMember(friend: FriendItem) {
  const uid = String(friend.uid);
  selectedGroupMemberUIDs.value = selectedGroupMemberUIDs.value.includes(uid)
    ? selectedGroupMemberUIDs.value.filter(item => item !== uid)
    : [...selectedGroupMemberUIDs.value, uid];
}

function isGroupMemberSelected(friend: FriendItem) {
  return selectedGroupMemberUIDs.value.includes(String(friend.uid));
}

function friendName(friend: FriendItem) {
  return friend.remark || friend.nick || `用户 ${friend.uid}`;
}

function selectedFriends() {
  return friends.value.filter(friend => selectedGroupMemberUIDs.value.includes(String(friend.uid)));
}

function defaultGroupName() {
  const list = selectedFriends();
  const names = list.slice(0, 3).map(friendName).join('、');
  return `${names}${list.length > 3 ? '...' : ''}`;
}

async function createGroup() {
  if (!selectedGroupMemberUIDs.value.length)
    return uni.$u.toast('请选择群成员');
  const selected = selectedFriends();
  if (selected.length === 1) {
    selectedGroupMemberUIDs.value = [];
    showGroupForm.value = false;
    openFriend(selected[0]);
    return;
  }
  try {
    const group = await IMApi.createGroup({ name: defaultGroupName(), member_uids: selectedGroupMemberUIDs.value });
    selectedGroupMemberUIDs.value = [];
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
    const [conversationRes, friendRes, groupRes] = await Promise.all([
      IMApi.conversations(),
      IMApi.friends(),
      IMApi.groups(),
    ]);
    conversations.value = conversationRes.contacts;
    friends.value = friendRes.list;
    groups.value = groupRes.list;
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

type HomeItem = typeof homeItems.value[number];
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

.member-picker {
  overflow-y: auto;
  max-height: 280px;
  background: #fff;
  border: 1px solid #edf0f5;
  border-radius: 8px;
}

.member-row {
  display: flex;
  align-items: center;
  min-height: 54px;
  padding: 9px 10px;
  box-sizing: border-box;
}

.member-row + .member-row {
  border-top: 1px solid #edf0f5;
}

.member-name {
  overflow: hidden;
  flex: 1;
  color: #172033;
  font-size: 15px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.check-dot {
  width: 20px;
  height: 20px;
  border: 1px solid #c8cfda;
  border-radius: 50%;
  box-sizing: border-box;
}

.check-dot.checked {
  border: 6px solid #21d59d;
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
