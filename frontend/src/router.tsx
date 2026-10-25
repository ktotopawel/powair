import { createBrowserRouter } from 'react-router'
import { Layout } from './components/Layout.tsx'
import { HomePage } from './pages/HomePage.tsx'
import { NotFoundPage } from './pages/NotFoundPage.tsx'
import { StationsPage } from './pages/StationsPage.tsx'

export const router = createBrowserRouter([
  {
    element: <Layout />,
    children: [
      { index: true, element: <HomePage /> },
      { path: 'stations', element: <StationsPage /> },
      { path: '*', element: <NotFoundPage /> },
    ],
  },
])
