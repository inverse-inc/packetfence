import { toRefs } from '@vue/composition-api'

export default (props, config) => {
  const {
    palettes
  } = toRefs(props)

  const color = node => {
    if (Object.keys(palettes.value).includes(config.value.palette) && config.value.palette in node.properties) {
      const value = node.properties[config.value.palette]
      if (Object.keys(palettes.value[config.value.palette]).includes(value)) {
        return palettes.value[config.value.palette][value]
      }
    }
    return 'black'
  }

  return {
    color
  }
}