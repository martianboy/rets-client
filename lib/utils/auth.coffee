### jshint node:true ###
### jshint -W097 ###
'use strict'

retsParsing = require('./retsParsing')
retsHttp = require('./retsHttp')
headersHelper = require('./headers')
errors = require('./errors')


###
# Executes RETS login routine.
###

login = (retsSession, client) ->
  retsHttp.callRetsMethod({retsMethod: 'login', queryOptions: {}}, retsSession, client)
  .then (retsContext) -> new Promise (resolve, reject) ->
    if client.settings.userAgentPassword && retsContext.headerInfo.setCookie
      typeIsArray = Array.isArray || ( value ) -> return {}.toString.call( value ) is '[object Array]'
      if typeIsArray retsContext.headerInfo.setCookie
        headerCookies = retsContext.headerInfo.setCookie
      else
        headerCookies = [retsContext.headerInfo.setCookie];
      for headerCookie in headerCookies
        matches = headerCookie.match(/RETS\-Session\-ID=([^;]+);/)
        if matches
          client.settings.sessionId = matches[1]
          break
          
    retsParser = retsParsing.getSimpleParser(retsContext, reject)

    systemData = {}
    gotData = false
    retsParser.parser.on 'text', (text) ->
      if retsParser.currElementName != 'RETS-RESPONSE'
        return
      gotData = true
      keyVals = text.split('\r\n')
      for keyVal in keyVals
        split = keyVal.split('=')
        if split.length > 1
          systemData[split[0].trim()] = split[1].trim()

    retsParser.parser.on 'endElement', (name) ->
      if name != 'RETS'
        return
      retsParser.finish()
      if !gotData
        reject(new errors.RetsProcessingError(retsContext, 'Failed to parse data'))
      else
        resolve({systemData, headerInfo: retsContext.headerInfo})

    retsParser.parser.write(retsContext.body)
    retsParser.parser.end()


###
# Logouts RETS user
###

logout = (retsSession, client) ->
  retsHttp.callRetsMethod({retsMethod: 'logout', queryOptions: {}}, retsSession, client)
  .then (retsContext) ->
    return {headerInfo: retsContext.headerInfo}

module.exports =
  login: login
  logout: logout
