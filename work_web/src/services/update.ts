export interface AppUpdateInfo {
  versionName: string;
  versionCode: number;
  apkUrl: string;
  force: boolean;
  notes: string[];
}

function updateConfigUrl() {
  const pageUrl = window.location.href.split('#')[0];
  return new URL(`static/update/update.json?t=${Date.now()}`, pageUrl).toString();
}

export async function fetchAppUpdateInfo() {
  const response = await fetch(updateConfigUrl(), { cache: 'no-store' });
  if (!response.ok)
    throw new Error('获取更新信息失败');
  return response.json() as Promise<AppUpdateInfo>;
}

export function currentAppVersion() {
  const session = window.__WORK_APP_SESSION__;
  return {
    versionName: session?.app_version_name || '1.0.0',
    versionCode: session?.app_version_code || 1,
  };
}

export function hasNewVersion(info: AppUpdateInfo) {
  return info.versionCode > currentAppVersion().versionCode;
}

export async function openAppUpdateUrl(info: AppUpdateInfo) {
  const bridge = (window as Window & {
    flutter_inappwebview?: { callHandler?: (name: string, payload?: unknown) => Promise<unknown> };
  }).flutter_inappwebview;
  if (bridge?.callHandler) {
    const opened = await bridge.callHandler('workAppOpenUrl', { url: info.apkUrl });
    return opened === true;
  }
  window.location.href = info.apkUrl;
  return true;
}
