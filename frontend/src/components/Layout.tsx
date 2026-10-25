import { Link, NavLink, Outlet } from 'react-router'

const navLinkClass = ({ isActive }: { isActive: boolean }) =>
  `flex min-h-11 items-center rounded-md px-3 text-sm font-medium ${
    isActive ? 'bg-sky-100 text-sky-900' : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
  }`

export function Layout() {
  return (
    <div className="flex min-h-screen flex-col bg-slate-50 text-slate-900">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-5xl items-center justify-between gap-4 px-4 py-3">
          <Link to="/" className="text-lg font-semibold tracking-tight text-sky-700">
            PowAir
          </Link>
          <nav className="flex gap-1">
            <NavLink to="/stations" className={navLinkClass}>
              Stations
            </NavLink>
          </nav>
        </div>
      </header>

      <main className="mx-auto w-full max-w-5xl flex-1 px-4 py-6">
        <Outlet />
      </main>

      <footer className="border-t border-slate-200 bg-white">
        <div className="mx-auto max-w-5xl px-4 py-4 text-xs text-slate-500">
          Data source:{' '}
          <a
            href="https://powietrze.gios.gov.pl/"
            target="_blank"
            rel="noreferrer"
            className="font-medium text-slate-700 underline underline-offset-2 hover:text-sky-700"
          >
            Główny Inspektorat Ochrony Środowiska (GIOŚ)
          </a>
          . Current readings are unverified data.
        </div>
      </footer>
    </div>
  )
}
