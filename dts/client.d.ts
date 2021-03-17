import { IClientMetadata } from './metadata' 
import { IClientSearch } from './search'
import { IClientObjects, IObjectData } from './object'
import { RetsReplyError } from './errors'

export type RETS_METHOD = 'GET' | 'POST'
export interface IClientConfiguration {
  loginUrl: string
  username: string
  password: string
  version: string
  userAgent: string
  method?: RETS_METHOD
  proxyUrl?: string
  requestDebugFunction?: RequestDebugFunction
}

type RetsClientEvent =
  'dataStream' | // for a stream containing an object's raw data
  'location' | // when no stream is available but a URL is available in the headerInfo (as per the Location: 1 option)
  'headerInfo' | // with the headers for the outer multipart response
  'error' // for an error corresponding to a single object rather than the stream as a whole

/**
 * https://github.com/request/request-debug
 */
export interface RequestDebugFunction {
  (type: 'request' | 'response' | 'redirect' | 'auth',
    data: any): void
}

export interface IClientSettingsWithUAAuthorization extends IClientConfiguration {
  userAgent: string
  userAgentPassword: string
  sessionId?: string
}

export type ClientSettings = IClientConfiguration & IClientSettingsWithUAAuthorization

export class Client {
  settings: ClientSettings
  constructor(settings: ClientSettings)
  metadata: IClientMetadata
  systemData: any
  search: IClientSearch
  /**
   * https://github.com/sbruno81/rets-client/blob/master/lib/clientModules/object.coffee
   */
  objects: IClientObjects
  login(): Promise<any>
  logout(): Promise<any>
}
/**
 * https://github.com/sbruno81/rets-client/blob/master/lib/utils/queryOptions.coffee
 * default query parameters:
 *   _queryOptionsDefaults =
 *   queryType: 'DMQL2'
 *   format: 'COMPACT-DECODED'
 *   count: number
 *   standardNames: 0
 *   restrictedIndicator: '***'
 *   limit: 'NONE'
 */
export interface IQueryOptions {
  searchType?: string
  class?: string
  query?: string
  limit: number | string
  /**
   * Some RETS servers appear to require a 1 based offest
   * NaN is passed unless supplied
   * Offsets are 1-based, thus an offset of 1 means to start with the first record.
   * http://www.dis.com/NAR/api/user/classlibrets_1_1_search_request.html#ddc8fb0423f46082749a4ac16315ce7f
   */
  offset: number
  restrictedIndicator?: string
  /**
   * CUSTOM - limit the number of calls/pages in the RETS query
   */
  select?: string
  method?: RETS_METHOD
}
export interface IBaseResponse {
  headerInfo: IHeaderInfo
  replyCode: number
  replyTag: ReplyTag
  replyText: string
}
export interface IGetResourcesResponse extends IBaseResponse {
  results: {
    info?: any
    metadata?: IRecordMetadata[]
  }[]
  type?: 'METADATA-RESOURCE'
}
export interface IGetClassResponse extends IBaseResponse {
  results: {
    info?: any
    metadata?: IClassMetadata[]
  }[]
  type?: 'METADATA-RESOURCE',
  entriesReceived?: number
}
export interface IGetTableResponse extends IBaseResponse {
  results: ITableResult[]
  type: 'METADATA-RESOURCE'
  entriesReceived: number
}
export interface ITableResult {
  info?: any
  metadata?: ITableMetadata[]
}
export type ReplyTag = 'OPERATION_SUCCESSFUL'
export interface IHeaderInfo {
  cacheControl: string
  contentLength: number
  contentType: string
  server: string
  retsVersion: string
  retsRequestId: string
  xAspNetVersion: string
  xPoweredBy: string
  serverId: string
  connection: string
  mimeVersion: string
  contentId: string
  transferEncoding: string
  vary: string
  date: string
}
export interface IQueryResponse extends IGetResourcesResponse {
  /** true when there are more results to obtain */
  maxRowsExceeded: boolean
  /** number of records returned */
  rowsReceived: number
  /** count of total records */
  count: number
}

export interface IRetsStream extends NodeJS.ReadableStream {
  on (event: 'data', callback: (event: IRetsStreamEvent<any> | IRetsStreamDoneEvent | IRetsStreamErrorEvent | IRetsStreamDataEvent | IRetsStreamHeaderInfoEvent) => void): this
  on (event: 'error', callback: (error: any) => void): this
  on (event: 'end', callback: () => void): this
}
export interface IRetsStreamEvent<TPayload> {
  type: 'headerInfo' | 'error' | 'data' | 'done'
  payload: TPayload
}
export interface IRetsStreamDoneEvent extends IRetsStreamEvent<{
  rowsReceived: number
}> {
  type: 'done'
}
export interface IRetsStreamErrorEvent extends IRetsStreamEvent<RetsReplyError> {
  type: 'error'
}

export interface IRetsStreamDataEvent extends IRetsStreamEvent<IRecord> {
  type: 'data'
}
export interface IRetsStreamHeaderInfoEvent extends IRetsStreamEvent<IHeaderInfo> {
  type: 'headerInfo'
}

export interface IObjectHeaderInfo {
  contentId: string
  objectId: string
  contentType: string
  /**
   * Present with Location=1 GetObject requests
   */
  location?: string
  contentDescription?: string
  /**
   * CAML-case dictionary of extra headerInfo metadata
   */
  objectData?: IDictionaryLike<string>
}

export interface IRecord extends IDictionaryLike<any> {
  metadata?: IRecordMetadata[]
  info?: {}
}
export interface IClass {
  ResourceID?: string
  metadata?: IClassMetadata[]
  info?: {}
}
export interface ITable {
  metadata?: ITableMetadata[]
  info?: {}
}
export interface IRecordMetadata {
  ResourceID?: string
  StandardName?: string
  VisibleName?: string
  ClassDate?: string
  ObjectVersion?: string
  ObjectDate?: string
  SearchHelpVersion?: string
  SearchHelpDate?: string
  EditMaskVersion?: string
  EditMaskDate?: string
  LookupVersion?: string
  LookupDate?: string
  UpdateHelpVersion?: string
  UpdateHelpDate?: string
  ValidationExpressionVersion?: string
  ValidationExpressionDate?: string
  ValidationLookupVersion?: string
  ValidationLookupDate?: string
  ValidationExternalVersion?: string
  ValidationExternalDate?: string
}
export interface IClassMetadata {
  _ResourceID?: string
  ClassName?: string
  StandardName?: string
  VisibleName?: string
  TableVersion?: string
}
export interface ITableMetadata {
  MetadataEntryID?: string
  SystemName?: string
  ShortName?: string
  LongName?: string
  DataType?: string
}
export interface IErrorInfo {
  error?: Error
  stack?: any
}

export interface RetsContext {
  headerInfo: IHeaderInfo
  retsMethod: 'search'
  queryOptions: IRetsQueryOptions
}
export interface IRetsQueryOptions {
  QueryType: string
  Format: 'COMPACT-DECODED'
  Count: number
  StandardNames: number
  RestrictedIndicator: string
  Limit: number
  Offset: number
  SearchType: string
  Class: string
  Query: string

}


export interface IGetAutoLogoutClient {
  (clientSettings: ClientSettings, callback: (client: Client) => Promise<any>): Promise<void>
}

export interface IFieldDetail {
  SystemName: string
  StandardName: string
  LongName: string
  DBName: string
  ShortName: string
  MaximumLength: string
  DataType: 'Character' | 'Int' | 'Boolean' | 'DateTime'
  Precision: string
  Searchable: boolean
  Interpretation: string
  Alignment: string
  UseSeparator: string
  EditMaskID: string
  LookupName: string
  MaxSelect: string
  Units: string
  Index: string
  Minimum: string
  Maximum: string
  Default: string
  Required: boolean
  SearchHelpID: string
  Unique: boolean
  MetadataEntryID: string
  ModTimeStamp: string
  ForeignKeyName: string
  ForeignField: string
  InKeyIndex: number
}

interface IDictionaryLike<T> {
  [index: string]: T
}