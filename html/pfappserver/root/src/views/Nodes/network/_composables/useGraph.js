import { computed, nextTick, onBeforeUnmount, onMounted, ref, toRefs, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'

export default (search, refs) => {
  const {
    reSearch
  } = search
  const {
    items
  } = toRefs(search)

  const nodes = computed(() => {
    let { 0: { nodes = [] } = {} } = items.value
    if (nodes.length === 1 && nodes.filter(n => n.type !== 'packetfence').length === 0) // ignore single `packetfence` node
      return []
    else
      return nodes
  })

  const links = computed(() => {
    let { 0: { links = [] } = {} } = items.value
    return links
  })

  const dimensions = ref({
    height: 0,
    width: 0,
    fit: 'min'
  })
  const layouts = ref(['radial', 'tree']) // available layouts
  const palettes = ref({
    autoreg: { yes: 'green', no: 'red' },
    online: { on: 'green', off: 'red', unknown: 'yellow' },
    voip: { yes: 'green', no: 'red' },
    status: { reg: 'green', unreg: 'red' }
  })
  const options = ref({
    layout: 'radial',
    legendPosition: 'top-right',
    palette: 'status', // autoreg|status|online|voip
    miniMapHeight: undefined,
    miniMapWidth: 200,
    miniMapPosition: 'top-left',
    minZoom: 0,
    maxZoom: 4,
    mouseWheelZoom: true,
    padding: 25,
    sort: search.sortBy,
    order: (search.sortDesc) ? 'DESC' : 'ASC'
  })
  const live = ref({
    enabled: false,
    allowed: false,
    interval: false,
    timeout: 30 * 1E3, // 30s
    options: [5000, 10000, 15000, 30000, 60000, 120000, 300000]
  })

  const graphRef = ref(null)
  let dimDebouncer
  const setDimensions = () => {
    if (!dimDebouncer)
      dimDebouncer = createDebouncer()
    dimDebouncer({
      handler: () => {
        // get width of svg container
        const { graphRef: { $el: { offsetWidth: width = 0 } = {} } = {} } = refs
        dimensions.value.width = width
        if (dimensions.value.fit === 'max')
          dimensions.value.height = width
        else {
          // get height of window document
          const documentHeight = Math.max(document.documentElement.clientHeight, window.innerHeight || 0)
          const { graphRef: { $el = {} } = {} } = refs
          const { top } = $el.getBoundingClientRect()
          const padding = 20 + 16 /* padding = 20, margin = 16 */
          let height = documentHeight - top - padding
          height = Math.max(height, width / 2) // minimum height of 1/2 width
          dimensions.value.height = height
        }
      },
      time: 100 // 100ms
    })
  }

  onMounted(() => { // after DOM is ready
    watch([
      items,
      () => dimensions.value.fit
    ], () => {
      nextTick(() => {
        setDimensions()
      })
    }, { deep: true, immediate: true })

    watch(() => options.value.sort, () => {
      search.useFields = () => {
        return [...(new Set([ // unique set
          ...['mac', 'last_seen', 'device_type', 'device_class', 'device_version', 'device_score', 'device_manufacturer'].map(key => `node.${key}`), // include `node.mac` and `node.last_seen`
          ...[options.value.sort].map(key => (key.includes('.')) ? key : `node.${key}`), // include `options`.`sort`
          ...Object.keys(palettes.value).map(key => `node.${key}`), // include node fields for palettes
          ...['description', 'type'].map(key => `switch.${key}`), // include `switch` data
          ...['connection_type', 'port', 'realm', 'role', 'ssid', 'switch_mac', 'vlan'].map(key => `locationlog.${key}`) // include `locationlog` data
        ]))]
      }
    }, { immediate: true })

    watch([ // after search is mutated w/ user_preference (saved search)
      () => search.sortBy,
      () => search.sortDesc
    ], ([sortBy, sortDesc]) => {
      if (sortBy !== options.value.sort)
        options.value.sort = sortBy
      if ((sortDesc) ? 'DESC' : 'ASC' !== options.value.order)
        options.value.order = (sortDesc) ? 'DESC' : 'ASC'
    })

    watch([
      () => options.value.sort,
      () => options.value.order
    ], () => {
      search.setSort({
        sortBy: options.value.sort,
        sortDesc: options.value.order === 'DESC'
      })
    })

    search.responseInterceptor = response => {
      // allowed live mode
      live.value.allowed = true
      // remap { network_graph: ... } => { items: [...] }
      const { network_graph, ...rest } = response || {}
      return { ...rest, items: [ network_graph ] }
    }

    watch([
      () => live.value.enabled,
      () => live.value.timeout
    ], () => {
      if (live.value.interval)
        clearInterval(live.value.interval)
      if (live.value.enabled)
        live.value.interval = setInterval(reSearch, live.value.timeout)
    })

    window.addEventListener('resize', setDimensions)
  })

  onBeforeUnmount(() => window.removeEventListener('resize', setDimensions))

  const onTouch = () => {
    live.value.allowed = false
    live.value.enabled = false
  }

  return {
    nodes,
    links,

    graphRef,
    dimensions,
    layouts,
    palettes,
    options,
    live,
    onTouch
  }
}