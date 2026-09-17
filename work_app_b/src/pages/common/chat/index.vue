<template>
  <view class="chat-page">
    <view class="chat-header">
      <u-icon name="arrow-left" size="22" @click="back" />
      <text class="chat-title">{{ title }}</text>
      <u-button v-if="options.type === '2'" size="mini" text="群设置" @click="openGroupSettings" />
    </view>

    <scroll-view class="messages" scroll-y :scroll-into-view="lastMessageId">
      <view v-if="orderedMessages.length === 0" class="empty-chat">
        <view class="empty-title">开始聊天</view>
        <view class="empty-subtitle">给 {{ title }} 发送第一条消息</view>
      </view>
      <view
        v-for="message in orderedMessages"
        :id="`msg-${message.msg_id}`"
        :key="message.msg_id"
        class="message-row"
        :class="{ mine: isMine(message) }"
      >
        <u-avatar
          v-if="!isMine(message)"
          :src="senderAvatar(message)"
          :text="senderName(message).slice(0, 1)"
          size="36"
          custom-style="margin-right: 8px"
        />
        <view class="message-main">
          <view v-if="options.type === '2' && !isMine(message)" class="sender-name">{{ senderName(message) }}</view>
          <view class="bubble" @longpress="recall(message)">
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
          :text="(session?.nick || '我').slice(0, 1)"
          size="36"
          custom-style="margin-left: 8px"
        />
      </view>
    </scroll-view>

    <view class="composer">
      <u-button class="tool-button" text="+" @click="sendImage" />
      <u-input v-model="draft" placeholder="输入消息" border="none" confirm-type="send" @confirm="send" />
      <u-button type="primary" text="发送" @click="send" />
    </view>
  </view>
</template>

<script setup lang="ts">
import type { ChatMessage } from '@/api/im';
import { IMApi } from '@/api';
import { uploadImage } from '@/api/im';
import { getSession } from '@/utils/auth';

const session = computed(() => getSession());
const options = ref<Record<string, string>>({});
const title = computed(() => options.value.title || '聊天');
const messages = ref<ChatMessage[]>([]);
const draft = ref('');
const lastMessageId = computed(() => {
  const last = orderedMessages.value[orderedMessages.value.length - 1];
  return last ? `msg-${last.msg_id}` : '';
});
const orderedMessages = computed(() => [...messages.value].reverse());
let removePeerListener: (() => void) | null = null;
let removeGroupListener: (() => void) | null = null;

function back() {
  uni.navigateBack();
}

function imageUrl(message: ChatMessage) {
  const url = message.content.image_content?.url;
  return Array.isArray(url) ? url[0] : url;
}

function canRecall(message: ChatMessage) {
  return message.status !== 2 && isMine(message);
}

function isMine(message: ChatMessage) {
  return String(message.sender_uid) === String(session.value?.uid || '');
}

function senderName(message: ChatMessage) {
  return message.send_user?.nick || `用户 ${message.sender_uid}`;
}

function senderAvatar(message: ChatMessage) {
  return message.send_user?.portrait;
}

function openGroupSettings() {
  const params = new URLSearchParams({
    group_id: options.value.peer_id,
    title: title.value,
  });
  uni.navigateTo({ url: `/pages/common/group/index?${params.toString()}` });
}

function previewImage(message: ChatMessage) {
  const url = imageUrl(message);
  if (url)
    uni.previewImage({ urls: [url] });
}

async function loadMessages() {
  const peer_id = options.value.peer_id;
  let res;
  try {
    res = await IMApi.messages({ contact_id: options.value.contact_id, peer_id, direction: 0 });
  }
  catch (error: any) {
    if (!options.value.contact_id && String(error?.message || '').includes('contact not found')) {
      messages.value = [];
      return;
    }
    uni.$u.toast(error?.message || '获取消息列表失败');
    return;
  }
  messages.value = res.list;
  const last = res.list[0];
  if (!options.value.contact_id && last?.contact_id)
    options.value.contact_id = last.contact_id;
  const contact_id = options.value.contact_id;
  if (contact_id && last?.msg_id) {
    if (options.value.type === '2')
      await IMApi.groupRead({ contact_id, msg_id: last.msg_id });
    else
      await IMApi.peerRead({ contact_id, peer_id, msg_id: last.msg_id });
  }
}

async function recall(message: ChatMessage) {
  if (!canRecall(message) || !options.value.contact_id)
    return;
  if (options.value.type === '2')
    await IMApi.recallGroup({ contact_id: options.value.contact_id, msg_id: message.msg_id });
  else
    await IMApi.recallPeer({ contact_id: options.value.contact_id, msg_id: message.msg_id });
  await loadMessages();
}

async function send() {
  const text = draft.value.trim();
  if (!text)
    return;
  draft.value = '';
  if (options.value.type === '2') {
    const message = await IMApi.sendGroup({ group_id: options.value.peer_id, text });
    options.value.contact_id = message.contact_id || options.value.contact_id;
  }
  else {
    const message = await IMApi.sendPeer({
      receiver_uid: options.value.peer_id,
      contact_id: options.value.contact_id,
      text,
    });
    options.value.contact_id = message.contact_id || options.value.contact_id;
  }
  await loadMessages();
}

async function sendImage() {
  const chooseResult = await uni.chooseImage({ count: 1 });
  const filePath = chooseResult.tempFilePaths[0];
  if (!filePath)
    return;
  const url = await uploadImage(filePath);
  if (options.value.type === '2') {
    const message = await IMApi.sendGroupImage({ group_id: options.value.peer_id, url });
    options.value.contact_id = message.contact_id || options.value.contact_id;
  }
  else {
    const message = await IMApi.sendPeerImage({
      receiver_uid: options.value.peer_id,
      contact_id: options.value.contact_id,
      url,
    });
    options.value.contact_id = message.contact_id || options.value.contact_id;
  }
  await loadMessages();
}

function bindRealtime() {
  removePeerListener?.();
  removeGroupListener?.();
  const peerHandler = (payload: any) => {
    if (options.value.type !== '1')
      return;
    const info = payload?.info;
    const contactId = info?.contact_id;
    if (contactId && options.value.contact_id && String(contactId) !== options.value.contact_id)
      return;
    loadMessages();
  };
  const groupHandler = (payload: any) => {
    if (options.value.type !== '2')
      return;
    if (payload?.group_id && String(payload.group_id) !== options.value.peer_id)
      return;
    loadMessages();
  };
  uni.$on('im.peer', peerHandler);
  uni.$on('im.group', groupHandler);
  removePeerListener = () => uni.$off('im.peer', peerHandler);
  removeGroupListener = () => uni.$off('im.group', groupHandler);
}

onLoad((query) => {
  options.value = Object.fromEntries(Object.entries(query || {}).map(([key, value]) => [key, String(value)]));
  uni.setNavigationBarTitle({ title: title.value });
  bindRealtime();
  loadMessages();
});

onUnload(() => {
  removePeerListener?.();
  removeGroupListener?.();
});
</script>

<style scoped lang="scss">
.chat-page {
  min-height: 100vh;
  padding-top: env(safe-area-inset-top);
  background: #f6f7fb;
  box-sizing: border-box;
}

.chat-header {
  display: flex;
  align-items: center;
  gap: 12px;
  height: 56px;
  padding: 0 12px;
  background: #fff;
  box-sizing: border-box;
}

.chat-title {
  flex: 1;
  overflow: hidden;
  color: #172033;
  font-size: 17px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.messages {
  height: calc(100vh - 56px - 66px - env(safe-area-inset-top) - env(safe-area-inset-bottom));
  padding: 16px 12px;
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
  max-width: 78%;
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
  line-height: 16px;
}

.bubble {
  padding: 10px 12px;
  color: #172033;
  font-size: 16px;
  line-height: 1.5;
  background: #fff;
  border-radius: 4px 14px 14px;
  box-shadow: 0 1px 2px rgba(28, 38, 64, 0.04);
  word-break: break-word;
}

.mine .bubble {
  color: #fff;
  background: #1f7aff;
  border-radius: 14px 4px 14px 14px;
}

.composer {
  position: fixed;
  right: 0;
  bottom: 0;
  left: 0;
  z-index: 10;
  display: grid;
  grid-template-columns: auto 1fr auto;
  align-items: center;
  gap: 10px;
  padding: 10px 10px calc(10px + env(safe-area-inset-bottom));
  background: #f7f8fb;
  border-top: 1px solid #eceff5;
  box-sizing: border-box;
}

.composer :deep(.u-input) {
  min-height: 42px;
  padding: 0 12px !important;
  background: #fff;
  border-radius: 6px;
}

.tool-button {
  width: 42px;
}

.chat-image {
  display: block;
  max-width: 180px;
  border-radius: 6px;
}

.recall-btn {
  margin-top: 4px;
}

.empty-chat {
  padding-top: 28vh;
  text-align: center;
}

.empty-title {
  color: #172033;
  font-size: 16px;
  font-weight: 700;
}

.empty-subtitle {
  margin-top: 8px;
  color: #9aa3b5;
  font-size: 13px;
}
</style>
