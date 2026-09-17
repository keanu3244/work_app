import { io, Socket } from 'socket.io-client';
import { getSession, getToken } from '@/utils/auth';

let socket: Socket | null = null;

function linkMessage(payload: any) {
  return payload?.ms?.[0]?.link_msg;
}

function messageText(message: any) {
  if (message?.status === 2)
    return '消息已撤回';
  return message?.content?.text_content?.content || (message?.content?.image_content ? '[图片]' : '你收到一条新消息');
}

function notify(title: string, body: string) {
  const bridge = (window as Window & {
    flutter_inappwebview?: { callHandler?: (name: string, payload?: unknown) => void };
  }).flutter_inappwebview;
  if (bridge?.callHandler) {
    bridge.callHandler('workAppNotify', { title, body });
  }
  else {
    uni.showToast({ title: body, icon: 'none' });
  }
}

function handlePeer(payload: any) {
  const msg = linkMessage(payload);
  if (!msg)
    return;
  uni.$emit('im.peer', msg);
  const info = msg.info;
  if (msg.tp === 'msg' && info)
    notify(info.send_user?.nick || '新消息', messageText(info));
}

function handleGroup(payload: any) {
  const msg = linkMessage(payload);
  if (!msg)
    return;
  uni.$emit('im.group', msg);
  const info = msg.info;
  if (msg.tp === 'msg' && info)
    notify('群聊消息', messageText(info));
}

function handleFriend(payload: any) {
  const msg = linkMessage(payload);
  if (!msg)
    return;
  uni.$emit('im.friend', msg);
  if (msg.tp === 'friend_request')
    notify('好友申请', '你收到一条好友申请');
}

export function setupRealtime() {
  const token = getToken();
  const session = getSession();
  if (!token || !session?.uid || socket)
    return;

  socket = io(import.meta.env.VITE_API_BASE_URL.replace('/api/v1', ''), {
    path: '/socket.io/',
    transports: ['websocket', 'polling'],
    auth: { token },
    query: { uid: session.uid },
  });
  socket.on('connect', () => socket?.emit('auth', token));
  socket.on('im.peer', handlePeer);
  socket.on('im.group', handleGroup);
  socket.on('im.friend', handleFriend);
  socket.on('connect_error', () => {
    uni.$emit('im.socket.error');
  });
}

export function disconnectRealtime() {
  socket?.disconnect();
  socket = null;
}
