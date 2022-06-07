<template>
  <div ref="svgContainer" class="svgContainer" key="svgContainer">

    <!-- SVG drag layer (for event capture only) -->
    <svg ref="svgDrag" class="svgDrag" key="svgDrag"
      xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink"
      width="100%"
      :height="dimensions.height+'px'"
      :viewBox="viewBoxString"
      v-show="lastX && lastY"
      @mousemove="mouseMoveSvg($event)"
      @mouseout="mouseUpSvg($event)"
      @mouseup="mouseUpSvg($event)"
    />

    <!-- SVG draw layer -->
    <svg ref="svgDraw" :class="[ 'svgDraw', `zoom-${zoom}` ]" key="svgDraw"
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
        <linearGradient id="node-blur">
          <stop offset="0%" stop-color="rgb(255, 255, 255)"/>
          <stop offset="100%" stop-color="rgb(192, 192, 192)"/>
        </linearGradient>
        <linearGradient id="node-focus">
          <stop offset="0%" stop-color="rgb(192, 192, 192)"/>
          <stop offset="100%" stop-color="rgb(127, 127, 127)"/>
        </linearGradient>
      </defs>
      <defs>

        <!-- outer hosts text label paths -->
        <path v-for="host in svgOuterHostsText" :key="host.path.key" v-bind="host.path.props" />

        <!-- inner hosts text label paths -->
        <path v-for="host in svgInnerHostsText" :key="host.path.key" v-bind="host.path.props" />

        <!-- devices text label paths -->
        <path v-for="host in svgDevicesText" :key="host.path.key" v-bind="host.path.props" />

      </defs>

      <!-- background to capture node mouseout event -->
<!--
      <rect fill-opacity="0" :x="viewBox.minX" :y="viewBox.minY" :width="viewBox.width" :height="viewBox.height"
        @mouseover="mouseOutNode($event)"
      />
-->
      <!-- outer hosts ring -->
      <circle v-bind="svgOuterHostsRingProps" key="outerHostsRing" />

      <!-- inner hosts ring -->
      <circle v-bind="svgInnerHostsRingProps" key="innerHostsRing" />

      <!-- devices ring -->
      <circle v-bind="svgDevicesRingProps" key="devicesRing" />

      <!-- flows -->
      <path v-for="flow in svgFlows" :key="flow.key" v-bind="flow.props" v-on="flow.handlers" />

      <!-- outer hosts -->
      <circle v-for="host in svgOuterHosts" :key="host.key" v-bind="host.props" v-on="host.handlers" />

      <!-- inner hosts -->
      <circle v-for="host in svgInnerHosts" :key="host.key" v-bind="host.props" v-on="host.handlers" />

      <!-- devices -->
      <circle v-for="device in svgDevices" :key="device.key" v-bind="device.props" v-on="device.handlers"/>

      <!-- text labels -->
      <text>

        <!-- outer hosts -->
        <textPath v-for="host in svgOuterHostsText" :key="host.textPath.key" v-bind="host.textPath.props" v-on="host.textPath.handlers">
          <tspan v-for="tspan in host.textPath.tspan" :key="tspan.key" v-bind="tspan.props" v-html="tspan.text" />
        </textPath>

        <!-- inner hosts -->
        <textPath v-for="host in svgInnerHostsText" :key="host.textPath.key" v-bind="host.textPath.props" v-on="host.textPath.handlers">
          <tspan v-for="tspan in host.textPath.tspan" :key="tspan.key" v-bind="tspan.props" v-html="tspan.text" />
        </textPath>

        <!-- devices -->
        <textPath v-for="device in svgDevicesText" :key="device.textPath.key" v-bind="device.textPath.props" v-on="device.textPath.handlers">
          <tspan v-for="tspan in device.textPath.tspan" :key="tspan.key" v-bind="tspan.props" v-on="tspan.handlers" v-html="tspan.text" />
        </textPath>

      </text>

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
  padding: 25,
}

const props = {
  animate: {
    type: Boolean
  },
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

import { computed, onBeforeUnmount, ref, toRefs, watch } from '@vue/composition-api'
import { useViewBox, useMiniMap } from '@/composables/useSvg'
import { rgbaProto } from '../_composables/useCommunication'

const setup = (props, context) => {

  const {
    animate,
    options,
    dimensions,
    items
  } = toRefs(props)

  const { emit } = context

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

  const cx = computed(() => dimensions.value.width / 2)
  const cy = computed(() => dimensions.value.height / 2)

  // make font size relative to dimensions
  const fontSize = computed(() => dimensions.value.height / 150)

  const totalCount = computed(() => {
    return items.value.reduce((total, item) => {
      const { count } = item
      return total + count
    }, 0)
  })

  const alignTspan = tspans => {
    const center = 0.25
    const deltaY = 1
    if (tspans.length > 0) {
      tspans[0].props.dy = `${center - ((tspans.length - 1) * deltaY / 2)}em`
    }
    return tspans
  }

  const deviceRotation = ref(0)
  const innerHostRotation = ref(0)
  const outerHostRotation = ref(0)

  let rotationInterval
  // scale interval w/ # of items
  const rotationIntervalTimeout = computed(() => 5 * Math.pow(Math.log2(items.value.length), 2.1))
  watch([items, animate], () => {
    if (rotationInterval) {
      clearInterval(rotationInterval)
    }
    const perInterval = (360 / 600) * rotationIntervalTimeout.value / 1E3
    if (animate.value) {
      rotationInterval = setInterval(() => {
        if (!deviceRingFocus.value) {
          deviceRotation.value += perInterval * 2 // 0.2
        }
        if (!innerHostRingFocus.value) {
          innerHostRotation.value -= perInterval // 0.1
        }
        if (!outerHostRingFocus.value) {
          outerHostRotation.value -= perInterval / 2 // 0.05
        }
      }, rotationIntervalTimeout.value)
    }
  }, { immediate: true })
  onBeforeUnmount(() => {
    clearInterval(rotationInterval)
  })

  const hasRingFocus = computed(() => deviceRingFocus.value || innerHostRingFocus.value || outerHostRingFocus.value)

  const devicesRingScale = .25 // 25% height
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
    const minSize = fontSize.value / 2
    const maxSize = fontSize.value * 5
    return keys.reduce((nodes, node, n) => {
      const angle = (n * 360 / keys.length + deviceRotation.value) % 360
      const xTheta = Math.cos(angle * Math.PI / 180)
      const yTheta = Math.sin(angle * Math.PI / 180)
      const x = cx.value + (devicesRingRadius.value * xTheta)
      const y = cy.value + (devicesRingRadius.value * yTheta)
      const size = scaleCount(assocDevicesCount.value[node], totalCount.value, minSize, maxSize)
      const isFocus = deviceRingFocus.value && deviceFocus.value.indexOf(node) > -1
      const isVisible = !hasRingFocus.value || deviceFocus.value.indexOf(node) > -1
      return { ...nodes, [node]: { node, size, angle, x, y, xTheta, yTheta, isFocus, isVisible } }
    }, {})
  })
  const deviceFocus = ref([])
  const deviceRingFocus = ref(false)
  let deviceMouseDebouncer
  // eslint-disable-next-line no-unused-vars
  const deviceOver = (event, key) => {
    if (deviceMouseDebouncer) {
      clearTimeout(deviceMouseDebouncer)
    }
    deviceMouseDebouncer = setTimeout(() => {
      deviceFocus.value = [key]
      deviceRingFocus.value = true
      innerHostFocus.value = items.value
        .filter(item => item.mac === key && item.internalHost)
        .map(item => item.host)
      outerHostFocus.value = items.value
        .filter(item => item.mac === key && !item.internalHost)
        .map(item => item.host)
    }, 50)
  }
  // eslint-disable-next-line no-unused-vars
  const deviceOut = (event, key) => {
    if (deviceMouseDebouncer) {
      clearTimeout(deviceMouseDebouncer)
    }
    deviceMouseDebouncer = setTimeout(() => {
      deviceFocus.value = []
      deviceRingFocus.value = false
      innerHostFocus.value = []
      outerHostFocus.value = []
    }, 50)
  }
  const deviceDown = (event, key) => {
    if (event.which === 1) { // left-mouse click
      if (deviceMouseDebouncer) {
        clearTimeout(deviceMouseDebouncer)
      }
      deviceFocus.value = []
      deviceRingFocus.value = false
      innerHostFocus.value = []
      outerHostFocus.value = []
      emit('device', key)
    }
  }
  const svgDevices = computed(() => {
    return Object.values(devices.value)
      .sort((a,b) => b.size - a.size)
      .map(device => {
        const { node, size, x, y, isFocus, isVisible } = device
        const fill = (isVisible)
          ? `url(#node-${(isFocus) ? 'focus' : 'blur' })`
          : 'rgb(0, 0, 0, 0)'
        const stroke = `rgb(0, 0, 0, ${(isVisible) ? .2 : 0})`
        return {
          key: `device-${node}`,
          props: {
            class: 'device',
            r: size,
            cx: x,
            cy: y,
            fill,
            stroke,
            'stroke-width': 1,
          },
          handlers: {
            mouseover: event => deviceOver(event, node),
            mouseout: event => deviceOut(event, node),
            mousedown: event => deviceDown(event, node)
          }
        }
      })
  })
  const svgDevicesText = computed(() => {
    return Object.values(devices.value)
      .map(device => {
        const { angle, node, size, xTheta, yTheta, isFocus, isVisible } = device
        const opacity = (isVisible) ? 1 : 0
        const id = `href-${node}`
        const x1 = cx.value + ((devicesRingRadius.value + size + fontSize.value) * xTheta)
        const y1 = cy.value + ((devicesRingRadius.value + size + fontSize.value) * yTheta)
        const x2 = cx.value + (10 * devicesRingRadius.value * xTheta)
        const y2 = cy.value + (10 * devicesRingRadius.value * yTheta)
        return {
          path: {
            key: `devicePath-${node}`,
            props: {
              id,
              d: `M ${x1},${y1} ${x2},${y2} ${x2},${y2} ${x1},${y1}`
            }
          },
          textPath: {
            key: `deviceTextPath-${node}`,
            props: {
              'xlink:href': `#${id}`,
              fill: `rgb(0, 0, 0, ${opacity})`,
              'font-size': `${fontSize.value}px`,
              'stroke-width': `${fontSize.value / 50}`,
              stroke: `rgb(0, 0, 0, ${opacity})`,
              ...((angle > 90 && angle < 270)
                ? { 'text-anchor': 'end', startOffset: '100%' } // flip text
                : {}
              )
            },
            handlers: {
              mouseover: event => deviceOver(event, node),
              mouseout: event => deviceOut(event, node),
              mousedown: event => deviceDown(event, node)
            },
            tspan: alignTspan([
              {
                key: `deviceTextPath-${node}`,
                props: {
                  x: '0em',
                  dy: '0.25em'
                },
                text: node
              },
              ...((isFocus)
                ? Object.entries(
                    deviceFocus.value.reduce((assoc, mac) => {
                      items.value
                        .filter(item => item.mac === mac)
                        .forEach(item => {
                          const { proto, port, count } = item
                          if (!(proto in assoc)) {
                            assoc[proto] = {}
                          }
                          assoc[proto][port] = (assoc[proto][port] || 0) + count
                        })
                      return assoc
                    }, {})
                  )
                  .reduce((lines, [proto, ports]) => {
                    Object.entries(ports).forEach(([port, count]) => {
                      const text = `${proto}:${port}<tspan fill="rgba(0, 0, 0, 0.5)">(${count})</tspan>`
                      lines.push({
                        key: `deviceTextPath-${node}-${proto}-${port}`,
                        props: {
                          x: '0em',
                          dy: '1.2em',
                          fill: rgbaProto(proto, port)
                        },
                        text
                      })
                    })
                    return lines
                  }, [])
                : []
              )
            ])
          }
        }
      })
      .filter(device => device)
  })

  const innerHostsRingScale = .5 // 50% height
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
    const minSize = fontSize.value / 2
    const maxSize = fontSize.value * 5
    return keys.reduce((nodes, node, n) => {
      const angle = (n * 360 / keys.length + innerHostRotation.value) % 360
      const xTheta = Math.cos(angle * Math.PI / 180)
      const yTheta = Math.sin(angle * Math.PI / 180)
      const x = cx.value + (innerHostsRingRadius.value * xTheta)
      const y = cy.value + (innerHostsRingRadius.value * yTheta)
      const size = scaleCount(assocInnerHostsCount.value[node], totalCount.value, minSize, maxSize)
      const isFocus = innerHostRingFocus.value && innerHostFocus.value.indexOf(node) > -1
      const isVisible = !hasRingFocus.value || ((deviceRingFocus.value || innerHostRingFocus.value) && innerHostFocus.value.indexOf(node) > -1)
      return { ...nodes, [node]: { node, size, angle, x, y, xTheta, yTheta, isFocus, isVisible } }
    }, {})
  })
  const innerHostFocus = ref([])
  const innerHostRingFocus = ref(false)
  let innerHostMouseDebouncer
  // eslint-disable-next-line no-unused-vars
  const innerHostOver = (event, key) => {
    if (innerHostMouseDebouncer) {
      clearTimeout(innerHostMouseDebouncer)
    }
    innerHostMouseDebouncer = setTimeout(() => {
      innerHostFocus.value = [key]
      innerHostRingFocus.value = true
      deviceFocus.value = items.value
        .filter(item => item.host === key)
        .map(item => item.mac)
    }, 50)
  }
  // eslint-disable-next-line no-unused-vars
  const innerHostOut = (event, key) => {
    if (innerHostMouseDebouncer) {
      clearTimeout(innerHostMouseDebouncer)
    }
    innerHostMouseDebouncer = setTimeout(() => {
      innerHostFocus.value = []
      innerHostRingFocus.value = false
      deviceFocus.value = []
    }, 50)
  }
  const innerHostDown = (event, key) => {
    if (event.which === 1) { // left-mouse click
      if (innerHostMouseDebouncer) {
        clearTimeout(innerHostMouseDebouncer)
      }
      innerHostFocus.value = []
      innerHostRingFocus.value = false
      deviceFocus.value = []
      emit('host', key)
    }
  }
  const svgInnerHosts = computed(() => {
    return Object.values(innerHosts.value)
      .sort((a,b) => b.size - a.size)
      .map(host => {
        const { node, size, x, y, isFocus, isVisible } = host
        const fill = (isVisible)
          ? `url(#node-${(isFocus) ? 'focus' : 'blur' })`
          : 'rgb(0, 0, 0, 0)'
        const stroke = `rgb(0, 0, 0, ${(isVisible) ? .2 : 0})`
        return {
          key: `innerHost-${node}`,
          props: {
            class: 'host host-inner',
            r: size,
            cx: x,
            cy: y,
            fill,
            stroke,
            'stroke-width': 1,
          },
          handlers: {
            mouseover: event => innerHostOver(event, node),
            mouseout: event => innerHostOut(event, node),
            mousedown: event => innerHostDown(event, node)
          }
        }
      })
  })
  const svgInnerHostsText = computed(() => {
    return Object.values(innerHosts.value)
      .map(host => {
        const { angle, node, size, xTheta, yTheta, isFocus, isVisible } = host
        const opacity = (isVisible) ? 1 : 0
        const id = `href-${node}`
        const x1 = cx.value + ((innerHostsRingRadius.value + size + fontSize.value) * xTheta)
        const y1 = cy.value + ((innerHostsRingRadius.value + size + fontSize.value) * yTheta)
        const x2 = cx.value + (10 * innerHostsRingRadius.value * xTheta)
        const y2 = cy.value + (10 * innerHostsRingRadius.value * yTheta)
        return {
          path: {
            key: `innerHostPath-${node}`,
            props: {
              id,
              d: `M ${x1},${y1} ${x2},${y2} ${x2},${y2} ${x1},${y1}`
            }
          },
          textPath: {
            key: `innerHostTextPath-${node}`,
            props: {
              'xlink:href': `#${id}`,
              fill: `rgb(0, 0, 0, ${opacity})`,
              'font-size': `${fontSize.value}px`,
              'stroke-width': `${fontSize.value / 50}`,
              stroke: `rgb(0, 0, 0, ${opacity})`,
              ...((angle > 90 && angle < 270)
                ? { 'text-anchor': 'end', startOffset: '100%' } // flip text
                : {}
              )
            },
            handlers: {
              mouseover: event => innerHostOver(event, node),
              mouseout: event => innerHostOut(event, node),
              mousedown: event => innerHostDown(event, node)
            },
            tspan: alignTspan([
              {
                key: `innerHostTextPath-${node}`,
                props: {
                  x: '0em',
                  dy: '0.25em'
                },
                text: node
              },
              ...((isFocus)
                ? Object.entries(
                    innerHostFocus.value.reduce((assoc, host) => {
                      items.value
                        .filter(item => item.host === host)
                        .forEach(item => {
                          const { proto, port, count } = item
                          if (!(proto in assoc)) {
                            assoc[proto] = {}
                          }
                          assoc[proto][port] = (assoc[proto][port] || 0) + count
                        })
                      return assoc
                    }, {})
                  )
                  .reduce((lines, [proto, ports]) => {
                    Object.entries(ports).forEach(([port, count]) => {
                      const text = `${proto}:${port}<tspan fill="rgba(0, 0, 0, 0.5)">(${count})</tspan>`
                      lines.push({
                        key: `innerHostTextPath-${node}-${proto}-${port}`,
                        props: {
                          x: '0em',
                          dy: '1.2em',
                          fill: rgbaProto(proto, port)
                        },
                        text
                      })
                    })
                    return lines
                  }, [])
                : []
              )
            ])
          }
        }
      })
      .filter(host => host)


  })

  const outerHostsRingScale = .75 // 75% height
  const outerHostsRingRadius = computed(() => (dimensions.value.height / 2) * outerHostsRingScale)
  const svgOuterHostsRingProps = computed(() => ({
    cx: cx.value,
    cy: cy.value,
    r: outerHostsRingRadius.value,
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
    const minSize = fontSize.value / 2
    const maxSize = fontSize.value * 5
    return keys.reduce((nodes, node, n) => {
      const angle = (n * 360 / keys.length + outerHostRotation.value) % 360
      const xTheta = Math.cos(angle * Math.PI / 180)
      const yTheta = Math.sin(angle * Math.PI / 180)
      const x = cx.value + (outerHostsRingRadius.value * xTheta)
      const y = cy.value + (outerHostsRingRadius.value * yTheta)
      const size = scaleCount(assocOuterHostsCount.value[node], totalCount.value, minSize, maxSize)
      const isFocus = outerHostRingFocus.value && outerHostFocus.value.indexOf(node) > -1
      const isVisible = !hasRingFocus.value || ((deviceRingFocus.value || outerHostRingFocus.value) && outerHostFocus.value.indexOf(node) > -1)
      return { ...nodes, [node]: { node, size, angle, x, y, xTheta, yTheta, isFocus, isVisible } }
    }, {})
  })
  const outerHostFocus = ref([])
  const outerHostRingFocus = ref(false)
  let outerHostMouseDebouncer
  // eslint-disable-next-line no-unused-vars
  const outerHostOver = (event, key) => {
    if (outerHostMouseDebouncer) {
      clearTimeout(outerHostMouseDebouncer)
    }
    outerHostMouseDebouncer = setTimeout(() => {
      outerHostFocus.value = [key]
      outerHostRingFocus.value = true
      deviceFocus.value = items.value
        .filter(item => item.host === key)
        .map(item => item.mac)
    }, 50)
  }
  // eslint-disable-next-line no-unused-vars
  const outerHostOut = (event, key) => {
    if (outerHostMouseDebouncer) {
      clearTimeout(outerHostMouseDebouncer)
    }
    outerHostMouseDebouncer = setTimeout(() => {
      outerHostFocus.value = []
      outerHostRingFocus.value = false
      deviceFocus.value = []
    }, 50)
  }
  const outerHostDown = (event, key) => {
    if (event.which === 1) { // left-mouse click
      if (outerHostMouseDebouncer) {
        clearTimeout(outerHostMouseDebouncer)
      }
      outerHostFocus.value = []
      outerHostRingFocus.value = false
      deviceFocus.value = []
      emit('host', key)
    }
  }
  const svgOuterHosts = computed(() => {
    return Object.values(outerHosts.value)
      .sort((a,b) => b.size - a.size)
      .map(host => {
        const { node, size, x, y, isFocus, isVisible } = host
        const fill = (isVisible)
          ? `url(#node-${(isFocus) ? 'focus' : 'blur' })`
          : 'rgb(0, 0, 0, 0)'
        const stroke = `rgb(0, 0, 0, ${(isVisible) ? .2 : 0})`
        return {
          key: `outerHost-${node}`,
          props: {
            class: 'host host-outer',
            r: size,
            cx: x,
            cy: y,
            fill,
            stroke,
            'stroke-width': 1,
          },
          handlers: {
            mouseover: event => outerHostOver(event, node),
            mouseout: event => outerHostOut(event, node),
            mousedown: event => outerHostDown(event, node)
          }
        }
      })
  })
  const svgOuterHostsText = computed(() => {
    return Object.values(outerHosts.value)
      .map(host => {
        const { angle, node, size, xTheta, yTheta, isFocus, isVisible } = host
        const opacity = (isVisible) ? 1 : 0
        const id = `href-${node}`
        const x1 = cx.value + ((outerHostsRingRadius.value + size + fontSize.value) * xTheta)
        const y1 = cy.value + ((outerHostsRingRadius.value + size + fontSize.value) * yTheta)
        const x2 = cx.value + (10 * outerHostsRingRadius.value * xTheta)
        const y2 = cy.value + (10 * outerHostsRingRadius.value * yTheta)
        return {
          path: {
            key: `outerHostPath-${node}`,
            props: {
              id,
              d: `M ${x1},${y1} ${x2},${y2} ${x2},${y2} ${x1},${y1}`
            }
          },
          textPath: {
            key: `outerHostTextPath-${node}`,
            props: {
              'xlink:href': `#${id}`,
              fill: `rgb(0, 0, 0, ${opacity})`,
              'font-size': `${fontSize.value}px`,
              stroke: `rgb(0, 0, 0, ${opacity})`,
              'stroke-width': `${fontSize.value / 50}`,
              ...((angle > 90 && angle < 270)
                ? { 'text-anchor': 'end', startOffset: '100%' } // flip text
                : {}
              )
            },
            handlers: {
              mouseover: event => outerHostOver(event, node),
              mouseout: event => outerHostOut(event, node),
              mousedown: event => outerHostDown(event, node)
            },
            tspan: alignTspan([
              {
                key: `outerHostTextPath-${node}`,
                props: {
                  x: '0em',
                  dy: '0.25em'
                },
                text: node
              },
              ...((isFocus)
                ? Object.entries(
                    outerHostFocus.value.reduce((assoc, host) => {
                      items.value
                        .filter(item => item.host === host)
                        .forEach(item => {
                          const { proto, port, count } = item
                          if (!(proto in assoc)) {
                            assoc[proto] = {}
                          }
                          assoc[proto][port] = (assoc[proto][port] || 0) + count
                        })
                      return assoc
                    }, {})
                  )
                  .reduce((lines, [proto, ports]) => {
                    Object.entries(ports).forEach(([port, count]) => {
                      const text = `${proto}:${port}<tspan fill="rgba(0, 0, 0, 0.5)">(${count})</tspan>`
                      lines.push({
                        key: `outerHostTextPath-${node}-${proto}-${port}`,
                        props: {
                          x: '0em',
                          dy: '1.2em',
                          fill: rgbaProto(proto, port)
                        },
                        text
                      })
                    })
                    return lines
                  }, [])
                : []
              )
            ])
          }
        }
      })
      .filter(host => host)
  })

  const scaleCount = (count, total, min = 1, max = 100) => {
    const p = count / total // 0 to 1
    const l = Math.log10(p * 9 + 1) // 1 to 10 => 0 to 1
    return l * (max - min) + min
  }

  const svgFlows = computed(() => {
    const dx1 = cx.value
    const dy1 = cy.value
    const dx2 = cx.value
    const dy2 = cy.value
    return items.value
      .sort((a, b) => b.count - a.count)
      .map(item => {
        const { mac, host, count, proto, port } = item
        const key = `flow-${mac}-${proto}-${port}-${host}`
        const isVisible = (
          !(deviceRingFocus.value || innerHostRingFocus.value || outerHostRingFocus.value)
          || (deviceRingFocus.value && deviceFocus.value.indexOf(mac) > -1)
          || (innerHostRingFocus.value && innerHostFocus.value.indexOf(host) > -1)
          || (outerHostRingFocus.value && outerHostFocus.value.indexOf(host) > -1)
        )
        const strokeOpacity = (isVisible)
          ? scaleCount(count, totalCount.value, 0.25, 1)
          : 0
        const { x: sx, y: sy, size: iSize } = devices.value[mac]
        if (host in outerHosts.value) {
          const { x: dx, y: dy, size: oSize } = outerHosts.value[host]
          const d = `M ${sx},${sy} C ${dx1},${dy1} ${dx2},${dy2} ${dx},${dy}`
          const minSize = Math.min(iSize, oSize) / 5
          const maxSize = Math.max(iSize, oSize) * 2
          const strokeWidth = scaleCount(count, totalCount.value, minSize, maxSize)
          const stroke = rgbaProto(proto, port, strokeOpacity)
          return {
            key, props: { class: 'flow', d, fill: 'transparent', stroke, 'stroke-width': strokeWidth }
          }
        }
        if (host in innerHosts.value) {
          const { x: dx, y: dy, size: oSize } = innerHosts.value[host]
          const d = `M ${sx},${sy} C ${dx1},${dy1} ${dx2},${dy2} ${dx},${dy}`
          const minSize = Math.min(iSize, oSize) / 5
          const maxSize = Math.max(iSize, oSize) * 2
          const strokeWidth = scaleCount(count, totalCount.value, minSize, maxSize)
          const stroke = rgbaProto(proto, port, strokeOpacity)
          return {
            key, props: { class: 'flow', d, fill: 'transparent', stroke, 'stroke-width': strokeWidth }
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

    // SVG
    svgDevicesRingProps,
    svgDevices,
    svgDevicesText,
    svgInnerHostsRingProps,
    svgInnerHosts,
    svgInnerHostsText,
    svgOuterHostsRingProps,
    svgOuterHosts,
    svgOuterHostsText,
    svgFlows,

    deviceRotation,
    innerHostRotation,
    outerHostRotation
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
html {
  &.is-scroll-locked {
    overflow: hidden !important;
  }
}
</style>
<style lang="scss" scoped>
@import './BaseChartRinged.scss';

svg {
  transition: height .3s linear, width .3s linear;

  text {
    // https://stackoverflow.com/a/62720107
    transform-box: fill-box;
    transition: fill .3s linear;
  }
  circle.device,
  circle.host {
    transition: fill .3s linear, stroke .3s linear;
    cursor: pointer;
  }
  path.flow {
    transition: stroke .3s linear;
  }
}
</style>