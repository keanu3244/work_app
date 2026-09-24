<template>
  <view class="login-page">
    <view class="login-panel">
      <view class="brand">
        <image class="brand-logo" src="/static/images/logo.png" mode="aspectFill" />
        <view>
          <view class="brand-title">Work IM</view>
          <view class="brand-subtitle">企业内部沟通 Web 端</view>
        </view>
      </view>

      <view class="form">
        <u-tabs :list="tabs" :current="modeIndex" @click="onModeClick" />
        <u-input v-model="email" placeholder="邮箱" border="surround" clearable />
        <u-input v-model="password" placeholder="密码" border="surround" type="password" clearable />
        <u-input v-if="mode === 'register'" v-model="nick" placeholder="昵称" border="surround" clearable />
        <u-button type="primary" :loading="submitting" :text="submitText" @click="submit" />
      </view>
    </view>
  </view>
</template>

<script setup lang="ts">
import { UserApi } from '@/api';
import { HOME_PATH, LOGIN_PATH, removeQueryString } from '@/router';
import { setupRealtime } from '@/services/realtime';
import { setAuthSession } from '@/utils/auth';

const tabs = [{ name: '登录' }, { name: '注册' }];
const mode = ref<'login' | 'register'>('login');
const email = ref('');
const password = ref('');
const nick = ref('');
const submitting = ref(false);
let redirect = HOME_PATH;

const modeIndex = computed(() => mode.value === 'login' ? 0 : 1);
const submitText = computed(() => mode.value === 'login' ? '登录' : '注册并登录');

function onModeClick(item: { index: number }) {
  mode.value = item.index === 0 ? 'login' : 'register';
}

function validForm() {
  if (!/^[^\s@]+@[^\s@][^\s.@]*\.[^\s@]+$/.test(email.value.trim())) {
    uni.$u.toast('请输入正确邮箱');
    return false;
  }
  if (password.value.length < 6) {
    uni.$u.toast('密码至少 6 位');
    return false;
  }
  if (mode.value === 'register' && !nick.value.trim()) {
    uni.$u.toast('请输入昵称');
    return false;
  }
  return true;
}

async function submit() {
  if (!validForm() || submitting.value)
    return;
  submitting.value = true;
  try {
    const payload = mode.value === 'login'
      ? await UserApi.authLogin({ email: email.value.trim(), password: password.value })
      : await UserApi.authRegister({ email: email.value.trim(), password: password.value, nick: nick.value.trim() });
    setAuthSession(payload);
    setupRealtime();
    uni.reLaunch({ url: redirect });
  }
  catch (error: any) {
    uni.$u.toast(error?.message || '登录失败');
  }
  finally {
    submitting.value = false;
  }
}

onLoad((options: any) => {
  if (options.redirect && removeQueryString(options.redirect) !== LOGIN_PATH)
    redirect = decodeURIComponent(options.redirect);
});
</script>

<style lang="scss" scoped>
.login-page {
  display: flex;
  min-height: 100vh;
  align-items: center;
  justify-content: center;
  padding: 24px;
  background: #eef2f7;
  box-sizing: border-box;
}

.login-panel {
  width: 420px;
  max-width: 100%;
  padding: 28px;
  background: #fff;
  border: 1px solid #e4e9f1;
  border-radius: 8px;
  box-shadow: 0 12px 32px rgba(20, 35, 58, 0.08);
  box-sizing: border-box;
}

.brand {
  display: flex;
  align-items: center;
  gap: 14px;
  margin-bottom: 26px;
}

.brand-logo {
  width: 48px;
  height: 48px;
  border-radius: 8px;
}

.brand-title {
  color: #172033;
  font-size: 24px;
  font-weight: 700;
  line-height: 30px;
}

.brand-subtitle {
  margin-top: 4px;
  color: #7a8499;
  font-size: 14px;
  line-height: 20px;
}

.form {
  display: grid;
  gap: 14px;
}
</style>
