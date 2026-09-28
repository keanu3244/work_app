export interface ProfileReq {
  user_id?: string;
}

export interface ProfileRes {
  user_id?: string;
  user_name?: string;
  avatar?: string;
  token?: string;
}

export interface LoginReq {
  phone: string;
  code: string;
}

export interface LoginRes {
  token: string;
  user_id: number;
  user_name: string;
  avatar: string;
}

export interface LoginByCodeReq {
  code: string;
}

export interface LoginByCodeRes {
  [key: string]: any;
}

export interface AuthLoginReq {
  email: string;
  password: string;
}

export interface AuthRegisterReq extends AuthLoginReq {
  nick: string;
}

export interface AuthTokenPair {
  access_token: string;
  refresh_token: string;
  token_type: 'Bearer';
  expires_in: number;
  uid: number;
  nick: string;
}
