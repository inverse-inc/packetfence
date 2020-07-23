export const mergeProps = (...props) => {

  console.log('mergeProps', JSON.stringify(props, null, 2))

  return props.reduce((a, p) => {
    return { ...a, ...p }
  }, {})
}
