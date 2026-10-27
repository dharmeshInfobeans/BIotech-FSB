@RestResource(urlMapping='/insertSchemes/*')
global without sharing class SchemeRestService {
    
    @HttpPost
    global static ApiResponse doPost() {
        
        RestResponse res = RestContext.response;
        
        try {
            
            RestRequest req = RestContext.request;
            
            List<Scheme> schemes =
                (List<Scheme>) JSON.deserialize(req.requestBody.toString(), List<Scheme>.class);
            
            List<Scheme_Information__c> schemeToUpsert = new List<Scheme_Information__c>();
            List<Scheme_Line_Item__c> schemeLineItemToUpsert = new List<Scheme_Line_Item__c>();
            
            Map<String, List<SchemeLinetem>> schmLineItemMap = new Map<String, List<SchemeLinetem>>();
            Map<String, Scheme_Information__c> existingSchemesMap = new Map<String, Scheme_Information__c>();
            
            Map<String, Id> upsertedSchemeInfoMap = new Map<String, Id>();
            
            Map<String, Scheme_Line_Item__c> existingSchemeLineItemsMap =
                new Map<String, Scheme_Line_Item__c>();
            
            
            // Map Scheme Numbers
            for (Scheme scheme : schemes) {
                schmLineItemMap.put(scheme.SCHEMENo, scheme.schemeLinetems);
            }
            
            
            // Query existing schemes
            List<Scheme_Information__c> existingSchemes = [
                
                SELECT Id, Scheme_Number__c,
                (SELECT Id, Scheme_No__c, Product_Code__c
                 FROM Scheme_Line_Items__r)
                
                FROM Scheme_Information__c
                
                WHERE Scheme_Number__c IN :schmLineItemMap.keySet()
            ];
            
            
            // Map existing schemes
            for (Scheme_Information__c existingScheme : existingSchemes) {
                
                existingSchemesMap.put(existingScheme.Scheme_Number__c, existingScheme);
                
                for (Scheme_Line_Item__c existingLineItem : existingScheme.Scheme_Line_Items__r) {
                    
                    String key = existingScheme.Scheme_Number__c + '-' + existingLineItem.Product_Code__c;
                    
                    existingSchemeLineItemsMap.put(key, existingLineItem);
                }
            }
            
            
            // Prepare scheme records
            for (Scheme scheme : schemes) {
                
                Scheme_Information__c newScheme =
                    createOrUpdateScheme(scheme, existingSchemesMap);
                
                schemeToUpsert.add(newScheme);
            }
            
            
            // Upsert scheme
            if (!schemeToUpsert.isEmpty()) {
                
                upsert schemeToUpsert Scheme_Number__c;
                
                for (Scheme_Information__c sf : schemeToUpsert) {
                    
                    upsertedSchemeInfoMap.put(sf.Scheme_Number__c, sf.Id);
                }
            }
            
            
            // Prepare line items
            for (Scheme schemeInfo : schemes) {
                
                for (SchemeLinetem newSchemeLineItem : schemeInfo.schemeLinetems) {
                    
                    Scheme_Line_Item__c newSchemeItem =
                        createOrUpdateSchemeLineItem(
                            newSchemeLineItem,
                            schemeInfo,
                            upsertedSchemeInfoMap,
                            existingSchemeLineItemsMap
                        );
                    
                    schemeLineItemToUpsert.add(newSchemeItem);
                }
            }
            
            
            // Upsert line items
            if (!schemeLineItemToUpsert.isEmpty()) {
                
                upsert schemeLineItemToUpsert;
            }
            
            
            res.statusCode = 200;
            
            ApiResponse response = new ApiResponse(
                'Success',
                'Schemes inserted successfully'
            );
            
            return response;
            
        }
        
        catch (Exception e) {
            
            res.statusCode = 500;
            
            ApiResponse response = new ApiResponse(
                'Error',
                e.getMessage()
            );
            
            return response;
        }
    }
    
    
    
    private static Scheme_Information__c createOrUpdateScheme(
        
        Scheme scheme,
        Map<String, Scheme_Information__c> existingSchemesMap
    ) {
        
        Scheme_Information__c newScheme = new Scheme_Information__c();
        
        if (existingSchemesMap.containsKey(scheme.SCHEMENo)) {
            
            newScheme.Id = existingSchemesMap.get(scheme.SCHEMENo).Id;
        }
        
        newScheme.Name = scheme.SCHEMENAME;
        newScheme.Scheme_Desc__c = scheme.SCHEMEDESC;
        newScheme.Tenure__c = scheme.TENURE;
        newScheme.Pay_Terms__c = scheme.PAYTERMS;
        newScheme.TOT_Business__c = scheme.TOTBUSINESS;
        newScheme.PUR_Unit_Comm__c = scheme.PURUNITCOMM;
        newScheme.Min_Qty__c = scheme.MINQTY;
        newScheme.Credit_Note__c = scheme.CREDITNOTE;
        
        newScheme.Total_Qty_Flg__c = String.valueOf(scheme.TOTALQTYFLG);
        
        newScheme.Credit_Percentage__c = scheme.CREDITPER;
        
        if(scheme.ADDCN != null)
            newScheme.Add_On__c = Integer.valueOf(scheme.ADDCN);
        
        newScheme.Total_Amount__c = scheme.TOTALAMT;
        
        newScheme.Valid_Upto__c = scheme.VALIDUPTO;
        
        newScheme.Scheme_Number__c = scheme.SCHEMENo;
        
        newScheme.Is_Deleted__c = scheme.ISDELETED;
        
        newScheme.Country__c = scheme.Country;
        
        return newScheme;
    }
    
    
    
    private static Scheme_Line_Item__c createOrUpdateSchemeLineItem(
        
        SchemeLinetem newSchemeLineItem,
        Scheme schemeInfo,
        Map<String, Id> upsertedSchemeInfoMap,
        Map<String, Scheme_Line_Item__c> existingSchemeLineItemsMap
    ) {
        
        String lineItemKey = newSchemeLineItem.SCHEMENO + '-' + newSchemeLineItem.PRODUCTCODE;
        
        Scheme_Line_Item__c newSchemeItem = new Scheme_Line_Item__c();
        
        //system.debug('upsertedSchemeInfoMap-->'+Json.serialize(upsertedSchemeInfoMap));
        
        if (existingSchemeLineItemsMap.containsKey(lineItemKey)) {
            
            newSchemeItem.Id = existingSchemeLineItemsMap.get(lineItemKey).Id;
        }
        
        newSchemeItem.Scheme_Information__c =  upsertedSchemeInfoMap.get(newSchemeLineItem.SCHEMENO);
        
        newSchemeItem.Scheme_No__c = String.valueOf(schemeInfo.SCHEMENo);
        
        newSchemeItem.Product_Code__c = newSchemeLineItem.PRODUCTCODE;
        
        newSchemeItem.Product_Description__c = newSchemeLineItem.PRODUCTDESC;
        
        newSchemeItem.Min_Qty__c = newSchemeLineItem.MINQTY;
        
        newSchemeItem.Reg_Price__c = newSchemeLineItem.REGPRICE;
        
        newSchemeItem.Credit_Note__c = newSchemeLineItem.CREDITNOTE;
        
        newSchemeItem.Net_Price__c = newSchemeLineItem.NETPRICE;
        
        newSchemeItem.Credit_Percentage__c = newSchemeLineItem.CREDITPER;
        
        newSchemeItem.CR_Note_PL_GST__c = newSchemeLineItem.CRNOTPLGST;
        
        newSchemeItem.Add_On__c = newSchemeLineItem.ADDCN;
        
        newSchemeItem.Benifit__c = newSchemeLineItem.BENEFIT;
        
        newSchemeItem.Is_Deleted__c = newSchemeLineItem.ISDELETED;
        
        // newSchemeItem.Name = schemeInfo.SCHEMENAME + ' Item';
        
        return newSchemeItem;
    }
    
    
    
    global class Scheme {
        
        public String SCHEMENAME;
        public String SCHEMEDESC;
        public String TENURE;
        public String PAYTERMS;
        public String TOTBUSINESS;
        public String PURUNITCOMM;
        public Integer MINQTY;
        public String CREDITNOTE;
        public Integer TOTALQTYFLG;
        public Decimal CREDITPER;
        public String ADDCN;
        public Decimal TOTALAMT;
        public Date VALIDUPTO;
        public Boolean ISDELETED;
        public String SCHEMENo;
        public String Country;
        
        public List<SchemeLinetem> schemeLinetems;
    }
    
    
    global class SchemeLinetem {
        
        public string SCHEMENO;
        public String PRODUCTCODE;
        public String PRODUCTDESC;
        public Integer MINQTY;
        public Decimal REGPRICE;
        public String CREDITNOTE;
        public Decimal NETPRICE;
        public Integer CREDITPER;
        public String CRNOTPLGST;
        public Integer ADDCN;
        public String BENEFIT;
        public Boolean ISDELETED;
    }
    
    global class ApiResponse {
        public String status;
        public String message;
        
        public ApiResponse(String status, String message){
            this.status = status;
            this.message = message;
        }
    }
    
}