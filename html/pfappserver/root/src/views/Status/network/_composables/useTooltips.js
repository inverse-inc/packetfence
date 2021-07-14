import { computed, ref, toRefs } from '@vue/composition-api'
import d3 from '@/utils/d3'
import useColor from './useColor'
import { useViewBox } from './useSvg'

const getAngleFromCoords = (x1, y1, x2, y2) => {
  const dx = x2 - x1
  const dy = y2 - y1
  let theta = Math.atan2(dy, dx)
  theta *= 180 / Math.PI // radians to degrees
  return (360 + theta) % 360
}

export default (props, config, bounds, viewBox, nodes, links) => {

  const {
    dimensions
  } = toRefs(props)

  const {
    centerX,
    centerY
  } = useViewBox(config, dimensions)

  const {
    color
  } = useColor(props, config)

  const localTooltips = ref([]) // private d3 tooltips

  const tooltips = computed(() => {
    return localTooltips.value
      .filter(tooltip => !('fx' in tooltip || 'fy' in tooltip))
      .map(tooltipBounded => {
        const node = nodes.value.find(node => node.id === tooltipBounded.id)
        const nodeBounded = coordBounded(node)
        const angle = getAngleFromCoords(nodeBounded.x, nodeBounded.y, tooltipBounded.x, tooltipBounded.y)
        return {
          node,
          line: {
            angle,
            x1: nodeBounded.x,
            y1: nodeBounded.y,
            x2: tooltipBounded.x,
            y2: tooltipBounded.y
          }
        }
      })
  })

  const coordBounded = coord => {
    const { x = 0, y = 0 } = coord
    const { minX = 0, maxX = 0, minY = 0, maxY = 0 } = bounds.value
    const { height = 0, width = 0 } = dimensions.value
    if ((minX | maxX | minY | maxY) !== 0) { // not all zero's
      const xMult = (width - (2 * config.value.padding)) / (maxX - minX)
      const yMult = (height - (2 * config.value.padding)) / (maxY - minY)
      return {
        x: config.value.padding + (x - minX) * xMult,
        y: config.value.padding + (y - minY) * yMult
      }
    }
    return { x: 0, y: 0 }
  }

  const tooltipAnchorAttrs = tooltip => {
    let { line: { x2: x, y2: y } = {} } = tooltip
    let style = [] // set styles
    const { height: dHeight, width: dWidth } = dimensions.value
    const { minX, minY, width: vWidth, height: vHeight } = viewBox.value
    // scale coords to absolute offset from outer container (x: 0, y: 0)
    let absoluteX = (x - minX) / vWidth * dWidth
    let absoluteY = (y - minY) / vHeight * dHeight
    style.push(`top: ${absoluteY}px`, `left: ${absoluteX}px`)
    style = `${style.join('; ')};` // collapse
    return { style }
  }

  let highlight = ref(false) // mouseOver @ node
  let highlightNodeId = ref(false) // last highlighted node

  const highlightedLinks = computed(() => {
    return links.value.filter(link => { link.highlight })
  })

  const mouseOverNode = node => {
    const { width, height } = dimensions.value
    _highlightNodeById(node.id) // highlight node
    highlight.value = (node.type === 'node') ? color(node) : 'none'
    // tooltips
    if (highlightNodeId.value !== node.id) {
      highlightNodeId.value = node.id
      const highlightedNodes = nodes.value.filter(node => node.tooltip)
      localTooltips.value = [
        ...highlightedNodes.map(node => {
          const { id, type, properties } = node
          const { x, y } = coordBounded(node)
          return JSON.parse(JSON.stringify({ id, type, properties, x, y }))
        }),
        ...highlightedNodes.map(node => {
          const { id } = node
          const { x: fx, y: fy } = coordBounded(node)
          return JSON.parse(JSON.stringify({ id: `${id}-fixed`, fx, fy }))
        })
      ]
      // link force from tooltip to node (self)
      let selfLinks = []
      highlightedNodes.map(node => {
        const { id } = node
        selfLinks.push({ source: id, target: `${id}-fixed` })
      })
      // link force from tooltip to other nodes
      let nodeLinks = []
      highlightedNodes.map(node => {
        const { id } = node
        highlightedNodes.map(other => {
          const { id: otherId } = other
          if (otherId !== id) {
            if (nodeLinks.filter(link =>
              ([link.source, link.target].includes(id) && [link.source, link.target].includes(`${otherId}-fixed`))
            ).length === 0) {
              nodeLinks.push({ source: id, target: `${otherId}-fixed` })
            }
          }
        })
      })
      // link force from tooltip to other tooltips
      let tooltipLinks = []
      highlightedNodes.map(node => {
        const { id } = node
        highlightedNodes.map(other => {
          const { id: otherId } = other
          if (otherId !== id) {
            if (tooltipLinks.filter(link =>
              ([link.source, link.target].includes(id) && [link.source, link.target].includes(otherId))
            ).length === 0) {
              tooltipLinks.push({ source: otherId, target: id })
            }
          }
        })
      })
      d3.forceSimulation(localTooltips.value)
        .alphaDecay(1 - Math.pow(0.001, 1 / 50)) // default: 1 - Math.pow(0.001, 1 / 300)
        .velocityDecay(0.8) // default: 0.4
        .force('x', d3.forceX() // force: tooltip w/ center x
          .x(centerX.value)
          .strength(0.5)
        )
        .force('y', d3.forceY() // force: tooltip w/ center y
          .y(centerY.value)
          .strength(0.5)
        )
        .force('selfLinks', d3.forceLink(selfLinks) // force: tooltip w/ node
          .id((d) => d.id)
          .distance(Math.min(width, height) / 8)
          .strength(0.5)
          .iterations(4)
        )
        .force('nodeLinks', d3.forceLink(nodeLinks) // force: tooltip w/ other nodes
          .id((d) => d.id)
          .distance(Math.min(width, height) / 2)
          .strength(0.5)
          .iterations(2)
        )
        .force('tooltipLinks', d3.forceLink(tooltipLinks) // force: tooltip w/ other tooltips
          .id((d) => d.id)
          .distance(Math.min(width, height) / 2)
          .strength(0.5)
          .iterations(8)
        )
        .restart()
    }
  }

  const mouseOutNode = () => {
    _unhighlightNodes()
    _unhighlightLinks()
    highlight.value = false
    highlightNodeId.value = false
    localTooltips.value = []
  }

  const _unhighlightNodes = () => {
    nodes.value = nodes.value.map(node => ({ ...node, highlight: false, tooltip: false }))
  }

  const _unhighlightLinks = () => {
    links.value = links.value.map(link => ({ ...link, highlight: false }))
  }

  const _highlightNodeById = id => {
    _unhighlightNodes()
    _unhighlightLinks()
    // highlight all target nodes linked to this source node
    links.value.forEach((link, index)=> {
      if (link.source.id === id) {
        links.value[index].highlight = true // highlight link
        links.value[index].target.highlight = true // highlight target node
      }
    })
    let sourceIndex = nodes.value.findIndex(node => node.id === id)
    while (sourceIndex > -1) { // travel to center of tree [ (target|source) -> (target|source) -> ... ]
      nodes.value[sourceIndex].highlight = true  // highlight node
      nodes.value[sourceIndex].tooltip = true // show node tooltip
      const { id: sourceId } = nodes.value[sourceIndex]
      links.value.forEach((link, index) => {
        const { target: { id: targetId } = {} } = link
        if (targetId === sourceId) {
          links.value[index].highlight = true
        }
      })
      if ('source' in nodes.value[sourceIndex])
        sourceIndex = nodes.value.findIndex(node => node.id === nodes.value[sourceIndex].source.id)
      else
        break
    }
  }

  return {
    coordBounded,
    localTooltips,
    tooltips,
    tooltipAnchorAttrs,
    highlight,
    highlightNodeId,
    highlightedLinks,
    mouseOverNode,
    mouseOutNode
  }
}