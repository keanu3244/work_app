const TokenKey = 'admin-token';
const SessionKey = 'work-app-session';
const TokenPrefix = 'Bearer ';

function readJwtClaim(token: string, key: string) {
  const parts = token.split('.');
  if (parts.length !== 3)
    return '';
  try {
    const payload = JSON.parse(atob(parts[1].replace(/-/g, '+').replace(/_/g, '/')));
    const value = payload[key];
    return value === undefined || value === null ? '' : String(value);
  }
  catch {
    return '';
  }
}

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
function setAuthSession(auth: AuthSessionPayload) {
  setSession({
    access_token: auth.access_token,
    refresh_token: auth.refresh_token,
    uid: String(auth.uid),
    sid: readJwtClaim(auth.access_token, 'sid'),
    nick: auth.nick || String(auth.uid),
  });
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
  refresh_token?: string;
  uid: string;
  sid: string;
  nick: string;
}

export interface AuthSessionPayload {
  access_token: string;
  refresh_token: string;
  uid: number | string;
  nick: string;
}

export { bootstrapSession, clearToken, getSession, getToken, isLogin, setAuthSession, setSession, setToken, TokenPrefix };
