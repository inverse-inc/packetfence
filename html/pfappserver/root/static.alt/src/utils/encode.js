const encode = {
  pid (pid) {
    return encodeURI(pid.replace('/', '~'))
  },
  switch_id (id) {
    return uri.replace('/', '~')
  }
}

export default encode
