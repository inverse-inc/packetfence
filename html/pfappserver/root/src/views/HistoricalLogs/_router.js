import { HISTORICAL_LOGS_PANEL, showPanel } from '@/plugins'

/**
 * Historical logs are a panel under the header (_components/ThePanel). Their
 * URLs open it, over the page the admin is on (or the default page when the
 * address is entered).
 */
// no page to stay on: /login, and its aliases /logout and /expire. After the
// login, a bookmark of the panel opens it over the default page.
const NO_PAGE = ['login']

const openPanel = (to, from, next) => {
  showPanel(HISTORICAL_LOGS_PANEL)
  next((from && from.matched.length && !NO_PAGE.includes(from.name)) ? false : '/')
}

export default [
  {
    path: '/historical-logs',
    name: 'historical_logs',
    meta: {
      can: 'read system'
    },
    beforeEnter: openPanel
  },
  {
    path: '/historical-logs/:id',
    name: 'historical_log',
    meta: {
      can: 'read system'
    },
    beforeEnter: openPanel
  }
]
