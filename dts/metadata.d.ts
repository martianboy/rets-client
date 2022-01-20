import { IHeaderInfo, IGetResourcesResponse, IGetClassResponse, IGetTableResponse } from './client'

export interface IClientMetadata {
  getResources (): Promise<IGetResourcesResponse>
  /** METADATA-CLASS */
  getClass (resourceId: string): Promise<IGetClassResponse>
  /** METADATA-TABLE */
  getTable (resourceId: string, classId: string): Promise<IGetTableResponse>
  /** METADATA-LOOKUP */

  getLookups (resourceId: string, classId: string): Promise<IGetTableResponse>
  /** METADATA-LOOKUP_TYPE */

  getLookupTypes (resourceId: string, field: string): Promise<IGetTableResponse>

  getForeignKeys (resourceId: string): Promise<IGetTableResponse>

  getAllClass (): Promise<IGetTableResponse>

  getAllTable (): Promise<IGetTableResponse>

  getAllClass (): Promise<IGetTableResponse>

  getAllLookups (): Promise<IGetTableResponse>

  getAllLookupTypes (): Promise<MetadataLookupTypes>

  getAllForeignKeys (): Promise<IGetTableResponse>
}

interface MetadataLookupTypes {
  results: MetadataLookupResult[];
  type: string;
  headerInfo: IHeaderInfo;
  replyCode: string;
  replyTag: string;
  replyText: string;
  entriesReceived: number;
}

interface MetadataLookupResult {
  info: MetadataLookupInfo;
  metadata: MetadataLookupValue[];
}

interface MetadataLookupValue {
  MetadataEntryID: string;
  LongValue: string;
  ShortValue: string;
  Value: string;
}

interface MetadataLookupInfo {
  Resource: string;
  Version: string;
  Date: string;
  Lookup: string;
  rowsReceived: number;
}