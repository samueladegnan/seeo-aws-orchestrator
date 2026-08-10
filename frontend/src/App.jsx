import { Fragment, useCallback, useEffect, useState, useRef } from 'react'

const API_KEY = import.meta.env.VITE_SEEO_API_KEY || 'local-development-only'
const isLocalhost = ['localhost', '127.0.0.1'].includes(window.location.hostname)
const API_BASE = import.meta.env.VITE_API_BASE || (isLocalhost ? 'http://localhost:3000' : '')
const isLocalApi = /localhost|127\.0\.0\.1|host\.docker\.internal/.test(API_BASE)

function getWsUrl(token) {
  const base = API_BASE
    ? API_BASE.replace(/\/$/, '').replace(/^http/, 'ws')
    : `${window.location.protocol === 'https:' ? 'wss:' : 'ws:'}//${window.location.host}`
  return `${base}/cable?${new URLSearchParams({ token }).toString()}`
}

const PROVIDERS = [
  { value: 'aws', label: 'Amazon Web Services', shortLabel: 'AWS' },
  { value: 'azure', label: 'Microsoft Azure', shortLabel: 'Azure' },
  { value: 'gcp', label: 'Google Cloud', shortLabel: 'GCP' },
  { value: 'oci', label: 'Oracle Cloud Infrastructure', shortLabel: 'OCI' },
]

const PROVIDER_REGIONS = {
  aws: [
    { value: 'us-east-1', label: 'US East (N. Virginia)' },
    { value: 'us-west-2', label: 'US West (Oregon)' },
    { value: 'eu-west-1', label: 'Europe (Ireland)' },
    { value: 'ap-southeast-1', label: 'Asia Pacific (Singapore)' },
  ],
  azure: [
    { value: 'eastus', label: 'East US' },
    { value: 'westus2', label: 'West US 2' },
    { value: 'westeurope', label: 'West Europe' },
    { value: 'southeastasia', label: 'Southeast Asia' },
  ],
  gcp: [
    { value: 'us-central1', label: 'Iowa' },
    { value: 'us-east1', label: 'South Carolina' },
    { value: 'europe-west1', label: 'Belgium' },
    { value: 'asia-southeast1', label: 'Singapore' },
  ],
  oci: [
    { value: 'us-ashburn-1', label: 'Ashburn' },
    { value: 'us-phoenix-1', label: 'Phoenix' },
    { value: 'uk-london-1', label: 'London' },
    { value: 'ap-singapore-1', label: 'Singapore' },
  ],
}

const COMPUTE_TIERS = [
  { value: 'small', label: 'Small - light preview workloads' },
  { value: 'medium', label: 'Medium - application workloads' },
  { value: 'large', label: 'Large - heavier integration work' },
]

const STORAGE_TIERS = [
  { value: 'balanced', label: 'Balanced storage' },
  { value: 'performance', label: 'Performance storage' },
  { value: 'throughput', label: 'Throughput storage' },
]

let SESSION_ID = null
let SESSION_TOKEN = null
let SESSION_REFRESH = null
try {
  SESSION_ID = sessionStorage.getItem('seeo_session_id')
  SESSION_TOKEN = sessionStorage.getItem('seeo_session_token')
} catch {
  // Storage may be unavailable in privacy-restricted browsers.
}

async function ensureSessionToken(forceRefresh = false) {
  if (SESSION_REFRESH) return SESSION_REFRESH
  if (!forceRefresh && SESSION_TOKEN && SESSION_ID) return SESSION_TOKEN

  if (forceRefresh) {
    SESSION_ID = null
    SESSION_TOKEN = null
    try {
      sessionStorage.removeItem('seeo_session_id')
      sessionStorage.removeItem('seeo_session_token')
    } catch {
      // Storage may be unavailable in privacy-restricted browsers.
    }
  }

  const refresh = async () => {
    const res = await fetch(`${API_BASE}/session-token`, {
      headers: { 'X-API-Key': API_KEY },
    })
    if (!res.ok) throw new Error(`HTTP ${res.status}`)
    const data = await res.json()
    SESSION_ID = data.session_id
    SESSION_TOKEN = data.token
    try {
      sessionStorage.setItem('seeo_session_id', SESSION_ID)
      sessionStorage.setItem('seeo_session_token', SESSION_TOKEN)
    } catch {
      // Keep the token in memory for this tab when storage is unavailable.
    }
    return SESSION_TOKEN
  }

  SESSION_REFRESH = refresh().finally(() => { SESSION_REFRESH = null })
  return SESSION_REFRESH
}

async function authorizedFetch(url, options = {}) {
  const request = async (forceRefresh = false) => {
    const token = await ensureSessionToken(forceRefresh)
    return fetch(url, {
      ...options,
      headers: { ...(options.headers || {}), 'X-Session-Token': token },
    })
  }

  const response = await request()
  return response.status === 401 ? request(true) : response
}

const STATUS_STYLES = {
  ready: 'bg-emerald-100 text-emerald-800',
  provisioning: 'bg-amber-100 text-amber-800',
  terminating: 'bg-rose-100 text-rose-800',
  terminated: 'bg-slate-100 text-slate-600',
  default: 'bg-slate-100 text-slate-800',
}

function StatusBadge({ status }) {
  const classes = STATUS_STYLES[status] || STATUS_STYLES.default
  return (
    <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${classes}`}>
      {status || 'unknown'}
    </span>
  )
}

function Button({ children, variant = 'primary', disabled, ...props }) {
  const base = 'inline-flex items-center justify-center rounded-lg px-4 py-2 text-sm font-semibold transition focus:outline-none focus:ring-2 focus:ring-offset-2'
  const variants = {
    primary: 'bg-indigo-600 text-white hover:bg-indigo-700 focus:ring-indigo-500 disabled:bg-indigo-300',
    danger: 'bg-rose-600 text-white hover:bg-rose-700 focus:ring-rose-500 disabled:bg-rose-300',
    secondary: 'bg-white text-slate-700 border border-slate-300 hover:bg-slate-50 focus:ring-slate-500 disabled:bg-slate-100',
    ghost: 'text-slate-600 hover:bg-slate-100 focus:ring-slate-500',
  }
  return (
    <button type="button" className={`${base} ${variants[variant]}`} disabled={disabled} {...props}>
      {children}
    </button>
  )
}

function Input({ label, id, className = '', as, rows = 3, ...props }) {
  const inputClasses = "w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
  return (
    <div className={className}>
      <label htmlFor={id} className="mb-1 block text-xs font-semibold uppercase tracking-wide text-slate-500">
        {label}
      </label>
      {as === 'textarea' ? (
        <textarea id={id} className={inputClasses} rows={rows} {...props} />
      ) : (
        <input id={id} className={inputClasses} {...props} />
      )}
    </div>
  )
}

function Select({ label, id, options, ...props }) {
  return (
    <div>
      <label htmlFor={id} className="mb-1 block text-xs font-semibold uppercase tracking-wide text-slate-500">
        {label}
      </label>
      <select
        id={id}
        className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
        {...props}
      >
        {options.map((opt) => (
          <option key={opt.value} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </div>
  )
}

function formatCost(cost) {
  if (cost === null || cost === undefined) return '$0.00'
  return `$${Number(cost).toFixed(4)}`
}

const isNetworkError = (err) => err instanceof TypeError || err?.message === 'Failed to fetch'

function App() {
  const [environments, setEnvironments] = useState([])
  const [cost, setCost] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [form, setForm] = useState({
    project_name: '',
    provider: 'aws',
    ttl_minutes: 60,
    compute_tier: 'small',
    region: 'us-east-1',
    volume_size: 10,
    storage_tier: 'balanced',
    notes: '',
    tags: '',
    ssh_key_name: '',
  })
  const [showAdvanced, setShowAdvanced] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [destroyingId, setDestroyingId] = useState(null)
  const [terminateTarget, setTerminateTarget] = useState(null)
  const [wsStatus, setWsStatus] = useState('connecting')
  const [cableToken, setCableToken] = useState(null)
  const [wsReconnectAttempt, setWsReconnectAttempt] = useState(0)
  const [mockMode, setMockMode] = useState(true)
  const [availableProviders, setAvailableProviders] = useState(PROVIDERS)
  const [coldStarting, setColdStarting] = useState(false)
  const [serverUnreachable, setServerUnreachable] = useState(false)
  const [showAdBlockerTip, setShowAdBlockerTip] = useState(false)
  const [statusFilter, setStatusFilter] = useState('')
  const [search, setSearch] = useState('')
  const [sort, setSort] = useState({ key: 'created_at', direction: 'desc' })
  const [expandedId, setExpandedId] = useState(null)
  const cancelButtonRef = useRef(null)
  const wakeAbortRef = useRef(null)
  const wakeTimeoutRef = useRef(null)
  const reconnectTimeoutRef = useRef(null)
  const reconnectAttemptRef = useRef(0)
  const mounted = useRef(true)
  const statusFilterRef = useRef(statusFilter)
  statusFilterRef.current = statusFilter
  const providerOptions = availableProviders.map((provider) => ({
    value: provider.value || provider.id,
    label: provider.label,
  }))

  useEffect(() => {
    return () => {
      mounted.current = false
    }
  }, [])

  useEffect(() => {
    const enabled = new Set(availableProviders.map((provider) => provider.value || provider.id))
    if (enabled.has(form.provider)) return

    const nextProvider = availableProviders[0]?.value || availableProviders[0]?.id || 'aws'
    setForm((previous) => ({
      ...previous,
      provider: nextProvider,
      region: PROVIDER_REGIONS[nextProvider]?.[0]?.value || previous.region,
    }))
  }, [availableProviders, form.provider])

  const fetchEnvironments = useCallback(async () => {
    const query = statusFilter ? `?status=${encodeURIComponent(statusFilter)}` : ''
    const res = await authorizedFetch(`${API_BASE}/environments${query}`, {
      headers: { 'X-API-Key': API_KEY },
    })
    if (!res.ok) {
      const data = await res.json().catch(() => ({}))
      throw new Error(data.error || `HTTP ${res.status}`)
    }
    const data = await res.json()
    setEnvironments((data.environments || []).filter((env) => env.status !== 'terminated'))
    setCost(data.cost || null)
    // A successful refresh means the backend is reachable. Clear stale errors.
    setError(null)
  }, [statusFilter, setError])

  const tryRefreshEnvironments = async () => {
    try {
      setError(null)
      setLoading(true)
      await fetchEnvironments()
    } catch (err) {
      console.error('[SEEO] fetchEnvironments failed:', err)
      setError(err.message)
    } finally {
      setLoading(false)
    }
  }

  const environmentsRef = useRef(environments)
  environmentsRef.current = environments

  const fetchHealth = async (signal) => {
    try {
      // Health is public. Omit auth headers to avoid a CORS preflight on /health.
      const res = await fetch(`${API_BASE}/health`, { signal })
      if (!res.ok) return { ok: false, error: new Error(`HTTP ${res.status}`) }
      const data = await res.json()
      setMockMode(data.mock_mode === true)
      if (Array.isArray(data.providers) && data.providers.length > 0) setAvailableProviders(data.providers)
      setColdStarting(false)
      return { ok: true }
    } catch (err) {
      if (err.name === 'AbortError') return { ok: false, error: null }
      console.error('[SEEO] health check failed:', err)
      return { ok: false, error: err }
    }
  }

  const clearWakeRefs = () => {
    wakeAbortRef.current = null
    wakeTimeoutRef.current = null
  }

  const wakeAndRetry = async (fn) => {
    try {
      return await fn()
    } catch (err) {
      if (!isNetworkError(err)) throw err
      if (isLocalApi) {
        throw new Error(
          `Could not reach the backend at ${API_BASE || 'http://localhost:3000'}. ` +
          `Error: ${err.message}. Make sure the Rails server/Docker container is running and port 3000 is exposed. ` +
          `If the server is running, open the browser console (F12 → Console/Network) for details.`
        )
      }
      const controller = new AbortController()
      wakeAbortRef.current = controller
      setColdStarting(true)
      let attempts = 0
      return new Promise((resolve, reject) => {
        const tryWake = async () => {
          if (controller.signal.aborted) {
            clearWakeRefs()
            return reject(new Error('Cancelled'))
          }
          const health = await fetchHealth(controller.signal)
          if (health.ok) {
            if (!mounted.current) return
            setColdStarting(false)
            try {
              const result = await fn()
              clearWakeRefs()
              resolve(result)
            } catch (retryErr) {
              clearWakeRefs()
              reject(retryErr)
            }
          } else {
            if (!mounted.current) return
            attempts += 1
            if (attempts < 60) {
              wakeTimeoutRef.current = setTimeout(tryWake, 3000)
            } else {
              setColdStarting(false)
              setServerUnreachable(true)
              clearWakeRefs()
              reject(new Error(`Server unreachable${health.error?.message ? `: ${health.error.message}` : ''}`))
            }
          }
        }
        tryWake()
      })
    }
  }

  useEffect(() => {
    mounted.current = true
    let timeout = null
    const controller = new AbortController()

    const tryWake = async () => {
      const health = await fetchHealth(controller.signal)
      if (health.ok) {
        try {
          await fetchEnvironments()
          if (!mounted.current) return
          setError(null)
        } catch (err) {
          if (!mounted.current) return
          setError(err.message)
        } finally {
          if (mounted.current) {
            setLoading(false)
          }
        }
      } else {
        if (!mounted.current) return
        // In local dev, the Rails server in Docker can take a few seconds to boot.
        // Keep retrying until the backend is reachable so the error auto-clears
        // once the server is ready. In production, show the waking-up modal.
        if (!isLocalApi) setColdStarting(true)
        timeout = setTimeout(tryWake, 3000)
      }
    }

    tryWake()
    return () => {
      controller.abort()
      if (timeout) clearTimeout(timeout)
      if (wakeTimeoutRef.current) clearTimeout(wakeTimeoutRef.current)
      if (wakeAbortRef.current) wakeAbortRef.current.abort()
      mounted.current = false
    }
  }, [fetchEnvironments])

  useEffect(() => {
    if (!terminateTarget) return
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') setTerminateTarget(null)
    }
    document.addEventListener('keydown', handleKeyDown)
    cancelButtonRef.current?.focus()
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [terminateTarget])

  const connectWebSocket = useCallback(() => {
    if (reconnectTimeoutRef.current) {
      clearTimeout(reconnectTimeoutRef.current)
      reconnectTimeoutRef.current = null
    }

    if (!cableToken) return () => {}

    const ws = new WebSocket(getWsUrl(cableToken.token))

    ws.onopen = () => {
      reconnectAttemptRef.current = 0
      setWsStatus('connected')
      ws.send(JSON.stringify({
        command: 'subscribe',
        identifier: JSON.stringify({ channel: 'EnvironmentChannel', stream_key: `session_${cableToken.sessionId}` })
      }))
    }

    ws.onmessage = (event) => {
      try {
        const data = JSON.parse(event.data)
        if (data?.message?.environment) {
          setEnvironments((prev) => {
            const env = data.message.environment
            if (env.status === 'terminated') {
              return prev.filter((e) => e.id !== env.id)
            }
            // If a status filter is active, keep the live list consistent with it:
            // remove the environment if it no longer matches the filter, otherwise
            // add or update it in place.
            const filter = statusFilterRef.current
            if (filter && env.status !== filter) {
              return prev.filter((e) => e.id !== env.id)
            }
            const updated = [...prev]
            const index = updated.findIndex((e) => e.id === env.id)
            if (index >= 0) {
              updated[index] = env
            } else {
              updated.unshift(env)
            }
            return updated
          })
        }
      } catch {
        // Ignore non-environment ActionCable messages
      }
    }

    ws.onclose = () => scheduleReconnect(ws, 'disconnected')
    ws.onerror = () => scheduleReconnect(ws, 'error')

    return () => {
      ws._stale = true
      ws.close()
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current)
        reconnectTimeoutRef.current = null
      }
    }
  }, [cableToken])

  // Poll every few seconds while environments are still provisioning or the
  // WebSocket is not connected, so the UI updates even if the socket is blocked.
  useEffect(() => {
    const interval = setInterval(() => {
      const hasProvisioning = environmentsRef.current.some((env) => env.status === 'provisioning')
      if (mounted.current && (hasProvisioning || wsStatus !== 'connected')) {
        fetchEnvironments().catch(() => {})
      }
    }, 4000)
    return () => clearInterval(interval)
  }, [fetchEnvironments, wsStatus])

  useEffect(() => {
    let cancelled = false
    const requestCableToken = async () => {
      let sessionToken = await ensureSessionToken()
      let sessionId = SESSION_ID
      let res = await fetch(`${API_BASE}/cable-token`, {
        headers: { 'X-API-Key': API_KEY, 'X-Session-Token': sessionToken },
      })
      if (res.status === 401) {
        sessionToken = await ensureSessionToken(true)
        sessionId = SESSION_ID
        res = await fetch(`${API_BASE}/cable-token`, {
          headers: { 'X-API-Key': API_KEY, 'X-Session-Token': sessionToken },
        })
      }
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      const data = await res.json()
      return { token: data.token, sessionId }
    }

    requestCableToken()
      .then((data) => {
        if (!cancelled) setCableToken(data)
      })
      .catch((err) => {
        console.warn('[SEEO] ActionCable token request failed:', err)
        if (!cancelled) setWsStatus('disconnected')
      })
    return () => { cancelled = true }
  }, [wsReconnectAttempt])

  useEffect(() => {
    mounted.current = true
    const cleanup = connectWebSocket()
    return () => {
      mounted.current = false
      if (cleanup) cleanup()
    }
  }, [connectWebSocket, wsReconnectAttempt])

  const scheduleReconnect = (ws, status) => {
    if (!mounted.current) return
    if (reconnectTimeoutRef.current || ws._stale) return

    setWsStatus(status)
    reconnectAttemptRef.current += 1
    const delay = Math.min(1000 * 2 ** reconnectAttemptRef.current, 30000)
    reconnectTimeoutRef.current = setTimeout(() => {
      if (!mounted.current) return
      setWsReconnectAttempt((prev) => prev + 1)
    }, delay)
  }

  const handleReconnect = () => {
    if (wsStatus === 'connected') return
    reconnectAttemptRef.current = 0
    setWsStatus('connecting')
    setWsReconnectAttempt((prev) => prev + 1)
  }

  const parseTags = (input) => {
    const tags = {}
    if (!input.trim()) return tags
    input.split(',').forEach((pair) => {
      const [key, ...rest] = pair.split('=')
      if (key && rest.length > 0) {
        tags[key.trim()] = rest.join('=').trim()
      }
    })
    return tags
  }

  const createEnvironment = async (formData, idempotencyKey) => {
    const payload = {
      project_name: formData.project_name,
      ttl_minutes: formData.ttl_minutes,
      provider: formData.provider,
      compute_tier: formData.compute_tier,
      region: formData.region,
      volume_size: formData.volume_size,
      storage_tier: formData.storage_tier,
      notes: formData.notes,
      tags: parseTags(formData.tags),
      ssh_key_name: formData.ssh_key_name,
    }
    const res = await authorizedFetch(`${API_BASE}/environments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': API_KEY,
        'X-Idempotency-Key': idempotencyKey,
      },
      body: JSON.stringify(payload),
    })
    if (!res.ok) {
      const data = await res.json().catch(() => ({}))
      console.error('[SEEO] createEnvironment failed:', data.error || `HTTP ${res.status}`)
      throw new Error(data.error || `HTTP ${res.status}`)
    }
    return res.json()
  }

  const handleCreate = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)
    setError(null)
    try {
      const idempotencyKey = typeof crypto !== 'undefined' && crypto.randomUUID
        ? crypto.randomUUID()
        : `idempotency-${Date.now()}-${Math.random().toString(16).slice(2)}`
      await wakeAndRetry(() => createEnvironment(form, idempotencyKey))
      // Refresh the list, but don't let a transient refresh failure overwrite
      // the success of the create. Polling/WebSocket will catch up.
      await fetchEnvironments().catch((err) => {
        console.warn('[SEEO] post-create refresh failed:', err)
      })
      setForm({
        project_name: '',
        ttl_minutes: 60,
        provider: 'aws',
        compute_tier: 'small',
        region: 'us-east-1',
        volume_size: 10,
        storage_tier: 'balanced',
        notes: '',
        tags: '',
        ssh_key_name: '',
      })
    } catch (err) {
      console.error('[SEEO] handleCreate error:', err)
      setError(err.message)
    } finally {
      setIsSubmitting(false)
    }
  }

  const destroyEnvironment = async (id) => {
    const res = await authorizedFetch(`${API_BASE}/environments/${id}`, {
      method: 'DELETE',
      headers: { 'X-API-Key': API_KEY },
    })
    if (!res.ok) {
      const data = await res.json().catch(() => ({}))
      console.error('[SEEO] destroyEnvironment failed:', data.error || `HTTP ${res.status}`)
      throw new Error(data.error || `HTTP ${res.status}`)
    }
    return res.json()
  }

  const handleDestroy = async () => {
    if (!terminateTarget) return
    setDestroyingId(terminateTarget.id)
    setError(null)
    try {
      await wakeAndRetry(() => destroyEnvironment(terminateTarget.id))
      await fetchEnvironments().catch((err) => {
        console.warn('[SEEO] post-destroy refresh failed:', err)
      })
    } catch (err) {
      console.error('[SEEO] handleDestroy error:', err)
      setError(err.message)
    } finally {
      setDestroyingId(null)
      setTerminateTarget(null)
    }
  }

  const filteredEnvironments = environments
    .filter((env) => {
      if (!search.trim()) return true
      const term = search.toLowerCase()
      return (
        env.project_name?.toLowerCase().includes(term) ||
        env.id?.toLowerCase().includes(term) ||
        env.provider?.toLowerCase().includes(term) ||
        env.instance_type?.toLowerCase().includes(term) ||
        env.region?.toLowerCase().includes(term)
      )
    })
    .sort((a, b) => {
      let aVal = a[sort.key]
      let bVal = b[sort.key]
      if (sort.key === 'created_at') {
        aVal = aVal || a.id
        bVal = bVal || b.id
      }
      if (typeof aVal === 'string') aVal = aVal.toLowerCase()
      if (typeof bVal === 'string') bVal = bVal.toLowerCase()
      if (aVal < bVal) return sort.direction === 'asc' ? -1 : 1
      if (aVal > bVal) return sort.direction === 'asc' ? 1 : -1
      return 0
    })

  const handleSort = (key) => {
    setSort((prev) => ({
      key,
      direction: prev.key === key && prev.direction === 'asc' ? 'desc' : 'asc',
    }))
  }

  const SortIcon = ({ column }) => {
    if (sort.key !== column) return <span className="ml-1 text-slate-400">↕</span>
    return <span className="ml-1 text-indigo-600">{sort.direction === 'asc' ? '↑' : '↓'}</span>
  }

  const toggleExpand = (id) => {
    setExpandedId((prev) => (prev === id ? null : id))
  }

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      {mockMode && (
        <div className="border-b border-amber-200 bg-amber-50 px-4 py-2 text-center text-sm font-medium text-amber-900" role="status">
          <span className="font-bold">Safe demo mode:</span> every provider is simulated in memory; no credentials, billable resources, or cloud API calls are used.
        </div>
      )}

      <header className="sticky top-0 z-50 border-b border-slate-200 bg-white/80 shadow-sm backdrop-blur">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex items-center gap-4">
            <a
              href="https://samueladegnan.github.io/"
              className="inline-flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 shadow-sm transition hover:border-slate-300 hover:bg-slate-50 hover:text-slate-900 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            >
              <span aria-hidden="true">←</span>
              Back to portfolio
            </a>
            <div>
              <h1 className="text-lg font-bold tracking-tight text-slate-900 sm:text-xl" aria-label="SEEO dashboard">SEEO</h1>
              <p className="hidden text-xs text-slate-500 sm:block">Ephemeral environments · multi-cloud control plane</p>
            </div>
          </div>
          <button
            type="button"
            onClick={handleReconnect}
            className="group relative flex items-center gap-2 rounded-lg p-2 text-sm transition hover:bg-slate-100 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            onMouseEnter={() => setShowAdBlockerTip(true)}
            onMouseLeave={() => setShowAdBlockerTip(false)}
            onFocus={() => setShowAdBlockerTip(true)}
            onBlur={() => setShowAdBlockerTip(false)}
            onKeyDown={(e) => {
              if (e.key === 'Escape') setShowAdBlockerTip(false)
            }}
            aria-live="polite"
          >
            <span className="hidden text-slate-500 sm:inline">Live updates:</span>
            <span
              className={`inline-flex h-2.5 w-2.5 rounded-full ${
                wsStatus === 'connected'
                  ? 'bg-emerald-500'
                  : wsStatus === 'connecting'
                  ? 'bg-amber-400'
                  : 'bg-rose-500'
              }`}
            />
            <span className="capitalize text-slate-600">{wsStatus}</span>
            <span
              aria-label="Why might Live updates be disconnected?"
              aria-describedby="ws-tooltip"
              className="inline-flex h-8 w-8 items-center justify-center rounded-full bg-amber-100 text-xs font-bold text-amber-800 group-hover:bg-amber-200"
            >
              ?
            </span>
            <span
              id="ws-tooltip"
              role="tooltip"
              className={`pointer-events-none absolute right-0 top-full z-50 mt-2 max-w-[calc(100vw-2rem)] rounded-lg bg-slate-800 p-3 text-xs leading-relaxed text-white shadow-lg transition-opacity w-64 sm:w-72 ${
                showAdBlockerTip ? 'opacity-100' : 'opacity-0'
              }`}
            >
              Ad blockers and privacy extensions sometimes block <code className="rounded bg-slate-700 px-1">.onrender.com</code> requests. If the dashboard seems stuck or <strong>Live updates</strong> shows disconnected, try disabling your ad blocker or opening this page in an incognito/private window. The backend may also take 30–50 seconds to wake up.
            </span>
          </button>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {error && (
          <div className="mb-6 rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800" role="alert">
            <p className="font-semibold">Error</p>
            <p className="text-sm">{error}</p>
            <button
              onClick={tryRefreshEnvironments}
              className="mt-3 rounded-md bg-rose-200 px-3 py-1.5 text-sm font-semibold text-rose-900 hover:bg-rose-300 focus:outline-none focus:ring-2 focus:ring-rose-500"
            >
              Retry
            </button>
          </div>
        )}

        <div className="mb-6 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.18em] text-indigo-600">Environment control plane</p>
            <h2 className="mt-1 text-2xl font-bold tracking-tight text-slate-900 sm:text-3xl">Build a safe, short-lived workspace</h2>
            <p className="mt-2 max-w-2xl text-sm leading-relaxed text-slate-600">Choose a provider, set an expiry window, and watch the lifecycle move through the same normalized contract used by the Rails API.</p>
          </div>
          <div className="flex items-center gap-2 text-xs text-slate-500" aria-label={`${availableProviders.length} cloud providers enabled`}>
            <span className="inline-flex h-2 w-2 rounded-full bg-emerald-500" aria-hidden="true" />
            {availableProviders.length} providers enabled
          </div>
        </div>

        <div className="mb-8 grid grid-cols-1 items-start gap-6 lg:grid-cols-3">
          <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200 lg:col-span-2">
            <h2 className="mb-4 text-lg font-semibold">Create environment</h2>
            <form onSubmit={handleCreate} className="space-y-4" aria-label="Create environment form">
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
                <Select
                  label="Cloud provider"
                  id="provider"
                  value={form.provider}
                  onChange={(e) => {
                    const provider = e.target.value
                    setForm({ ...form, provider, region: PROVIDER_REGIONS[provider][0].value })
                  }}
                  options={providerOptions}
                />
                <Input
                  label="Project name"
                  id="project-name"
                  type="text"
                  placeholder="e.g. web-api"
                  required
                  value={form.project_name}
                  onChange={(e) => setForm({ ...form, project_name: e.target.value })}
                  className="sm:col-span-2"
                />
                <Select
                  label="Region"
                  id="region"
                  value={form.region}
                  onChange={(e) => setForm({ ...form, region: e.target.value })}
                  options={PROVIDER_REGIONS[form.provider]}
                />
                <Select
                  label="Compute tier"
                  id="compute-tier"
                  value={form.compute_tier}
                  onChange={(e) => setForm({ ...form, compute_tier: e.target.value })}
                  options={COMPUTE_TIERS}
                />
              </div>

              {showAdvanced && (
                <div id="advanced-environment-options" className="rounded-xl border border-slate-200 bg-slate-50 p-4">
                  <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
                    <Input
                      label="TTL (minutes)"
                      id="ttl-minutes"
                      type="number"
                      min={1}
                      max={1440}
                      required
                      value={form.ttl_minutes}
                      onChange={(e) => setForm({ ...form, ttl_minutes: parseInt(e.target.value, 10) || 1 })}
                    />
                    <Input
                      label="Volume size (GB)"
                      id="volume-size"
                      type="number"
                      min={10}
                      max={1000}
                      value={form.volume_size}
                      onChange={(e) => setForm({ ...form, volume_size: parseInt(e.target.value, 10) || 10 })}
                    />
                    <Select
                      label="Storage tier"
                      id="storage-tier"
                      value={form.storage_tier}
                      onChange={(e) => setForm({ ...form, storage_tier: e.target.value })}
                      options={STORAGE_TIERS}
                    />
                    <Input
                      label="Tags"
                      id="tags"
                      type="text"
                      placeholder="env=demo, owner=sam"
                      value={form.tags}
                      onChange={(e) => setForm({ ...form, tags: e.target.value })}
                      className="sm:col-span-2"
                    />
                    <Input
                      label="SSH key name"
                      id="ssh-key-name"
                      type="text"
                      placeholder="seeo-demo-key"
                      value={form.ssh_key_name}
                      onChange={(e) => setForm({ ...form, ssh_key_name: e.target.value })}
                      className="sm:col-span-2"
                    />
                    <Input
                      label="Notes"
                      id="notes"
                      as="textarea"
                      rows={3}
                      placeholder="Add a description or purpose for this environment..."
                      value={form.notes}
                      onChange={(e) => setForm({ ...form, notes: e.target.value })}
                      className="sm:col-span-2"
                    />
                  </div>
                </div>
              )}

              <div className="flex flex-wrap items-center gap-3 sm:justify-end">
                <button
                  type="button"
                  aria-expanded={showAdvanced}
                  aria-controls="advanced-environment-options"
                  onClick={() => setShowAdvanced((prev) => !prev)}
                  className="text-sm font-medium text-slate-600 hover:text-slate-900 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                >
                  {showAdvanced ? 'Hide advanced' : 'Show advanced'}
                </button>
                <Button type="submit" disabled={isSubmitting}>
                  {isSubmitting ? 'Creating…' : 'Create environment'}
                </Button>
              </div>
            </form>
          </div>

          <div className="rounded-2xl bg-gradient-to-br from-emerald-700 to-teal-800 p-6 text-white shadow-sm">
            <h2 className="text-sm font-medium text-indigo-100">Estimated monthly cost</h2>
            <p className="mt-2 text-4xl font-bold">${cost?.total?.toFixed(2) || '0.00'}</p>
            <p className="mt-1 text-sm text-indigo-200">{cost?.environments_count || 0} environments</p>
            <p className="mt-4 text-xs text-indigo-200">
              Based on on-demand compute + storage rates for the configured TTL.
            </p>
            <div className="mt-5 flex flex-wrap gap-2" aria-label="Enabled cloud providers">
              {availableProviders.map((provider) => (
                <span key={provider.id || provider.value} className="rounded-full border border-white/20 bg-white/10 px-2.5 py-1 text-xs font-semibold text-white">
                  {provider.short_label || provider.shortLabel || provider.label || provider.id}
                </span>
              ))}
            </div>
          </div>
        </div>

        <div className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
          <div className="flex flex-col gap-4 border-b border-slate-200 px-6 py-4 sm:flex-row sm:items-center sm:justify-between">
            <h2 className="text-lg font-semibold">Environments</h2>
            <div className="flex flex-col gap-2 sm:flex-row">
              <label htmlFor="environment-search" className="sr-only">Search environments</label>
              <input
                id="environment-search"
                type="search"
                placeholder="Search environments…"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              />
              <label htmlFor="status-filter" className="sr-only">Filter by status</label>
              <select
                id="status-filter"
                value={statusFilter}
                onChange={(e) => setStatusFilter(e.target.value)}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              >
                <option value="">All statuses</option>
                <option value="provisioning">Provisioning</option>
                <option value="ready">Ready</option>
                <option value="terminating">Terminating</option>
              </select>
            </div>
          </div>

          {loading ? (
            <div className="p-8 text-center text-slate-500">Loading environments…</div>
          ) : filteredEnvironments.length === 0 ? (
            <div className="p-10 text-center">
              <div className="mx-auto flex h-12 w-12 items-center justify-center rounded-2xl bg-indigo-50 text-2xl" aria-hidden="true">⌁</div>
              <h3 className="mt-4 font-semibold text-slate-900">No environments match this view</h3>
              <p className="mx-auto mt-1 max-w-sm text-sm text-slate-500">Create a workspace above, or clear the search and status filters to see more lifecycle activity.</p>
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-slate-200 text-left text-sm" aria-label="Environments">
                <caption className="sr-only">List of provisioned environments</caption>
                <thead className="bg-slate-50">
                  <tr>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">
                      <button type="button" onClick={() => handleSort('project_name')} className="flex items-center font-semibold focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                        Project <SortIcon column="project_name" />
                      </button>
                    </th>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">
                      <button type="button" onClick={() => handleSort('status')} className="flex items-center font-semibold focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2">
                        Status <SortIcon column="status" />
                      </button>
                    </th>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">Provider</th>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">Region</th>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">Tier</th>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">TTL</th>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">Cost</th>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">IP</th>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200">
                  {filteredEnvironments.map((env) => (
                    <Fragment key={env.id}>
                      <tr className="hover:bg-slate-50">
                        <td className="px-6 py-4">
                          <div className="font-medium text-slate-900">{env.project_name}</div>
                          <div className="font-mono text-xs text-slate-500">{env.id}</div>
                        </td>
                        <td className="px-6 py-4">
                          <StatusBadge status={env.status} />
                        </td>
                        <td className="px-6 py-4 text-slate-600">{env.provider_label || env.provider}</td>
                        <td className="px-6 py-4 text-slate-600">{env.region}</td>
                        <td className="px-6 py-4 text-slate-600">{env.compute_tier || env.instance_type}</td>
                        <td className="px-6 py-4 text-slate-600">{env.ttl_minutes} min</td>
                        <td className="px-6 py-4 text-slate-600">{formatCost(env.cost)}</td>
                        <td className="px-6 py-4 text-slate-600">
                          {env.public_ip || '-'}
                          {mockMode && env.public_ip && <span className="ml-1 text-xs text-slate-400">(mock)</span>}
                        </td>
                        <td className="px-6 py-4">
                          <div className="flex items-center gap-3">
                            <button
                              type="button"
                              aria-expanded={expandedId === env.id}
                              onClick={() => toggleExpand(env.id)}
                              className="text-sm font-medium text-indigo-600 hover:text-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
                            >
                              {expandedId === env.id ? 'Hide' : 'Details'}
                            </button>
                            <button
                              type="button"
                              onClick={() => setTerminateTarget(env)}
                              disabled={destroyingId === env.id || env.status === 'terminating'}
                              aria-label={`Terminate environment ${env.project_name}`}
                              className="text-sm font-medium text-rose-600 hover:text-rose-700 disabled:opacity-50 disabled:cursor-not-allowed"
                            >
                              {destroyingId === env.id || env.status === 'terminating' ? 'Terminating…' : 'Terminate'}
                            </button>
                          </div>
                        </td>
                      </tr>
                      {expandedId === env.id && (
                        <tr className="bg-slate-50">
                          <td colSpan={9} className="px-6 py-4">
                            <EnvironmentDetails env={env} mockMode={mockMode} />
                          </td>
                        </tr>
                      )}
                    </Fragment>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </main>

      {coldStarting && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4 backdrop-blur-sm"
          role="status"
          aria-live="polite"
          aria-busy="true"
        >
          <div className="w-full max-w-md rounded-2xl bg-white p-6 text-center shadow-xl ring-1 ring-slate-200">
            <div className="mx-auto mb-4 h-8 w-8 animate-spin rounded-full border-4 border-indigo-200 border-t-indigo-600" aria-hidden="true" />
            <h3 className="text-lg font-semibold text-slate-900">Waking up the server…</h3>
            <p className="mt-2 text-sm text-slate-600">
              The demo backend sleeps after a period of inactivity. This can take 30–50 seconds.
            </p>
            <p className="mt-2 text-xs text-slate-500">
              Still stuck? Ad blockers sometimes block requests to <code className="rounded bg-slate-100 px-1">.onrender.com</code> domains. Try disabling your ad blocker or opening this page in an incognito/private window.
            </p>
          </div>
        </div>
      )}

      {serverUnreachable && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4 backdrop-blur-sm"
          role="dialog"
          aria-modal="true"
          aria-labelledby="unreachable-title"
        >
          <div className="w-full max-w-md rounded-2xl bg-white p-6 text-center shadow-xl ring-1 ring-slate-200">
            <h3 id="unreachable-title" className="text-lg font-semibold text-slate-900">Demo server unavailable</h3>
            <p className="mt-2 text-sm text-slate-600">
              The live backend could not be reached. Ad blockers sometimes block requests to <code className="rounded bg-slate-100 px-1">.onrender.com</code> domains. Try disabling your ad blocker or opening this page in an incognito/private window. You can also run the demo locally.
            </p>
            <div className="mt-6 flex justify-center gap-3">
              <Button variant="secondary" onClick={() => setServerUnreachable(false)}>
                Close
              </Button>
              <a
                href="http://localhost:5173"
                target="_blank"
                rel="noopener noreferrer"
                className="inline-flex items-center justify-center rounded-lg bg-indigo-600 px-4 py-2 text-sm font-semibold text-white hover:bg-indigo-700"
              >
                Open Local Demo
              </a>
            </div>
          </div>
        </div>
      )}

      {terminateTarget && (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4 backdrop-blur-sm"
          role="dialog"
          aria-modal="true"
          aria-labelledby="terminate-title"
          onClick={(e) => {
            if (e.currentTarget === e.target) setTerminateTarget(null)
          }}
        >
          <div className="w-full max-w-sm rounded-2xl bg-white p-6 shadow-xl ring-1 ring-slate-200">
            <h3 id="terminate-title" className="text-lg font-semibold text-slate-900">Terminate environment?</h3>
            <p className="mt-2 text-sm text-slate-600">
              This will permanently terminate <strong className="text-slate-900">{terminateTarget.project_name}</strong>.
            </p>
            <div className="mt-6 flex justify-end gap-3">
              <button
                type="button"
                ref={cancelButtonRef}
                onClick={() => setTerminateTarget(null)}
                className="rounded-lg px-4 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleDestroy}
                disabled={!!destroyingId}
                className="rounded-lg bg-rose-600 px-4 py-2 text-sm font-semibold text-white hover:bg-rose-700 disabled:opacity-50"
              >
                {destroyingId ? 'Terminating…' : 'Terminate'}
              </button>
            </div>
          </div>
        </div>
      )}

      <footer className="border-t border-slate-200 bg-white py-6">
        <div className="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
          <p className="text-center text-sm leading-relaxed text-slate-500">Built with Ruby on Rails and Terraform across AWS, Azure, Google Cloud, and OCI.<br />Samuel Degnan made the final engineering decisions and reviewed the code.</p>
        </div>
      </footer>
    </div>
  )
}

function EnvironmentDetails({ env, mockMode }) {
  const endpoint = env.public_ip || 'x.x.x.x'

  return (
    <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
      <DetailBlock title="Metadata">
        <DetailRow label="ID" value={env.id} />
        <DetailRow label="Project" value={env.project_name} />
        <DetailRow label="Provider" value={env.provider_label || env.provider} />
        <DetailRow label="Region" value={env.region} />
        <DetailRow label="Compute tier" value={env.compute_tier || env.instance_type} />
        <DetailRow label="Status" value={<StatusBadge status={env.status} />} />
      </DetailBlock>
      <DetailBlock title="Network & Storage">
        <DetailRow label="Public IP" value={env.public_ip || '-'} />
        <DetailRow label="Private IP" value={env.private_ip || '-'} />
        <DetailRow label="Instance ID" value={env.instance_id || '-'} />
        <DetailRow label="Storage" value={`${env.volume_size || 10} GB ${env.storage_tier || env.volume_type || 'balanced'}`} />
        <DetailRow label="Volume ID" value={env.volume_id || '-'} />
      </DetailBlock>
      <DetailBlock title="Lifecycle">
        <DetailRow label="Created" value={env.created_at ? new Date(env.created_at).toLocaleString() : '-'} />
        <DetailRow label="Expires" value={env.expires_at ? new Date(env.expires_at).toLocaleString() : '-'} />
        <DetailRow label="TTL" value={`${env.ttl_minutes} minutes`} />
        <DetailRow label="Estimated cost" value={formatCost(env.cost)} />
      </DetailBlock>
      <DetailBlock title="Connection">
        {env.public_ip ? (
          <>
            <DetailRow label="Provider resource" value={env.provider_resource_id || env.instance_id || '-'} code />
            <DetailRow label="Endpoint" value={endpoint} code />
            {mockMode && <p className="mt-2 text-xs text-amber-700">Mock mode. This endpoint is illustrative and not reachable.</p>}
          </>
        ) : (
          <p className="text-sm text-slate-500">No public IP assigned.</p>
        )}
      </DetailBlock>
      {env.notes && (
        <DetailBlock title="Notes" className="md:col-span-2">
          <p className="whitespace-pre-wrap text-sm text-slate-700">{env.notes}</p>
        </DetailBlock>
      )}
      {env.tags && Object.keys(env.tags).length > 0 && (
        <DetailBlock title="Tags" className="md:col-span-2">
          <div className="flex flex-wrap gap-2">
            {Object.entries(env.tags).map(([key, value]) => (
              <span key={key} className="rounded-full bg-slate-100 px-2 py-1 text-xs text-slate-700">
                {key}={value}
              </span>
            ))}
          </div>
        </DetailBlock>
      )}
    </div>
  )
}

function DetailBlock({ title, children, className = '' }) {
  return (
    <div className={`rounded-xl border border-slate-200 bg-white p-4 ${className}`}>
      <h4 className="mb-3 text-xs font-bold uppercase tracking-wide text-slate-500">{title}</h4>
      {children}
    </div>
  )
}

function DetailRow({ label, value, code = false }) {
  return (
    <div className="flex items-start justify-between gap-4 py-1">
      <span className="text-sm text-slate-500">{label}</span>
      {code ? (
        <code className="max-w-[16rem] truncate rounded bg-slate-100 px-1 py-0.5 text-xs text-slate-700">{value}</code>
      ) : (
        <span className="text-sm font-medium text-slate-900">{value}</span>
      )}
    </div>
  )
}

export default App
