import { computed, ref, toRefs, watch } from '@vue/composition-api'
import { createDebouncer } from 'promised-debounce'
import useColor from './useColor'

export default (props, config, bounds, viewBox, nodes, links) => {

  const {
    dimensions
  } = toRefs(props)

  const {
    color
  } = useColor(props, config)

  const tooltipsRef = ref(null) // component ref
  const tooltipsRefBounds = ref(false)

  let tooltipDebouncer
  let closeLastObserver = false
  watch(tooltipsRef, () => {
    if (tooltipsRef.value) {
      if (closeLastObserver) {
        closeLastObserver() // disconnect
      }
      const observer = new MutationObserver(() => {
        if (!tooltipDebouncer)
          tooltipDebouncer = createDebouncer()
        tooltipDebouncer({
          handler: () => {
            if (tooltipsRef.value) {
              tooltipsRefBounds.value = tooltipsRef.value.getBoundingClientRect()
            }
          },
          time: 250
        })
      })
      closeLastObserver = () => observer.disconnect()
      observer.observe(tooltipsRef.value, { attributes: true, characterData: true, childList: true, subtree: true })
    }
  })

  const localTooltips = ref([]) // private tooltips

  const tooltips = computed(() => {
    return [...(new Set(localTooltips.value))] // dereferenced
      .filter(tooltip => !('fx' in tooltip || 'fy' in tooltip))
      .map(tooltipBounded => {
        const node = nodes.value.find(node => node.id === tooltipBounded.id)
        const nodeBounded = coordBounded(node)
        return {
          node,
          ...nodeBounded
        }
      })
      .sort((a, b) => (a.y - b.y)) // sort by `y`
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

  let highlight = ref(false) // mouseOver @ node
  let highlightNodeId = ref(false) // last highlighted node

  const highlightedLinks = computed(() => {
    return links.value.filter(link => { link.highlight })
  })

  const tooltipsOther = computed(() => {
    const { width, minX } = viewBox.value
    return localTooltips.value.reduce((other, tooltip) => {
      const { id, x = 0 } = tooltip
      if (id === highlightNodeId.value) {
        return other || (x <= minX + (width / 2))
      }
      return other
    }, false)
  })
  const tooltipsPinned = ref(false)

  const mouseDownNode = node => {
    const { id = false } = node || {}
    tooltipsPinned.value = (tooltipsPinned.value !== id) ? id : false
    if (id) {
      _mouseOverNode(node)
    }
    else {
      mouseOutNode()
    }
  }

  const _mouseOverNode = node => {
    highlightNodeById(node.id) // highlight node
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
    }
  }

  let mouseOverNodeDebouncer
  const mouseOverNode = node => {
    if (tooltipsPinned.value && tooltipsPinned.value !== node.id) {
      return
    }
    if (!mouseOverNodeDebouncer) {
      mouseOverNodeDebouncer = createDebouncer()
    }
    mouseOverNodeDebouncer({
      handler: () => {
        _mouseOverNode(node)
      },
      time: 300
    })
  }

  const mouseOutNode = () => {
    if (!tooltipsPinned.value) {
      _unhighlightNodes()
      _unhighlightLinks()
      highlight.value = false
      highlightNodeId.value = false
      localTooltips.value = []
    }
  }

  const _unhighlightNodes = () => {
    nodes.value = nodes.value.map(node => ({ ...node, highlight: false, tooltip: false }))
  }

  const _unhighlightLinks = () => {
    links.value = links.value.map(link => ({ ...link, highlight: false }))
  }

  const highlightNodeById = id => {
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

  const tooltipsLines = computed(() => {
    const { maxX = 0, maxY = 0 } = bounds.value
    const { minX: viewBoxX, minY: viewBoxY, width, height } = viewBox.value
    return tooltips.value
      .map((tooltip, t) => {
        if (tooltipsRef.value && t in tooltipsRef.value.childNodes) {
          const tooltipBounds = tooltipsRef.value.childNodes[t].getBoundingClientRect()
          let x = (tooltipBounds.x - tooltipsRefBounds.value.x) + tooltipBounds.width
          let y = (tooltipBounds.y - tooltipsRefBounds.value.y) + (tooltipBounds.height / 2)
          if (tooltipsOther.value) {
            x = dimensions.value.width - x
          }
          const x1 = viewBoxX + (x / maxX * width)
          const y1 = viewBoxY + (y / maxY * height)
          if (!isNaN(x1) && !isNaN(y1)) {
            return {
              x1,
              y1,
              x2: tooltip.x,
              y2: tooltip.y,
            }
          }
        }
        return false
      })
      .filter(tooltip => Object.keys(tooltip).length > 0)
  })

  return {
    tooltipsRef,
    coordBounded,
    localTooltips,
    tooltips,
    tooltipsLines,
    tooltipsOther,
    tooltipsPinned,
    highlight,
    highlightNodeById,
    highlightNodeId,
    highlightedLinks,
    mouseDownNode,
    mouseOverNode,
    mouseOutNode,
  }
}