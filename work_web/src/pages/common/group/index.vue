<template>
  <view class="page">
    <view class="panel">
      <u-input v-model="name" placeholder="群名称" border="surround" />
      <u-button type="primary" text="保存群名称" @click="updateProfile" />
    </view>

    <view class="panel">
      <u-cell
        title="群公告"
        :label="announcement || '未设置'"
        is-link
        @click="openAnnouncement"
      />
    </view>

    <view class="panel">
      <view class="section-title">成员</view>
      <view class="inline-form">
        <u-input v-model="memberInput" placeholder="成员 UID，逗号分隔" border="surround" />
        <u-button type="primary" text="邀请" @click="addMembers" />
      </view>
      <u-cell-group>
        <u-cell
          v-for="member in members"
          :key="String(member.uid)"
          :title="member.nickname || member.nick || member.user?.nick || `用户 ${member.uid}`"
          :label="roleText(member.role)"
        >
          <template #icon>
            <u-avatar :src="member.portrait || member.user?.portrait" :text="String(member.uid).slice(-1)" size="36" custom-style="margin-right: 10px" />
          </template>
          <template #value>
            <view class="member-actions">
              <u-button size="mini" text="禁言" @click="mute(member.uid)" />
              <u-button size="mini" text="踢出" @click="kick(member.uid)" />
              <u-button size="mini" text="转让" @click="transfer(member.uid)" />
            </view>
          </template>
        </u-cell>
      </u-cell-group>
    </view>

    <view class="panel danger">
      <u-button text="退出群聊" @click="quit" />
      <u-button type="error" text="解散群聊" @click="dissolve" />
    </view>
  </view>
</template>

<script setup lang="ts">
import type { GroupMemberItem } from '@/api/im';
import { IMApi } from '@/api';

const groupId = ref('');
const name = ref('');
const announcement = ref('');
const memberInput = ref('');
const members = ref<GroupMemberItem[]>([]);
let membersRequestID = 0;
let groupProfileRequestID = 0;
let pageActive = false;

function parseUIDs(value: string) {
  const list = value.split(',').map(item => item.trim()).filter(Boolean);
  return list.every(item => /^\d+$/.test(item)) ? list : [];
}

function roleText(role: number) {
  if (role === 1)
    return '群主';
  if (role === 2)
    return '管理员';
  return '成员';
}

async function loadMembers() {
  const requestID = ++membersRequestID;
  try {
    const res = await IMApi.groupMembers(groupId.value);
    if (pageActive && requestID === membersRequestID)
      members.value = res.list;
  }
  catch (error: any) {
    if (pageActive && requestID === membersRequestID)
      uni.$u.toast(error?.message || '加载群成员失败');
  }
}

async function loadGroupProfile() {
  const requestID = ++groupProfileRequestID;
  try {
    const res = await IMApi.groups();
    if (!pageActive || requestID !== groupProfileRequestID)
      return;
    const group = res.list.find(item => item.group_id === groupId.value);
    if (!group)
      return;
    name.value = group.name;
    announcement.value = group.announcement || '';
  }
  catch (error: any) {
    if (pageActive && requestID === groupProfileRequestID)
      uni.$u.toast(error?.message || '加载群资料失败');
  }
}

async function updateProfile() {
  await IMApi.updateGroup({
    group_id: groupId.value,
    name: name.value,
  });
  groupProfileRequestID += 1;
  uni.$u.toast('已保存');
}

function openAnnouncement() {
  const params = new URLSearchParams({
    group_id: groupId.value,
    title: name.value,
    announcement: announcement.value,
  });
  uni.navigateTo({ url: `/pages/common/group-announcement/index?${params.toString()}` });
}

async function addMembers() {
  const member_uids = parseUIDs(memberInput.value);
  if (!member_uids.length)
    return uni.$u.toast('请输入成员 UID');
  await IMApi.addGroupMembers({ group_id: groupId.value, member_uids });
  memberInput.value = '';
  await loadMembers();
}

async function kick(uid: number | string) {
  await IMApi.kickGroupMembers({ group_id: groupId.value, member_uids: [String(uid)] });
  await loadMembers();
}

async function mute(uid: number | string) {
  await IMApi.muteGroupMember({ group_id: groupId.value, member_uid: String(uid), duration: 600 });
  uni.$u.toast('已禁言 10 分钟');
}

async function transfer(uid: number | string) {
  await IMApi.transferGroup({ group_id: groupId.value, to_uid: String(uid) });
  await loadMembers();
}

async function quit() {
  await IMApi.quitGroup(groupId.value);
  uni.switchTab({ url: '/pages/tab/list/index' });
}

async function dissolve() {
  await IMApi.dissolveGroup(groupId.value);
  uni.switchTab({ url: '/pages/tab/list/index' });
}

onLoad((query) => {
  pageActive = true;
  groupId.value = String(query?.group_id || '');
  name.value = String(query?.title || '');
  announcement.value = String(query?.announcement || '');
  loadGroupProfile();
  loadMembers();
});

onShow(() => {
  pageActive = true;
  if (groupId.value)
    loadGroupProfile();
});

onUnload(() => {
  pageActive = false;
  membersRequestID += 1;
  groupProfileRequestID += 1;
});
</script>

<style scoped lang="scss">
.page {
  min-height: 100vh;
  padding: 12px;
  background: #f6f7fb;
  box-sizing: border-box;
}

.panel {
  display: grid;
  gap: 10px;
  margin-bottom: 12px;
  padding: 12px;
  background: #fff;
  border-radius: 8px;
}

.section-title {
  color: #172033;
  font-size: 16px;
  font-weight: 700;
}

.inline-form {
  display: grid;
  gap: 10px;
}

.member-actions {
  display: flex;
  gap: 6px;
}

.danger {
  grid-template-columns: 1fr 1fr;
}
</style>
