import store from '@/store'

/**
 * Wrap a route's beforeEnter so the route is unreachable in cloud.
 *
 * Sections that do not apply in cloud are hidden with the `no-saas` class, but
 * that only hides the link -- the route itself stays addressable by URL. The
 * `meta.can` those routes declare does not close the gap either: canRoute() in
 * App.vue reads it only to decide which top-level nav links to render, and
 * nothing consults it during navigation. So the redirect has to live in the
 * route's own guard, which is what this provides.
 *
 * Define the guard once at the root of a route subtree rather than on each
 * sibling: `networks/_router.js`, for instance, already wraps every route it
 * owns (including the interfaces, layer2 and routed-network children it
 * imports), so wrapping there covers all of them.
 *
 * The system summary is fetched by the global beforeEach ahead of the first
 * navigation, so `isSaas` is populated by the time this runs.
 *
 * @param {Function} [beforeEnter] existing guard to run when not in cloud
 * @param {String} [redirect] name of the route to send cloud users to
 */
export const onPremOnly = (beforeEnter, redirect = 'configuration') =>
  (to, from, next = () => {}) => {
    if (store.getters['system/isSaas']) {
      next({ name: redirect })
      return
    }
    if (beforeEnter) {
      beforeEnter(to, from, next)
      return
    }
    next()
  }

export default { onPremOnly }
