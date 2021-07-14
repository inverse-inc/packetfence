import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'
import d3 from '@/utils/d3'

export default (props, config, nodes, links) => {

  const {
    dimensions
  } = toRefs(props)

  const simulation = ref(null)

  const bounds = computed(() => {
    const { width, height } = dimensions.value
    return {
      minX: 0,
      maxX: width,
      minY: 0,
      maxY: height
    }
  })

  const init = () => {
    simulation.value = d3
      .forceSimulation(nodes.value)
      .on('tick', tick)
    force()
  }

  const start = () => {
    if (simulation.value) {
      nextTick(() => {
        simulation.value.restart()
      })
    }
  }

  const stop = () => {
    if (simulation.value)
      simulation.value.stop()
  }

  const coords = ref([])

  let tickDebouncer = false
  const tick = () => {
    if (!tickDebouncer) {
      tickDebouncer = setTimeout(() => {
        tickDebouncer = false
        const { minX = 0, maxX = 0, minY = 0, maxY = 0 } = bounds.value
        const { height = 0, width = 0 } = dimensions.value
        if ((minX | maxX | minY | maxY) !== 0) { // not all zero's
          const xMult = (width - (2 * config.value.padding)) / (maxX - minX)
          const yMult = (height - (2 * config.value.padding)) / (maxY - minY)
          coords.value = nodes.value.map(node => {
            const x = config.value.padding + (node.x - minX) * xMult
            const y = config.value.padding + (node.y - minY) * yMult
            return {
              x: isNaN(x) ? 0 : x,
              y: isNaN(y) ? 0 : y
            }
          })
        }
        else
          coords.value = nodes.value.map(() => ({ x: 0, y: 0 })) // all zero's
      }, 100)
    }
  }

  const force = () => {
    /* `collide` force - prevents nodes from overlapping */
    simulation.value.force('collide', d3.forceCollide()
      .radius(_forceCollideRadius)
      .strength(0.25)
      .iterations(8)
    )
    simulation.value.force('x', d3.forceX()
      .x(_forceX())
      .strength(0.25)
    )
    simulation.value.force('y', d3.forceY()
      .y(_forceY())
      .strength(0.25)
    )

    switch (config.value.layout) {
      case 'radial':
        simulation.value.velocityDecay(0.4) // default: 0.4
        /* `radial` force - orient on circle of specified radius centered at x, y */
        /*
        simulation.value.force('radial', d3.forceRadial()
          .radius(this.forceRadialRadius)
          .strength(this.forceRadialStrength)
          .x(dimensions.value.width / 2)
          .y(dimensions.value.height / 2)
        )
        */
        break

      case 'tree':
        simulation.value.velocityDecay(0.5) // default: 0.4
        break

      default:
        throw new Error(`Unhandled layout ${config.value.layout}`)
    }
    simulation.value.alpha(1)
  }

  const _getCoordFromCoordAngle = (x1, y1, angle, length) => {
    const rads = angle * (Math.PI / 180) // degrees to radians
    return {
      x: x1 + (length * Math.cos(rads)),
      y: y1 + (length * Math.sin(rads))
    }
  }

  const _getMinMaxPropertyFromSwitch = switche => {
    return links.value.filter(node => node.source.id === switche.id).reduce((limits, link) => {
      let { min = undefined, max = undefined } = limits
      const { target: { type } = {} } = link
      if (type !== 'node') {
        const { min: sMin, max: sMax } = _getMinMaxPropertyFromSwitch(link.target) // recurse
        min = ([undefined, null].includes(min)) ? sMin : ((min.localeCompare(sMin) === 1) ? sMin : min)
        max = ([undefined, null].includes(max)) ? sMax : ((max.localeCompare(sMax) === -1) ? sMax : max)
      }
      else {
        const { target: { properties: { [config.value.sort]: prop } = {} } = {} } = link
        min = ([undefined, null].includes(min)) ? prop : ((min.localeCompare(prop) === 1) ? prop : min)
        max = ([undefined, null].includes(max)) ? prop : ((max.localeCompare(prop) === -1) ? prop : max)
      }
      return { min, max }
    }, { min: undefined, max: undefined })
  }

  const _sortNodes = nodes => {
    const order = (config.value.order === 'ASC') ? 1 : -1 // order multiplier
    // dereference w/ sort
    return Array.prototype.slice.call(nodes)
      .sort((a, b) => {
        const { id: idA, type: typeA, properties: { [config.value.sort]: propA } = {} } = a
        const { id: idB, type: typeB, properties: { [config.value.sort]: propB } = {} } = b
        if (typeA === 'node' && typeB === 'node') {
          switch (true) {
            case propA === propB:
              return idA.localeCompare(idB)
              // break
            case !propA && propB:
              return 1 * order
              // break
            case propA && !propB:
              return -1 * order
              // break
            default:
              return idA.localeCompare(idB)
          }
        }
        else if (typeA === 'node') {
          return 1 * order // switch (non-node) first
        }
        else if (typeB === 'node') {
          return -1 * order // switch (non-node) first
        }
        else {
          const { min: minA = null, max: maxA = null } = _getMinMaxPropertyFromSwitch(a)
          const { min: minB = null, max: maxB = null } = _getMinMaxPropertyFromSwitch(b)
          switch (order) {
            case -1: // ascending
              return (minA === minB) ? idA.localeCompare(idB) : String(minA).localeCompare(minB)
              // break
            case 1: // descending
              return (minA === minB) ? idA.localeCompare(idB) : String(maxA).localeCompare(maxB)
              // break
          }
        }
      })
  }

  const _forceCollideRadius = () => {
    return node => {
      const { type } = node
      switch (type) {
        case 'packetfence':
        case 'switch-group':
        case 'switch':
        case 'unknown':
          return 32 / 2
        case 'node':
          return 16 / 2
      }
    }
  }

  const _forceRadialRadius = () => {
    return node => {
      const { type, depth } = node
      const { depth: totalDepth } = nodes.value.find(n => n.type === 'packetfence')
      switch (type) {
        case 'packetfence':
          return 0
        case 'switch-group':
        case 'switch':
        case 'unknown':
          return Math.min(dimensions.value.height, dimensions.value.width) * ((totalDepth - depth) / totalDepth) / 2
        case 'node':
          return Math.min(dimensions.value.height, dimensions.value.width) / 2
      }
    }
  }

  const _forceRadialStrength = () => {
    return node => {
      const { type } = node
      switch (type) {
        case 'packetfence':
          return 0
        case 'switch-group':
        case 'switch':
        case 'unknown':
          return 1
        case 'node':
          return 0.2
      }
    }
  }

  const _forceXY = () => {
    const { depth: totalDepth, num: totalNum } = nodes.value.find(n => n.type === 'packetfence')
    const sortedNodes = _sortNodes(nodes.value)
    return node => {
      const { id, type, depth, num } = node
      let shift
      switch (config.value.layout) {
        case 'radial': {
          /**
          * 'radial' force - rendered outside-in
          *  - node(s) on outer ring - evenly distributed
          *  - switch(es) on middle ring - using average angle of its target nodes
          *  - switch-group(s) on inner ring - using average angle of its target switches
          *  - packetfence - centered
          **/
          shift = 270 // start upward (12 o-clock)
          let offset
          let angle
          let distance
          switch (type) {
            case 'node': {
              offset = sortedNodes.filter(n => n.id === id).reduce((offset, node) => {
                let { id, source = {}, source: { targets: siblings = null } = {} } = node
                do {
                  if (siblings) {
                    for (let t = 0; t < siblings.length; t++) {
                      if (siblings[t].id === id) break
                      offset += siblings[t].num || 1
                    }
                  }
                } while ('source' in source && ({ id, source, source: { targets: siblings = null } = {} } = source))
                return offset
              }, 0)
              angle = ((360 / totalNum * offset) + shift) % 360
              distance = Math.min(dimensions.value.height, dimensions.value.width) / 2
              return _getCoordFromCoordAngle(dimensions.value.width / 2, dimensions.value.height / 2, angle, distance)
              // break
            }
            case 'switch-group':
            case 'switch':
            case 'unknown': {
              offset = sortedNodes.filter(n => n.id === id).reduce((offset, node) => {
                let { id, source = {}, source: { targets: siblings = null } = {} } = node
                do {
                  if (siblings) {
                    for (let t = 0; t < siblings.length; t++) {
                      if (siblings[t].id === id) break
                      offset += siblings[t].num
                    }
                  }
                } while ('source' in source && ({ id, source, source: { targets: siblings = null } = {} } = source))
                return offset
              }, 0) + ((num - 1) / 2)
              angle = ((360 / totalNum * offset) + shift) % 360
              distance = Math.min(dimensions.value.height, dimensions.value.width) * ((totalDepth - depth) / totalDepth) / 2
              return _getCoordFromCoordAngle(dimensions.value.width / 2, dimensions.value.height / 2, angle, distance)
              // break
            }
            case 'packetfence': {
              const x = dimensions.value.width / 2
              const y = dimensions.value.height / 2
              return { x, y }
              // break
            }
          }
          break
        }
        case 'tree': {
          /**
          * 'tree' force - rendered inside-out
          *  - packetfence - centered
          *  - switch-group(s) on inner ring - evenly distributed around source (packetfence)
          *  - switch(es) on middle ring - evenly distributed around source (switch-group)
          *  - node(s) on outer ring - evenly distributed around source (switch)
          **/
          shift = 270 // start upward (12 o-clock)
          switch (type) {
            case 'packetfence': {
              const x = dimensions.value.width / 2
              const y = dimensions.value.height / 2
              return { x, y }
              // break
            }
            case 'switch-group':
            case 'switch':
            case 'unknown':
            case 'node': {
              const _getDistanceByDepth = (depth = 0) => {
                let distance = Math.min(dimensions.value.width, dimensions.value.height) / 6
                for (let n = 0; n < depth; n++) {
                  distance /= 0.5
                }
                return distance
              }
              const _getNodeCoordAngle = localNode => {
                const sortedNode = sortedNodes.find(n => n.id === localNode.id)
                if (!('source' in sortedNode)) { // packetfence node
                  const angle = shift
                  const x = dimensions.value.width / 2
                  const y = dimensions.value.height / 2
                  return { angle, x, y }
                }
                else { // everything else
                  const { angle: sourceAngle, x: sourceX, y: sourceY } = _getNodeCoordAngle(sortedNode.source)
                  const siblings = sortedNode.source.targets.length
                  let offset = sortedNode.source.targets.findIndex(target => target.id === localNode.id)
                  if (sortedNode.source.id !== 'packetfence' && siblings % 2 === 0) // even # of siblings
                    offset += 0.5
                  const angle = ((360 / siblings * offset) + sourceAngle) % 360
                  const distance = _getDistanceByDepth(sortedNode.depth)
                  const { x, y } = _getCoordFromCoordAngle(sourceX, sourceY, angle, distance)
                  return { angle, x, y }
                }
              }
              return _getNodeCoordAngle(node)
              // break
            }
          }
          break
        }
      }
    }
  }

  const _forceX = () => {
    return node => {
      return _forceXY()(node).x
    }
  }

  const _forceY = () => {
    return node => {
      return _forceXY()(node).y
    }
  }

  watch(() => config.value.layout, (a, b) => {
    if (simulation.value && a !== b) {
      stop()
      init()
      start()
    }
  })

  return {
    simulation,
    bounds,
    coords,
    init,
    start,
    stop,
    force
  }

}