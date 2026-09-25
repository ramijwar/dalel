import { createContext, useContext, useEffect, useState, useCallback } from 'react'
import type { ReactNode } from 'react'
import type { Category, Governorate, Region, Settings, User } from './types'
import { api, getToken, setToken } from './api'

interface Store {
  loading: boolean
  user: User | null
  categories: Category[]
  regions: Region[]
  governorates: Governorate[]
  locations: Governorate[]
  settings: Settings
  /** عدد الخدمات لكل قسم — يأتي ضمن /api/meta فلا يحتاج طلباً منفصلاً */
  counts: Record<string, number>
  refreshMeta: () => Promise<void>
  refreshUser: () => Promise<void>
  login: (phone: string, password: string) => Promise<void>
  register: (payload: {
    phone: string
    password: string
    full_name: string
    birth_date?: string
  }) => Promise<void>
  logout: () => void
}

const EMPTY_SETTINGS: Settings = {
  site_name: 'وين في؟',
  city: '',
  ad_interval: 5,
  announcements: [],
  whatsapp_admin: '',
  service_types: [],
}

const Ctx = createContext<Store>(null!)

export function StoreProvider({ children }: { children: ReactNode }) {
  const [loading, setLoading] = useState(true)
  const [user, setUser] = useState<User | null>(null)
  const [categories, setCategories] = useState<Category[]>([])
  const [regions, setRegions] = useState<Region[]>([])
  const [governorates, setGovernorates] = useState<Governorate[]>([])
  const [locations, setLocations] = useState<Governorate[]>([])
  const [settings, setSettings] = useState<Settings>(EMPTY_SETTINGS)
  const [counts, setCounts] = useState<Record<string, number>>({})

  const refreshMeta = useCallback(async () => {
    try {
      const d = await api.meta()
      setCategories(d.categories ?? [])
      setRegions(d.regions ?? [])
      setGovernorates(d.governorates ?? [])
      setLocations(d.locations ?? [])
      setCounts(d.counts ?? {})
      if (d.settings) setSettings({ ...EMPTY_SETTINGS, ...d.settings })
    } catch (e) {
      console.error('فشل تحميل البيانات العامة:', e)
    }
  }, [])

  const refreshUser = useCallback(async () => {
    if (!getToken()) {
      setUser(null)
      return
    }
    try {
      const r = await api.me()
      setUser(r.user)
    } catch {
      setToken(null)
      setUser(null)
    }
  }, [])

  // التحميل الأولي — مرة واحدة فقط
  useEffect(() => {
    let alive = true
    ;(async () => {
      await refreshMeta()
      if (!alive) return
      await refreshUser()
      if (alive) setLoading(false)
    })()
    return () => {
      alive = false
    }
  }, [refreshMeta, refreshUser])

  const login = useCallback(async (phone: string, password: string) => {
    const r = await api.login(phone, password)
    setToken(r.token)
    setUser(r.user)
  }, [])

  const register = useCallback(
    async (payload: { phone: string; password: string; full_name: string; birth_date?: string }) => {
      const r = await api.register(payload)
      setToken(r.token)
      setUser(r.user)
    },
    [],
  )

  const logout = useCallback(() => {
    setToken(null)
    setUser(null)
  }, [])

  return (
    <Ctx.Provider
      value={{
        loading, user, categories, regions, governorates, locations, settings, counts,
        refreshMeta, refreshUser,
        login, register, logout,
      }}
    >
      {children}
    </Ctx.Provider>
  )
}

export function useStore() {
  return useContext(Ctx)
}
