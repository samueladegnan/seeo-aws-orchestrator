import { useEffect, useState, useRef } from 'react'

const API_KEY = import.meta.env.VITE_SEEO_API_KEY || 'dev-change-me-in-production'
const API_BASE = import.meta.env.VITE_API_BASE || ''

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
  }
  return (
    <button className={`${base} ${variants[variant]}`} disabled={disabled} {...props}>
      {children}
    </button>
  )
}

const isNetworkError = (err) => err instanceof TypeError || err?.message === 'Failed to fetch'

function App() {
  const [environments, setEnvironments] = useState([])
  const [cost, setCost] = useState(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [form, setForm] = useState({ project_name: '', ttl_minutes: 60, instance_type: 't3.micro' })
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [destroyingId, setDestroyingId] = useState(null)
  const [terminateTarget, setTerminateTarget] = useState(null)
  const [wsStatus, setWsStatus] = useState('connecting')
  const [mockMode, setMockMode] = useState(true)
  const [coldStarting, setColdStarting] = useState(false)
  const [serverUnreachable, setServerUnreachable] = useState(false)
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
    const res = await fetch(`${API_BASE}/environments`, {
      headers: { 'X-API-Key': API_KEY },
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
        headers: { 'X-API-Key': API_KEY },
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
  }, [])

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
      ws.send(JSON.stringify({ command: 'subscribe', identifier: JSON.stringify({ channel: 'EnvironmentChannel' }) }))
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
        // Ignore non-environment ActionCable messages (pings, confirmations, etc.)
      }
    }

    ws.onclose = () => setWsStatus('disconnected')
    ws.onerror = () => setWsStatus('error')

    return () => ws.close()
  }, [])

  const createEnvironment = async (formData) => {
    const res = await fetch(`${API_BASE}/environments`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': API_KEY,
      },
      body: JSON.stringify(formData),
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
      setForm({ project_name: '', ttl_minutes: 60, instance_type: 't3.micro' })
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
      headers: { 'X-API-Key': API_KEY },
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

  return (
    <div className="min-h-screen bg-slate-50 text-slate-900">
      {mockMode && (
        <div className="bg-amber-100 px-4 py-2 text-center text-sm font-medium text-amber-900">
          Demo Mode — no real AWS resources are provisioned.
        </div>
      )}

      <header className="sticky top-0 z-50 border-b border-slate-200 bg-white/80 shadow-sm backdrop-blur">
        <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
          <div className="flex items-center gap-3">
            <h1 className="text-xl font-bold tracking-tight text-slate-900">SEEO</h1>
            <a
              href="https://samueladegnan.github.io/"
              target="_self"
              rel="noopener noreferrer"
              className="hidden rounded-md bg-slate-100 px-2 py-1 text-xs font-medium text-slate-700 hover:bg-slate-200 sm:inline-block"
            >
              ← Back to portfolio
            </a>
          </div>
          <div className="flex items-center gap-2 text-sm" title="Ad blockers may block the real-time WebSocket connection">
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
          </div>
        </div>
      </header>

      <main className="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">
        {error && (
          <div className="mb-6 rounded-lg border border-rose-200 bg-rose-50 p-4 text-rose-800">
            <p className="font-semibold">Error</p>
            <p className="text-sm">{error}</p>
          </div>
        )}

        <div className="mb-8 grid grid-cols-1 gap-6 lg:grid-cols-3">
          <div className="rounded-2xl bg-white p-6 shadow-sm ring-1 ring-slate-200 lg:col-span-2">
            <h2 className="mb-4 text-lg font-semibold">Create environment</h2>
            <form onSubmit={handleCreate} className="grid grid-cols-1 gap-4 sm:grid-cols-4">
              <input
                type="text"
                placeholder="Project name"
                required
                value={form.project_name}
                onChange={(e) => setForm({ ...form, project_name: e.target.value })}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500 sm:col-span-2"
              />
              <input
                type="number"
                min={1}
                required
                value={form.ttl_minutes}
                onChange={(e) => setForm({ ...form, ttl_minutes: parseInt(e.target.value, 10) || 1 })}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              />
              <select
                value={form.instance_type}
                onChange={(e) => setForm({ ...form, instance_type: e.target.value })}
                className="rounded-lg border border-slate-300 px-3 py-2 text-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500"
              >
                <option value="t3.micro">t3.micro</option>
                <option value="t3.small">t3.small</option>
                <option value="t3.medium">t3.medium</option>
                <option value="m6i.large">m6i.large</option>
              </select>
              <div className="sm:col-span-4 sm:flex sm:justify-end">
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
          </div>
        </div>

        <div className="overflow-hidden rounded-2xl bg-white shadow-sm ring-1 ring-slate-200">
          <div className="border-b border-slate-200 px-6 py-4">
            <h2 className="text-lg font-semibold">Environments</h2>
          </div>

          {loading ? (
            <div className="p-8 text-center text-slate-500">Loading environments…</div>
          ) : environments.length === 0 ? (
            <div className="p-8 text-center text-slate-500">No environments found.</div>
          ) : (
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-slate-200 text-left text-sm">
                <thead className="bg-slate-50">
                  <tr>
                    <th className="px-6 py-3 font-semibold text-slate-700">ID</th>
                    <th className="px-6 py-3 font-semibold text-slate-700">Project</th>
                    <th className="px-6 py-3 font-semibold text-slate-700">Status</th>
                    <th className="px-6 py-3 font-semibold text-slate-700">Type</th>
                    <th className="px-6 py-3 font-semibold text-slate-700">TTL (min)</th>
                    <th className="px-6 py-3 font-semibold text-slate-700">IP</th>
                    <th className="px-6 py-3 font-semibold text-slate-700">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200">
                  {environments.map((env) => (
                    <tr key={env.id} className="hover:bg-slate-50">
                      <td className="whitespace-nowrap px-6 py-4 font-mono text-slate-600">{env.id}</td>
                      <td className="whitespace-nowrap px-6 py-4 font-medium text-slate-900">{env.project_name}</td>
                      <td className="whitespace-nowrap px-6 py-4">
                        <StatusBadge status={env.status} />
                      </td>
                      <td className="whitespace-nowrap px-6 py-4 text-slate-600">{env.instance_type}</td>
                      <td className="whitespace-nowrap px-6 py-4 text-slate-600">{env.ttl_minutes}</td>
                      <td className="whitespace-nowrap px-6 py-4 text-slate-600">
                        {env.public_ip || '—'}
                        {mockMode && env.public_ip && (
                          <span className="ml-1 text-xs text-slate-400">(mock)</span>
                        )}
                      </td>
                      <td className="whitespace-nowrap px-6 py-4">
                        <button
                          onClick={() => setTerminateTarget(env)}
                          disabled={destroyingId === env.id || env.status === 'terminating'}
                          aria-label={`Terminate environment ${env.project_name}`}
                          className="text-sm font-medium text-rose-600 hover:text-rose-700 disabled:opacity-50 disabled:cursor-not-allowed"
                        >
                          {destroyingId === env.id || env.status === 'terminating' ? 'Terminating…' : 'Terminate'}
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </main>

      {coldStarting && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 text-center shadow-xl ring-1 ring-slate-200">
            <div className="mx-auto mb-4 h-8 w-8 animate-spin rounded-full border-4 border-indigo-200 border-t-indigo-600" />
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
    </div>
  )
}

export default App
