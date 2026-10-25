import { Link } from 'react-router'

export function NotFoundPage() {
  return (
    <section className="space-y-3">
      <h1 className="text-2xl font-semibold tracking-tight">Page not found</h1>
      <Link to="/" className="text-sm font-medium text-sky-700 underline underline-offset-2">
        Back to home
      </Link>
    </section>
  )
}
