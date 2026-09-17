const TokenKey = 'admin-token';
const SessionKey = 'work-app-session';
const TokenPrefix = 'Bearer ';
function isLogin() {
  return !!uni.getStorageSync(TokenKey);
}
function getToken() {
  return uni.getStorageSync(TokenKey);
}
function setToken(token: string) {
  uni.setStorageSync(TokenKey, token);
}
function clearToken() {
  uni.removeStorageSync(TokenKey);
  uni.removeStorageSync(SessionKey);
}
function setSession(session: WorkSession) {
  uni.setStorageSync(SessionKey, session);
  setToken(session.access_token);
}
function getSession(): WorkSession | null {
  return uni.getStorageSync(SessionKey) || null;
}
function bootstrapSession() {
  const injected = typeof window !== 'undefined' ? window.__WORK_APP_SESSION__ : null;
  const search = typeof window !== 'undefined' ? new URLSearchParams(window.location.search) : null;
  const token = injected?.access_token || search?.get('token');
  const uid = injected?.uid || search?.get('uid');
  const sid = injected?.sid || search?.get('sid');
  if (token && uid && sid) {
    setSession({
      access_token: String(token),
      uid: String(uid),
      sid: String(sid),
      nick: injected?.nick ? String(injected.nick) : String(uid),
    });
  }
}

export interface WorkSession {
  access_token: string;
  uid: string;
  sid: string;
  nick: string;
}

export { bootstrapSession, clearToken, getSession, getToken, isLogin, setSession, setToken, TokenPrefix };
