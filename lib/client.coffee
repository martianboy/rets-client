### jshint node:true ###
### jshint -W097 ###
'use strict'

crypto = require('crypto')
request = require('request-promise-native')
promiseTry = require('es6-promise-try');

metadata = require('./clientModules/metadata')
search = require('./clientModules/search')
object = require('./clientModules/object')

auth = require('./utils/auth')
normalizeUrl = require('./utils/normalizeUrl')
errors = require('./utils/errors')

URL_KEYS =
  GET_METADATA: "GetMetadata"
  GET_OBJECT: "GetObject"
  SEARCH: "Search"
  UPDATE: "Update"
  ACTION: "Action"
  LOGIN: "Login"
  LOGOUT: "Logout"


class Client
  constructor: (_settings) ->
    @settings = {}
    for key, val of _settings
      @settings[key] = val
    
    @headers =
      'User-Agent': @settings.userAgent || 'RETS node-client/4.x',
      'RETS-Version': @settings.version || 'RETS/1.7.2'

    # add RETS-UA-Authorization header
    if @settings.userAgentPassword
      a1 = crypto.createHash('md5').update([@settings.userAgent, @settings.userAgentPassword].join(":")).digest('hex')
      retsUaAuth = crypto.createHash('md5').update([a1, "", @settings.sessionId || "", @settings.version || @headers['RETS-Version']].join(":")).digest('hex')
      @headers['RETS-UA-Authorization'] = "Digest " + retsUaAuth

    debugRequest = require('debug')('rets-client:request')
    if debugRequest.enabled
      require('request-debug')(request, (type, data) -> debugRequest("#{type}:", data))
    if 'requestDebugFunction' of @settings
      require('request-debug')(request, @settings.requestDebugFunction)
    
    defaults =
      jar: request.jar()
      headers: @headers
      
    if @settings.method
      defaults.method = @settings.method
    else
      defaults.method = 'GET'

    if @settings.username && @settings.password
      defaults.auth =
        'user': @settings.username
        'pass': @settings.password
        'sendImmediately': false
    
    if @settings.timeout
      defaults.timeout = @settings.timeout

    if @settings.proxyUrl
      defaults.proxy = @settings.proxyUrl
      if @settings.useTunnel
        defaults.tunnel = @settings.useTunnel
    
    @baseRetsSession = request.defaults defaults
    @loginRequest = @baseRetsSession.defaults(uri: @settings.loginUrl, resolveWithFullResponse: true)


  login: () ->
    auth.login(@loginRequest, @)
    .then (retsContext) =>
      @systemData = retsContext.systemData
      @loginHeaderInfo = retsContext.headerInfo
      @urls = {}
      for key,val of URL_KEYS
        if @systemData[val]
          @urls[val] = normalizeUrl(@systemData[val], @settings.loginUrl)
          
      hasPermissions = true
      missingPermissions = []
      if @urls[URL_KEYS.GET_METADATA]
        @metadata = metadata(@baseRetsSession.defaults(uri: @urls[URL_KEYS.GET_METADATA], resolveWithFullResponse: true), @)
      else
        hasPermissions = false
        missingPermissions.push URL_KEYS.GET_METADATA
      if @urls[URL_KEYS.SEARCH]
        @search = search(@baseRetsSession.defaults(uri: @urls[URL_KEYS.SEARCH], resolveWithFullResponse: true), @)
      else
        hasPermissions = false
        missingPermissions.push URL_KEYS.SEARCH
      if @urls[URL_KEYS.GET_OBJECT]
        @objects = object(@baseRetsSession.defaults(uri: @urls[URL_KEYS.GET_OBJECT], resolveWithFullResponse: true), @)
      @logoutRequest = @baseRetsSession.defaults(uri: @urls[URL_KEYS.LOGOUT], resolveWithFullResponse: true)
      if !hasPermissions
        throw new errors.RetsPermissionError(missingPermissions)
        
      if @settings.userAgentPassword && @settings.sessionId
        a1 = crypto.createHash('md5').update([@settings.userAgent, @settings.userAgentPassword].join(":")).digest('hex')
        retsUaAuth = crypto.createHash('md5').update([a1, "", @settings.sessionId || "", @settings.version || @headers['RETS-Version']].join(":")).digest('hex')
        @headers['RETS-UA-Authorization'] = "Digest " + retsUaAuth
        
      return @

  # Logs the user out of the current session
  logout: () ->
    auth.logout(@logoutRequest, @)
    .then (retsContext) =>
      @logoutHeaderInfo = retsContext.headerInfo


Client.getAutoLogoutClient = (settings, handler) -> promiseTry () ->
  client = new Client(settings)
  client.login()
  .then () ->
    promiseTry () ->
      handler(client)
    .finally () ->
      client.logout()


module.exports = Client
