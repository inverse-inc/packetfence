<template>
  <div ref="svgContainer" :class="[ 'svgContainer', { [`highlight highlight-${highlight}`]: highlight } ]">

    <!-- SVG drag layer (for event capture only) -->
    <svg ref="svgDrag" class="svgDrag"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      width="100%"
      :height="dimensions.height+'px'"
      :viewBox="viewBoxString"
      v-show="lastX && lastY"
      @mousemove="mouseMoveSvg($event)"
      @mouseout="mouseUpSvg($event)"
      @mouseup="mouseUpSvg($event)"
    ></svg>

    <!-- SVG draw layer -->
    <svg ref="svgDraw" :class="[ 'svgDraw', `zoom-${zoom}` ]"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      width="100%"
      :height="dimensions.height+'px'"
      :viewBox="viewBoxString"
      @mousedown.prevent="mouseDownSvg($event)"
      @mousewheel="mouseWheelSvg($event)"
    >
      <!-- symbol definitions -->
      <defs v-once>
<!--
        <filter x="0" y="0" width="1" height="1" id="label-white">
          <feFlood flood-color="yellow" result="bg" />
  <feComponentTransfer>
    <feFuncA type="linear" slope="0.2"/>
  </feComponentTransfer>
          <feMerge>
            <feMergeNode in="bg" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
-->
      </defs>

      <!-- background to capture node mouseout event -->
<!--
      <rect fill-opacity="0" :x="viewBox.minX" :y="viewBox.minY" :width="viewBox.width" :height="viewBox.height"
        @mouseover="mouseOutNode($event)"
      />
-->
      <!-- outer hosts ring -->
      <circle v-bind="svgOuterHostsRingProps" />

      <!-- inner hosts ring -->
      <circle v-bind="svgInnerHostsRingProps" />

      <!-- devices ring -->
      <circle v-bind="svgDevicesRingProps" />

      <!-- flows -->
      <path v-for="flow in flows" :key="flow.key" v-bind="flow.props" v-on="flow.handlers" />

      <!-- outer hosts -->
      <circle v-for="host in svgOuterHosts" :key="host.key" v-bind="host.props" v-on="host.handlers" />

      <!-- outer hosts text -->
      <text v-for="text in svgOuterHostsText" :key="text.key" v-bind="text.props" v-on="text.handlers">{{ text.text }}</text>

      <!-- inner hosts -->
      <circle v-for="host in svgInnerHosts" :key="host.key" v-bind="host.props" v-on="host.handlers" />

      <!-- inner hosts text -->
      <text v-for="text in svgInnerHostsText" :key="text.key" v-bind="text.props" v-on="text.handlers">{{ text.text }}</text>

      <!-- devices -->
      <circle v-for="device in svgDevices" :key="device.key" v-bind="device.props" v-on="device.handlers"/>

      <!-- devices text -->
      <text v-for="text in svgDevicesText" :key="text.key" v-bind="text.props" v-on="text.handlers">{{ text.text }}</text>


      <!-- mini map -->
      <rect v-if="showMiniMap" class="innerMiniMap" v-bind="innerMiniMapProps" />
      <rect v-if="showMiniMap" class="outerMiniMap" v-bind="outerMiniMapProps"
        @mousedown.stop="mouseDownMiniMap($event)"
        @mousemove.capture="mouseMoveMiniMap($event)"
      />
    </svg>

    <!-- loading -->
    <div class="loadingContainer" v-show="isLoading">
      <b-row class="justify-content-md-center text-secondary">
        <b-col cols="12" md="auto">
          <b-media no-body>
            <template v-slot:aside><icon name="circle-notch" scale="2" spin></icon></template>
            <div class="mx-2">
              <h4 v-t="'Loading Network Data'"></h4>
              <p class="font-weight-light" v-t="'Please wait...'"></p>
            </div>
          </b-media>
        </b-col>
      </b-row>
    </div>

<pre>{{ {svgDevicesText} }}</pre>
<pre>{{ {assocInnerHostsCount, assocOuterHostsCount,
innerHostsRingCircumference,
outerHostsRingCircumference,
totalCount,
innerHosts,
outerHosts,
svgInnerHosts,
svgOuterHosts,
items,
} }}</pre>

  </div>
</template>

<script>
const components = {}

require('typeface-b612-mono') // custom pixel font

const defaults = { // default options
  layout: 'radial',
  palette: 'status',
  legendPosition: 'bottom-right',
  miniMapHeight: undefined,
  miniMapWidth: undefined,
  miniMapPosition: 'bottom-left',
  minZoom: 0,
  maxZoom: 4,
  mouseWheelZoom: true,
  padding: 25
}

const props = {
  dimensions: { // svg dimensions
    type: Object,
    required: true
  },
  options: {
    type: Object
  },
  isLoading: {
    type: Boolean
  },
  items: {
    type: Array
  },
}

import { computed, ref, toRefs } from '@vue/composition-api'
import { useViewBox, useMiniMap } from '@/composables/useSvg'

const setup = (props) => {

  const {
    options,
    dimensions,
    isLoading,
    items
  } = toRefs(props)
  const config = computed(() => ({ ...defaults, ...options.value }))

  const {
    zoom,
    scale,
    centerX,
    centerY,
    lastX,
    lastY,
    viewBox,
    viewBoxString,
    setCenter,
    mouseDownSvg,
    mouseMoveSvg,
    mouseUpSvg,
    mouseWheelSvg
  } = useViewBox(config, dimensions)

  const {
    miniMapLatch,
    showMiniMap,
    innerMiniMapProps,
    outerMiniMapProps,
    mouseDownMiniMap,
    mouseMoveMiniMap
  } = useMiniMap(props, config, viewBox, scale, setCenter)

  const highlight = ref(false)

  const cx = computed(() => dimensions.value.width / 2)
  const cy = computed(() => dimensions.value.height / 2)

  // make font size relative to dimensions
  const fontSize = computed(() => dimensions.value.height / 200)

  const totalCount = computed(() => {
    return items.value.reduce((total, item) => {
      const { count } = item
      return total + count
    }, 0)
  })

  const devicesRingScale = .25 // 25% height
  const devicesRingCircumference = computed(() => (Math.PI * dimensions.value.height * innerHostsRingScale))
  const devicesRingRadius = computed(() => (dimensions.value.height / 2) * devicesRingScale)
  const svgDevicesRingProps = computed(() => ({
    cx: cx.value,
    cy: cy.value,
    r: devicesRingRadius.value,
    fill: 'rgb(255, 255, 255, 1)',
    stroke: 'rgb(0, 0, 0, 0.1)',
    'stroke-width': 1,
  }))
  const assocDevicesCount = computed(() => {
    if (items.value.length === 0) {
      return {}
    }
    return items.value.reduce((assoc, item) => {
      const { count, mac } = item
      assoc[mac] = (assoc[mac] || 0) + count
      return assoc
    }, {})
  })
  const devices = computed(() => {
    const keys = Object.keys(assocDevicesCount.value)
    const maxSize = Math.min(
      devicesRingCircumference.value / 32,
      devicesRingCircumference.value / keys.length
    )
    return keys.reduce((nodes, node, n) => {
      const angle = n * 360 / keys.length + 90
      const x = cx.value + (devicesRingRadius.value * Math.cos(angle * Math.PI / 180))
      const y = cy.value + (devicesRingRadius.value * Math.sin(angle * Math.PI / 180))
      const size = scaleCount(assocDevicesCount.value[node], totalCount.value, 12, maxSize)
      return { ...nodes, [node]: { node, size, angle, x ,y } }
    }, {})
  })
  const deviceFocus = ref(false)
  const deviceOver = (event, key) => {
    deviceFocus.value = key
  }
  const deviceOut = (event, key) => {
    deviceFocus.value = false
  }
  const svgDevices = computed(() => {
    return Object.values(devices.value).map(device => {
      const { node, size, x, y } = device
      return {
        key: node,
        props: {
          class: 'device',
          r: size,
          cx: x,
          cy: y,
          fill: ((!deviceFocus.value || deviceFocus.value === node)
            ? 'rgb(192, 192, 192, 1)'
            : 'rgb(255, 255, 255, 1)'
          ),
          stroke: 'rgb(0, 0, 0, 0.2)',
          'stroke-width': 1,
        },
        handlers: {
          mouseover: event => deviceOver(event, node),
          mouseout: event => deviceOut(event, node),
        }
      }
    })
  })
  const svgDevicesText = computed(() => {
    return Object.values(devices.value)
      .map(device => {
        const { angle, node, size, x, y } = device
        const opacity = ((!deviceFocus.value || deviceFocus.value === node) ? 1 : 0)
        return {
          key: `text-${node}`,
          props: {
            'font-size': `${fontSize.value}px`,
            'stroke-width': `${fontSize.value / 100}`,
            fill: `rgb(0, 0, 0, ${opacity})`,
            transform: `rotate(${angle})`,
            'transform-origin': '0% 50%', // left center
            x, y
          },
          handlers: {
            mouseover: event => deviceOver(event, node),
            mouseout: event => deviceOut(event, node),
          },
          text: node
        }
      })
      .filter(device => device)
  })

  const innerHostsRingScale = .5 // 50% height
  const innerHostsRingCircumference = computed(() => (Math.PI * dimensions.value.height * innerHostsRingScale))
  const innerHostsRingRadius = computed(() => (dimensions.value.height / 2) * innerHostsRingScale)
  const svgInnerHostsRingProps = computed(() => ({
    cx: cx.value,
    cy: cy.value,
    r: innerHostsRingRadius.value,
    fill: 'rgb(255, 255, 255, 1)',
    stroke: 'rgb(0, 0, 0, 0.1)',
    'stroke-width': 1,
  }))
  const assocInnerHostsCount = computed(() => {
    if (items.value.length === 0) {
      return {}
    }
    return items.value.reduce((assoc, item) => {
      const { count, host, internalHost } = item
      if (internalHost) {
        assoc[host] = (assoc[host] || 0) + count
      }
      return assoc
    }, {})
  })
  const innerHosts = computed(() => {
    const keys = Object.keys(assocInnerHostsCount.value)
    const maxSize = Math.min(
      innerHostsRingCircumference.value / 32,
      innerHostsRingCircumference.value / keys.length
    )
    return keys.reduce((nodes, node, n) => {
      const angle = n * 360 / keys.length + 45
      const x = cx.value + (innerHostsRingRadius.value * Math.cos(angle * Math.PI / 180))
      const y = cy.value + (innerHostsRingRadius.value * Math.sin(angle * Math.PI / 180))
      const size = scaleCount(assocInnerHostsCount.value[node], totalCount.value, 12, maxSize)
      return { ...nodes, [node]: { node, size, angle, x ,y } }
    }, {})
  })
  const innerHostFocus = ref(false)
  const innerHostOver = (event, key) => {
    innerHostFocus.value = key
  }
  const innerHostOut = (event, key) => {
    innerHostFocus.value = false
  }
  const svgInnerHosts = computed(() => {
    return Object.values(innerHosts.value).map(host => {
      const { node, size, x, y } = host
      return {
        key: node,
        props: {
          class: 'host host-inner',
          r: size,
          cx: x,
          cy: y,
          fill: (((!innerHostFocus.value || innerHostFocus.value === node) && !outerHostFocus.value)
            ? 'rgb(192, 192, 192, 1)'
            : 'rgb(255, 255, 255, 1)'
          ),
          stroke: 'rgb(0, 0, 0, 0.2)',
          'stroke-width': 1,
        },
        handlers: {
          mouseover: event => innerHostOver(event, node),
          mouseout: event => innerHostOut(event, node),
        }
      }
    })
  })
  const svgInnerHostsText = computed(() => {
    return Object.values(innerHosts.value)
      .map(host => {
        const { angle, node, size, x, y } = host
        const opacity = (((!innerHostFocus.value || innerHostFocus.value === node) && !outerHostFocus.value) ? 1 : 0)
        return {
          key: `text-${node}`,
          props: {
            'font-size': `${fontSize.value}px`,
            'stroke-width': `${fontSize.value / 100}`,
            fill: `rgb(0, 0, 0, ${opacity})`,
            transform: `rotate(${angle})`,
            'transform-origin': '0% 50%', // left center
            x, y
          },
          handlers: {
            mouseover: event => innerHostOver(event, node),
            mouseout: event => innerHostOut(event, node),
          },
          text: node
        }
      })
      .filter(host => host)
  })

  const outerHostsRingScale = .75 // 75% height
  const outerHostsRingCircumference = computed(() => (Math.PI * dimensions.value.height * outerHostsRingScale))
  const outerHostsRingRadius = computed(() => (dimensions.value.height / 2) * outerHostsRingScale)
  const svgOuterHostsRingProps = computed(() => ({
    cx: cx.value,
    cy: cy.value,
    r: outerHostsRingRadius.value,
    //fill: 'rgb(0, 0, 0, 0.05)',
    fill: 'rgb(255, 255, 255, 1)',
    stroke: 'rgb(0, 0, 0, 0.1)',
    'stroke-width': 1,
  }))
  const assocOuterHostsCount = computed(() => {
    if (items.value.length === 0) {
      return {}
    }
    return items.value.reduce((assoc, item) => {
      const { count, host, internalHost } = item
      if (!internalHost) {
        assoc[host] = (assoc[host] || 0) + count
      }
      return assoc
    }, {})
  })
  const outerHosts = computed(() => {
    const keys = Object.keys(assocOuterHostsCount.value)
    const maxSize = Math.min(
      outerHostsRingCircumference.value / 64,
      outerHostsRingCircumference.value / keys.length
    )
    return keys.reduce((nodes, node, n) => {
      const angle = n * 360 / keys.length - 90
      const x = cx.value + (outerHostsRingRadius.value * Math.cos(angle * Math.PI / 180))
      const y = cy.value + (outerHostsRingRadius.value * Math.sin(angle * Math.PI / 180))
      const size = scaleCount(assocOuterHostsCount.value[node], totalCount.value, 12, maxSize)
      return { ...nodes, [node]: { node, size, angle, x ,y } }
    }, {})
  })
  const outerHostFocus = ref(false)
  const outerHostOver = (event, key) => {
    outerHostFocus.value = key
  }
  const outerHostOut = (event, key) => {
    outerHostFocus.value = false
  }
  const svgOuterHosts = computed(() => {
    return Object.values(outerHosts.value).map(host => {
      const { node, size, x, y } = host
      return {
        key: node,
        props: {
          class: 'host host-outer',
          r: size,
          cx: x,
          cy: y,
          fill: (((!outerHostFocus.value || outerHostFocus.value === node) && !innerHostFocus.value)
            ? 'rgb(192, 192, 192, 1)'
            : 'rgb(255, 255, 255, 1)'
          ),
          stroke: 'rgb(0, 0, 0, 0.2)',
          'stroke-width': 1,
        },
        handlers: {
          mouseover: event => outerHostOver(event, node),
          mouseout: event => outerHostOut(event, node),
        }
      }
    })
  })
  const svgOuterHostsText = computed(() => {
    return Object.values(outerHosts.value)
      .map(host => {
        const { angle, node, size, x, y } = host
        const opacity = (((!outerHostFocus.value || outerHostFocus.value === node) && !innerHostFocus.value) ? 1 : 0)
        return {
          key: `text-${node}`,
          props: {
            'font-size': `${fontSize.value}px`,
            'stroke-width': `${fontSize.value / 100}`,
            fill: `rgb(0, 0, 0, ${opacity})`,
            transform: `rotate(${angle})`,
            'transform-origin': '0% 50%', // left center
            x, y
          },
          handlers: {
            mouseover: event => outerHostOver(event, node),
            mouseout: event => outerHostOut(event, node),
          },
          text: node
        }
      })
      .filter(host => host)
  })

  const scaleCount = (count, total, min = 1, max = 100) => {
    const p = count / total // 0 to 1
    const l = Math.log10(p * 9 + 1) // 1 to 10 => 0 to 1
    return l * (max - min) + min
  }

  const strokeProto = (proto, opacity = 1) => {
    switch (proto) {
      case 'TCP':
        return `rgb(0, 0, 255, ${opacity})`
        // break
      case 'UDP':
        return `rgb(255, 0, 0, ${opacity})`
        // break
      default:
        return `rgb(0, 0, 0, ${opacity})`
    }
  }

  const flows = computed(() => {
    const dx1 = cx.value
    const dy1 = cy.value
    const dx2 = cx.value
    const dy2 = cy.value
    return items.value
      .sort((a, b) => b.count - a.count)
      .map(item => {
        const { mac, host, count, proto } = item
        if (mac in devices.value) {
          const { x: sx, y: sy, size: iSize } = devices.value[mac]
          if (host in outerHosts.value) {
            const { x: dx, y: dy, size: oSize } = outerHosts.value[host]
            const d = `M ${sx},${sy} C ${dx1},${dy1} ${dx2},${dy2} ${dx},${dy}`
            const maxSize = Math.min(iSize, oSize)
            const strokeOpacity = ((
              (!deviceFocus.value || deviceFocus.value === mac)
              && (!outerHostFocus.value || outerHostFocus.value === host)
              && !innerHostFocus.value
            )
              ? scaleCount(count, totalCount.value, 0.25, 1)
              : 0
            )
            const strokeWidth = scaleCount(count, totalCount.value, 1, maxSize)
            const stroke = strokeProto(proto, strokeOpacity)
            return {
              props: { class: 'flow', d, fill: 'transparent', stroke, 'stroke-width': strokeWidth }
            }
          }
          if (host in innerHosts.value) {
            const { x: dx, y: dy, size: oSize } = innerHosts.value[host]
            const d = `M ${sx},${sy} C ${dx1},${dy1} ${dx2},${dy2} ${dx},${dy}`
            const maxSize = Math.min(iSize, oSize)
            const strokeOpacity = ((
              (!deviceFocus.value || deviceFocus.value === mac)
              && (!innerHostFocus.value || innerHostFocus.value === host)
              && !outerHostFocus.value
            )
              ? scaleCount(count, totalCount.value, 0.25, 1)
              : 0
            )
            const strokeWidth = scaleCount(count, totalCount.value, 1, maxSize)
            const stroke = strokeProto(proto, strokeOpacity)
            return {
              props: { class: 'flow', d, fill: 'transparent', stroke, 'stroke-width': strokeWidth }
            }
          }
        }
        return null
      })
      .filter(item => item)
  })

  return {
    config,

    // useViewBox
    zoom,
    scale,
    centerX,
    centerY,
    lastX,
    lastY,
    viewBox,
    viewBoxString,
    setCenter,
    mouseDownSvg,
    mouseMoveSvg,
    mouseUpSvg,
    mouseWheelSvg,

    // useMiniMap
    miniMapLatch,
    showMiniMap,
    innerMiniMapProps,
    outerMiniMapProps,
    mouseDownMiniMap,
    mouseMoveMiniMap,

    // ...
    highlight,
    svgDevicesRingProps,
    svgInnerHostsRingProps,
    svgOuterHostsRingProps,

    svgDevices,
svgDevicesText,
    svgInnerHosts,
svgInnerHostsText,
    svgOuterHosts,
svgOuterHostsText,



assocInnerHostsCount,
assocOuterHostsCount,
innerHostsRingCircumference,
outerHostsRingCircumference,
totalCount,
innerHosts,
outerHosts,
flows,
deviceFocus,
  }
}

// @vue/component
export default {
  name: 'base-chart-ringed',
  components,
  props,
  setup
}
</script>

<style lang="scss">
@import './BaseChartRinged.scss';

svg {
  text {
    // https://stackoverflow.com/a/62720107
    transform-box: fill-box;
    transition: fill .3s ease;
  }
  circle.device,
  circle.host {
    transition: fill .3s ease;
  }
  path.flow {
    transition: stroke .3s ease;
  }
}
</style>