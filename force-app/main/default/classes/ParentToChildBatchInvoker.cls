public class ParentToChildBatchInvoker {
    
    @InvocableMethod(
        label = 'Run Parent to Child Sync Batch'
        description = 'Executes SAP Parent to Child Sync Batch'
    )
    public static void runBatch(List<FlowInput> inputs) {
        
        if (inputs == null || inputs.isEmpty()) {
            return;
        }
        
        Map<String, List<String>> parentToChildMap = new Map<String, List<String>>();
        Map<String, String> bundleFlagMap = new Map<String, String>();
        
        for (FlowInput input : inputs) {
            
            system.debug('input--->'+input.customerNumber);
            
            if (String.isNotBlank(input.customerNumber)) {
                
                try {
                    
                    MOU_Integration__c mouData =
                        MOU_Integration__c.getInstance('parenttochildsyncingwithoutparam');
                    
                    HttpRequest req = new HttpRequest();
                    req.setEndpoint(mouData.End_Point_URL__c);
                    req.setMethod('GET');
                    req.setTimeout(120000);
                    
                    Blob auth = Blob.valueOf(mouData.Username__c + ':' + mouData.Password__c);
                    req.setHeader('Authorization','Basic '+EncodingUtil.base64Encode(auth));
                    req.setHeader('Accept','application/json');
                    
                    HttpResponse res = new Http().send(req);
                    
                    Map<String, Object> jsonMap =
                        (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    
                    Map<String, Object> dMap =
                        (Map<String, Object>) jsonMap.get('d');
                    
                    List<Object> parentResults =
                        (List<Object>) dMap.get('results');
                    
                    for (Object parentObj : parentResults) {
                        
                        Map<String, Object> parent =
                            (Map<String, Object>) parentObj;
                        
                        String parentCode =
                            (String) parent.get('ParentCustomerNumber');
                        
                        if (String.isBlank(parentCode)) continue;
                        
                        String parentBundle =
                            (String) parent.get('BundleCustomer');
                        
                        bundleFlagMap.put(parentCode, parentBundle);
                        
                        List<String> childCodes = new List<String>();
                        
                        Map<String, Object> childWrapper =
                            (Map<String, Object>) parent.get('to_Children');
                        
                        if (childWrapper != null &&
                            childWrapper.get('results') instanceof List<Object>) {
                                
                                List<Object> childResults =
                                    (List<Object>) childWrapper.get('results');
                                
                                for (Object childObj : childResults) {
                                    
                                    Map<String, Object> child =
                                        (Map<String, Object>) childObj;
                                    
                                    String childCode =
                                        (String) child.get('ChildCustomer');
                                    
                                    if (!String.isBlank(childCode)) {
                                        childCodes.add(childCode);
                                    }
                                    
                                    String childBundle =
                                        (String) child.get('BundleCustomer');
                                    
                                    bundleFlagMap.put(childCode, childBundle);
                                }
                            }
                        
                        if (!childCodes.isEmpty()) {
                            parentToChildMap.put(parentCode, childCodes);
                        }
                    }
                    
                } catch (Exception ex) {
                    System.debug('❌ ERROR MESSAGE: ' + ex.getMessage());
                    System.debug('📍 LINE NUMBER: ' + ex.getLineNumber());
                    System.debug('📦 CLASS NAME: ' + ex.getTypeName());
                    System.debug('🧾 STACK TRACE: ' + ex.getStackTraceString());
                    
                    createApiErrorLog(
                        'MOU scheme',
                        'ParentToChildSyncAPIbatch',
                        500,
                        'DML_EXCEPTION',
                        ex.getMessage(),
                        null,
                        null
                    );
                    
                }
                
                
                // ------------------------------
                // CHUNK LOGIC
                // ------------------------------
                
            
               Integer chunkSize = 100;
                
                List<String> parentKeys = new List<String>(parentToChildMap.keySet());
                
                for (Integer i = 0; i < parentKeys.size(); i += chunkSize) {
                    
                    Integer endIndex = Math.min(i + chunkSize, parentKeys.size());
                    
                    List<String> chunkParents = new List<String>();
                    
                    for(Integer j = i; j < endIndex; j++){
                        chunkParents.add(parentKeys[j]);
                    }
                    
                    Database.executeBatch(
                        new ParentToChildSyncAPIbatch(
                            parentToChildMap,
                            bundleFlagMap,
                            chunkParents
                        ),
                        1
                    );
                }
            }
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
){
    try{

        API_Log__c log = new API_Log__c();
        log.API_Module_Type__c = apiModuleType;
        log.Class_Name__c = className;
        log.Log_Date__c = System.now();
        log.Message__c = message;
        log.request_body__c = requestBody;
        log.Response_Body__c = responseBody;

        insert log;

    }catch(Exception ex){
        System.debug('API Log insert failed: ' + ex.getMessage());
    }
}


public class FlowInput {
    
    @InvocableVariable(
        label = 'Parent Customer Number'
        required = true
    )
    public String customerNumber;
}
}