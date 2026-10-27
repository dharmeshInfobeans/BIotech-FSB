global without sharing class MOUSchemeMasterBatch implements Database.Batchable<Integer>, Database.AllowsCallouts {

    public String startDate;
    public String endDate;

    // Constructor (no parameters)
    global MOUSchemeMasterBatch(String startDate,String endDate) {
        this.startDate = startDate;
        this.endDate   = endDate;
    }

    // START
    global Iterable<Integer> start(Database.BatchableContext bc) {
        return new List<Integer>{ 1 };
    }

    // EXECUTE
    global void execute(Database.BatchableContext bc, List<Integer> scope) {

        String jsonBody = '';
        try {
            MOU_Integration__c mouData =
                MOU_Integration__c.getInstance('getschememaster');

            if (mouData == null || String.isBlank(mouData.End_Point_URL__c)) {
                System.debug('❌ Endpoint missing');
                return;
            }

            Map<String, String> requestBody = new Map<String, String>{
                'SchemeValidDateFrom' => startDate,
                'SchemeValidDateTo'   => endDate
            };
            jsonBody = JSON.serialize(requestBody);

            HttpRequest req = new HttpRequest();
            req.setEndpoint(mouData.End_Point_URL__c);
            req.setMethod('GET');
            req.setTimeout(120000);
            req.setHeader('Content-Type', 'application/json;charset=UTF-8');

            Blob headerValue =
                Blob.valueOf(mouData.Username__c + ':' + mouData.Password__c);
            req.setHeader(
                'Authorization',
                'Basic ' + EncodingUtil.base64Encode(headerValue)
            );

            req.setBody(jsonBody);

            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Response JSON ==> ' + JSON.serializePretty(
                JSON.deserializeUntyped(res.getBody())
            ));

            if (res.getStatusCode() == 200) {
                processSchemeData(res.getBody());
            } else {
                createApiErrorLog(
                    'MOU scheme',
                    'MOUSchemeMasterBatch',
                    res.getStatusCode(),
                    res.getStatus(),
                    'Non-200 response',
                    jsonBody,
                    res.getBody()
                );
            }

        } catch (Exception e) {
            createApiErrorLog(
                'MOU scheme',
                'MOUSchemeMasterBatch',
                null,
                'EXCEPTION',
                e.getMessage() + ' | Line: ' + e.getLineNumber(),
                jsonBody,
                null
            );
        }
    }


    // PROCESS RESPONSE
      public static void processSchemeData(String responseBody) {
          
          system.debug('responseBody-->'+Json.serialize(responseBody));

        try {
            Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);

            List<Object> headers = (List<Object>) jsonResponse.get('Header');
            if (headers == null || headers.isEmpty()) {
                System.debug('No Header data found');
                return;
            }

            List<Scheme_Information__c> schemes = new List<Scheme_Information__c>();
            Map<String, List<Object>> schemeItemMap = new Map<String, List<Object>>();
            //Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            //List<Object> headers = (List<Object>) jsonResponse.get('Header');
            System.debug('Main heder'+JSON.serialize(headers));
            if (headers != null && !headers.isEmpty()) {
                List<Scheme_Information__c> schemeRequests = new List<Scheme_Information__c>();
                List<Scheme_Line_Item__c> schemelineitem = new List<Scheme_Line_Item__c>();  
                Map<string, List<Object>> schemeMap = new Map<string, List<Object>>();
                
                for (Object headerObj : headers) {
                    
                    Map<String, Object> headerMap = (Map<String, Object>) headerObj;
                    
                    System.debug('Header Map'+JSON.serialize(headerMap));
                    Scheme_Information__c scheme = new Scheme_Information__c();
                    if(headerMap.containskey('SchemeNo')){
                     scheme.Scheme_Number__c = string.valueOf(headerMap.get('SchemeNo'));
                    }
                    if(headerMap.containskey('SchemeName')){
                      scheme.Name = string.valueOf(headerMap.get('SchemeName'));
                    }
                     if(headerMap.containskey('SchemeDesc')){
                      scheme.Scheme_Desc__c = string.valueOf(headerMap.get('SchemeDesc'));    
                     }
                   if(headerMap.containskey('Tenure')){
                      scheme.Tenure__c = string.valueOf(headerMap.get('Tenure'));    
                     }
                    if(headerMap.containskey('PayTerms')){
                      scheme.Pay_Terms__c = string.valueOf(headerMap.get('PayTerms'));   
                     }
                    if(headerMap.containskey('TotBusiness')){
                      scheme.TOT_Business__c = string.valueOf(headerMap.get('TotBusiness'));  
                     }
                    if(headerMap.containskey('PurUnitComm')){
                      scheme.PUR_Unit_Comm__c = string.valueOf(headerMap.get('PurUnitComm')); 
                     }
                    if(headerMap.containskey('Remarks')){
                      scheme.Remark__c = string.valueOf(headerMap.get('Remarks')); 
                     }
                    if(headerMap.containskey('MinQty')){
                      scheme.Min_Qty__c = double.valueOf(headerMap.get('MinQty')); 
                     }
                    if(headerMap.containskey('CreditNote')){
                        scheme.Credit_Note__c = string.valueOf(headerMap.get('CreditNote')); 
                    } 
                    if(headerMap.containskey('TotalQtyFlg')){
                       scheme.Total_Qty_Flg__c = string.valueOf(headerMap.get('TotalQtyFlg')); 
                    } 
                     if(headerMap.containskey('AddCn')){
                        scheme.Add_On__c =  double.valueOf(headerMap.get('AddCn'));
                    } 
                    if(headerMap.containskey('country')){
                        scheme.Country__c =  string.valueOf(headerMap.get('country'));
                    } 
                     if(headerMap.containskey('TotalAmt')){
                        scheme.Total_Amount__c = double.valueOf(headerMap.get('TotalAmt'));
                    } 
                    if(headerMap.containskey('ValidUpto')){
                        String rawDate = String.valueOf(headerMap.get('ValidUpto')); 
                        
                        if (!String.isBlank(rawDate) && rawDate.length() == 8) {
                            String formattedDate =
                                rawDate.substring(0, 4) + '-' +
                                rawDate.substring(4, 6) + '-' +
                                rawDate.substring(6, 8);
                            
                            scheme.Valid_Upto__c = Date.valueOf(formattedDate);
                        }          
                    } 
                    if (String.isBlank(scheme.Country__c)) {
                        scheme.Country__c = System.Label.Open_MOU_Scheme_Country_Mapping;
                    }
                    
                  
                   
                    
                  
                    
                    schemeRequests.add(scheme);
                    
                    // Extract related items
                    List<Object> items = (List<Object>) headerMap.get('Item');
                    schemeMap.put(string.valueOf(headerMap.get('SchemeNo')), items);
                }
                
                Set<String> schemeNumbers = new Set<String>();
                
                for (Scheme_Information__c s : schemeRequests) {
                    schemeNumbers.add(s.Scheme_Number__c);
                }
                
                Map<String, Scheme_Information__c> existingSchemes = new Map<String, Scheme_Information__c>();
                
                for (Scheme_Information__c s : [
                    SELECT Id, Scheme_Number__c
                    FROM Scheme_Information__c
                    WHERE Scheme_Number__c IN :schemeNumbers
                ]) {
                    existingSchemes.put(s.Scheme_Number__c, s);
                }
                
                // Insert Scheme Records in Salesforce with Bulk DML Operation
                if (!schemeRequests.isEmpty()) {
                    upsert schemeRequests Scheme_Number__c;
                    System.debug('Inserted ' + schemeRequests.size() + ' Scheme Information');
                    Map<String, Scheme_Line_Item__c> existingItems = new Map<String, Scheme_Line_Item__c>();
                    
                    for(Scheme_Line_Item__c sli : [
                        SELECT Id, Scheme_No__c,Scheme_Product_Key__c, Product_Code__c
                        FROM Scheme_Line_Item__c
                        WHERE Scheme_No__c IN :schemeNumbers
                    ]){
                        existingItems.put(
                            sli.Scheme_No__c + '-' + sli.Product_Code__c,
                            sli
                        );
                    }
                    Map<String, Id> schemeIdMap = new Map<String, Id>();
                    
                    for(Scheme_Information__c sch : [
                        SELECT Id, Scheme_Number__c
                        FROM Scheme_Information__c
                        WHERE Scheme_Number__c IN :schemeNumbers
                    ]){
                        schemeIdMap.put(sch.Scheme_Number__c, sch.Id);
                    }
                    List<Scheme_Line_Item__c> productItems = new List<Scheme_Line_Item__c>();
                    // Insert related Product records in Bulk
                    for (Scheme_Information__c schi : schemeRequests) {
                        
                      /*  if (existingSchemes.containsKey(schi.Scheme_Number__c)) {
                            System.debug('Scheme already exists, skipping line items: ' + schi.Scheme_Number__c);
                            continue;
                        }*/
                                               
                        if (schemeMap.containsKey(schi.Scheme_Number__c)) {
                            for (Object itemObj : schemeMap.get(schi.Scheme_Number__c)) {
                                Map<String, Object> itemMap = (Map<String, Object>) itemObj;
                                String productCode = String.valueOf(itemMap.get('ProductCode'));
                                
                                //String key = schi.Scheme_Number__c + '-' + productCode;
                                
                               /* if(existingItems.containsKey(key)){
                                    continue;
                                }*/
                                
                                String key = schi.Scheme_Number__c + '-' + productCode;
                                
                                Scheme_Line_Item__c product = new Scheme_Line_Item__c();
                                
                                product.Scheme_Product_Key__c = key;
                                
                                if(existingItems.containsKey(key)){
                                    product.Id = existingItems.get(key).Id;
                                }
                                
                                
                                
                                if(schi.Id !=null){
                                    product.Scheme_Information__c = schemeIdMap.get(schi.Scheme_Number__c);
                                    product.Scheme_No__c = schi.Scheme_Number__c;
                                }
                                
                                if(itemMap.containskey('ProductCode')){
                                    product.Product_Code__c = string.valueOf(itemMap.get('ProductCode'));
                                }
                                if(itemMap.containskey('ProductDesc')){
                                     product.Product_Description__c = string.valueOf(itemMap.get('ProductDesc'));
                                }
                                if(itemMap.containskey('MinQty')){
                                     product.Min_Qty__c = Double.valueOf(itemMap.get('MinQty'));
                                }
                               if(itemMap.containskey('RegPrice')){
                                    product.Reg_Price__c = Double.valueOf(itemMap.get('RegPrice'));
                                }
                                if(itemMap.containskey('NetPrice')){
                                    product.Net_Price__c = Double.valueOf(itemMap.get('NetPrice'));
                                }
                                if(itemMap.containskey('CreditNote')){
                                     product.Credit_Note__c =string.valueOf(itemMap.get('CreditNote'));
                                }
                                 if(itemMap.containskey('CreditPer')){
                                     product.Credit_Percentage__c = Double.valueOf(itemMap.get('CreditPer'));
                                }
                                if(itemMap.containskey('CrNotePlGst')){
                                     product.CR_Note_PL_GST__c = string.valueOf(itemMap.get('CrNotePlGst'));
                                }
                                if(itemMap.containskey('AddCn')){
                                     product.Add_On__c = Double.valueOf(itemMap.get('AddCn'));
                                }
                                if(itemMap.containskey('Benefit')){
                                     product.Benifit__c =  string.valueOf(itemMap.get('Benefit'));
                                }
                                                             
                                
                                productItems.add(product);
                            }
                        }
                        
                        
                    }
                    // Insert the products in bulk for each Scheme
                    if (!productItems.isEmpty()) {
                        upsert productItems Scheme_Product_Key__c;
                        System.debug('Inserted ' + productItems.size() + ' Products.');
                    }
                }
            } else {
                System.debug('No Header data found in API response.');
            }

        } catch (Exception e) {
            System.debug(
                'Exception in processSchemeData: ' +
                e.getMessage() + ' Line ' + e.getLineNumber()
            );
        }
    }

    // =========================
    // API LOG
    // =========================
    public static void createApiErrorLog(
        String apiModuleType,
        String className,
        Integer statusCode,
        String status,
        String message,
        String requestBody,
        String responseBody
    ) {
        try {
            API_Log__c log = new API_Log__c();
            log.API_Module_Type__c = 'MOU scheme';
            log.Class_Name__c = className;
            log.Log_Date__c = System.now();
            log.Message__c = message;
            log.request_body__c = requestBody;
            log.Response_Body__c = responseBody;
            insert log;
        } catch (Exception e) {
            System.debug('API log insert failed: ' + e.getMessage());
        }
    }

    global void finish(Database.BatchableContext bc) {
        System.debug('✅ MOU Scheme Master Batch completed');
    }
}