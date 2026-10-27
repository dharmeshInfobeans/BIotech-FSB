public without sharing class MOUSchemeAPI {
    
    // Named Constants for Repeated Strings
    //private static final String API_ENDPOINT_SETTING = 'End_Point_URL__c';
    private static final String AUTHORIZATION_HEADER = 'Authorization';
    private static final String CONTENT_TYPE_HEADER = 'Content-Type';
    private static final String CONTENT_TYPE_JSON = 'application/json';
    private static final String BEARER_PREFIX = 'Bearer ';
    
    //--------------------------for getschememaster---------------------------------------------------API
    // Method to call API and insert Scheme_Request__c & related Product__c records
    /*  @future(callout=true)
public static void getschememasterAPI(String startDate, String endDate) {
String jsonBody ='';
try {
// Retrieve API endpoint from Custom Settings
string endpoint='';
MOU_Integration__c mouData = MOU_Integration__c.getInstance('getschememaster');
if(mouData!=null) {
endpoint= mouData.End_Point_URL__c;
}

if (String.isEmpty(endpoint)) {
System.debug('Error: API Endpoint not found in Custom Settings');
return;
}
System.debug('Inside');
// Create request body with startDate and endDate
Map<String, String> requestBody = new Map<String, String>();
requestBody.put('SchemeValidDateFrom', startDate);
requestBody.put('SchemeValidDateTo', endDate);
jsonBody = JSON.serialize(requestBody);

Http http=new Http();
HttpRequest req=new HttpRequest();
req.setEndpoint(mouData.End_Point_URL__c);
System.debug('Inside1');
req.setHeader('Content-Type', 'application/json;charset=UTF-8');
Blob headerValue = Blob.valueOf(mouData.Username__c + ':' + mouData.Password__c);
// String username = 'piuser';
// String password = 'Welcome@123';
System.debug('Inside2');
//Blob headerValue = Blob.valueOf(username + ':' + password);
String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
System.debug('Inside2');
req.setHeader('Authorization', authorizationHeader);
req.setMethod('GET');
req.setTimeout(120000);
req.setBody(jsonBody);         
System.debug('Inside2');
HTTPResponse res = http.send(req);
System.debug('Inside5');
if (res.getStatusCode() == 200) {
String responseBody = res.getBody();
//   System.debug('API Response: ' + JSON.serialize(responseBody));

// Parse and insert records
processSchemeData(responseBody);
} else {
System.debug('Error: ' + res.getStatusCode() + ' - ' + res.getBody());
createApiErrorLog(
'Get Scheme Master',
'MOUSchemeAPI',
res.getStatusCode(),
res.getStatus(),
'API returned non-200 status',
jsonBody,
res.getBody()
);
}

} catch (Exception e) {
//System.debug('Inerro')
System.debug('Exception: ' + e.getMessage());
createApiErrorLog(
'Get Scheme Master',
'MOUSchemeAPI',
null,
'EXCEPTION',
e.getMessage() + ' | Line: ' + e.getLineNumber(),
jsonBody,
null
);
}
}


// Method to parse JSON and insert records
private static void processSchemeData(String responseBody) {
try {
// Deserialize JSON response
Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
List<Object> headers = (List<Object>) jsonResponse.get('Header');
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
//scheme.Remarks = (Date) headerMap.get('Remarks'); //--------------------------------Not found fields in saleforce
}
if(headerMap.containskey('MinQty')){
scheme.Min_Qty__c = double.valueOf(headerMap.get('MinQty')); 
}
if(headerMap.containskey('CreditNote')){
scheme.Credit_Note__c = string.valueOf(headerMap.get('CreditNote')); 
} 
if(headerMap.containskey('TotalQtyFlg')){
// scheme.Total_Qty_Flg__c = string.valueOf(headerMap.get('TotalQtyFlg')); 
} 
if(headerMap.containskey('AddCn')){
scheme.Add_On__c =  double.valueOf(headerMap.get('AddCn'));
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
}                    } 
if(headerMap.containskey('IsDeleted')){
//scheme.IsDeleted = (boolean) headerMap.get('IsDeleted');
} 



schemeRequests.add(scheme);

// Extract related items
List<Object> items = (List<Object>) headerMap.get('Item');
schemeMap.put(string.valueOf(headerMap.get('SchemeNo')), items);
}

// Insert Scheme Records in Salesforce with Bulk DML Operation
if (!schemeRequests.isEmpty()) {
insert schemeRequests;
System.debug('Inserted ' + schemeRequests.size() + ' Scheme Requests');

// Insert related Product records in Bulk
for (Scheme_Information__c schi : schemeRequests) {
List<Scheme_Line_Item__c> productItems = new List<Scheme_Line_Item__c>();

if (schemeMap.containsKey(schi.Scheme_Number__c)) {
for (Object itemObj : schemeMap.get(schi.Scheme_Number__c)) {
Map<String, Object> itemMap = (Map<String, Object>) itemObj;

Scheme_Line_Item__c product = new Scheme_Line_Item__c();
if(schi.Id !=null){
product.Scheme_Information__c = schi.Id; // Relate product to scheme
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

// Insert the products in bulk for each Scheme
if (!productItems.isEmpty()) {
insert productItems;
System.debug('Inserted ' + productItems.size() + ' Products for Scheme: ' + schi.Scheme_Number__c);
}
}
}
} else {
System.debug('No Header data found in API response.');
}

} catch (Exception e) {
System.debug('Exception in processing response: ' + e.getMessage()+'At line number'+e.getLineNumber());

}
}

*/
    
    
    //--------------------------for PostCustomerMappingToScheme---------------------------------------------------API-----tested
    //
    @InvocableMethod(label='Post Customer Mapping' description='Posts a single customer mapping to Scheme API')
    public static void postCustomerMappingToSchemeAPI(List<Scheme_Request__c> customerMappingsJson) {
        set<Id> schemeIds = new set<Id>();
        schemeIds.add(customerMappingsJson[0].Id);
        if(schemeIds.size()>0){
            postCustomerMappingSchemeAPI(schemeIds);
        }
    }
    //------------------------------------------------Call below method-------------------------------------------------------------//
    
    @future(callout=true)
    public static void postCustomerMappingSchemeAPI(set<Id> schemerequestIds) {
        
        
        Scheme_Request__c customerMappingsJson;
        if(schemerequestIds.size()>0){
            customerMappingsJson = [SELECT Id,Scheme_applied_By_Parent__c,Customer_Scheme_Id__c,RSM__c,ZSM__c,NSM__c,Customer_Scheme_Id_status__c,Account__c,Approval_Status__c,Customer_SAP_code__c,Scheme_Number__c,Start_Date__c FROM Scheme_Request__c where Id IN:schemerequestIds limit 1];
        }else{
            return;
        }
        
        List<Account> childAccounts = [
            SELECT Id, SAP_Code__c
            FROM Account
            WHERE ParentId = :customerMappingsJson.Account__c
        ];
        List<Scheme_Request__c> schemeToUpdate = new List<Scheme_Request__c>();
        List<Scheme_Request__c> childSchemes = [
            SELECT Id, Customer_SAP_code__c,Customer_Scheme_Id__c,Scheme_applied_By_Parent__c,Customer_Scheme_Id_status__c,Approval_Status__c,RSM__c,ZSM__c,NSM__c,Status__C, Account__c,Scheme_Number__c,Start_Date__c,End_Date__c
            FROM Scheme_Request__c
            WHERE Scheme_Number__c = :customerMappingsJson.Scheme_Number__c And Scheme_applied_By_Parent__c = true and Account__r.parentId =: customerMappingsJson.account__c 
        ];
        
        System.debug('customerMappingsJson: ' + customerMappingsJson);
        List<Map<String,String>> childCustomerList = new List<Map<String,String>>();
        
        for(Scheme_Request__c sr : childSchemes){
            
            if(sr.Customer_SAP_code__c != null){
                
                childCustomerList.add(new Map<String,String>{
                    'ChildCustomerNo' => String.valueOf(sr.Customer_SAP_code__c)
                        });
                
            }
        }
        schemeToUpdate.add(customerMappingsJson);
        schemeToUpdate.addall(childSchemes);
        
        String schemeId = customerMappingsJson.Id;
        
        String customerNo = string.valueof(customerMappingsJson.Customer_SAP_code__c);
        String schemeNo = string.valueof(customerMappingsJson.Scheme_Number__c);
        Date myDateData = customerMappingsJson.Start_Date__c;
        String formattedDateData = myDateData.year() + (myDateData.month() < 10 ? '0' + myDateData.month() : String.valueOf(myDateData.month())) + 
            (myDateData.day() < 10 ? '0' + myDateData.day() : String.valueOf(myDateData.day()));
        
        // Retrieve endpoint URL from Custom Setting
        String endpoint = '';
        MOU_Integration__c mouData = MOU_Integration__c.getInstance('PostCustomerMappingToScheme');
        if (mouData != null) {
            endpoint = mouData.End_Point_URL__c;
        }
        
        // Construct request body
        Map<String, Object> requestBody = new Map<String, Object>();
        // List<Map<String, String>> dataList = new List<Map<String, String>>();
        List<Map<String,Object>> dataList = new List<Map<String,Object>>();
        
        Map<String,Object> parentMap = new Map<String,Object>();
        
        parentMap.put('CustomerNo', customerNo);
        parentMap.put('SchemeNo', schemeNo);
        parentMap.put('StartDate', formattedDateData);
        parentMap.put('ChildCustomer', childCustomerList);
        
        dataList.add(parentMap);
        
        requestBody.put('Mapping', dataList);
        //requestBody.put('Mapping', dataList);
        
        // Convert to JSON
        String requestBodyJson = JSON.serialize(requestBody);
        system.debug('requestBodyJson'+ requestBodyJson);
        
        // Prepare HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setHeader('Content-Type', 'application/json;charset=UTF-8');
        
        // Basic Authentication
        //String username = 'piuser';
        //String password = 'Welcome@123';
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(Blob.valueOf(mouData.Username__c + ':' + mouData.Password__c));
        req.setHeader('Authorization', authorizationHeader);
        req.setTimeout(120000);
        req.setMethod('POST');
        req.setBody(requestBodyJson);
        
        system.debug('req--------->'+req);
        
        // Send HTTP request
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('Status Code ---> ' + res.getStatusCode());
        System.debug('Status ---> ' + res.getStatus());
        System.debug('Response Body ---> ' + res.getBody());
        System.debug('Response Headers ---> ' + res.getHeaderKeys());
        
        
        
        // Check the response status and process the result
        if (res.getStatusCode() == 200) {
            
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            System.debug('Serialize response map ' + JSON.serialize(responseMap));
            
            List<Object> resList = (List<Object>) responseMap.get('Response');
            System.debug('resList Size: ' + resList.size());
            
            for (Object objData : resList) {
                
                Map<String,Object> responseItem = (Map<String,Object>) objData;
                
                System.debug('Status: ' + responseItem.get('Status'));
                System.debug('Message: ' + responseItem.get('Message'));
                System.debug('CustomerSchemeID: ' + responseItem.get('CustomerSchemeID'));
                
                for(Scheme_Request__c reqRec : schemeToUpdate){
                    
                    if (String.isNotBlank(requestBodyJson)) {
                        reqRec.Customer_Sceheme_ID_JSON__c = requestBodyJson;
                    }
                    
                    if (responseItem.containsKey('Status')) {
                        reqRec.Customer_Scheme_Id_status__c = String.valueOf(responseItem.get('Status'));
                    }
                    
                    if (responseItem.containsKey('Message')) {
                        reqRec.Customer_Sceheme_Id_Message__c = String.valueOf(responseItem.get('Message'));
                    }
                    
                    if (responseItem.containsKey('CustomerSchemeID')) {
                        reqRec.Customer_Scheme_Id__c = String.valueOf(responseItem.get('CustomerSchemeID'));
                    }
                    if(reqRec.Scheme_applied_By_Parent__c == true){
                        reqRec.Approval_Status__c = 'Approved';
                        if(reqRec.RSM__c !=null){
                            reqRec.Status__c = 'RSM Approved';
                        }else if(reqRec.ZSM__c != null){
                            reqRec.Status__c = 'ZSM Approved';
                        }else if(reqRec.NSM__c !=null){
                            reqRec.Status__c = 'GM NSM Approved';
                        }
                    }
                    
                }
            }
            
            // 🔹 Update all records in single DML
            if(!schemeToUpdate.isEmpty()){
                update schemeToUpdate;
            }
            
            // 🔹 Queueable call after update
            Boolean hasChildSchemes = childSchemes != null && !childSchemes.isEmpty();
            
            for(Scheme_Request__c schem : schemeToUpdate){
                
               if(schem.Customer_Scheme_Id__c != null && schem.Customer_Scheme_Id_status__c == '1'){
                    
                    if(hasChildSchemes && schem.Id != customerMappingsJson.Id){
                        continue;
                    }
                    
                    Date myDate = schem.Start_Date__c;
                    
                    String formattedDate =
                        myDate.year() +
                        (myDate.month() < 10 ? '0' + myDate.month() : String.valueOf(myDate.month())) +
                        (myDate.day() < 10 ? '0' + myDate.day() : String.valueOf(myDate.day()));
                    
                    System.debug('Formatted Date: ' + formattedDate);
                    
                    System.enqueueJob(new PdfCustomerSchemeQueueable(
                        schem.Customer_Scheme_Id__c,
                        formattedDate,
                        String.valueOf(schem.Account__c),
                        schem.Id,childSchemes
                    ));
                }
            }
        } else {
            // Handle error if status code is not 200
            System.debug('Error: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());
            createApiErrorLog(
                'Post Customer Mapping To Scheme',
                'MOUSchemeAPI',
                res.getStatusCode(),
                res.getStatus(),
                'API returned non-200 status',
                requestBodyJson,
                res.getBody()
            );
        }
    }
    
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
            // log.Sample_Request_Header__c = requestBody;
            log.Response_Body__c = responseBody;
            insert log;
        } catch (Exception e) {
            System.debug('Failed to insert API log: ' + e.getMessage());
        }
    }
    
    
    
    //--------------------------for PDF-----------------API
    // Method to make the HTTP callout
    /*  @future(callout=true)
public static void pdfcustomerschemeAPI(String customerMappingsJson) {

// Deserialize the JSON string back into the object
//  List<Map<String, String>> customerMappings = (List<Map<String, String>>) JSON.deserialize(customerMappingsJson, List<Map<String, String>>.class);
string endpoint='';
MOU_Integration__c mouData = MOU_Integration__c.getInstance('pdfcustomerscheme');
if(mouData!=null) {
endpoint= mouData.End_Point_URL__c;
}


// Create the JSON body for the request
Map<String, Object> requestBody = new Map<String, Object>();
List<Map<String,String>> dataList=new List<Map<String,String>>();
dataList.add(new Map<String,String>{'CustomerSchemeNo'=>'BIO/PBS/-  1/9000000055','StartDate'=>'20250227'});
requestBody.put('Records', dataList);


// Convert the body to JSON format
String requestBodyJson = JSON.serialize(requestBody);
System.debug('requestBodyJson'+requestBodyJson);
// Create a new HTTP request
HttpRequest req = new HttpRequest();
req.setEndpoint(endpoint);
System.debug('Inside1');
req.setHeader('Content-Type', 'application/json;charset=UTF-8');
String username = 'piuser';
String password = 'Welcome@123';
System.debug('Inside2');
Blob headerValue = Blob.valueOf(username + ':' + password);
String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
System.debug('Inside2');
req.setHeader('Authorization', authorizationHeader);
req.setMethod('POST');
System.debug('Inside2');
req.setBody(requestBodyJson);
System.debug('Req'+req);
// Initialize an Http object to send the request
Http http = new Http();
HttpResponse res = http.send(req);

// Check the response status and process the result
if (res.getStatusCode() == 200) {
// Parse the response JSON
Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
System.debug('Response map'+JSON.serialize(responseMap));
List<Map<String, Object>> responseList = (List<Map<String, Object>>) responseMap.get('Response');
for (Map<String, Object> responseItem : responseList) {
System.debug('PDFData: ' + responseItem.get('PDFData'));
System.debug('Status: ' + responseItem.get('Status'));
System.debug('Message: ' + responseItem.get('Message'));

}
} else {
// Handle error if status code is not 200
System.debug('Error: ' + res.getStatusCode());
System.debug('Response Body: ' + res.getBody());
}
}*/
    
}