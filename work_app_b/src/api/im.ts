import { post } from '@/utils/request';
import { getToken } from '@/utils/auth';

function apiBaseURL() {
  // #ifdef H5
  if (import.meta.env.VITE_APP_PROXY === 'true')
    return import.meta.env.VITE_API_PREFIX;
  // #endif
  return import.meta.env.VITE_API_BASE_URL;
}

function parseIMPayload(text: string) {
  return JSON.parse(text.replace(/:\s*(-?\d{16,})(?=\s*[,}\]])/g, ':"$1"'));
}

function buildIMURL(url: string, params?: Record<string, string | number | undefined>) {
  const requestURL = `${apiBaseURL()}${url}`;
  const target = requestURL.startsWith('http')
    ? new URL(requestURL)
    : new URL(requestURL, window.location.origin);
  Object.entries(params || {}).forEach(([key, value]) => {
    if (value !== undefined && value !== '')
      target.searchParams.set(key, String(value));
  });
  return target.toString();
}

async function getRawJson<T>(url: string, params?: Record<string, string | number | undefined>) {
  const response = await fetch(buildIMURL(url, params), {
    headers: {
      Authorization: `Bearer ${getToken()}`,
    },
  });
  const payload = parseIMPayload(await response.text());
  if (payload.code !== 0)
    throw payload;
  return payload.data as T;
}

async function postRawJson<T>(url: string, body: string) {
  const response = await fetch(`${apiBaseURL()}${url}`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${getToken()}`,
      'Content-Type': 'application/json',
    },
    body,
  });
  const payload = parseIMPayload(await response.text());
  if (payload.code !== 0)
    throw payload;
  return payload.data as T;
}

export interface UserBasic {
  uid: number | string;
  nick?: string;
  portrait?: string;
}

export interface MessageContent {
  text_content?: { content: string };
  image_content?: { url: string | string[]; width?: number; height?: number };
}

export interface ChatMessage {
  contact_id: string;
  msg_id: string;
  sender_uid: number | string;
  receiver_uid?: number | string;
  group_id?: string;
  msg_type: number;
  content: MessageContent;
  send_user?: UserBasic;
  status: number;
  create_time: number;
}

export interface Conversation {
  contact_id: string;
  contact_type: number;
  peer_id: number | string;
  peer_user?: UserBasic;
  group?: GroupInfo;
  last_msg?: ChatMessage;
  unread_count: number;
  is_top: boolean;
}

export interface GroupInfo {
  group_id: string;
  name: string;
  portrait?: string;
  announcement?: string;
  owner_uid: number | string;
  member_count: number;
  create_time: number;
}

export interface GroupMemberItem {
  uid: number | string;
  nick?: string;
  portrait?: string;
  role: number;
  nickname?: string;
  join_time: number;
  user?: UserBasic;
}

export interface FriendItem extends UserBasic {
  remark?: string;
  friend_since?: number;
}

export interface FriendRequestItem {
  request_id: string;
  from_uid: number | string;
  to_uid: number | string;
  status: number;
  note?: string;
  user?: UserBasic;
  create_time: number;
}

export const IMApi = {
  conversations: () => getRawJson<{ contacts: Conversation[]; has_more: number }>('/im/conversations', { size: 50, direction: 0 }),
  messages: (params: { contact_id?: string; peer_id?: string; msg_id?: string; direction?: number }) =>
    getRawJson<{ list: ChatMessage[]; has_more: number; next_version_id: string }>('/im/messages', { size: 50, direction: 0, msg_id: '0', ...params }),
  sendPeer: (data: { receiver_uid: string; contact_id?: string; text: string }) =>
    postRawJson<ChatMessage>(
      '/im/messages/send',
      `{"receiver_uid":${data.receiver_uid},"contact_id":${JSON.stringify(data.contact_id || '')},"msg_type":1,"content":{"text_content":{"content":${JSON.stringify(data.text)}}}}`,
    ),
  sendPeerImage: (data: { receiver_uid: string; contact_id?: string; url: string }) =>
    postRawJson<ChatMessage>(
      '/im/messages/send',
      `{"receiver_uid":${data.receiver_uid},"contact_id":${JSON.stringify(data.contact_id || '')},"msg_type":2,"content":{"image_content":{"url":${JSON.stringify(data.url)}}}}`,
    ),
  sendGroup: (data: { group_id: string; text: string }) =>
    post<ChatMessage>('/im/messages/group/send', {
      data: {
        group_id: data.group_id,
        msg_type: 1,
        content: { text_content: { content: data.text } },
      },
    }),
  sendGroupImage: (data: { group_id: string; url: string }) =>
    post<ChatMessage>('/im/messages/group/send', {
      data: {
        group_id: data.group_id,
        msg_type: 2,
        content: { image_content: { url: data.url } },
      },
    }),
  recallPeer: (data: { contact_id: string; msg_id: string }) =>
    post('/im/messages/recall', { data }),
  recallGroup: (data: { contact_id: string; msg_id: string }) =>
    post('/im/messages/group/recall', { data }),
  peerRead: (data: { contact_id: string; peer_id?: string; msg_id?: string }) =>
    postRawJson('/im/message/peer/read_receipt', `{"contact_id":${JSON.stringify(data.contact_id)},"peer_id":${data.peer_id || 0},"msg_id":${JSON.stringify(data.msg_id || '')}}`),
  groupRead: (data: { contact_id: string; msg_id?: string }) =>
    post('/im/message/group/read_receipt', { data }),
  friends: () => getRawJson<{ list: FriendItem[]; has_more: number }>('/im/friends', { size: 100 }),
  friendRequests: (box: 'inbox' | 'sent' = 'inbox') =>
    getRawJson<{ list: FriendRequestItem[]; has_more: number }>('/im/friend-requests', { box, size: 50 }),
  applyFriend: (data: { to_uid: string; note: string }) =>
    postRawJson<FriendRequestItem>('/im/friends/apply', `{"to_uid":${data.to_uid},"note":${JSON.stringify(data.note)}}`),
  handleFriend: (data: { request_id: string; accept: boolean }) =>
    post('/im/friends/handle', { data }),
  groups: () => getRawJson<{ list: GroupInfo[]; has_more: number }>('/im/groups', { size: 100 }),
  createGroup: (data: { name: string; member_uids: string[] }) =>
    postRawJson<GroupInfo>(
      '/im/group/create',
      `{"name":${JSON.stringify(data.name)},"member_uids":[${data.member_uids.join(',')}]}`,
    ),
  updateGroup: (data: { group_id: string; name?: string; portrait?: string; announcement?: string }) =>
    post('/im/group/update', { data }),
  dissolveGroup: (group_id: string) => post('/im/group/dissolve', { data: { group_id } }),
  quitGroup: (group_id: string) => post('/im/group/quit', { data: { group_id } }),
  transferGroup: (data: { group_id: string; to_uid: string }) =>
    postRawJson('/im/group/transfer', `{"group_id":${JSON.stringify(data.group_id)},"to_uid":${data.to_uid}}`),
  groupMembers: (group_id: string) =>
    getRawJson<{ list: GroupMemberItem[]; has_more: number }>('/im/group/members', { group_id, size: 100 }),
  addGroupMembers: (data: { group_id: string; member_uids: string[] }) =>
    postRawJson('/im/group/members/add', `{"group_id":${JSON.stringify(data.group_id)},"member_uids":[${data.member_uids.join(',')}]}`),
  kickGroupMembers: (data: { group_id: string; member_uids: string[] }) =>
    postRawJson('/im/group/members/kick', `{"group_id":${JSON.stringify(data.group_id)},"member_uids":[${data.member_uids.join(',')}]}`),
  muteGroupMember: (data: { group_id: string; member_uid: string; duration: number }) =>
    postRawJson('/im/group/members/mute', `{"group_id":${JSON.stringify(data.group_id)},"member_uid":${data.member_uid},"duration":${data.duration}}`),
  blockList: () => getRawJson<{ list: UserBasic[] }>('/im/block/list'),
  blockUser: (peer_uid: string) => postRawJson('/im/block/set', `{"peer_uid":${peer_uid}}`),
  unblockUser: (peer_uid: string) => postRawJson('/im/block/cancel', `{"peer_uid":${peer_uid}}`),
  registerPushToken: (data: { platform: 'ios' | 'android'; provider: 'apns' | 'fcm'; token: string }) =>
    post('/im/push/token', { data }),
  deletePushToken: (token: string) => post('/im/push/token/delete', { data: { token } }),
};

export async function uploadImage(filePath: string) {
  const response = await fetch(filePath);
  const blob = await response.blob();
  const uploadResponse = await fetch(`${apiBaseURL()}/upload/image?sufix=.jpg`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${getToken()}`,
      'Content-Type': blob.type || 'image/jpeg',
    },
    body: blob,
  });
  const payload = await uploadResponse.json();
  if (payload.code !== 0)
    throw payload;
  return payload.data.url as string;
}
