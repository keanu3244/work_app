<template>
  <view class="page">
    <u-tabs :list="tabs" :current="current" @click="onTabClick" />

    <view v-if="current === 0" class="section">
      <u-cell-group>
        <u-cell v-for="friend in friends" :key="String(friend.uid)" :title="friend.remark || friend.nick || `用户 ${friend.uid}`" is-link @click="openPeer(friend)">
          <template #icon>
            <u-avatar :text="(friend.remark || friend.nick || '员').slice(0, 1)" :src="friend.portrait" size="38" custom-style="margin-right: 10px" />
          </template>
        </u-cell>
      </u-cell-group>
      <u-empty v-if="friends.length === 0" text="暂无好友" mode="list" />
    </view>

    <view v-if="current === 1" class="section">
      <view class="inline-form">
        <u-input v-model="friendUid" placeholder="输入员工 UID" border="surround" type="number" />
        <u-button type="primary" text="添加" @click="applyFriend" />
      </view>
      <u-cell-group>
        <u-cell v-for="item in requests" :key="item.request_id" :title="item.user?.nick || `用户 ${item.from_uid}`" :label="item.note || '好友申请'">
          <template #value>
            <view v-if="item.status === 0" class="actions">
              <u-button size="mini" type="primary" text="同意" @click="handleRequest(item.request_id, true)" />
              <u-button size="mini" text="拒绝" @click="handleRequest(item.request_id, false)" />
            </view>
            <text v-else>{{ item.status === 1 ? '已同意' : '已拒绝' }}</text>
          </template>
        </u-cell>
      </u-cell-group>
    </view>

    <view v-if="current === 2" class="section">
      <view class="inline-form">
        <u-input v-model="groupName" placeholder="群名称" border="surround" />
        <u-input v-model="groupMembers" placeholder="成员 UID，逗号分隔" border="surround" />
        <u-button type="primary" text="建群" @click="createGroup" />
      </view>
      <u-cell-group>
        <u-cell v-for="group in groups" :key="group.group_id" :title="group.name" :label="`${group.member_count} 人`" is-link @click="openGroup(group)" />
      </u-cell-group>
      <u-empty v-if="groups.length === 0" text="暂无群聊" mode="list" />
    </view>
  </view>
</template>

<script setup lang="ts">
import type { FriendItem, FriendRequestItem, GroupInfo } from '@/api/im';
import { IMApi } from '@/api';

const tabs = [{ name: '好友' }, { name: '申请' }, { name: '群聊' }];
const current = ref(0);
const friends = ref<FriendItem[]>([]);
const requests = ref<FriendRequestItem[]>([]);
const groups = ref<GroupInfo[]>([]);
const friendUid = ref('');
const groupName = ref('');
const groupMembers = ref('');
let removeFriendListener: (() => void) | null = null;
let removeGroupListener: (() => void) | null = null;

function onTabClick(item: { index: number }) {
  current.value = item.index;
}

function openPeer(friend: FriendItem) {
  const params = new URLSearchParams({
    type: '1',
    title: friend.remark || friend.nick || `用户 ${friend.uid}`,
    peer_id: String(friend.uid),
  });
  uni.navigateTo({ url: `/pages/common/chat/index?${params.toString()}` });
}

function openGroup(group: GroupInfo) {
  const params = new URLSearchParams({
    type: '2',
    title: group.name,
    peer_id: group.group_id,
  });
  uni.navigateTo({ url: `/pages/common/chat/index?${params.toString()}` });
}

async function applyFriend() {
  const uid = friendUid.value.trim();
  if (!/^\d+$/.test(uid))
    return uni.$u.toast('请输入 UID');
  await IMApi.applyFriend({ to_uid: uid, note: '我是你的同事' });
  friendUid.value = '';
  uni.$u.toast('已发送申请');
}

async function handleRequest(request_id: string, accept: boolean) {
  await IMApi.handleFriend({ request_id, accept });
  await loadAll();
}

async function createGroup() {
  const member_uids = parseUIDs(groupMembers.value);
  if (!groupName.value.trim())
    return uni.$u.toast('请输入群名称');
  if (!member_uids.length)
    return uni.$u.toast('请输入正确的成员 UID');
  await IMApi.createGroup({ name: groupName.value.trim(), member_uids });
  groupName.value = '';
  groupMembers.value = '';
  await loadAll();
}

function parseUIDs(value: string) {
  const list = value.split(',').map(item => item.trim()).filter(Boolean);
  return list.every(item => /^\d+$/.test(item)) ? list : [];
}

async function loadAll() {
  const [friendRes, requestRes, groupRes] = await Promise.all([
    IMApi.friends(),
    IMApi.friendRequests('inbox'),
    IMApi.groups(),
  ]);
  friends.value = friendRes.list;
  requests.value = requestRes.list;
  groups.value = groupRes.list;
}

function bindRealtime() {
  if (removeFriendListener)
    return;
  const reload = () => loadAll();
  uni.$on('im.friend', reload);
  uni.$on('im.group', reload);
  removeFriendListener = () => uni.$off('im.friend', reload);
  removeGroupListener = () => uni.$off('im.group', reload);
}

onShow(() => {
  bindRealtime();
  loadAll();
});

onUnload(() => {
  removeFriendListener?.();
  removeGroupListener?.();
});
</script>

<style scoped lang="scss">
.page {
  min-height: 100vh;
  background: #f6f7fb;
}

.section {
  padding: 12px;
}

.inline-form {
  display: grid;
  gap: 10px;
  margin-bottom: 12px;
  padding: 12px;
  background: #fff;
  border-radius: 8px;
}

.actions {
  display: flex;
  gap: 8px;
}
</style>
