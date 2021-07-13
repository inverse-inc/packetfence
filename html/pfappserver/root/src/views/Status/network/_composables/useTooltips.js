import { computed, ref, toRefs } from '@vue/composition-api'

const getAngleFromCoords = (x1, y1, x2, y2) => {
  const dx = x2 - x1
  const dy = y2 - y1
  let theta = Math.atan2(dy, dx)
  theta *= 180 / Math.PI // radians to degrees
  return (360 + theta) % 360
}

export default (props, config, bounds, viewBox, nodes) => {

  const {
    dimensions
  } = toRefs(props)

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

  return {
    coordBounded,
    localTooltips,
    tooltips,
    tooltipAnchorAttrs
  }
}