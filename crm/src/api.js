import axios from "axios";

export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "/api/v1";
export const TOKEN_KEY = "farmapp_crm_access_token";
export const REFRESH_TOKEN_KEY = "farmapp_crm_refresh_token";
export const ROLE_KEY = "farmapp_crm_role";
export const SESSION_KEY = "farmapp_crm_session";
export const FARM_KEY = "farmapp_crm_farm_id";

const sessionStorageFor = (key) =>
  localStorage.getItem(key) !== null ? localStorage : sessionStorage;
const readSessionValue = (key) =>
  localStorage.getItem(key) ?? sessionStorage.getItem(key);

function notifyAuthExpired() {
  clearSession();
  window.dispatchEvent(new Event("farmapp-auth-expired"));
}

export const api = axios.create({ baseURL: API_BASE_URL });
let refreshing;

api.interceptors.request.use((config) => {
  const token = readSessionValue(TOKEN_KEY);
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

api.interceptors.response.use(undefined, async (error) => {
  const request = error.config;
  if (error.response?.status !== 401 || request?.skipAuthRefresh || request?._authRetried) {
    return Promise.reject(error);
  }
  const refreshToken = readSessionValue(REFRESH_TOKEN_KEY);
  if (!refreshToken) {
    notifyAuthExpired();
    return Promise.reject(error);
  }
  request._authRetried = true;
  try {
    refreshing ||= axios.post(`${API_BASE_URL}/auth/refresh`, { refresh_token: refreshToken });
    const response = await refreshing;
    refreshing = undefined;
    const storage = sessionStorageFor(TOKEN_KEY);
    storage.setItem(TOKEN_KEY, response.data.access_token);
    storage.setItem(REFRESH_TOKEN_KEY, response.data.refresh_token);
    request.headers.Authorization = `Bearer ${response.data.access_token}`;
    return api(request);
  } catch (refreshError) {
    refreshing = undefined;
    notifyAuthExpired();
    return Promise.reject(refreshError);
  }
});

export function saveSession(response, rememberMe = false) {
  const user = response.data?.user || {};
  const farms = response.data?.farms?.data || response.data?.farms || [];
  const session = { user, farms };
  clearSession();
  const storage = rememberMe ? localStorage : sessionStorage;
  storage.setItem(TOKEN_KEY, response.data.access_token);
  storage.setItem(REFRESH_TOKEN_KEY, response.data.refresh_token || "");
  storage.setItem(ROLE_KEY, user.crm_role || (user.role === "farmOwner" ? "admin" : "customer_support"));
  storage.setItem(SESSION_KEY, JSON.stringify(session));
  return session;
}

export function saveProfile(response) {
  const session = {
    user: response.data?.user || {},
    farms: response.data?.farms?.data || response.data?.farms || [],
  };
  const storage = sessionStorageFor(SESSION_KEY);
  storage.setItem(ROLE_KEY, session.user.crm_role || (session.user.role === "farmOwner" ? "admin" : "customer_support"));
  storage.setItem(SESSION_KEY, JSON.stringify(session));
  return session;
}

export function clearSession() {
  localStorage.removeItem(TOKEN_KEY);
  localStorage.removeItem(REFRESH_TOKEN_KEY);
  localStorage.removeItem(ROLE_KEY);
  localStorage.removeItem(SESSION_KEY);
  sessionStorage.removeItem(TOKEN_KEY);
  sessionStorage.removeItem(REFRESH_TOKEN_KEY);
  sessionStorage.removeItem(ROLE_KEY);
  sessionStorage.removeItem(SESSION_KEY);
}
