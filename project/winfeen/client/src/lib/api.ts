import type {
  Governorate,
  AdminStats, ActivityItem, Category, MetaResponse, Region, Service,
  ServiceListResponse, ServiceRequest, Settings, User, ScheduleRow, Specialty,
  CategoryField, FieldOption,
} from './types'
import { getBasePath } from './basePath'

const TOKEN_KEY = 'winfeen_token'

export class ApiError extends Error {
  status: number
  constructor(message: string, status: number) {
    super(message)
    this.status = status
  }
}

export function getToken(): string | null {
  try { return localStorage.getItem(TOKEN_KEY) } catch { return null }
}
export function setToken(t: string | null) {
  try {
    if (t) localStorage.setItem(TOKEN_KEY, t)
    else localStorage.removeItem(TOKEN_KEY)
  } catch { /* ignore */ }
}

async function request<T>(path: string, opts: { method?: string; body?: any; headers?: Record<string, string> } = {}): Promise<T> {
  const headers: Record<string, string> = { ...opts.headers }
  const token = getToken()
  if (token) headers['Authorization'] = `Bearer ${token}`

  let body: BodyInit | null | undefined = undefined
  if (opts.body !== undefined) {
    if (opts.body instanceof FormData) {
      body = opts.body
    } else {
      headers['Content-Type'] = 'application/json'
      // حماية: إن مُرِّرت سلسلة مُحوَّلة مسبقاً فلا نُرمّزها مرتين
      // (الترميز المزدوج يجعل الخادم يرى نصاً بدل كائن فيُعيد "الحقل مطلوب")
      body = typeof opts.body === 'string' ? opts.body : JSON.stringify(opts.body)
    }
  }

  const reqInit: RequestInit = { method: opts.method || 'GET', headers, body }
  const base = getBasePath()
  const res = await fetch(`${base}/api${path}`, reqInit)
  let data: any = null
  const text = await res.text()
  const ctype = (res.headers.get('content-type') || '').toLowerCase()

  if (text) {
    try {
      data = JSON.parse(text)
    } catch {
      // ردّ ليس JSON — غالباً صفحة HTML ناتجة عن إعادة توجيه خاطئة لمسار /api
      const isHtml = ctype.includes('text/html') || /^\s*<!doctype\s+html/i.test(text)
      data = {
        ok: false,
        message: isHtml
          ? `الخادم أعاد صفحة HTML بدل بيانات JSON (${res.status}) — تحقّق من إعداد .htaccess في جذر الموقع`
          : `ردّ غير متوقع من الخادم (${res.status})`,
      }
    }
  }
  if (!res.ok || (data && data.ok === false)) {
    throw new ApiError(data?.message || `خطأ في الاتصال (${res.status})`, res.status)
  }
  return data as T
}

const q = (params: Record<string, any>) => {
  const s = new URLSearchParams()
  Object.entries(params).forEach(([k, v]) => {
    if (v !== undefined && v !== null && v !== '') s.set(k, String(v))
  })
  const str = s.toString()
  return str ? `?${str}` : ''
}

export const api = {
  // عامة
  meta: () => request<MetaResponse>('/meta'),
  home: () => request<{ categories: Category[]; counts: Record<string, number> }>('/home'),
  stats: () => request<{ by_category: Record<string, number>; open_now: number; total_services: number }>('/stats'),
  categories: () => request<{ items: Category[] }>('/categories'),
  regions: (zone?: string) => request<{ items: Region[] }>(`/regions${q({ zone })}`),
  governorates: () => request<{ items: Governorate[] }>('/governorates'),
  locations: () => request<{ items: Governorate[] }>('/locations'),
  services: (params: Record<string, any> = {}) =>
    request<ServiceListResponse>(`/services${q(params)}`),
  service: (id: number) => request<{ service: Service; nearby: Service[] }>(`/services/${id}`),
  /** الاختصاصات الطبية من قاعدة البيانات */
  specialties: () => request<{ ok: true; items: Specialty[] }>('/specialties'),
  createRequest: (payload: Record<string, any>) =>
    request<{ id: number; message: string }>('/service-requests', { method: 'POST', body: payload }),

  // المصادقة
  login: (phone: string, password: string) =>
    request<{ token: string; user: User }>('/auth/login', { method: 'POST', body: { phone, password } }),
  register: (payload: { phone: string; password: string; full_name: string; birth_date?: string }) =>
    request<{ token: string; user: User }>('/auth/register', { method: 'POST', body: payload }),
  me: () => request<{ user: User }>('/auth/me'),

  // الملف الشخصي
  updateProfile: (payload: Record<string, any>) =>
    request<{ user: User; message: string }>('/profile', { method: 'PUT', body: payload }),
  uploadAvatar: (file: File) => {
    const fd = new FormData()
    fd.append('avatar', file)
    return request<{ user: User; message: string }>('/profile/avatar', { method: 'POST', body: fd })
  },

  // خدماتي
  myServices: () => request<{ items: Service[]; total: number }>('/my/services'),
  myRequests: () => request<{ items: ServiceRequest[] }>('/my/requests'),
  myActivity: () => request<{ items: ActivityItem[] }>('/my/activity'),

  // تحكم صاحب الخدمة
  ownerService: (id: number) => request<{ service: Service }>(`/owner/services/${id}`),
  ownerStatus: (id: number, payload: { mode: 'open' | 'closed' | 'auto'; note?: string; hours?: number; on_duty?: boolean; duty_hours?: number }) =>
    request<{ service: Service; message: string }>(`/owner/services/${id}/status`, { method: 'PUT', body: payload }),
  ownerSchedule: (id: number, schedule: ScheduleRow[], keepManual = false) =>
    request<{ schedule: ScheduleRow[]; message: string }>(`/owner/services/${id}/schedule`, { method: 'PUT', body: { schedule, keep_manual: keepManual } }),
  ownerUpdate: (id: number, payload: Record<string, any>) =>
    request<{ service: Service; message: string }>(`/owner/services/${id}`, { method: 'PUT', body: payload }),

  // الإدارة
  admin: {
    stats: () => request<AdminStats>('/admin/stats'),
    services: (params: Record<string, any> = {}) => request<{ items: Service[]; total: number }>(`/admin/services${q(params)}`),
    service: (id: number) => request<{ service: Service }>(`/admin/services/${id}`),
    createService: (payload: Record<string, any>) => request<{ id: number; message: string }>('/admin/services', { method: 'POST', body: payload }),
    updateService: (id: number, payload: Record<string, any>) => request<{ message: string }>(`/admin/services/${id}`, { method: 'PUT', body: payload }),
    deleteService: (id: number) => request<{ message: string }>(`/admin/services/${id}`, { method: 'DELETE' }),

    categories: () => request<{ items: Category[] }>('/admin/categories'),
    createCategory: (payload: Record<string, any>) => request<{ id: number; message: string }>('/admin/categories', { method: 'POST', body: payload }),
    updateCategory: (id: number, payload: Record<string, any>) => request<{ message: string }>(`/admin/categories/${id}`, { method: 'PUT', body: payload }),
    deleteCategory: (id: number, force = false) => request<{ message: string }>(`/admin/categories/${id}${force ? '?force=1' : ''}`, { method: 'DELETE' }),

    // ─── الحقول الخاصة بالأقسام ───
    fields: (categoryId?: number) =>
      request<{ items: CategoryField[] }>(`/admin/category-fields${q({ category_id: categoryId })}`),
    createField: (payload: Partial<CategoryField>) =>
      request<{ id: number; message: string }>('/admin/category-fields', { method: 'POST', body: payload }),
    updateField: (id: number, payload: Partial<CategoryField>) =>
      request<{ id: number; message: string }>(`/admin/category-fields/${id}`, { method: 'PUT', body: payload }),
    deleteField: (id: number) =>
      request<{ message: string }>(`/admin/category-fields/${id}`, { method: 'DELETE' }),
    createOption: (fieldId: number, payload: Partial<FieldOption>) =>
      request<{ id: number; message: string }>(`/admin/category-fields/${fieldId}/options`, { method: 'POST', body: payload }),
    updateOption: (fieldId: number, optionId: number, payload: Partial<FieldOption>) =>
      request<{ id: number; message: string }>(`/admin/category-fields/${fieldId}/options/${optionId}`, { method: 'PUT', body: payload }),
    deleteOption: (fieldId: number, optionId: number) =>
      request<{ message: string }>(`/admin/category-fields/${fieldId}/options/${optionId}`, { method: 'DELETE' }),

    regions: (zone?: string) => request<{ items: Region[] }>(`/admin/regions${q({ zone })}`),
    governorates: () => request<{ items: Governorate[] }>('/admin/governorates'),
    // ملاحظة: request() يتولى JSON.stringify — لا تُمرَّر سلسلة مُحوَّلة مسبقاً وإلا حدث ترميز مزدوج
    createGovernorate: (payload: Partial<Governorate>) => request<{ id: number; message: string }>('/admin/governorates', { method: 'POST', body: payload }),
    updateGovernorate: (id: number, payload: Partial<Governorate>) => request<{ id: number; message: string }>(`/admin/governorates/${id}`, { method: 'PUT', body: payload }),
    deleteGovernorate: (id: number, force = false) => request<{ message: string }>(`/admin/governorates/${id}${force ? '?force=1' : ''}`, { method: 'DELETE' }),
    createRegion: (payload: Record<string, any>) => request<{ id: number; message: string }>('/admin/regions', { method: 'POST', body: payload }),
    updateRegion: (id: number, payload: Record<string, any>) => request<{ message: string }>(`/admin/regions/${id}`, { method: 'PUT', body: payload }),
    deleteRegion: (id: number) => request<{ message: string }>(`/admin/regions/${id}`, { method: 'DELETE' }),

    requests: (status?: string) => request<{ items: ServiceRequest[] }>(`/admin/requests${q({ status })}`),
    approveRequest: (id: number, payload: Record<string, any>) => request<{ service_id: number; message: string }>(`/admin/requests/${id}/approve`, { method: 'POST', body: payload }),
    rejectRequest: (id: number, admin_note: string) => request<{ message: string }>(`/admin/requests/${id}/reject`, { method: 'POST', body: { admin_note } }),
    deleteRequest: (id: number) => request<{ message: string }>(`/admin/requests/${id}`, { method: 'DELETE' }),

    users: (params: Record<string, any> = {}) => request<{ items: User[] }>(`/admin/users${q(params)}`),
    updateUser: (id: number, payload: Record<string, any>) => request<{ message: string }>(`/admin/users/${id}`, { method: 'PUT', body: payload }),
    deleteUser: (id: number) => request<{ message: string }>(`/admin/users/${id}`, { method: 'DELETE' }),

    activity: () => request<{ items: ActivityItem[] }>('/admin/activity'),
    saveSettings: (payload: Record<string, any>) => request<{ message: string }>('/admin/settings', { method: 'PUT', body: payload }),
    dataCounts: () => request<{ counts: Record<string, number> }>('/admin/data'),
    clearData: (targets: string[], confirm: string) =>
      request<{ message: string; deleted: Record<string, number> }>('/admin/data', { method: 'DELETE', body: { targets, confirm } }),
  },
}

export type { Settings }
