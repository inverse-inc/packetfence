const convert = {
  statusToVariant (params) {
    let variant = params.variant || ''
    switch (params.status) {
      case 'success':
        variant = 'success'
        break
      case 'skipped':
        variant = 'warning'
        break
      case 'failed':
        variant = 'danger'
        break
    }
    return variant
  }
}

export default convert
