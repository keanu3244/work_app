<template>
  <view class="page-wrap">
    <view class="page-header">
      <u-icon name="camera-fill" color="#18213a" size="22" />
    </view>
    <view class="profile-card">
      <view class="avatar">
        <u-avatar src="/static/images/logo.png" size="70" />
      </view>
      <view class="profile-main">
        <view class="profile-name">
          {{ session?.nick || '员工' }}
        </view>
        <view class="profile-uid" @click="toCopyUid">
          UID: {{ session?.uid || '-' }}
        </view>
      </view>
      <view class="profile-action">
        <u-icon name="scan" color="#969799" />
      </view>
      <view class="profile-action">
        <u-icon name="arrow-right" color="#969799" />
      </view>
    </view>

    <view class="section">
      <u-cell-group>
        <u-cell icon="chat" title="会话" is-link @click="goMessages" />
        <u-cell icon="download" title="版本更新" :label="versionLabel" is-link @click="checkUpdate" />
      </u-cell-group>
    </view>

    <view class="section">
      <u-cell-group>
        <u-cell v-for="item in blocks" :key="String(item.uid)" icon="minus-circle" :title="`已拉黑 ${item.nick || item.uid}`" :label="String(item.uid)">
          <template #value>
            <u-button size="mini" text="解除" @click="unblock(String(item.uid))" />
          </template>
        </u-cell>
        <u-cell v-if="blocks.length === 0" icon="checkmark-circle" title="黑名单为空" />
      </u-cell-group>
    </view>

    <view class="section">
      <u-cell-group>
        <u-cell icon="close-circle" title="退出登录" is-link @click="logout" />
      </u-cell-group>
    </view>
  </view>
</template>

<script setup lang="ts">
import type { UserBasic } from '@/api/im';
import { IMApi } from '@/api';
import { useClipboard } from '@/hooks';
import { clearToken, getSession } from '@/utils/auth';
import { disconnectRealtime } from '@/services/realtime';
import { currentAppVersion, fetchAppUpdateInfo, hasNewVersion, openAppUpdateUrl } from '@/services/update';

const { setClipboardData, getClipboardData } = useClipboard();
const session = computed(() => getSession());
const blocks = ref<UserBasic[]>([]);
const currentVersion = computed(() => currentAppVersion());
const versionLabel = computed(() => `当前版本 ${currentVersion.value.versionName}`);

// 复制
const toCopyUid = async () => {
  await setClipboardData({ data: session.value?.uid || '' });
  await getClipboardData();
  uni.$u.toast('已复制 UID');
};

function goMessages() {
  uni.switchTab({ url: '/pages/tab/home/index' });
}

async function checkUpdate() {
  try {
    uni.showLoading({ title: '检查更新' });
    const info = await fetchAppUpdateInfo();
    uni.hideLoading();
    if (!hasNewVersion(info)) {
      uni.$u.toast('当前已是最新版本');
      return;
    }
    const notes = info.notes.join('\n');
    uni.showModal({
      title: `发现新版本 ${info.versionName}`,
      content: notes,
      showCancel: !info.force,
      confirmText: '立即更新',
      success: async (res) => {
        if (!res.confirm)
          return;
        const opened = await openAppUpdateUrl(info);
        if (!opened)
          uni.$u.toast('打开下载链接失败');
      },
    });
  }
  catch (error: any) {
    uni.hideLoading();
    uni.$u.toast(error?.message || '检查更新失败');
  }
}

async function loadBlocks() {
  const res = await IMApi.blockList();
  blocks.value = res.list;
}

async function unblock(uid: string) {
  await IMApi.unblockUser(uid);
  await loadBlocks();
}

function logout() {
  disconnectRealtime();
  clearToken();
  const bridge = (window as Window & { flutter_inappwebview?: { callHandler?: (name: string) => void } }).flutter_inappwebview;
  if (bridge?.callHandler) {
    bridge.callHandler('workAppLogout');
  }
  else {
    uni.$u.toast('已退出');
  }
}

onShow(loadBlocks);
</script>

<style scoped lang="scss">
.page-wrap {
  min-height: 100vh;
  box-sizing: border-box;
  padding-bottom: calc(env(safe-area-inset-bottom) + 16px);
  background: #f6f7fb;
}

.page-header {
  display: flex;
  justify-content: flex-end;
  padding: calc(env(safe-area-inset-top) + 18px) 22px 12px;
}

.profile-card {
  display: flex;
  align-items: center;
  min-height: 92px;
  padding: 0 20px 24px 24px;
  background: #fff;
}

.avatar {
  flex: 0 0 auto;
  margin-right: 14px;
}

.profile-main {
  min-width: 0;
  flex: 1;
}

.profile-name {
  overflow: hidden;
  color: #172033;
  font-size: 22px;
  font-weight: 700;
  line-height: 1.25;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.profile-uid {
  overflow: hidden;
  margin-top: 8px;
  color: #7a8499;
  font-size: 15px;
  line-height: 1.35;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.profile-action {
  flex: 0 0 auto;
  padding: 10px 6px 10px 10px;
}

.section {
  margin-top: 12px;
  background: #fff;
}
</style>
