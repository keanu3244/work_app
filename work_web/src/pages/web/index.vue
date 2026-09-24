<template>
  <view class="web-shell">
    <aside class="rail">
      <view class="brand">
        <image class="brand-logo" src="/static/images/logo.png" mode="aspectFill" />
        <text class="brand-name">Work IM</text>
      </view>
      <view
        v-for="item in navItems"
        :key="item.key"
        class="nav-item"
        :class="{ active: activeNav === item.key }"
        @click="activeNav = item.key"
      >
        <u-icon :name="item.icon" size="20" />
        <text>{{ item.label }}</text>
      </view>
      <view class="rail-spacer" />
      <view class="session-card">
        <u-avatar :text="sessionInitial" size="38" />
        <view class="session-main">
          <text class="session-name">{{ session?.nick || '员工' }}</text>
          <text class="session-uid">UID {{ session?.uid || '-' }}</text>
        </view>
      </view>
      <u-button size="small" text="退出登录" @click="logout" />
    </aside>

    <section class="panel">
      <template v-if="activeNav === 'messages'">
        <view class="panel-header">
          <view>
            <view class="panel-title">消息</view>
            <view class="panel-subtitle">会话、好友和群聊</view>
          </view>
          <u-button size="small" type="primary" text="刷新" @click="loadWorkspace" />
        </view>
        <scroll-view scroll-y class="list-scroll">
          <view
            v-for="item in conversationItems"
            :key="item.key"
            class="conversation-row"
            :class="{ active: activeItem?.key === item.key }"
            @click="selectItem(item)"
          >
            <u-avatar :src="item.avatar" :text="item.avatarText" size="42" custom-style="margin-right: 10px" />
            <view class="row-main">
              <view class="row-top">
                <text class="row-title">{{ item.title }}</text>
                <text class="row-time">{{ conversationTime(item.conversation?.last_msg?.create_time) }}</text>
              </view>
              <view class="row-bottom">
                <text class="row-preview">{{ messagePreview(item.conversation?.last_msg) }}</text>
                <u-badge v-if="item.conversation?.unread_count" :value="item.conversation.unread_count" />
              </view>
            </view>
          </view>
          <u-empty v-if="!conversationItems.length && !loading" text="暂无会话" mode="list" />
        </scroll-view>
      </template>

      <template v-else-if="activeNav === 'contacts'">
        <view class="panel-header">
          <view>
            <view class="panel-title">通讯录</view>
            <view class="panel-subtitle">好友申请、好友与群聊</view>
          </view>
          <u-button size="small" text="刷新" @click="loadWorkspace" />
        </view>
        <u-tabs :list="contactTabs" :current="contactTab" @click="onContactTabClick" />
        <scroll-view scroll-y class="list-scroll with-tabs">
          <view v-if="contactTab === 0" class="tool-card">
            <view class="inline-form">
              <u-input v-model="friendUid" placeholder="输入员工 UID" border="surround" type="number" />
              <u-button type="primary" text="添加好友" @click="applyFriend" />
            </view>
            <view
              v-for="friend in friends"
              :key="String(friend.uid)"
              class="plain-row"
              @click="selectFriend(friend)"
            >
              <u-avatar :src="friend.portrait" :text="friendName(friend).slice(0, 1)" size="38" custom-style="margin-right: 10px" />
              <text>{{ friendName(friend) }}</text>
            </view>
            <u-empty v-if="!friends.length" text="暂无好友" mode="list" />
          </view>

          <view v-else-if="contactTab === 1" class="tool-card">
            <view
              v-for="request in requests"
              :key="request.request_id"
              class="request-row"
            >
              <view>
                <view class="request-title">{{ request.user?.nick || `用户 ${request.from_uid}` }}</view>
                <view class="request-note">{{ request.note || '好友申请' }}</view>
              </view>
              <view v-if="request.status === 0" class="row-actions">
                <u-button size="mini" type="primary" text="同意" @click="handleRequest(request.request_id, true)" />
                <u-button size="mini" text="拒绝" @click="handleRequest(request.request_id, false)" />
              </view>
              <text v-else class="muted">{{ request.status === 1 ? '已同意' : '已拒绝' }}</text>
            </view>
            <u-empty v-if="!requests.length" text="暂无申请" mode="list" />
          </view>

          <view v-else class="tool-card">
            <u-input v-model="groupName" placeholder="群名称，不填则自动生成" border="surround" />
            <view class="member-picker">
              <view
                v-for="friend in friends"
                :key="String(friend.uid)"
                class="member-row"
                @click="toggleGroupMember(friend)"
              >
                <u-avatar :src="friend.portrait" :text="friendName(friend).slice(0, 1)" size="34" custom-style="margin-right: 10px" />
                <text class="member-name">{{ friendName(friend) }}</text>
                <view class="check-dot" :class="{ checked: isGroupMemberSelected(friend) }" />
              </view>
            </view>
            <u-button type="primary" :text="createGroupButtonText" @click="createGroup" />
            <view
              v-for="group in groups"
              :key="group.group_id"
              class="plain-row"
              @click="selectGroup(group)"
            >
              <u-avatar :src="group.portrait" :text="(group.name || '群').slice(0, 1)" size="38" custom-style="margin-right: 10px" />
              <view>
                <view>{{ group.name }}</view>
                <view class="muted">{{ group.member_count }} 人</view>
              </view>
            </view>
          </view>
        </scroll-view>
      </template>

      <template v-else>
        <view class="panel-header">
          <view>
            <view class="panel-title">设置</view>
            <view class="panel-subtitle">账号与黑名单</view>
          </view>
          <u-button size="small" text="刷新" @click="loadBlocks" />
        </view>
        <scroll-view scroll-y class="list-scroll">
          <view class="tool-card">
            <view class="setting-line">
              <text>昵称</text>
              <text>{{ session?.nick || '-' }}</text>
            </view>
            <view class="setting-line">
              <text>UID</text>
              <text>{{ session?.uid || '-' }}</text>
            </view>
          </view>
          <view class="tool-card">
            <view class="card-title">黑名单</view>
            <view
              v-for="block in blocks"
              :key="String(block.uid)"
              class="plain-row"
            >
              <text>{{ block.nick || block.uid }}</text>
              <u-button size="mini" text="解除" @click="unblock(String(block.uid))" />
            </view>
            <u-empty v-if="!blocks.length" text="黑名单为空" mode="list" />
          </view>
        </scroll-view>
      </template>
    </section>

    <main class="chat">
      <template v-if="activeItem">
        <view class="chat-header">
          <view>
            <view class="chat-title">{{ activeItem.title }}</view>
            <view class="chat-subtitle">{{ activeItem.type === 'group' ? '群聊' : `UID ${activeItem.peerId}` }}</view>
          </view>
          <view class="chat-actions">
            <u-button v-if="activeItem.type === 'friend'" size="small" text="拉黑" @click="blockActivePeer" />
            <u-button v-if="activeItem.type === 'group'" size="small" text="群公告" @click="showGroupTools = !showGroupTools" />
          </view>
        </view>

        <view v-if="showGroupTools && activeItem.type === 'group'" class="group-tools">
          <u-textarea v-model="announcementDraft" placeholder="群公告" height="90" />
          <u-button size="small" type="primary" text="保存公告" @click="saveAnnouncement" />
        </view>

        <scroll-view class="messages" scroll-y :scroll-into-view="lastMessageId">
          <view
            v-for="message in orderedMessages"
            :id="`msg-${message.msg_id}`"
            :key="message.msg_id"
            class="message-row"
            :class="{ mine: isMine(message) }"
          >
            <u-avatar
              v-if="!isMine(message)"
              :src="message.send_user?.portrait"
              :text="senderName(message).slice(0, 1)"
              size="34"
              custom-style="margin-right: 8px"
            />
            <view class="message-main">
              <view v-if="activeItem.type === 'group' && !isMine(message)" class="sender-name">{{ senderName(message) }}</view>
              <view class="bubble">
                <text v-if="message.status === 2">消息已撤回</text>
                <image v-else-if="imageUrl(message)" class="chat-image" :src="imageUrl(message)" mode="widthFix" @click="previewImage(message)" />
                <text v-else>{{ message.content.text_content?.content || '[非文本消息]' }}</text>
              </view>
              <u-button
                v-if="canRecall(message)"
                class="recall-btn"
                size="mini"
                text="撤回"
                @click="recall(message)"
              />
            </view>
            <u-avatar
              v-if="isMine(message)"
              :text="sessionInitial"
              size="34"
              custom-style="margin-left: 8px"
            />
          </view>
          <u-empty v-if="!messages.length && !loadingMessages" text="暂无消息" mode="chat" />
        </scroll-view>

        <view class="composer">
          <u-button class="icon-button" text="+" @click="sendImage" />
          <textarea
            v-model="draft"
            class="composer-input"
            placeholder="输入消息，Enter 发送，Shift + Enter 换行"
            :adjust-position="false"
            @keydown.enter.exact.prevent="send"
          />
          <u-button type="primary" text="发送" @click="send" />
        </view>
      </template>
      <view v-else class="blank-chat">
        <u-empty text="请选择一个会话" mode="chat" />
      </view>
    </main>
  </view>
</template>

<script setup lang="ts">
import type { ChatMessage, Conversation, FriendItem, FriendRequestItem, GroupInfo, UserBasic } from '@/api/im';
import { IMApi, uploadImage } from '@/api/im';
import { disconnectRealtime, setupRealtime } from '@/services/realtime';
import { clearToken, getSession, isLogin } from '@/utils/auth';

type NavKey = 'messages' | 'contacts' | 'settings';
type ConversationItem = {
  key: string;
  type: 'friend' | 'group';
  title: string;
  avatar?: string;
  avatarText: string;
  peerId: string;
  conversation?: Conversation;
  source: FriendItem | GroupInfo;
};

const navItems = [
  { key: 'messages' as NavKey, label: '消息', icon: 'chat' },
  { key: 'contacts' as NavKey, label: '通讯录', icon: 'account' },
  { key: 'settings' as NavKey, label: '设置', icon: 'setting' },
];
const contactTabs = [{ name: '好友' }, { name: '申请' }, { name: '群聊' }];
const activeNav = ref<NavKey>('messages');
const contactTab = ref(0);
const session = computed(() => getSession());
const sessionInitial = computed(() => (session.value?.nick || '我').slice(0, 1));
const loading = ref(false);
const loadingMessages = ref(false);
const conversations = ref<Conversation[]>([]);
const friends = ref<FriendItem[]>([]);
const requests = ref<FriendRequestItem[]>([]);
const groups = ref<GroupInfo[]>([]);
const blocks = ref<UserBasic[]>([]);
const activeItem = ref<ConversationItem | null>(null);
const messages = ref<ChatMessage[]>([]);
const draft = ref('');
const friendUid = ref('');
const groupName = ref('');
const selectedGroupMemberUIDs = ref<string[]>([]);
const showGroupTools = ref(false);
const announcementDraft = ref('');
let removePeerListener: (() => void) | null = null;
let removeGroupListener: (() => void) | null = null;
let removeFriendListener: (() => void) | null = null;

function friendName(friend: FriendItem) {
  return friend.remark || friend.nick || `用户 ${friend.uid}`;
}

function peerUID(item: Conversation) {
  return String(item.peer_id || item.peer_user?.uid || '');
}

function friendConversation(friend: FriendItem) {
  return conversations.value.find(item => item.contact_type === 1 && peerUID(item) === String(friend.uid));
}

function groupConversation(group: GroupInfo) {
  return conversations.value.find(item => item.contact_type === 2 && String(item.peer_id || item.group?.group_id || '') === group.group_id);
}

function messagePreview(message?: ChatMessage) {
  if (!message)
    return '暂无消息';
  if (message.status === 2)
    return '消息已撤回';
  return message.content.text_content?.content || (message.content.image_content ? '[图片]' : '[非文本消息]');
}

function conversationTime(time?: number) {
  if (!time)
    return '';
  const date = new Date(time * 1000);
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

function imageUrl(message: ChatMessage) {
  const url = message.content.image_content?.url;
  return Array.isArray(url) ? url[0] : url;
}

function senderName(message: ChatMessage) {
  return message.send_user?.nick || `用户 ${message.sender_uid}`;
}

function isMine(message: ChatMessage) {
  return String(message.sender_uid) === String(session.value?.uid || '');
}

function canRecall(message: ChatMessage) {
  return message.status !== 2 && isMine(message);
}

const conversationItems = computed<ConversationItem[]>(() => {
  const friendItems = friends.value.map(friend => ({
    key: `friend-${friend.uid}`,
    type: 'friend' as const,
    title: friendName(friend),
    avatar: friend.portrait,
    avatarText: friendName(friend).slice(0, 1),
    peerId: String(friend.uid),
    conversation: friendConversation(friend),
    source: friend,
  }));
  const groupItems = groups.value.map(group => ({
    key: `group-${group.group_id}`,
    type: 'group' as const,
    title: group.name,
    avatar: group.portrait,
    avatarText: (group.name || '群').slice(0, 1),
    peerId: group.group_id,
    conversation: groupConversation(group),
    source: group,
  }));
  return [...friendItems, ...groupItems].sort((a, b) => (b.conversation?.last_msg?.create_time || 0) - (a.conversation?.last_msg?.create_time || 0));
});
const orderedMessages = computed(() => [...messages.value].reverse());
const lastMessageId = computed(() => {
  const last = orderedMessages.value[orderedMessages.value.length - 1];
  return last ? `msg-${last.msg_id}` : '';
});
const createGroupButtonText = computed(() => `创建群聊${selectedGroupMemberUIDs.value.length ? `(${selectedGroupMemberUIDs.value.length})` : ''}`);

function onContactTabClick(item: { index: number }) {
  contactTab.value = item.index;
}

function selectedFriends() {
  return friends.value.filter(friend => selectedGroupMemberUIDs.value.includes(String(friend.uid)));
}

function defaultGroupName() {
  const selected = selectedFriends();
  const names = selected.slice(0, 3).map(friendName).join('、');
  return groupName.value.trim() || `${names}${selected.length > 3 ? '...' : ''}`;
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

function selectItem(item: ConversationItem) {
  activeItem.value = item;
  showGroupTools.value = false;
  announcementDraft.value = item.type === 'group' ? (item.source as GroupInfo).announcement || '' : '';
  loadMessages();
}

function selectFriend(friend: FriendItem) {
  activeNav.value = 'messages';
  selectItem({
    key: `friend-${friend.uid}`,
    type: 'friend',
    title: friendName(friend),
    avatar: friend.portrait,
    avatarText: friendName(friend).slice(0, 1),
    peerId: String(friend.uid),
    conversation: friendConversation(friend),
    source: friend,
  });
}

function selectGroup(group: GroupInfo) {
  activeNav.value = 'messages';
  selectItem({
    key: `group-${group.group_id}`,
    type: 'group',
    title: group.name,
    avatar: group.portrait,
    avatarText: (group.name || '群').slice(0, 1),
    peerId: group.group_id,
    conversation: groupConversation(group),
    source: group,
  });
}

async function loadWorkspace() {
  loading.value = true;
  try {
    const [conversationRes, friendRes, requestRes, groupRes] = await Promise.all([
      IMApi.conversations(),
      IMApi.friends(),
      IMApi.friendRequests('inbox'),
      IMApi.groups(),
    ]);
    conversations.value = conversationRes.contacts;
    friends.value = friendRes.list;
    requests.value = requestRes.list;
    groups.value = groupRes.list;
    if (!activeItem.value && conversationItems.value.length)
      selectItem(conversationItems.value[0]);
    else if (activeItem.value) {
      const fresh = conversationItems.value.find(item => item.key === activeItem.value?.key);
      if (fresh)
        activeItem.value = fresh;
    }
  }
  catch (error: any) {
    uni.$u.toast(error?.message || '加载失败');
  }
  finally {
    loading.value = false;
  }
}

async function loadMessages() {
  if (!activeItem.value)
    return;
  loadingMessages.value = true;
  try {
    const res = await IMApi.messages({
      contact_id: activeItem.value.conversation?.contact_id,
      peer_id: activeItem.value.peerId,
      direction: 0,
    });
    messages.value = res.list;
    const last = res.list[0];
    if (!activeItem.value.conversation && last?.contact_id)
      activeItem.value.conversation = { contact_id: last.contact_id } as Conversation;
    const contactId = activeItem.value.conversation?.contact_id || last?.contact_id;
    if (contactId && last?.msg_id) {
      if (activeItem.value.type === 'group')
        await IMApi.groupRead({ contact_id: contactId, msg_id: last.msg_id });
      else
        await IMApi.peerRead({ contact_id: contactId, peer_id: activeItem.value.peerId, msg_id: last.msg_id });
    }
  }
  catch (error: any) {
    if (String(error?.message || '').includes('contact not found')) {
      messages.value = [];
      return;
    }
    uni.$u.toast(error?.message || '获取消息失败');
  }
  finally {
    loadingMessages.value = false;
  }
}

async function send() {
  const text = draft.value.trim();
  if (!text || !activeItem.value)
    return;
  draft.value = '';
  if (activeItem.value.type === 'group') {
    const message = await IMApi.sendGroup({ group_id: activeItem.value.peerId, text });
    activeItem.value.conversation = { ...(activeItem.value.conversation || {}), contact_id: message.contact_id } as Conversation;
  }
  else {
    const message = await IMApi.sendPeer({
      receiver_uid: activeItem.value.peerId,
      contact_id: activeItem.value.conversation?.contact_id,
      text,
    });
    activeItem.value.conversation = { ...(activeItem.value.conversation || {}), contact_id: message.contact_id } as Conversation;
  }
  await Promise.all([loadMessages(), loadWorkspace()]);
}

async function sendImage() {
  if (!activeItem.value)
    return;
  const chooseResult = await uni.chooseImage({ count: 1 });
  const filePath = chooseResult.tempFilePaths[0];
  if (!filePath)
    return;
  const url = await uploadImage(filePath);
  if (activeItem.value.type === 'group') {
    const message = await IMApi.sendGroupImage({ group_id: activeItem.value.peerId, url });
    activeItem.value.conversation = { ...(activeItem.value.conversation || {}), contact_id: message.contact_id } as Conversation;
  }
  else {
    const message = await IMApi.sendPeerImage({
      receiver_uid: activeItem.value.peerId,
      contact_id: activeItem.value.conversation?.contact_id,
      url,
    });
    activeItem.value.conversation = { ...(activeItem.value.conversation || {}), contact_id: message.contact_id } as Conversation;
  }
  await Promise.all([loadMessages(), loadWorkspace()]);
}

async function recall(message: ChatMessage) {
  const contactId = activeItem.value?.conversation?.contact_id;
  if (!activeItem.value || !contactId || !canRecall(message))
    return;
  if (activeItem.value.type === 'group')
    await IMApi.recallGroup({ contact_id: contactId, msg_id: message.msg_id });
  else
    await IMApi.recallPeer({ contact_id: contactId, msg_id: message.msg_id });
  await loadMessages();
}

function previewImage(message: ChatMessage) {
  const url = imageUrl(message);
  if (url)
    uni.previewImage({ urls: [url] });
}

async function applyFriend() {
  const uid = friendUid.value.trim();
  if (!/^\d+$/.test(uid))
    return uni.$u.toast('请输入 UID');
  await IMApi.applyFriend({ to_uid: uid, note: '我是你的同事' });
  friendUid.value = '';
  uni.$u.toast('已发送申请');
}

async function handleRequest(requestId: string, accept: boolean) {
  await IMApi.handleFriend({ request_id: requestId, accept });
  await loadWorkspace();
}

async function createGroup() {
  if (!selectedGroupMemberUIDs.value.length)
    return uni.$u.toast('请选择群成员');
  const selected = selectedFriends();
  if (selected.length === 1) {
    selectedGroupMemberUIDs.value = [];
    selectFriend(selected[0]);
    return;
  }
  const group = await IMApi.createGroup({ name: defaultGroupName(), member_uids: selectedGroupMemberUIDs.value });
  selectedGroupMemberUIDs.value = [];
  groupName.value = '';
  await loadWorkspace();
  selectGroup(group);
}

async function saveAnnouncement() {
  if (!activeItem.value || activeItem.value.type !== 'group')
    return;
  await IMApi.updateGroup({ group_id: activeItem.value.peerId, announcement: announcementDraft.value });
  uni.$u.toast('已保存');
  await loadWorkspace();
}

async function blockActivePeer() {
  if (!activeItem.value || activeItem.value.type !== 'friend')
    return;
  await IMApi.blockUser(activeItem.value.peerId);
  uni.$u.toast('已拉黑');
  await loadBlocks();
}

async function loadBlocks() {
  const res = await IMApi.blockList();
  blocks.value = res.list;
}

async function unblock(uid: string) {
  await IMApi.unblockUser(uid);
  await loadBlocks();
}

function bindRealtime() {
  if (removePeerListener)
    return;
  const reloadActive = () => {
    loadWorkspace();
    loadMessages();
  };
  const reloadAll = () => loadWorkspace();
  uni.$on('im.peer', reloadActive);
  uni.$on('im.group', reloadActive);
  uni.$on('im.friend', reloadAll);
  removePeerListener = () => uni.$off('im.peer', reloadActive);
  removeGroupListener = () => uni.$off('im.group', reloadActive);
  removeFriendListener = () => uni.$off('im.friend', reloadAll);
}

function logout() {
  disconnectRealtime();
  clearToken();
  uni.reLaunch({ url: '/pages/common/login/index' });
}

onShow(() => {
  if (!isLogin()) {
    uni.redirectTo({ url: '/pages/common/login/index?redirect=/pages/web/index' });
    return;
  }
  setupRealtime();
  bindRealtime();
  loadWorkspace();
  loadBlocks();
});

onUnload(() => {
  removePeerListener?.();
  removeGroupListener?.();
  removeFriendListener?.();
});
</script>

<style scoped lang="scss">
.web-shell {
  display: grid;
  width: 100vw;
  height: 100vh;
  grid-template-columns: 220px 360px minmax(0, 1fr);
  overflow: hidden;
  color: #172033;
  background: #eef2f7;
}

.rail {
  display: flex;
  min-width: 0;
  flex-direction: column;
  gap: 8px;
  padding: 18px 14px;
  background: #172033;
  box-sizing: border-box;
}

.brand {
  display: flex;
  align-items: center;
  gap: 10px;
  height: 44px;
  margin-bottom: 16px;
}

.brand-logo {
  width: 34px;
  height: 34px;
  border-radius: 8px;
}

.brand-name {
  color: #fff;
  font-size: 18px;
  font-weight: 700;
}

.nav-item {
  display: flex;
  align-items: center;
  gap: 10px;
  height: 42px;
  padding: 0 12px;
  color: #b8c1d4;
  border-radius: 6px;
  cursor: pointer;
  box-sizing: border-box;
}

.nav-item.active {
  color: #fff;
  background: #2563eb;
}

.rail-spacer {
  flex: 1;
}

.session-card {
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
  padding: 10px;
  background: rgba(255, 255, 255, 0.08);
  border-radius: 8px;
}

.session-main {
  display: grid;
  min-width: 0;
}

.session-name,
.session-uid {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.session-name {
  color: #fff;
  font-size: 14px;
}

.session-uid {
  color: #9aa6bd;
  font-size: 12px;
}

.panel {
  min-width: 0;
  background: #f8fafc;
  border-right: 1px solid #dfe5ee;
}

.panel-header,
.chat-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  height: 76px;
  padding: 0 18px;
  background: #fff;
  border-bottom: 1px solid #e5eaf2;
  box-sizing: border-box;
}

.panel-title,
.chat-title {
  color: #172033;
  font-size: 20px;
  font-weight: 700;
  line-height: 26px;
}

.panel-subtitle,
.chat-subtitle,
.muted {
  color: #7a8499;
  font-size: 12px;
  line-height: 18px;
}

.list-scroll {
  height: calc(100vh - 76px);
}

.list-scroll.with-tabs {
  height: calc(100vh - 120px);
}

.conversation-row,
.plain-row,
.request-row,
.member-row {
  display: flex;
  align-items: center;
  min-height: 64px;
  padding: 10px 14px;
  background: #fff;
  border-bottom: 1px solid #edf1f6;
  cursor: pointer;
  box-sizing: border-box;
}

.conversation-row.active {
  background: #eaf2ff;
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
  gap: 8px;
}

.row-title,
.row-preview {
  overflow: hidden;
  flex: 1;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.row-title {
  font-size: 15px;
  font-weight: 700;
}

.row-preview,
.row-time {
  color: #8a94a6;
  font-size: 12px;
}

.tool-card {
  display: grid;
  gap: 10px;
  margin: 12px;
  padding: 12px;
  background: #fff;
  border: 1px solid #e5eaf2;
  border-radius: 8px;
}

.inline-form {
  display: grid;
  grid-template-columns: 1fr auto;
  gap: 8px;
}

.request-row {
  justify-content: space-between;
  border: 1px solid #edf1f6;
  border-radius: 8px;
}

.request-title {
  font-size: 14px;
  font-weight: 700;
}

.request-note {
  margin-top: 4px;
  color: #7a8499;
  font-size: 12px;
}

.row-actions,
.chat-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.member-picker {
  overflow-y: auto;
  max-height: 260px;
  border: 1px solid #edf1f6;
  border-radius: 8px;
}

.member-name {
  flex: 1;
}

.check-dot {
  width: 18px;
  height: 18px;
  border: 1px solid #c8cfda;
  border-radius: 50%;
  box-sizing: border-box;
}

.check-dot.checked {
  border: 5px solid #2563eb;
}

.card-title {
  font-weight: 700;
}

.setting-line {
  display: flex;
  justify-content: space-between;
  gap: 16px;
  min-height: 34px;
  align-items: center;
}

.chat {
  display: grid;
  min-width: 0;
  grid-template-rows: auto auto minmax(0, 1fr) auto;
  background: #f3f6fb;
}

.group-tools {
  display: grid;
  gap: 10px;
  padding: 12px 18px;
  background: #fff;
  border-bottom: 1px solid #e5eaf2;
}

.messages {
  min-height: 0;
  padding: 20px 24px;
  box-sizing: border-box;
}

.message-row {
  display: flex;
  align-items: flex-start;
  margin-bottom: 14px;
}

.message-row.mine {
  justify-content: flex-end;
}

.message-main {
  display: flex;
  max-width: min(620px, 72%);
  flex-direction: column;
  align-items: flex-start;
}

.mine .message-main {
  align-items: flex-end;
}

.sender-name {
  margin-bottom: 4px;
  color: #8a94a6;
  font-size: 12px;
}

.bubble {
  padding: 10px 12px;
  color: #172033;
  font-size: 15px;
  line-height: 1.5;
  background: #fff;
  border-radius: 6px 14px 14px;
  box-shadow: 0 1px 2px rgba(28, 38, 64, 0.04);
  word-break: break-word;
}

.mine .bubble {
  color: #fff;
  background: #2563eb;
  border-radius: 14px 6px 14px 14px;
}

.chat-image {
  display: block;
  max-width: 240px;
  border-radius: 6px;
}

.recall-btn {
  margin-top: 4px;
}

.composer {
  display: grid;
  grid-template-columns: 44px minmax(180px, 720px) 96px;
  gap: 8px;
  align-items: center;
  justify-content: center;
  padding: 12px 24px;
  background: #fff;
  border-top: 1px solid #e5eaf2;
  box-shadow: 0 -10px 24px rgba(20, 35, 58, 0.04);
}

.icon-button {
  width: 44px;
  height: 44px;
}

.composer-input {
  width: 100%;
  min-height: 44px;
  max-height: 92px;
  padding: 10px 14px;
  color: #172033;
  font-size: 15px;
  line-height: 22px;
  background: #f8fafc;
  border: 1px solid #d7dee9;
  border-radius: 6px;
  box-sizing: border-box;
  outline: none;
  resize: none;
  transition: border-color 0.15s ease, box-shadow 0.15s ease;
}

.composer-input:focus {
  border-color: #2563eb;
  box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.12);
}

.blank-chat {
  display: flex;
  min-height: 100vh;
  align-items: center;
  justify-content: center;
}

@media (max-width: 900px) {
  .web-shell {
    grid-template-columns: 72px minmax(0, 1fr);
  }

  .rail {
    padding: 12px 8px;
  }

  .brand-name,
  .nav-item text,
  .session-main {
    display: none;
  }

  .panel {
    display: none;
  }

  .composer {
    grid-template-columns: 40px minmax(0, 1fr) 72px;
    padding: 10px 12px;
  }
}
</style>
