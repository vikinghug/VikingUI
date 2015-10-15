fs           = require('fs')
xml2js       = require('xml2js')
EventEmitter = require('events').EventEmitter
parser       = new xml2js.Parser()

class VersionManager extends EventEmitter
  constructor: -> return
  getVersion: (data) ->
    xml = new Buffer(data, 'base64').toString('ascii')
    version = undefined
    parser.parseString xml, (err, result) =>
      version = result.Addon.$.Version or "nil"
    return version


module.exports = new VersionManager()