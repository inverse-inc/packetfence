const filters = {
  pfDate (value) {
    if (!value) {
      return ''
    } else if (value === '0000-00-00 00:00:00') {
      return 'Never'
    } else {
      return value
    }
  }
}

export default filters
