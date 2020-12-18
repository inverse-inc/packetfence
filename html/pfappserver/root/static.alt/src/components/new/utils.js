const mergeProps = (...collections) => {
  return collections.reduce((props, collection) => {
    Object.keys(collection).forEach(key => {
      let prop = collection[key]
      let normalized = ([Function, String].includes(prop.constructor))
        ? { default: prop }
        : prop
      if (key in props)
        props[key] = { ...props[key], ...normalized }
      else
        props[key] = normalized
    })
    return props
  }, {})
}

/**
 * Higher Order Component (HOC).
 *
 * @vue/composition-api plugin does not expose slots/scopedSlots in setup()
 *  - https://github.com/vuejs/composition-api/issues/26#issuecomment-516500321
 *
 * This limits component inheritance and overloading with slots/scopedSlots.
 *
 * Therefore `render` is used to create a HOC (shim) where it:
 *  - uses the `component.render` function, ignoring the original composite `component.setup`
 *  - overloads `component.components`
 *  - overloads `component.props`
 *  - overloads `component.setup`
 *  - provides `scopedSlots` programmatically
 *
 *  USAGE:
 *  // @vue/component
 *  export default {
 *    name: 'base-component',
 *    inheritAttrs: false,
 *    props = {...},
 *    render: renderHOCWithScopedSlots(BaseComponent, { components, props, setup }, {
 *      default: [ FirstSlotComponent, SecondSlotComponent ],
 *      header: HeaderSlotComponent
 *      footer: (h, props) => {
 *        return h(FooterSlotComponent, {}, [
 *          h(FooterSlotChildComponent, { props })
 *        ])
 *      }
 *    })
 *  }
 *
 *  TODO: refactor after migrating to Vue3
**/
const renderHOCWithScopedSlots = (component, params, slots) => {
  const { name, render, inheritAttrs } = component
  const { components, props, setup } = params
  return function (h) { // closure (this)
    const scopedSlots = Object.keys(slots).reduce((obj, slotName) => {
      // Function
      if (slots[slotName].constructor === Function) {
        return { ...obj, [slotName]: props => slots[slotName](h, props) }
      }
      // Array
      const scopedSlotArray = (slots[slotName].constructor === Array)
        ? slots[slotName]
        : [ slots[slotName] ]
      return { ...obj, [slotName]: props => scopedSlotArray.map(scopedSlot => h(scopedSlot, { props })) }
    }, {})
    return h(
      // @vue/component
      {
        name: `hoc-${name}`,
        inheritAttrs,
        render,
        components,
        props,
        setup
      },
      {
        props: this.$props,
        scopedSlots
      }
    )
  }
}

export {
  mergeProps,
  renderHOCWithScopedSlots
}
