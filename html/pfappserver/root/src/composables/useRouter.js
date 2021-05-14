import { customRef } from '@vue/composition-api'

export const useRouterQueryParam = ($router, param = 'query') => {
  return customRef((track, trigger) => ({
    get() {
      track()
      const { currentRoute: { query: { [param]: value } = {} } = {} } = $router
      if (value && ![false, null].includes(value))
        return JSON.parse(value)
      else
        return undefined
    },
    set(newValue) {
      const { currentRoute } = $router
      const value = JSON.stringify(newValue)
      $router.replace({ ...currentRoute, query: { [param]: value } })
        .catch(e => { if (e.name !== "NavigationDuplicated") throw e })
        .finally(() => trigger())
    }
  }))
}