import { Link } from 'react-router'

export function HomePage() {
  return (
    <section className="space-y-3">
      <h1 className="text-2xl font-semibold tracking-tight">Air quality in Poland</h1>
      <p className="text-slate-600">Browse GIOŚ monitoring stations, current readings and measurement history.</p>
      <Link to="/stations" className="inline-flex min-h-11 items-center rounded-md bg-sky-700 px-4 text-sm font-medium text-white hover:bg-sky-800">
        Browse stations
      </Link>
    </section>
  )
}
