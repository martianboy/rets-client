### jshint node:true ###
### jshint -W097 ###
'use strict'

through2 = require('through2')
promiseTry = require('es6-promise-try');

queryOptionHelpers = require('../utils/queryOptions')
errors = require('../utils/errors')
hex2a = require('../utils/hex2a')
replyCodes = require('../utils/replyCodes')
retsParsing = require('../utils/retsParsing')
retsHttp = require('../utils/retsHttp')
errors = require('../utils/errors')


###
# Invokes RETS search operation.
#
# @param _queryOptions Search query options.
#    See RETS specification for query options.
#
#    Default values for query params:
#
#       queryType:'DMQL2',
#       format:'COMPACT-DECODED',
#       count:1,
#       standardNames:0,
#       restrictedIndicator:'***',
#       limit:"NONE"
###

searchRets = (_queryOptions) -> promiseTry () =>
  queryOptions = queryOptionHelpers.normalizeOptions(_queryOptions)
  retsHttp.callRetsMethod({retsMethod: 'search', queryOptions}, @retsSession, @client)
  .then (retsContext) ->
    return {
      text: retsContext.body
      headerInfo: retsContext.headerInfo
    }


###
#
# Helper that performs a targeted RETS query and parses results.
#
# @param searchType Rets resource type (ex: Property)
# @param classType Rets class type (ex: RESI)
# @param query Rets query string. See RETS specification - (ex: MatrixModifiedDT=2014-01-01T00:00:00.000+)
# @param options Search query options (optional).
#    See RETS specification for query options.
#
#    Default values for query params:
#
#       queryType:'DMQL2',
#       format:'COMPACT-DECODED',
#       count:1,
#       standardNames:0,
#       restrictedIndicator:'***',
#       limit:"NONE"
#
#       Please note that queryType and format are immutable.
###

query = (resourceType, classType, queryString, options={}, parserEncoding='UTF-8') -> new Promise (resolve, reject) =>
  result =
    results: []
    maxRowsExceeded: false
  currEntry = null

  retsContext = @stream.query(resourceType, classType, queryString, options, null, parserEncoding)
  retsContext.retsStream.pipe through2.obj (event, encoding, callback) ->
    switch event.type
      when 'data'
        result.results.push(event.payload)
      when 'status'
        for own key, value of event.payload
          result[key] = value
      when 'count'
        result.count = event.payload
      when 'done'
        for own key, value of event.payload
          result[key] = value
        result.headerInfo = retsContext.headerInfo
        resolve(result)
      when 'error'
        reject(event.payload)
    callback()


module.exports = (_retsSession, _client) ->
  if !_retsSession
    throw new errors.RetsParamError('System data not set; invoke login().')
  retsSession: _retsSession
  client: _client
  searchRets: searchRets
  query: query
  stream: require('./search.stream')(_retsSession, _client)
