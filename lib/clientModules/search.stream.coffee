### jshint node:true ###
### jshint -W097 ###
'use strict'

through2 = require('through2')
promiseTry = require('es6-promise-try');

queryOptionHelpers = require('../utils/queryOptions')
retsHttp = require('../utils/retsHttp')
retsParsing = require('../utils/retsParsing')
errors = require('../utils/errors')


###
# Invokes RETS search operation and streams the resulting XML.
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
# @param headerInfoCallback optional callback to receive response header info
#
###

searchRets = (_options, responseHandler) -> promiseTry () =>
  queryOptions = queryOptionHelpers.normalizeOptions(_options)
  retsHttp.streamRetsMethod({retsMethod: 'search', queryOptions, responseHandler, parser: through2()}, @retsSession, @client)
  .then (retsContext) ->
    return {
      headerInfo: retsContext.headerInfo
      rawStream: retsContext.parser
    }


###
#
# Helper that performs a targeted RETS query and streams parsed (or semi-parsed) results
#
# @param searchType Rets resource type (ex: Property)
# @param classType Rets class type (ex: RESI)
# @param query Rets query string. See RETS specification - (ex: MatrixModifiedDT=2014-01-01T00:00:00.000+)
# @param options Search query options (optional).
#    See RETS specification for query options.
# @param rawData flag indicating whether to skip parsing of column and data elements.
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

query = (resourceType, classType, queryString, _options={}, rawData=false, parserEncoding='UTF-8') ->
  baseOpts =
    searchType: resourceType
    class: classType
    query: queryString
  mainOptions = queryOptionHelpers.mergeOptions(baseOpts, _options)

  # make sure queryType and format will use the searchRets defaults
  delete mainOptions.queryType
  if mainOptions.format != 'COMPACT-DECODED' && mainOptions.format != 'COMPACT'
    delete mainOptions.format
  queryOptions = queryOptionHelpers.normalizeOptions(mainOptions)

  retsContext = retsParsing.getSaxStreamParser({retsMethod: 'search', queryOptions}, null, rawData, parserEncoding)
  retsHttp.streamRetsMethod(retsContext, @retsSession, @client)

  return {
    headerInfo: retsContext.headerInfo
    retsStream: retsContext.retsStream
  }


module.exports = (_retsSession, _client) ->
  if !_retsSession
    throw new errors.RetsParamError('System data not set; invoke login().')
  retsSession: _retsSession
  client: _client
  query: query
  searchRets: searchRets
