const Radius = require('radius')
const Dgram = require('dgram')
const db = require('node-persist')

const codes = {
  request: 'Access-Request',
  reject: 'Access-Reject',
  accept: 'Access-Accept'
}

const mock = {}

mock.radius = function (host, port, secret, user_name, user_password) {

  this.host = host
  this.port = port
  this.secret = secret
  this.user_name = user_name
  this.user_password = user_password

  this.socket = Dgram.createSocket('udp4')

  this.socket.on('error', err => {
    console.error(err)
    this.socket.close()
  })

  this.socket.on('listening', () => {
    const address = this.socket.address()
    console.log('RADIUS listening on ' + address.address + ':' + address.port)

    Promise.resolve(db.init()).then(() => {
      db.setItem('history', [])
    })
  })

  this.socket.on('message', (message, client) => {
    let code

    const request = Radius.decode({
        packet: message,
        secret: this.secret
    })

    if (this.user_name) {
      const user_name = request.attributes['User-Name']
      const user_password = request.attributes['User-Password']
      if (user_name == this.user_name && user_password == this.user_password) {
        code = codes.accept
      }
      else {
        code = codes.reject
      }
    }
    else {
      code = codes.accept
    }

    const response = Radius.encode_response({
        packet: request,
        code: code,
        secret: this.secret
    })

    Promise.resolve(db.init()).then(() => {
      db.getItem('history').then(history => {
        const { code, identifer, length, attributes } = request
        history.push({ code, identifer, length, attributes })
        db.setItem('history', history)
      })
    })

    console.log('Sending ' + code + ' for User-Name ' + user_name)

    this.socket.send(response, 0, response.length, client.port, client.address, err => {
      if (err) {
        console.error('Error sending reponse to ', client)
      }
    })
  })

  return this
}

mock.radius.prototype.bind = function () {
  try {
    return this.socket.bind(this.port, this.host)
  }
  catch {}
}

mock.radius.prototype.close = function () {
  return this.socket.close()
}

module.exports = mock.radius