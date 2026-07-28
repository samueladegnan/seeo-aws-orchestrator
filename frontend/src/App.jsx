import { Fragment, useEffect, useState, useRef } from 'react'

const API_KEY = import.meta.env.VITE_SEEO_API_KEY || 'dev-change-me-in-production'
const API_BASE = import.meta.env.VITE_API_BASE || ''

const REGIONS = [
  { value: 'us-east-1', label: 'US East (N. Virginia)' },
  { value: 'us-west-2', label: 'US West (Oregon)' },
  { value: 'eu-west-1', label: 'Europe (Ireland)' },
  { value: 'ap-southeast-1', label: 'Asia Pacific (Singapore)' },
]

const INSTANCE_TYPES = [
  { value: 't3.micro', label: 't3.micro (2 vCPU, 1 GiB)' },
  { value: 't3.small', label: 't3.small (2 vCPU, 2 GiB)' },
  { value: 't3.medium', label: 't3.medium (2 vCPU, 4 GiB)' },
  { value: 'm6i.large', label: 'm6i.large (2 vCPU, 8 GiB)' },
  { value: 'm5.large', label: 'm5.large (2 vCPU, 8 GiB)' },
  { value: 'm5.xlarge', label: 'm5.xlarge (4 vCPU, 16 GiB)' },
  { value: 'c5.large', label: 'c5.large (2 vCPU, 4 GiB)' },
]

const VOLUME_TYPES = [
  { value: 'gp3', label: 'gp3 — General purpose SSD' },
  { value: 'io2', label: 'io2 — Provisioned IOPS SSD' },
  { value: 'st1', label: 'st1 — Throughput optimized HDD' },
]

function generateSessionId() {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID()
  }
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0
    const v = c === 'x' ? r : (r & 0x3) | 0x8
    return v.toString(16)
  })
}

const SESSION_ID = (() => {
  let id = null
  try {
    id = localStorage.getItem('seeo_session_id')
    if (!id) {
      id = generateSessionId()
      localStorage.setItem('seeo_session_id', id)
    }
  } catch {
    id = generateSessionId()
  }
  return id
})()

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
    <button className={`${base} ${variants[variant]}`} disabled={disabled} {...props}>
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
    ttl_minutes: 60,
    instance_type: 't3.micro',
    region: 'us-east-1',
    volume_size: 10,
    volume_type: 'gp3',
    notes: '',
    tags: '',
    ssh_key_name: '',
  })
  const [showAdvanced, setShowAdvanced] = useState(false)
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [destroyingId, setDestroyingId] = useState(null)
  const [terminateTarget, setTerminateTarget] = useState(null)
  const [wsStatus, setWsStatus] = useState('connecting')
  const [mockMode, setMockMode] = useState(true)
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
  const mounted = useRef(true)

  useEffect(() => {
    return () => {
      mounted.current = false
    }
  }, [])

  const fetchEnvironments = async () => {
    const query = statusFilter ? `?status=${encodeURIComponent(statusFilter)}` : ''
    const res = await fetch(`${API_BASE}/environments${query}`, {
      headers: { 'X-API-Key': API_KEY, 'X-Session-ID': SESSION_ID },
    })
    if (!res.ok) {
      const data = await res.json().catch(() => ({}))
      throw new Error(data.error || `HTTP ${res.status}`)
    }
    const data = await res.json()
    setEnvironments((data.environments || []).filter((env) => env.status !== 'terminated'))
    setCost(data.cost || null)
  }

  const fetchHealth = async (signal) => {
    try {
      const res = await fetch(`${API_BASE}/health`, {
        headers: { 'X-API-Key': API_KEY, 'X-Session-ID': SESSION_ID },
        signal,
      })
      if (!res.ok) return false
      const data = await res.json()
      setMockMode(data.mock_mode === true)
      setColdStarting(false)
      return true
    } catch {
      return false
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
          const ok = await fetchHealth(controller.signal)
          if (ok) {
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
              reject(new Error('Server unreachable'))
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
    let attempts = 0

    const tryWake = async () => {
      const ok = await fetchHealth(controller.signal)
      if (ok) {
        try {
          await fetchEnvironments()
          if (!mounted.current) return
          setError(null)
        } catch (err) {
          if (!mounted.current) return
          setError(err.message)
        } finally {
          if (!mounted.current) return
          setLoading(false)
        }
      } else {
        if (!mounted.current) return
        setColdStarting(true)
        attempts += 1
        if (attempts < 60) {
          timeout = setTimeout(tryWake, 3000)
        } else {
          setColdStarting(false)
          setLoading(false)
          setServerUnreachable(true)
        }
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
  }, [statusFilter])

  useEffect(() => {
    if (!terminateTarget) return
    const handleKeyDown = (e) => {
      if (e.key === 'Escape') setTerminateTarget(null)
    }
    document.addEventListener('keydown', handleKeyDown)
    cancelButtonRef.current?.focus()
    return () => document.removeEventListener('keydown', handleKeyDown)
  }, [terminateTarget])

  const getWsUrl = () => {
    if (API_BASE) {
      const base = API_BASE.replace(/\/$/, '')
      return base.replace(/^http/, 'ws') + '/cable'
    }
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:'
    return `${protocol}//${window.location.host}/cable`
  }

  useEffect(() => {
    const ws = new WebSocket(getWsUrl())

    ws.onopen = () => {
      setWsStatus('connected')
      ws.send(JSON.stringify({
        command: 'subscribe',
        identifier: JSON.stringify({ channel: 'EnvironmentChannel', session_id: SESSION_ID })
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
      } catch (e) {
        // Ignore non-environment ActionCable messages
      }
    }

    ws.onclose = () => setWsStatus('disconnected')
    ws.onerror = () => setWsStatus('error')

    return () => ws.close()
  }, [])

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

  const createEnvironment = async (formData) => {
    const payload = {
      project_name: formData.project_name,
      ttl_minutes: formData.ttl_minutes,
      instance_type: formData.instance_type,
      region: formData.region,
      volume_size: formData.volume_size,
      volume_type: formData.volume_type,
      notes: formData.notes,
      tags: parseTags(formData.tags),
      ssh_key_name: formData.ssh_key_name,
    }
    const res = await fetch(`${API_BASE}/environments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': API_KEY,
        'X-Session-ID': SESSION_ID,
      },
      body: JSON.stringify(payload),
    })
    if (!res.ok) {
      const data = await res.json().catch(() => ({}))
      throw new Error(data.error || `HTTP ${res.status}`)
    }
    return res.json()
  }

  const handleCreate = async (e) => {
    e.preventDefault()
    setIsSubmitting(true)
    try {
      await wakeAndRetry(() => createEnvironment(form))
      await fetchEnvironments()
      setForm({
        project_name: '',
        ttl_minutes: 60,
        instance_type: 't3.micro',
        region: 'us-east-1',
        volume_size: 10,
        volume_type: 'gp3',
        notes: '',
        tags: '',
        ssh_key_name: '',
      })
      setError(null)
    } catch (err) {
      setError(err.message)
    } finally {
      setIsSubmitting(false)
    }
  }

  const destroyEnvironment = async (id) => {
    const res = await fetch(`${API_BASE}/environments/${id}`, {
      method: 'DELETE',
      headers: { 'X-API-Key': API_KEY, 'X-Session-ID': SESSION_ID },
    })
    if (!res.ok) {
      const data = await res.json().catch(() => ({}))
      throw new Error(data.error || `HTTP ${res.status}`)
    }
    return res.json()
  }

  const handleDestroy = async () => {
    if (!terminateTarget) return
    setDestroyingId(terminateTarget.id)
    try {
      await wakeAndRetry(() => destroyEnvironment(terminateTarget.id))
      await fetchEnvironments()
      setError(null)
    } catch (err) {
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
        <div className="bg-amber-100 px-4 py-2 text-center text-sm font-medium text-amber-900">
          Demo Mode — no real AWS resources are provisioned.
        </div>
      )}

      <header className="sticky top-0 z-50 border-b border-slate-200 bg-white/80 shadow-sm backdrop-blur">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex items-center gap-4">
            <a
              href="https://samueladegnan.github.io/"
              target="_self"
              rel="noopener noreferrer"
              className="inline-flex items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-1.5 text-sm font-medium text-slate-700 shadow-sm transition hover:border-slate-300 hover:bg-slate-50 hover:text-slate-900 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2"
            >
              <span aria-hidden="true">←</span>
              Back to portfolio
            </a>
            <h1 className="text-xl font-bold tracking-tight text-slate-900" aria-label="SEEO dashboard">SEEO</h1>
          </div>
          <div
            className="group relative flex items-center gap-2 text-sm"
            onMouseEnter={() => setShowAdBlockerTip(true)}
            onMouseLeave={() => setShowAdBlockerTip(false)}
            onFocus={() => setShowAdBlockerTip(true)}
            onBlur={() => setShowAdBlockerTip(false)}
            onKeyDown={(e) => {
              if (e.key === 'Escape') setShowAdBlockerTip(false)
            }}
          >
            <span className="text-slate-500">Live updates:</span>
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
            <button
              type="button"
              onClick={() => setShowAdBlockerTip(true)}
              aria-label="Why might Live updates be disconnected?"
              aria-describedby="ws-tooltip"
              className="inline-flex h-8 w-8 items-center justify-center rounded-full bg-amber-100 text-xs font-bold text-amber-800 hover:bg-amber-200 focus:outline-none focus:ring-2 focus:ring-amber-400"
            >
              ?
            </button>
            <span
              id="ws-tooltip"
              role="tooltip"
              className={`pointer-events-none absolute right-0 top-full z-50 mt-2 max-w-[calc(100vw-2rem)] rounded-lg bg-slate-800 p-3 text-xs leading-relaxed text-white shadow-lg transition-opacity w-64 sm:w-72 ${
                showAdBlockerTip ? 'opacity-100' : 'opacity-0'
              }`}
            >
              Ad blockers and privacy extensions sometimes block <code className="rounded bg-slate-700 px-1">.onrender.com</code> requests. If the dashboard seems stuck or <strong>Live updates</strong> shows disconnected, try disabling your ad blocker or opening this page in an incognito/private window. The backend may also take 30–50 seconds to wake up.
            </span>
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {error && (
          <div className="mb-6 rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800" role="alert">
            <p className="font-semibold">Error</p>
            <p className="text-sm">{error}</p>
          </div>
        )}

        <div className="mb-8 grid grid-cols-1 gap-6 lg:grid-cols-3">
          <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200 lg:col-span-2">
            <h2 className="mb-4 text-lg font-semibold">Create environment</h2>
            <form onSubmit={handleCreate} className="space-y-4" aria-label="Create environment form">
              <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
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
                  options={REGIONS}
                />
                <Select
                  label="Instance type"
                  id="instance-type"
                  value={form.instance_type}
                  onChange={(e) => setForm({ ...form, instance_type: e.target.value })}
                  options={INSTANCE_TYPES}
                />
                <Input
                  label="TTL (minutes)"
                  id="ttl-minutes"
                  type="number"
                  min={1}
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
                  label="Volume type"
                  id="volume-type"
                  value={form.volume_type}
                  onChange={(e) => setForm({ ...form, volume_type: e.target.value })}
                  options={VOLUME_TYPES}
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
              </div>

              {showAdvanced && (
                <div className="rounded-xl border border-slate-200 bg-slate-50 p-4">
                  <Input
                    label="Notes"
                    id="notes"
                    as="textarea"
                    rows={3}
                    placeholder="Add a description or purpose for this environment..."
                    value={form.notes}
                    onChange={(e) => setForm({ ...form, notes: e.target.value })}
                  />
                </div>
              )}

              <div className="flex flex-wrap items-center gap-3 sm:justify-end">
                <button
                  type="button"
                  onClick={() => setShowAdvanced((prev) => !prev)}
                  className="text-sm font-medium text-slate-600 hover:text-slate-900"
                >
                  {showAdvanced ? 'Hide advanced' : 'Show advanced'}
                </button>
                <Button type="submit" disabled={isSubmitting}>
                  {isSubmitting ? 'Creating…' : 'Create environment'}
                </Button>
              </div>
            </form>
          </div>

          <div className="rounded-2xl bg-gradient-to-br from-indigo-600 to-violet-700 p-6 text-white shadow-sm">
            <h2 className="text-sm font-medium text-indigo-100">Estimated monthly cost</h2>
            <p className="mt-2 text-4xl font-bold">${cost?.total?.toFixed(2) || '0.00'}</p>
            <p className="mt-1 text-sm text-indigo-200">{cost?.environments_count || 0} environments</p>
            <p className="mt-4 text-xs text-indigo-200">
              Based on on-demand compute + storage rates for the configured TTL.
            </p>
          </div>
        </div>

        <div className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
          <div className="flex flex-col gap-4 border-b border-slate-200 px-6 py-4 sm:flex-row sm:items-center sm:justify-between">
            <h2 className="text-lg font-semibold">Environments</h2>
            <div className="flex flex-col gap-2 sm:flex-row">
              <input
                type="text"
                placeholder="Search..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              />
              <select
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
            <div className="p-8 text-center text-slate-500">No environments found.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-slate-200 text-left text-sm" aria-label="Environments">
                <caption className="sr-only">List of provisioned environments</caption>
                <thead className="bg-slate-50">
                  <tr>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">
                      <button onClick={() => handleSort('project_name')} className="flex items-center font-semibold">
                        Project <SortIcon column="project_name" />
                      </button>
                    </th>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">
                      <button onClick={() => handleSort('status')} className="flex items-center font-semibold">
                        Status <SortIcon column="status" />
                      </button>
                    </th>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">Region</th>
                    <th scope="col" className="px-6 py-3 font-semibold text-slate-700">Type</th>
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
                        <td className="px-6 py-4 text-slate-600">{env.region}</td>
                        <td className="px-6 py-4 text-slate-600">{env.instance_type}</td>
                        <td className="px-6 py-4 text-slate-600">{env.ttl_minutes} min</td>
                        <td className="px-6 py-4 text-slate-600">{formatCost(env.cost)}</td>
                        <td className="px-6 py-4 text-slate-600">
                          {env.public_ip || '—'}
                          {mockMode && env.public_ip && <span className="ml-1 text-xs text-slate-400">(mock)</span>}
                        </td>
                        <td className="px-6 py-4">
                          <div className="flex items-center gap-3">
                            <button
                              onClick={() => toggleExpand(env.id)}
                              className="text-sm font-medium text-indigo-600 hover:text-indigo-700"
                            >
                              {expandedId === env.id ? 'Hide' : 'Details'}
                            </button>
                            <button
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
                          <td colSpan={8} className="px-6 py-4">
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
              The live backend could not be reached. Ad blockers sometimes block requests to <code className="rounded bg-slate-100 px-1">.onrender.com</code> domains — try disabling your ad blocker or opening this page in an incognito/private window. You can also run the demo locally.
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
                Open local demo
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
                ref={cancelButtonRef}
                onClick={() => setTerminateTarget(null)}
                className="rounded-lg px-4 py-2 text-sm font-semibold text-slate-700 hover:bg-slate-100"
              >
                Cancel
              </button>
              <button
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
          <p className="text-center text-sm text-slate-500">Built with Ruby on Rails, Terraform & AWS.</p>
        </div>
      </footer>
    </div>
  )
}

function EnvironmentDetails({ env, mockMode }) {
  const sshCommand = env.ssh_key_name
    ? `ssh -i ~/.ssh/${env.ssh_key_name}.pem ec2-user@${env.public_ip || 'x.x.x.x'}`
    : `ssh ec2-user@${env.public_ip || 'x.x.x.x'}`

  return (
    <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
      <DetailBlock title="Metadata">
        <DetailRow label="ID" value={env.id} />
        <DetailRow label="Project" value={env.project_name} />
        <DetailRow label="Region" value={env.region} />
        <DetailRow label="Instance type" value={env.instance_type} />
        <DetailRow label="Status" value={<StatusBadge status={env.status} />} />
      </DetailBlock>
      <DetailBlock title="Network & Storage">
        <DetailRow label="Public IP" value={env.public_ip || '—'} />
        <DetailRow label="Private IP" value={env.private_ip || '—'} />
        <DetailRow label="Instance ID" value={env.instance_id || '—'} />
        <DetailRow label="Volume" value={`${env.volume_size || 10} GB ${env.volume_type || 'gp3'}`} />
        <DetailRow label="Volume ID" value={env.volume_id || '—'} />
      </DetailBlock>
      <DetailBlock title="Lifecycle">
        <DetailRow label="Created" value={env.created_at ? new Date(env.created_at).toLocaleString() : '—'} />
        <DetailRow label="Expires" value={env.expires_at ? new Date(env.expires_at).toLocaleString() : '—'} />
        <DetailRow label="TTL" value={`${env.ttl_minutes} minutes`} />
        <DetailRow label="Estimated cost" value={formatCost(env.cost)} />
      </DetailBlock>
      <DetailBlock title="Connection">
        {env.public_ip ? (
          <>
            <DetailRow label="SSH command" value={sshCommand} code />
            {mockMode && <p className="mt-2 text-xs text-amber-700">Mock mode — this IP is not real.</p>}
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
