public with sharing class CustomerLedgerViewController {
    private static final String dateStringFormat = 'dd.MM.yy';


    // public static set<Id> allUserId = new set<Id>();

    @AuraEnabled(Cacheable = true)
    public static Map<String, Object> getAccounts(Integer pageSize, Integer offset, Integer page, String searchTerm){
        // Id userId = UserInfo.getUserId();
         system.debug('BG >>> page : '+page);
         List<Account> accountList = new List<Account>();
        // system.debug('BG >>> pageSize : '+pageSize);
         Integer offset1 = Math.max(0, (page - 1) * pageSize);
        system.debug('BG >>> offset1 : '+offset1);
        system.debug('BG >>> offset : '+offset);
        system.debug('BG >>> pageSize : '+pageSize);
        system.debug('BG >>> searchTerm : '+searchTerm);
        set<Id> allUserId = new set<Id>();
        string sTempSearchKey = '%' + searchTerm + '%';
        Id currentUserRoleId = UserInfo.getUserroleId();
        Set<Id> allSubRoleIds = getAllChildRoleIds(currentUserRoleId);
        system.debug('=allSubRoleIds'+json.serialize(allSubRoleIds));
        for(User uc : [Select Id from User where UserRole.Id IN: allSubRoleIds]){
            allUserId.add(uc.Id);
        }
        allUserId.add(UserInfo.getUserId());
        // allUserId.add(UserInfo.getUserId());
        system.debug('BG >>> allUserId : '+allUserId);
        Integer totalRecords = [SELECT COUNT() FROM Account where SAP_Code__c != null AND Company_Code__c != null ];
        if(totalRecords>offset1) {
        accountList = [SELECT Id, Name, SAP_Code__c,CE_CIS_Rating__c, Phone, Phakic_Rating__c,Company_Code__c FROM Account
                                     where /*ownerId IN: allUserId */
                                     /* AND*/ (SAP_Code__c != null AND Company_Code__c != null)
                                     AND (Name LIKE : sTempSearchKey OR SAP_Code__c LIKE: sTempSearchKey)
                                      ORDER BY Name ASC
                                    LIMIT :pageSize
                                    OFFSET :offset1];
        }
        system.debug('total records : '+totalRecords);

        Map<String, Object> result = new Map<String, Object>();
        result.put('accountList', accountList);
        result.put('totalRecords', totalRecords);
        return result;
    }
    // @AuraEnabled(Cacheable = true)
    // public static List<Account> getSearchAccounts(Date fromDate, Date toDate){
    //     Id userId = UserInfo.getUserId();
    //     List<Account> accList = new List<Account>();
    //     if(toDate != null && fromDate != null){
    //         accList =  [SELECT Id, Name, SAP_Code__c,CE_CIS_Rating__c, Phone, Phakic_Rating__c FROM Account
    //         where ownerId =: userId and createddate >=: fromDate AND createddate <=: toDate ];
    //     }
    //     return accList;
    // }
    @AuraEnabled(Cacheable = true)
    public static List<Account> getSearchAccountsWithText(String searchTerm){
        // Id userId = UserInfo.getUserId();
        set<Id> allUserId = new set<Id>();
        Id currentUserRoleId = UserInfo.getUserroleId();
        Set<Id> allSubRoleIds = getAllChildRoleIds(currentUserRoleId);
        system.debug('=allSubRoleIds'+json.serialize(allSubRoleIds));
        for(User uc : [Select Id from User where UserRole.Id IN: allSubRoleIds and isActive = true]){
            allUserId.add(uc.Id);
        }
        allUserId.add(UserInfo.getUserId());
        List<Account> accList = new List<Account>();
        system.debug('-searchTerm--'+searchTerm);
        if(searchTerm != null){
            string sTempSearchKey = '%' + searchTerm + '%';
            accList =  [SELECT Id, Name, SAP_Code__c,CE_CIS_Rating__c, Phone, Phakic_Rating__c FROM Account
            where /*ownerId IN: allUserId and*/ (Name LIKE : sTempSearchKey OR SAP_Code__c LIKE: sTempSearchKey)
            AND (SAP_Code__c != null AND Company_Code__c != null)];
        }
        system.debug('--acclist--'+accList);
        return accList;
    }
    public static Set<Id> getAllChildRoleIds(Id parentRoleId) {
        Map<Id,List<Id>> parentChildRoleIdMap = queryAllDBRoles();
        Set<Id> allChildRoleSet = doSubRoleSearch(parentChildRoleIdMap, new Set<Id>{parentRoleId}, new Set<Id>());
        return allChildRoleSet;
    }
    public static Set<Id> doSubRoleSearch(Map<Id,List<Id>> parentChildRoleIdMap, Set<Id> parentRoleIdSet, Set<Id> cumulativeRoleIdSet) {
        Set<Id> queryMoreSet = new Set<Id>();
        for(Id pRoleId:parentRoleIdSet) {
            queryMoreSet = new Set<Id>();
            if(!parentChildRoleIdMap.containsKey(pRoleId)) {
                continue;
            }
            for(Id cRoleId:parentChildRoleIdMap.get(pRoleId)) {
                cumulativeRoleIdSet.add(cRoleId);
                queryMoreSet.add(cRoleId);
            }
        }
        if(!queryMoreSet.isEmpty()) {
            doSubRoleSearch(parentChildRoleIdMap, queryMoreSet, cumulativeRoleIdSet);
        }
        return cumulativeRoleIdSet;
    }
    public static Map<Id,List<Id>> queryAllDBRoles() {
        Map<Id,List<Id>> parentChildRoleIdMap = new Map<Id,List<Id>>();
        for(UserRole uRole:[SELECT Id,ParentRoleId FROM UserRole]) {
            if(uRole.ParentRoleId == NULL) {
                continue;
            }
            if(parentChildRoleIdMap.containsKey(uRole.ParentRoleId)) {
                List<Id> tempIdList = new List<Id>();
                tempIdList.addAll(parentChildRoleIdMap.get(uRole.ParentRoleId));
                tempIdList.add(uRole.Id);
                parentChildRoleIdMap.put(uRole.ParentRoleId, tempIdList);
            }else {
                parentChildRoleIdMap.put(uRole.ParentRoleId, new List<Id>{uRole.Id});
            }
        }
        return parentChildRoleIdMap;
    }

    public class CustomerData{
        @AuraEnabled public Integer Status { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String PDFData { get; set; }
    }

    public class CustomerDetails{
        public String Customer;
        public String PostingDateFrom;
        public String PostingDateTo;
        public String CompanyCode;
        public String IsRegularCustomer;
        public String IsEquipmentCustomer;
        public String AdditionalField1;
        public String AdditionalField2;
        public String AdditionalField3;
        public String AdditionalField4;
        public String AdditionalField5;
    }

    @AuraEnabled(cacheable=true)
    public static List<CustomerData> getBase64String(List<Map<String,Object>> selectedData){
        try {
        List<CustomerDetails> customerRecord = new List<CustomerDetails>();
        system.debug('--selectedData--'+JSON.serialize(selectedData));
        for (Map<String,Object> customer : selectedData) {
            CustomerDetails currentCustomer = new CustomerDetails();
                currentCustomer.Customer=(String)customer.get('sapcode');
                currentCustomer.PostingDateFrom=formatDate((String)customer.get('fromDate'));
                currentCustomer.PostingDateTo=formatDate((String)customer.get('toDate'));
                currentCustomer.CompanyCode=(String)customer.get('companycode');
                currentCustomer.IsRegularCustomer=customer.get('Category')=='Normal'?'X':'';
                currentCustomer.IsEquipmentCustomer=customer.get('Category')=='Equipment'?'X':'';
            customerRecord.add(currentCustomer);
        }

        List<CustomerData> customerDataList = new List<CustomerData>();

        SAP_Creds__c sapCreds = SAP_Creds__c.getValues('SAP_LedgerPDFData');

        // //generateInvoicePDF callout request creation ---------------

        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        Http http = new Http();

        // Set the endpoint URL
        String endpoint = sapCreds.Endpoint__c;
        req.setEndpoint(endpoint);
        req.setMethod('GET');

        // Encode the Basic Authentication credentials
        String username = sapCreds.Username__c;
        String password =  sapCreds.Password__c;
        Blob headerValue = Blob.valueOf(username + ':' + password);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        req.setHeader('Authorization', authorizationHeader);

        req.setHeader('Content-Type', 'application/json');

        // Define your JSON payload
        // String bodyStr = '{"Records":[{"PostingDateTo":"01.05.2024","PostingDateFrom":"01.03.2023","IsRegularCustomer":"","IsEquipmentCustomer":"","Customer":"1200021","CompanyCode":"1000","AdditionalField5":"","AdditionalField4":"","AdditionalField3":"","AdditionalField2":"","AdditionalField1":""},{"PostingDateTo":"01.05.2024","PostingDateFrom":"01.03.2023","IsRegularCustomer":"","IsEquipmentCustomer":"","Customer":"1200022","CompanyCode":"1000","AdditionalField5":"","AdditionalField4":"","AdditionalField3":"","AdditionalField2":"","AdditionalField1":""}]}';
        String bodyStr = '{"Records": '+JSON.serialize(customerRecord)+'}';

        // Set the request body
        req.setBody(bodyStr);

        // Calculate and set the Content-Length header
        req.setHeader('Content-Length', String.valueOf(Blob.valueOf(bodyStr).size()));

        // Set a longer timeout (in milliseconds)
        req.setTimeout(60000); // 60 seconds

        // Debugging information (remove in production)
        system.debug('BG >>> req : ' + req.getHeader('Authorization'));
        system.debug('BG >>> req : ' + req.getHeader('Content-Type'));
        system.debug('BG >>> req : ' + req.getHeader('Content-Length'));
        system.debug('BG >>> req : ' + req.getEndpoint());
        system.debug('BG >>> req : ' + String.valueOf(req));
        system.debug('BG >>> req : ' + req.getBody());
            //generateInvoicePDF callout ---- Send the request---------------

            res = http.send(req);

            // Debugging the response (remove in production)
            system.debug('BG >>> res : ' + res.getBody());

            //generateInvoicePDF callout response ---------------

            String responseString = res.getBody();
            system.debug('BG >>> responseString : ' +responseString);
            if(res.getStatusCode()==200){
                //initializing the invoice Map with Invoice Wrapper class instance
                Map<String, List<CustomerData>> cdataMap = (Map<String, List<CustomerData>>)JSON.deserialize(responseString, Map<String, List<CustomerLedgerViewController.CustomerData>>.class);

                for(CustomerData cData : cdataMap.get('Record')){
                    customerDataList.add(cData);
                    // cData.Status = cdataMap.get('Record').Status;
                    // cData.message = cdataMap.get('Record').message;
                    // cData.PDFData = cdataMap.get('Record').PDFData;
                }

            }else{
                Map<String,Map<String,String>> cDataMap = (Map<String,Map<String,String>>)JSON.deserialize(responseString,Map<String,Map<String,String>>.class);
                CustomerData cData = new CustomerData();
                cData.Status = Integer.valueOf(cDataMap.get('error').get('code'));
                cData.message = cDataMap.get('error').get('message');
                customerDataList.add(cData);
            }
            // System.debug('Status Code: ' + invoice.status_Code);
            // System.debug('Message: ' + invoice.message);
            // System.debug('Base64: ' + invoice.base64);

            //returning the Invoice wrapper class instance from invoice Map
            return customerDataList;

        } catch (Exception e) {
            System.debug(e);
            throw e;
        }
    }
    public static String formatDate(String dateValue) {
        if (dateValue == NULL) return NULL;
        List<String> dateParts = dateValue.split('-');
        return dateParts[2]+'.'+dateParts[1]+'.'+dateParts[0];
    }
}