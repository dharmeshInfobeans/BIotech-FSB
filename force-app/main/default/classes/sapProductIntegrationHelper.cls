@RestResource(urlMapping='/sap/productRationalization')
global with sharing class sapProductIntegrationHelper {
    @HttpPost    
    global static void receiveData() {
        
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        String requestBody = req.requestBody.toString();
        system.debug('line 10 ' + requestBody);
        
        Integration_Log__c logRec = new Integration_Log__c(
            EndPoint_URL__c = '/services/apexrest/sap/product',
            Object_Name__c = 'Product_Group__c, Product_M__c',
            //Request_Body__c = requestBody,
            Status__c = 'Processing'
        );
        
        sapProductIntegrationWrapper responseObj = new sapProductIntegrationWrapper();
        responseObj.summary = new sapProductIntegrationWrapper.Summary();
        responseObj.errors = new List<sapProductIntegrationWrapper.ErrorDetail>();
        responseObj.successes = new List<sapProductIntegrationWrapper.SuccessDetail>();
        
        try {
            
            sapProductIntegrationWrapper.MainWrapper data =
                (sapProductIntegrationWrapper.MainWrapper)
                JSON.deserialize(requestBody, sapProductIntegrationWrapper.MainWrapper.class);
            
            if (data == null || data.records == null || data.records.isEmpty()) {
                throw new AuraHandledException('No records received.');
            }
            
            List<Product_Group__c> headersToUpsert = new List<Product_Group__c>();
            List<Product_M__c> linesToUpsert = new List<Product_M__c>();
            Map<String, String> lineToHeaderMap = new Map<String, String>();
            
            
            //Product Group Records
            for (sapProductIntegrationWrapper.RecordWrapper rec : data.records) {
                
                responseObj.summary.totalHeaders++;
                
                Product_Group__c header = new Product_Group__c();
                header.Product_Group_External_ID__c = rec.headerExternalId; 
                header.Name = rec.groupName != null ? rec.groupName : header.Name;
                header.Group_Name__c = rec.groupName != null ? rec.groupName : header.Group_Name__c;
                header.Vertical__c = rec.vertical != null ? rec.vertical : header.Vertical__c;
                header.Product_Family__c =  rec.productFamily != null ? rec.productFamily : header.Product_Family__c;
                header.Brand__c = rec.brand != null ? rec.brand : header.Brand__c;
                header.Category__c = rec.category != null ? rec.category : header.Category__c;
                header.Sub_Category__c =  rec.subCategory != null ? rec.subCategory : header.Sub_Category__c;
                header.IsActive__c = rec.activeheader != null ? rec.activeheader : header.IsActive__c;
                header.Addition_1__c = rec.addition1 != null ? rec.addition1 : header.Addition_1__c;
                header.Addition_2__c =rec.addition2 != null ? rec.addition2 : header.Addition_2__c;
                header.Addition_3__c = rec.addition3 != null ? rec.addition3 : header.Addition_3__c;
                header.Addition_4__c = rec.addition4 != null ? rec.addition4 : header.Addition_4__c;
                header.Addition_5__c =  rec.addition5 != null ? rec.addition5 : header.Addition_5__c;
                
                headersToUpsert.add(header);
            }
            
            //Mat to update Product Group Value
            Map<String, Id> headerExternalIdToIdMap = new Map<String, Id>();
            
            if (!headersToUpsert.isEmpty()) {
                Database.UpsertResult[] headerResults =
                    Database.upsert(
                        headersToUpsert,
                        Product_Group__c.Product_Group_External_ID__c,
                        false);
                
                for (Integer i = 0; i < headerResults.size(); i++) {
                    if (headerResults[i].isSuccess()) {
                        
                        responseObj.summary.successfulHeaders++;
                        
                        Id recordId = headerResults[i].getId();
                        Boolean isInsert = headerResults[i].isCreated();
                        
                        headerExternalIdToIdMap.put(headersToUpsert[i].Product_Group_External_ID__c, recordId);
                        
                        // Add success detail
                        sapProductIntegrationWrapper.SuccessDetail success = new sapProductIntegrationWrapper.SuccessDetail();
                        success.level = 'HEADER';
                        success.externalId = headersToUpsert[i].Product_Group_External_ID__c;
                        success.recordId = recordId;
                        success.operation = isInsert ? 'CREATED' : 'UPDATED';
                        
                        responseObj.successes.add(success);
                        
                    } else {
                        
                        responseObj.summary.failedHeaders++;
                        
                        for (Database.Error errDb : headerResults[i].getErrors()) {
                            
                            sapProductIntegrationWrapper.ErrorDetail err = new sapProductIntegrationWrapper.ErrorDetail();
                            err.level = 'HEADER';
                            err.headerExternalId = headersToUpsert[i].Product_Group_External_ID__c;
                            err.objectName = 'Product_Group__c';
                            err.message = errDb.getMessage();
                            
                            responseObj.errors.add(err);
                        }
                    }
                }
            }
            
            //Product Master Records
            for (sapProductIntegrationWrapper.RecordWrapper rec : data.records) {
                
                if (rec.lines != null) {
                    
                    Id parentHeaderId = headerExternalIdToIdMap.get(rec.headerExternalId);
                    
                    for (sapProductIntegrationWrapper.LineWrapper line : rec.lines) {
                        
                        responseObj.summary.totalLines++;
                        
                        Product_M__c lineRec = new Product_M__c();
                        lineRec.IsActive__c = line.activeline != null ? line.activeline : lineRec.IsActive__c;
                        lineRec.Product_External_Id__c = line.lineExternalId != null ? line.lineExternalId : lineRec.Product_External_Id__c;
                        lineRec.Name = line.lineExternalId != null ? line.lineExternalId : lineRec.Name;
                        //lineRec.Name = line.productCode;
                        lineRec.Product_Code__c = line.productCode != null ? line.productCode : lineRec.Product_Code__c;
                        lineRec.Country__c = line.country != null ? line.country : lineRec.Country__c;
                        lineRec.CurrencyIsoCode = line.currency1 != null ? line.currency1 : lineRec.CurrencyIsoCode;
                        lineRec.Product_Family__c = line.productFamilyLine != null ? line.productFamilyLine : lineRec.Product_Family__c;
                        lineRec.Vertical__c = line.verticalLine != null ? line.verticalLine : lineRec.Vertical__c;
                        lineRec.Group_Name__c = line.groupNameLine != null ? line.groupNameLine : lineRec.Group_Name__c;
                        lineRec.Brand__c = line.brandLine != null ? line.brandLine : lineRec.Brand__c;
                        lineRec.Category__c = line.categoryLine != null ? line.categoryLine : lineRec.Category__c;
                        lineRec.Sub_Category__c = line.subCategoryLine != null ? line.subCategoryLine : lineRec.Sub_Category__c;
                        lineRec.Division__c = line.division != null ? line.division : lineRec.Division__c;
                        lineRec.Axis__c = line.axis != null ? line.axis : lineRec.Axis__c;
                        lineRec.CylinderPower__c = line.cylinderPower != null ? line.cylinderPower : lineRec.CylinderPower__c;
                        lineRec.Diaptor__c = line.diaptor != null ? line.diaptor : lineRec.Diaptor__c;
                        lineRec.Hydrophilic_Size__c = line.hydrophilicSize != null ? line.hydrophilicSize : lineRec.Hydrophilic_Size__c;
                        lineRec.Spherical_Power__c = line.sphericalPower != null ? line.sphericalPower : lineRec.Spherical_Power__c;
                        lineRec.Dummy_Product_Code__c = line.dummyProductCode != null ? line.dummyProductCode : lineRec.Dummy_Product_Code__c;
                        lineRec.Description__c = line.groupDescription != null ? line.groupDescription : lineRec.Description__c;
                        lineRec.Dummy_Product_Description__c = line.dummyProductDescription != null ? line.dummyProductDescription : lineRec.Dummy_Product_Description__c;
                        lineRec.Original_Product_Description__c = line.originalProductDescription != null ? line.originalProductDescription : lineRec.Original_Product_Description__c;
                        lineRec.Language__c = line.language != null ? line.language : lineRec.Language__c;
                        lineRec.Addition_1__c = line.addition1 != null ? line.addition1 : lineRec.Addition_1__c;
                        lineRec.Addition_2__c = line.addition2 != null ? line.addition2 : lineRec.Addition_2__c;
                        lineRec.Addition_3__c = line.addition3 != null ? line.addition3 : lineRec.Addition_3__c;
                        lineRec.Addition_4__c = line.addition4 != null ? line.addition4 : lineRec.Addition_4__c;
                        lineRec.Addition_5__c = line.addition5 != null ? line.addition5 : lineRec.Addition_5__c;
                        
                        if (parentHeaderId != null) {
                            lineRec.Product_Group__c = parentHeaderId;  
                        }
                        
                        linesToUpsert.add(lineRec);
                        lineToHeaderMap.put(line.lineExternalId, rec.headerExternalId);
                    }
                }
            }
            
            
            //upsert Operations
            if (!linesToUpsert.isEmpty()) {
                
                Database.UpsertResult[] lineResults =
                    Database.upsert(
                        linesToUpsert,
                        Product_M__c.Product_External_Id__c,
                        false
                    );
                
                for (Integer i = 0; i < lineResults.size(); i++) {
                    
                    if (lineResults[i].isSuccess()) {
                        
                        responseObj.summary.successfulLines++;
                        
                        Id recordId = lineResults[i].getId();
                        Boolean isInsert = lineResults[i].isCreated();
                        
                        sapProductIntegrationWrapper.SuccessDetail success = new sapProductIntegrationWrapper.SuccessDetail();
                        
                        success.level = 'LINE';
                        success.externalId = linesToUpsert[i].Product_External_Id__c;
                        success.recordId = recordId;
                        success.operation = isInsert ? 'CREATED' : 'UPDATED';
                        responseObj.successes.add(success);
                    } else {
                        responseObj.summary.failedLines++;
                        
                        for (Database.Error errDb : lineResults[i].getErrors()) {
                            sapProductIntegrationWrapper.ErrorDetail err = new sapProductIntegrationWrapper.ErrorDetail();
                            
                            err.level = 'LINE';
                            err.lineExternalId = linesToUpsert[i].Product_External_Id__c;
                            err.headerExternalId = lineToHeaderMap.get(linesToUpsert[i].Product_External_Id__c);
                            err.objectName = 'Product_M__c';
                            err.message = errDb.getMessage();
                            
                            responseObj.errors.add(err);
                        }
                    }
                }
            }
            
            
            //Response Structure
            if (responseObj.summary.failedHeaders > 0 || responseObj.summary.failedLines > 0) {
                responseObj.status = 'PARTIAL_SUCCESS';
                res.statusCode = 207;
                
            } else {
                responseObj.status = 'SUCCESS';
                res.statusCode = 200;
            }
            
            logRec.Status__c = responseObj.status;
            logRec.Response_Body__c = JSON.serialize(responseObj);
            insert logRec;
            
            res.responseBody = Blob.valueOf(JSON.serialize(responseObj));
            
        } catch (Exception e) {
            
            responseObj.status = 'FAILED';
            
            sapProductIntegrationWrapper.ErrorDetail err = new sapProductIntegrationWrapper.ErrorDetail();
            
            err.level = 'SYSTEM';
            err.objectName = 'System';
            err.message = e.getMessage();
            
            responseObj.errors.add(err);
            
            logRec.Status__c = 'FAILED';
            logRec.Response_Body__c = e.getMessage();
            insert logRec;
            
            res.statusCode = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(responseObj));
        }
    }
}