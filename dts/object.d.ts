/// <reference types="node" />

import { IDictionaryLike,  } from './client'

export interface IClientObjects {
    stream: {
      getObjects (
        resourceType: string,
        objectType: string,
        query: string,
        ids?: ObjectIds,
        options?: IGetObjectOptions): Promise<IObjectsStreamGetObjectsResponse>
      getAllObjects (
        resourceType: string,
        objectType: string,
        ids?: ObjectIds,
        options?: IGetObjectOptions): Promise<IObjectsStreamGetObjectsResponse>

    }

    getObjects (resourceType: string, objectType: string, ids?: ObjectIds, options?: IGetObjectOptions): Promise<IGetObjectsResponse>
    getAllObjects (resourceType: string, objectType: string, ids?: ObjectIds, options?: IGetObjectOptions): Promise<IGetAllObjectsResponse>
    getPreferredObjects (resourceType: string, objectType: string, ids?: ObjectIds, options?: IGetObjectOptions): Promise<IGetPreferredObjectsResponse>
}
/**
 * https://github.com/sbruno81/rets-client/blob/master/lib/clientModules/object.coffee#L66
 */
export interface IGetObjectOptions {
  /**
   * If true, all of the methods below will return a result
   * formatted as if a multipart response was received, even if a request only returns a single result.  If you
   * will sometimes get multiple results back from a single query, this will simplify your code by making the
   * results more consistent.  However, if you know you are only making requests that return a single result,
   * it is probably more intuitive to leave this false/unset
   */
  alwaysGroupObjects: boolean
  /*
   *        Location: can be 0 (default) or 1 a 1 value requests URLs be returned instead of actual image data, but the
   *           RETS server may ignore this
   */
  Location?: number
  /**
   *           ObjectData: can be null (default), a string to be used directly as the ObjectData argument, or an array of
   *           values to be joined with commas.  Requests that the server sets headers containing additional metadata
   *           about the object(s) in the response.  The special value '*' requests all available metadata.  Any headers
   *           set based on this argument will be parsed into a special object and set as the field 'objectData' in the
   *           headerInfo object.
   */
  ObjectData?: string | string[]
}
export type ObjectIds = string[] | string | Object
export interface IObjectData {
  headerInfo: IObjectHeaderInfo
}
export interface IObjectsStreamGetObjectsResponse {
  objectStream: IObjectsStream
  dataStream: NodeJS.ReadableStream
}

export interface IObjectsStream extends NodeJS.ReadableStream {
  on (event: 'data', callback: (event: IObjectsStreamEvent | IObjectsStreamErrorEvent | IObjectsStreamDataStreamEvent | IObjectsStreamHeaderInfoEvent) => void): this
  on (event: 'error', callback: (error: any) => void): this
  on (event: 'end', callback: () => void): this
}

export interface IObjectsStreamEvent {
  type: 'headerInfo' | 'error' | 'dataStream'
}
export interface IObjectsStreamDataStreamEvent extends IObjectsStreamEvent, IObjectData {
  type: 'dataStream'
  dataStream: NodeJS.ReadableStream
  headerInfo: IObjectHeaderInfo
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
export interface IObjectsStreamErrorEvent extends IObjectsStreamEvent {
  type: 'error'
  error: any
}
export interface IObjectsStreamHeaderInfoEvent extends IObjectsStreamEvent {
  type: 'headerInfo'
  headerInfo: IObjectHeaderInfo
}

export interface IObjectsStreamErrorEvent extends IObjectsStreamEvent {
  type: 'error'
  error: any
}

export interface IObjectsStreamHeaderInfoEvent extends IObjectsStreamEvent {
  type: 'headerInfo'
  headerInfo: IObjectHeaderInfo
}

export interface IGetObjectsResponse {
  data: Buffer;
  headerInfo: IObjectHeaderInfo;
}

export interface IGetAllObjectsResponse {
  objects: IObjectData[]
}