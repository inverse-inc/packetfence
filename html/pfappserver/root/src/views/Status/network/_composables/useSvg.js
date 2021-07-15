import { computed, nextTick, ref, toRefs, watch } from '@vue/composition-api'

export const useViewBox = (config, dimensions) => {

  const zoom = ref(0)
  const scale = computed(() => Math.pow(2, zoom.value))

  const centerX = ref(0) // viewBox center x
  const centerY = ref(0) // viewBox center y
  const lastX = ref(null) // last mouseDown x
  const lastY = ref(null) // last mouseDown y

  const viewBox = computed(() => {
    const { height, width } = dimensions.value
    if (!centerX.value && width) // initialize center (x)
      centerX.value = width / 2
    if (!centerY.value && height) // initialize center (y)
      centerY.value = height / 2
    const widthScaled = width / scale.value
    const heightScaled = height / scale.value
    return {
      minX: centerX.value - (widthScaled / 2),
      minY: centerY.value - (heightScaled / 2),
      width: widthScaled,
      height: heightScaled
    }
  })

  const viewBoxString = computed(() => {
    const { minX = 0, minY = 0, width = 0, height = 0 } = viewBox.value
    return `${minX} ${minY} ${width} ${height}`
  })

  const setCenter = (x, y) => {
    const { height, width } = dimensions.value
    // restrict min/max x bounds
    const minX = width / scale.value / 2
    const maxX = width - minX
    centerX.value = Math.min(Math.max(x, minX), maxX)
    // restrict min/max y bounds
    const minY = height / scale.value / 2
    const maxY = height - minY
    centerY.value = Math.min(Math.max(y, minY), maxY)
  }

  const mouseDownSvg = event => {
    const { minX, minY } = viewBox.value
    // get mouse delta and offset from top/left corner of current viewBox
    const { offsetX, offsetY } = event
    // calculate mouse offset from 0,0
    lastX.value = (offsetX / scale.value) + minX
    lastY.value = (offsetY / scale.value) + minY
  }

  const mouseMoveSvg = event => {
    if (lastX.value && lastY.value) {
      const { minX, minY } = viewBox.value
      // get mouse delta and offset from top/left corner of current viewBox
      const { offsetX, offsetY } = event
      nextTick(() => { // smoothen animation
        const x = centerX.value + (lastX.value - ((offsetX / scale.value) + minX))
        const y = centerY.value + (lastY.value - ((offsetY / scale.value) + minY))
        setCenter(x, y)
      })
    }
  }

  const mouseUpSvg = () => {
    lastX.value = null
    lastY.value = null
  }

  const mouseWheelSvg = event => {
    if (config.value.mouseWheelZoom) {
      event.preventDefault() // don't scroll
      const { minX, minY } = viewBox.value
      const _scale = scale.value
      // get mouse delta and offset from top/left corner of current viewBox
      const { deltaY = 0, offsetX, offsetY } = event
      // calculate mouse offset from 0,0
      const [ svgX, svgY ] = [ (offsetX / scale.value) + minX, (offsetY / scale.value) + minY ]
      // calculate mouse offset from center of current viewBox
      const [deltaCenterX, deltaCenterY] = [svgX - centerX, svgY - centerY]
      // handle zoom-in (-deltaY) and zoom-out (+deltaY)
      //  automatically match center of mouse pointer, so the
      //  x,y coord remains pinned at the mouse pointer after zoom.
      if (deltaY < 0) { // zoom in
        zoom.value = Math.min(++zoom.value, config.value.maxZoom)
      } else if (deltaY > 0) { // zoom out
        zoom.value = Math.max(--zoom.value, config.value.minZoom)
      }
      const factor = scale.value / _scale
      // calculate new center x,y at the current mouse position
      const x = svgX - (deltaCenterX / factor)
      const y = svgY - (deltaCenterY / factor)
      setCenter(x, y)
    }
  }

  // watch `dimensions` prop and limit centerX, centerY within viewBox (fixes out-of-bounds after resize)
  watch(dimensions, () => {
    const { width = 0, height = 0 } = dimensions.value
    const minCenterX = width / (scale.value * 2)
    const maxCenterX = width - (width / (scale.value * 2))
    const minCenterY = height / (scale.value * 2)
    const maxCenterY = height - (height / (scale.value * 2))
    centerX.value = Math.max(Math.min(centerX.value, maxCenterX), minCenterX)
    centerY.value = Math.max(Math.min(centerY.value, maxCenterY), minCenterY)
  }, { deep: true })

  return {
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
  }
}

export const useMiniMap = (props, config, viewBox, scale, setCenter) => {

  const {
    dimensions
  } = toRefs(props)

  const miniMapLatch = ref(false) // mouseDown @ miniMap

  const showMiniMap = computed(() => {
    return (~~config.value.miniMapHeight > 0 || ~~config.value.miniMapWidth > 0) && ~~config.value.maxZoom > ~~config.value.minZoom && scale.value > 1
  })

  const innerMiniMapProps = computed(() => {
    const { minX = 0, minY = 0, width: viewBoxWidth = 0, height: viewBoxHeight = 0 } = viewBox.value
    const { x = 0, y = 0, width: outerMiniMapWidth, height: outerMiniMapHeight } = outerMiniMapProps.value
    return {
      x: x + ((minX * outerMiniMapWidth) / (viewBoxWidth * scale.value)),
      y: y + ((minY * outerMiniMapHeight) / (viewBoxHeight * scale.value)),
      width: outerMiniMapWidth / scale.value,
      height: outerMiniMapHeight / scale.value,
      'stroke-width': `${1 / scale.value}px`
    }
  })

  const outerMiniMapProps = computed(() => {
    const { minX = 0, minY = 0, width: viewBoxWidth = 0, height: viewBoxHeight = 0 } = viewBox.value
    const aspectRatio = viewBoxWidth / viewBoxHeight
    let miniMapHeight = 0
    let miniMapWidth = 0
    switch (true) {
      case ~~config.value.miniMapHeight > 0 && ~~config.value.miniMapWidth > 0:
        miniMapHeight = config.value.miniMapHeight / scale.value
        miniMapWidth = config.value.miniMapWidth / scale.value
        break
      case ~~config.value.miniMapHeight > 0:
        miniMapHeight = config.value.miniMapHeight / scale.value
        miniMapWidth = (config.value.miniMapHeight * aspectRatio) / scale.value
        break
      case ~~config.value.miniMapWidth > 0:
        miniMapWidth = config.value.miniMapWidth / scale.value
        miniMapHeight = config.value.miniMapWidth / (scale.value * aspectRatio)
        break
    }
    let miniMapX = 0
    let miniMapY = 0
    switch (config.value.miniMapPosition) {
      case 'top-right':
        miniMapX = minX + viewBoxWidth - miniMapWidth
        miniMapY = minY
        break
      case 'bottom-right':
        miniMapX = minX + viewBoxWidth - miniMapWidth
        miniMapY = minY + viewBoxHeight - miniMapHeight
        break
      case 'bottom-left':
        miniMapX = minX
        miniMapY = minY + viewBoxHeight - miniMapHeight
        break
      case 'top-left':
      default:
        miniMapX = minX
        miniMapY = minY
    }
    return {
      x: miniMapX,
      y: miniMapY,
      width: miniMapWidth,
      height: miniMapHeight,
      'stroke-width': `${1 / scale.value}px`,
      'stroke-dasharray': 2 / scale.value
    }
  })

  const mouseDownMiniMap = event => {
    const { height: svgHeight, width: svgWidth } = dimensions.value
    const { width: outerMiniMapWidth, height: outerMiniMapHeight } = outerMiniMapProps.value
    const { width: viewBoxWidth, height: viewBoxHeight } = viewBox.value
    const { offsetX, offsetY } = event
    let mouseX = 0
    let mouseY = 0
    switch (config.value.miniMapPosition) {
      case 'top-right':
        mouseX = (outerMiniMapWidth * scale) - (svgWidth - offsetX)
        mouseY = offsetY
        break
      case 'bottom-right':
        mouseX = (outerMiniMapWidth * scale) - (svgWidth - offsetX)
        mouseY = (outerMiniMapHeight * scale) - (svgHeight - offsetY)
        break
      case 'bottom-left':
        mouseX = offsetX
        mouseY = (outerMiniMapHeight * scale) - (svgHeight - offsetY)
        break
      case 'top-left':
      default:
        mouseX = offsetX
        mouseY = offsetY
    }
    const x = viewBoxWidth * (mouseX / outerMiniMapWidth)
    const y = viewBoxHeight * (mouseY / outerMiniMapHeight)
    setCenter(x, y)
    miniMapLatch.value = true // latch miniMapLatch
  }

  const mouseMoveMiniMap = event => {
    if (!(event.which))
      miniMapLatch.value = false
    if (miniMapLatch.value)
      mouseDownMiniMap(event)
  }

  return {
    miniMapLatch,
    showMiniMap,
    innerMiniMapProps,
    outerMiniMapProps,
    mouseDownMiniMap,
    mouseMoveMiniMap
  }
}
