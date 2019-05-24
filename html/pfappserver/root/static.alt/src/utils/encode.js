const encode = {
  pid (pid) {
    return encodeURI(pid.replace('/', '~'))
  },
  switch_id (id) {
    return id.replace('/', '~')
  }
}

export default encode
