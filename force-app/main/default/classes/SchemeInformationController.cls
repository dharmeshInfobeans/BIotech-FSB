public without sharing class SchemeInformationController {
    
    @AuraEnabled(cacheable =true)
    public static Map<String, Object> getInitialData(String schemeId) {
        system.debug('schemeId ' + schemeId);
        Map<String, Object> finalResult = new Map<String, Object>();
        List<Object> schemeDataList = new List<Object>();
        
        try {
            Account account = [SELECT Id, Name, BillingCountry,SAP_Code__c FROM Account WHERE Id = :schemeId LIMIT 1];
            // ---------------- SAP API CALL ----------------
            // SAP response JSON string
            /*   String sapResponse = getParentCustomer(account.SAP_Code__c);

List<Map<String, Object>> childCustomerList = new List<Map<String, Object>>();

if (!String.isBlank(sapResponse)) {

Map<String, Object> rootMap =
(Map<String, Object>) JSON.deserializeUntyped(sapResponse);

// Step 1: get "d"
if (rootMap.containsKey('d')) {
Map<String, Object> dMap =
(Map<String, Object>) rootMap.get('d');

// Step 2: get "to_Children"
if (dMap.containsKey('to_Children')) {
Map<String, Object> childWrapper =
(Map<String, Object>) dMap.get('to_Children');

// Step 3: get "results"
if (childWrapper.containsKey('results')) {
List<Object> results =
(List<Object>) childWrapper.get('results');

for (Object obj : results) {
Map<String, Object> child =  (Map<String, Object>) obj;

String parentNum = String.valueOf(child.get('parentnum'));
parentNum = parentNum.replaceFirst('^0+', '');

childCustomerList.add(new Map<String, Object>{
'childCustomer' => child.get('ChildCustomer'),
'childCustomerName' => child.get('ChildcustomerName'),
'parentNumber' => parentNum
});
}
}
}
}
}

// Final result
finalResult.put('sapChildCustomers', childCustomerList);*/
            
            list<Scheme_Request__c> sampleRequest = [SELECT Id, Name, Account__c,Scheme_Name__c, Account__r.Name, Scheme_Number__c, Start_Date__c, End_Date__c, Valid_Upto__c 
                                                     FROM Scheme_Request__c 
                                                     WHERE Account__c = :account.Id 
                                                     AND Start_Date__c != null 
                                                     AND Valid_Upto__c >= TODAY 
                                                     LIMIT 1];
            
            if (sampleRequest.size()>0) {
                System.debug('No active scheme requests found.');
                finalResult.put('sampleRequestList',sampleRequest[0]);
                
            } else {
                finalResult.put('sampleRequestList',null);
                
                
            }
            
            //system.debug('sampleRequestList'+sampleRequestList);
            
            if(String.isNotBlank(account.BillingCountry) ){
                for (Scheme_Information__c scheme : [
                    SELECT Id, Name, Scheme_Desc__c, Account__c, Tenure__c, Pay_Terms__c, TOT_Business__c, 
                    PUR_Unit_Comm__c, Min_Qty__c, Credit_Note__c, Total_Qty_Flg__c, 
                    Credit_Percentage__c, Add_On__c, Total_Amount__c, Valid_Upto__c, 
                    Scheme_Number__c, Is_Deleted__c, Country__c,Type__c,
                    (
                        SELECT Id, Name, Scheme_Information__c, Scheme_No__c, Product_Code__c, 
                        Product_Description__c, Min_Qty__c, Reg_Price__c, 
                        Credit_Note__c, Net_Price__c, Credit_Percentage__c, 
                        CR_Note_PL_GST__c, Add_On__c, Benifit__c, Is_Deleted__c
                        FROM Scheme_Line_Items__r
                    )
                    FROM Scheme_Information__c
                    WHERE Valid_Upto__c >= TODAY  AND Country__c = :account.BillingCountry Order By Name ASC]) {
                        schemeDataList.add(new Map<String, Object>{
                            'Add_On__c' => scheme.Add_On__c,
                                'Account__c' => scheme.Account__c,
                                'Country__c' => scheme.Country__c,
                                'Credit_Note__c' => scheme.Credit_Note__c,
                                'Credit_Percentage__c' => scheme.Credit_Percentage__c,
                                'Id' => scheme.Id,
                                'Tenure__c' => scheme.Tenure__c,
                                'TOT_Business__c' => scheme.TOT_Business__c,
                                'Total_Qty_Flg__c' => scheme.Total_Qty_Flg__c,
                                'Total_Amount__c' => scheme.Total_Amount__c,
                                'Valid_Upto__c' => scheme.Valid_Upto__c,
                                'Scheme_Number__c' => scheme.Scheme_Number__c,
                                'Is_Deleted__c' => scheme.Is_Deleted__c,
                                'Min_Qty__c' => scheme.Min_Qty__c,
                                'Name' => scheme.Name,
                                'PUR_Unit_Comm__c' => scheme.PUR_Unit_Comm__c,
                                'Pay_Terms__c' => scheme.Pay_Terms__c,
                                'Scheme_Desc__c' => scheme.Scheme_Desc__c,
                                'Type__c'=>scheme.Type__c,
                                'Scheme_Line_Items__r' => scheme.Scheme_Line_Items__r,
                                'selectedId' => false
                                });
                    }
            }
            /*if(account.RSM__c == null){
finalResult.put('rsm', 'NA');
}else{
finalResult.put('rsm', string.valueOf(account.RSM__c));
}if(account.ZSM__c == null){
finalResult.put('zsm', 'NA');
}else{
finalResult.put('zsm', string.valueOf(account.ZSM__c));
}if(account.Admin__c == null){
finalResult.put('admin', 'NA');
}else{
finalResult.put('admin', string.valueOf(account.Admin__c));
}*/
            finalResult.put('schemeData', schemeDataList);
            
            
            finalResult.put('selectedId', false);
            
            if( account != null && String.isNotBlank(account.BillingCountry) ){
                
                String countryKey = account.BillingCountry.trim().toUpperCase();
                
                MOU_Scheme_Back_Date_Provision_Setting__c mouData =
                    MOU_Scheme_Back_Date_Provision_Setting__c.getInstance(countryKey);
                finalResult.put('country', account.BillingCountry);
                if (mouData != null && mouData.Number_Of_Months__c != null) {
                    finalResult.put('backmonthenumber', mouData.Number_Of_Months__c);
                } else {
                    finalResult.put('backmonthenumber', 0);
                }
                
            }else{
                finalResult.put('country', 'Not available');
            }
            
            
        } catch (Exception e) {
            System.debug('Error on line ' + e.getLineNumber() + ': ' + e.getMessage());
            finalResult.put('error', 'Error on line ' + e.getLineNumber() + ': ' + e.getMessage());
            
        }
        
        system.debug(finalResult.size());
        return finalResult;
    }
    
    @AuraEnabled
    public static string createSchemeRequestAndLineItems(List<Object> jsonObj, List<Object> accountdata, List<String> accIds) {
        system.debug('Data:----> ' + JSON.serialize(jsonObj));
        system.debug('accountdata: ' + JSON.serialize(accountdata));
        system.debug('accIds: ' + accIds);
        string res ='';
        List<String> acidslist = new List<String>();
        date startdate;
        date enddate;
        list<Account> acountlist = new list<Account>();
        try{
            if (accIds != null) {
                acidslist.addAll(accIds);
            }
            
            if (accountdata != null) {
                
                for (Object accdata : accountdata) {
                    
                    try {
                        Map<object, Object> accdatamap = (Map<object, Object>) accdata;
                        
                        
                        
                        if (accdatamap.containsKey('Id')) {
                            acidslist.add(String.valueOf(accdatamap.get('Id')));
                        }
                        
                        // Fixing Start_Date__c conversion
                        if (accdatamap.containsKey('Start_Date__c') && accdatamap.get('Start_Date__c') != null) {
                            String startDateStr = String.valueOf(accdatamap.get('Start_Date__c'));
                            startdate = Date.valueOf(startDateStr); // Safe conversion since it's in YYYY-MM-DD format
                        }
                        
                        // Fixing End_Date__c conversion
                        if (accdatamap.containsKey('End_Date__c') && accdatamap.get('End_Date__c') != null) {
                            String endDateStr = String.valueOf(accdatamap.get('End_Date__c'));
                            enddate = Date.valueOf(endDateStr); // Safe conversion
                        }
                        
                    } catch (Exception e) {
                        System.debug('Error processing accountdata: ' + e.getMessage());
                    }
                }
            }
            
            
            if (acidslist.isEmpty()) {
                return 'No Accounts Found';
            }
            
            List<Account> accountlist = [
                SELECT Id, Name, ParentId, Parent.Name, BillingCountry
                FROM Account
                WHERE Id IN :acidslist
            ];
            
            Map<Id, Id> childParentMap = new Map<Id, Id>();
            Set<Id> accountIdSet = new Set<Id>();
            
            for(Account acc : accountlist){
                if(acc.ParentId != null){
                    childParentMap.put(acc.Id, acc.ParentId);
                }
                accountIdSet.add(acc.id);
            }
            
            List<Scheme_Request__c> schemeRequestList = new List<Scheme_Request__c>();
            List<Scheme_Request_Line_Item__c> lineItemList = new List<Scheme_Request_Line_Item__c>();
            
            Map<String, String> schemeRequestIdMap = new Map<String, String>();
            
            for (Account acc : accountlist) {
                for (Object obj : jsonObj) {
                    Map<object, Object> objMap = (Map<object, Object>) obj;
                    
                    Scheme_Request__c schem = new Scheme_Request__c();
                    acc.Scheme_Start_Date__c = startdate;
                    acc.Scheme_End_Date__c = enddate;
                    
                    schem.Start_Date__c = startdate;
                    schem.End_Date__c = enddate;
                    schem.Account__c = acc.Id;
                    
                    if(childParentMap.containsKey(acc.Id) && accountIdSet.contains(childParentMap.get(acc.Id)))
                    {
                        schem.Scheme_applied_By_Parent__c = true;
                    }
                    
                    if (String.valueOf(objMap.get('Add_On__c')) != null && String.valueOf(objMap.get('Add_On__c')) != 'undefined') {
                        schem.Add_On__c = Integer.valueOf(String.valueOf(objMap.get('Add_On__c')));
                    }
                    
                    if (String.valueOf(objMap.get('Country__c')) != null && String.valueOf(objMap.get('Country__c')) != 'undefined') {
                        schem.Country__c = String.valueOf(objMap.get('Country__c')).toUpperCase();
                    }
                    
                    if (String.valueOf(objMap.get('Credit_Note__c')) != null && String.valueOf(objMap.get('Credit_Note__c')) != 'undefined') {
                        schem.Credit_Note__c = String.valueOf(objMap.get('Credit_Note__c'));
                    }
                    
                    if (String.valueOf(objMap.get('Credit_Percentage__c')) != null && String.valueOf(objMap.get('Credit_Percentage__c')) != 'undefined') {
                        schem.Credit_Percentage__c = Double.valueOf(String.valueOf(objMap.get('Credit_Percentage__c')));
                    }
                    
                    if (String.valueOf(objMap.get('Is_Deleted__c')) != null && String.valueOf(objMap.get('Is_Deleted__c')) != 'undefined') {
                        schem.Is_Deleted__c = Boolean.valueOf(String.valueOf(objMap.get('Is_Deleted__c')));
                    }
                    
                    if (String.valueOf(objMap.get('Min_Qty__c')) != null && String.valueOf(objMap.get('Min_Qty__c')) != 'undefined') {
                        schem.Min_Qty__c = Integer.valueOf(String.valueOf(objMap.get('Min_Qty__c')));
                    }
                    
                    if (String.valueOf(objMap.get('Pay_Terms__c')) != null && String.valueOf(objMap.get('Pay_Terms__c')) != 'undefined') {
                        schem.Pay_Terms__c = String.valueOf(objMap.get('Pay_Terms__c'));
                    }
                    
                    if (String.valueOf(objMap.get('PUR_Unit_Comm__c')) != null && String.valueOf(objMap.get('PUR_Unit_Comm__c')) != 'undefined') {
                        schem.PUR_Unit_Comm__c = String.valueOf(objMap.get('PUR_Unit_Comm__c'));
                    }
                    
                    if (String.valueOf(objMap.get('Scheme_Desc__c')) != null && String.valueOf(objMap.get('Scheme_Desc__c')) != 'undefined') {
                        schem.Scheme_Description__c = String.valueOf(objMap.get('Scheme_Desc__c'));
                        acc.Scheme_Description__c = String.valueOf(objMap.get('Scheme_Desc__c'));
                    }
                    
                    if (String.valueOf(objMap.get('Scheme_Number__c')) != null && String.valueOf(objMap.get('Scheme_Number__c')) != 'undefined') {
                        schem.Scheme_Number__c = string.valueOf(String.valueOf(objMap.get('Scheme_Number__c')));
                        acc.Scheme_Number__c = string.valueOf(String.valueOf(objMap.get('Scheme_Number__c')));
                    }
                    if (String.valueOf(objMap.get('Name')) != null && String.valueOf(objMap.get('Name')) != 'undefined') {
                        schem.Scheme_Name__c = string.valueOf(String.valueOf(objMap.get('Name')));
                        // acc.Scheme_Name__c = string.valueOf(String.valueOf(objMap.get('Scheme_Name__c')));
                    }
                    
                    
                    if (String.valueOf(objMap.get('Tenure__c')) != null && String.valueOf(objMap.get('Tenure__c')) != 'undefined') {
                        schem.Tenure__c = String.valueOf(objMap.get('Tenure__c'));
                    }
                    
                    if (String.valueOf(objMap.get('TOT_Business__c')) != null && String.valueOf(objMap.get('TOT_Business__c')) != 'undefined') {
                        schem.TOT_Business__c = String.valueOf(objMap.get('TOT_Business__c'));
                    }
                    
                    if (String.valueOf(objMap.get('Total_Amount__c')) != null && String.valueOf(objMap.get('Total_Amount__c')) != 'undefined') {
                        schem.Total_Amount__c = Integer.valueOf(String.valueOf(objMap.get('Total_Amount__c')));
                    }
                    
                    if (String.valueOf(objMap.get('Total_Qty_Flg__c')) != null && String.valueOf(objMap.get('Total_Qty_Flg__c')) != 'undefined') {
                        schem.Total_Qty_Flg__c = String.valueOf(objMap.get('Total_Qty_Flg__c'));
                    }
                    
                    if (String.valueOf(objMap.get('Valid_Upto__c')) != null && String.valueOf(objMap.get('Valid_Upto__c')) != 'undefined') {
                        schem.Valid_Upto__c = Date.valueOf(String.valueOf(objMap.get('Valid_Upto__c')));
                    }
                    
                    
                    // Add Scheme_Request__c to the list
                    acountlist.add(acc);
                    schemeRequestList.add(schem);
                }
            }
            
            
            if(acountlist.size()>0){
                update acountlist;
            }
            if (!schemeRequestList.isEmpty()) {
                insert schemeRequestList;
                
                for (Scheme_Request__c req : schemeRequestList) {
                    schemeRequestIdMap.put(req.Scheme_Number__c, req.Id);
                }
            }
            
            // Process the JSON data again to create Scheme_Request_Line_Item__c records
            for (Object obj : jsonObj) {
                Map<Object, Object> objMap = (Map<Object, Object>)obj;
                string key = string.valueOf(objMap.get('Scheme_Number__c'));
                if (schemeRequestIdMap.containsKey(key)) {
                    // Handle Scheme_Request_Line_Item__c creation
                    List<Object> objList = (List<Object>)objMap.get('Scheme_Line_Items__r');
                    if (objList != null) {
                        for (Object schLine : objList) {
                            Scheme_Request_Line_Item__c schemItem = new Scheme_Request_Line_Item__c();
                            Map<Object, Object> objDataMap = (Map<Object, Object>)schLine;
                            if(schemeRequestIdMap.containsKey(string.valueOf((objDataMap.get('Scheme_No__c'))))){  
                                
                                
                                /*  if (String.valueOf(objDataMap.get('Name')) != null && String.valueOf(objDataMap.get('Name')) != 'undefined') {
schemItem.Name = String.valueOf(objDataMap.get('Name'));*/
                            }
                            
                            if (objDataMap.get('Scheme_No__c') != null && objDataMap.get('Scheme_No__c') != 'undefined') {
                                schemItem.Scheme_Request__c = schemeRequestIdMap.get(string.valueOf(String.valueOf(objDataMap.get('Scheme_No__c'))));
                            }
                            
                            if (String.valueOf(objDataMap.get('Add_On__c')) != null && String.valueOf(objDataMap.get('Add_On__c')) != 'undefined') {
                                schemItem.Add_On__c = Integer.valueOf(String.valueOf(objDataMap.get('Add_On__c')));
                            }
                            
                            if (String.valueOf(objDataMap.get('Benifit__c')) != null && String.valueOf(objDataMap.get('Benifit__c')) != 'undefined') {
                                schemItem.Benifit__c = String.valueOf(objDataMap.get('Benifit__c'));
                            }
                            
                            if (String.valueOf(objDataMap.get('CR_Note_PL_GST__c')) != null && String.valueOf(objDataMap.get('CR_Note_PL_GST__c')) != 'undefined') {
                                schemItem.CR_Note_PL_GST__c = String.valueOf(objDataMap.get('CR_Note_PL_GST__c'));
                            }
                            
                            if (String.valueOf(objDataMap.get('Credit_Note__c')) != null && String.valueOf(objDataMap.get('Credit_Note__c')) != 'undefined') {
                                schemItem.Credit_Note__c = String.valueOf(objDataMap.get('Credit_Note__c'));
                            }
                            
                            if (String.valueOf(objDataMap.get('Credit_Percentage__c')) != null && String.valueOf(objDataMap.get('Credit_Percentage__c')) != 'undefined') {
                                schemItem.Credit_Percentage__c = Integer.valueOf(String.valueOf(objDataMap.get('Credit_Percentage__c')));
                            }
                            
                            if (String.valueOf(objDataMap.get('Is_Deleted__c')) != null && String.valueOf(objDataMap.get('Is_Deleted__c')) != 'undefined') {
                                schemItem.Is_Deleted__c = Boolean.valueOf(String.valueOf(objDataMap.get('Is_Deleted__c')));
                            }
                            
                            if (String.valueOf(objDataMap.get('Min_Qty__c')) != null && String.valueOf(objDataMap.get('Min_Qty__c')) != 'undefined') {
                                schemItem.Min_Qty__c = Integer.valueOf(String.valueOf(objDataMap.get('Min_Qty__c')));
                            }
                            
                            if (String.valueOf(objDataMap.get('Net_Price__c')) != null && String.valueOf(objDataMap.get('Net_Price__c')) != 'undefined') {
                                schemItem.Net_Price__c = Integer.valueOf(String.valueOf(objDataMap.get('Net_Price__c')));
                            }
                            
                            if (String.valueOf(objDataMap.get('Product_Code__c')) != null && String.valueOf(objDataMap.get('Product_Code__c')) != 'undefined') {
                                schemItem.Product_Code__c = String.valueOf(objDataMap.get('Product_Code__c'));
                            }
                            
                            if (String.valueOf(objDataMap.get('Product_Description__c')) != null && String.valueOf(objDataMap.get('Product_Description__c')) != 'undefined') {
                                schemItem.Product_Description__c = String.valueOf(objDataMap.get('Product_Description__c'));
                            }
                            
                            if (String.valueOf(objDataMap.get('Reg_Price__c')) != null && String.valueOf(objDataMap.get('Reg_Price__c')) != 'undefined') {
                                schemItem.Reg_Price__c = Integer.valueOf(String.valueOf(objDataMap.get('Reg_Price__c')));
                            }
                            
                            if (String.valueOf(objDataMap.get('Scheme_No__c')) != null && String.valueOf(objDataMap.get('Scheme_No__c')) != 'undefined') {
                                schemItem.Scheme_No__c = string.valueOf(String.valueOf(objDataMap.get('Scheme_No__c')));
                            }
                            
                            // Add Scheme_Request_Line_Item__c to the list
                            lineItemList.add(schemItem);
                        }
                    }
                }
            }
            
            
            // Insert Scheme_Request_Line_Item__c records
            if (!lineItemList.isEmpty()) {
                insert lineItemList;
                res ='success';
                system.debug('lineItemList---->'+lineItemList);
            }
            system.debug('res --------'+res + '           '+ lineItemList.isEmpty() );
            return res;
        }catch(exception e){
            
            system.debug(e.getmessage()+'       '+ e.getlineNumber());
            res= 'fail';
            system.debug('res --------'+res + '           '+ e.getmessage());
        }
        return res;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Object>> getAccountWithChildren(Id accountId, String selectedSchemeNumber) {
        
        Map<String, List<Object>> returnMap = new Map<String, List<Object>>();
        
        List<Account> parentAccountList = new List<Account>();
        List<Account> childRecordList   = new List<Account>();
        
        Set<String> childSapCodeSet     = new Set<String>();
        Set<String> parentSAPCodeSet    = new Set<String>();
        
        String bundleCustomer = '';
        
        
        if (accountId == null) {
            return returnMap;
        }
        
        // ✅ 1. Fetch Current Account
        List<Account> currentAcc = [
            SELECT Id, Name, SAP_Code__c, ParentId
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        
        if (currentAcc[0].SAP_Code__c == null) {
            return returnMap;
        }
        
        // ✅ 2. Decide Parent Account
        Account parentAcc;
        
        // ✅ Case-1: Account is Child
        if (currentAcc[0].ParentId != null) {
            
            parentAcc = [
                SELECT Id, Name, SAP_Code__c
                FROM Account
                WHERE Id = :currentAcc[0].ParentId
                LIMIT 1
            ];
            
            parentAccountList.add(parentAcc);
            
        }
        // ✅ Case-2: Account is Parent
        else {
            parentAcc = currentAcc[0];
            parentAccountList.add(currentAcc[0]);
        }
        
        // ✅ Parent SAP Store
        parentSAPCodeSet.add(parentAcc.SAP_Code__c);
        
        // ✅ 3. Call SAP API with Parent SAP Code
        String sapResponse = getParentCustomer(currentAcc[0].SAP_Code__c);
        
        system.debug('sapResponse--->'+sapResponse);
        
        if (!String.isBlank(sapResponse)) {
            
            Map<String, Object> rootMap =
                (Map<String, Object>) JSON.deserializeUntyped(sapResponse);
            
            if (rootMap.containsKey('d')) {
                
                Map<String, Object> dMap =
                    (Map<String, Object>) rootMap.get('d');
                
                if (dMap.containsKey('BundleCustomer')) {
                    bundleCustomer = String.valueOf(dMap.get('BundleCustomer'));
                }
                
                
                // ✅ Extract Children from SAP
                if (dMap.containsKey('to_Children')) {
                    
                    Map<String, Object> childWrapper =
                        (Map<String, Object>) dMap.get('to_Children');
                    
                    List<Object> results =
                        (List<Object>) childWrapper.get('results');
                    
                    for (Object obj : results) {
                        
                        Map<String, Object> childMap =
                            (Map<String, Object>) obj;
                        
                        if (childMap.containsKey('ChildCustomer')) {
                            
                            childSapCodeSet.add(
                                String.valueOf(childMap.get('ChildCustomer'))
                            );
                        }
                    }
                }
            }
        }
        
        // ✅ 4. Fetch Child Accounts from Salesforce
        if (!childSapCodeSet.isEmpty()) {
            
            childRecordList = [
                SELECT Id, Name,
                Phone, BillingPostalCode, BillingCity, BillingState, E_Mail__c, CE_CIS_Rating__c, 
                Phakic_Rating__c, SAP_Code__c, Parent.Name, Parent.SAP_Code__c, 
                ParentId
                FROM Account
                WHERE SAP_Code__c IN :childSapCodeSet
                AND ParentId = :parentAcc.Id AND Customer_Type__c = 'Non-Bundle' ORDER BY SAP_Code__c ASC
            ];
        }
        
        // ✅ 5. Collect Accounts for Scheme Query
        List<Id> accountIdsForScheme = new List<Id>();
        
        // ✅ Parent always
        accountIdsForScheme.add(parentAcc.Id);
        
        // ✅ If current is Child → include itself also
        if (currentAcc[0].ParentId != null) {
            accountIdsForScheme.add(currentAcc[0].Id);
        }
        
        // ✅ Include all Child Accounts from SAP
        for (Account ch : childRecordList) {
            accountIdsForScheme.add(ch.Id);
        }
        
        // ✅ 6. Fetch Approved Schemes (Dynamic Query)
        
        String baseQuery =
            'SELECT Id, Account__c, Account__r.ParentId,' +
            ' Account_Name__c, Customer_SAP_code__c,' +
            ' Scheme_Number__c,Scheme_Name__c,Scheme_Description__c, Start_Date__c, End_Date__c,' +
            ' Approval_Status__c' +
            ' FROM Scheme_Request__c' +
            ' WHERE Account__c IN :accountIdsForScheme';
        
        // ✅ Add Approval Status dynamically
        String approvalStatus = 'Approved';
        baseQuery += ' AND Approval_Status__c = :approvalStatus';
        
        // ✅ Add Date condition dynamically
        Date todayDate = System.today();
        baseQuery += ' AND End_Date__c >= :todayDate';
        
        // ✅ Execute Dynamic Query
        List<Scheme_Request__c> schemeList =
            Database.query(baseQuery);
        
        // NEW LOGIC: Find child accounts with SAME scheme
        Set<Id> childAccountsWithSameScheme = new Set<Id>();
        system.debug('==== START SCHEME FILTER LOGIC ====');
        System.debug('Selected Scheme Number: ' + selectedSchemeNumber);
        System.debug('Total Scheme Records: ' + schemeList.size());
        
        
        if (String.isNotBlank(selectedSchemeNumber)) {
            for (Scheme_Request__c sc : schemeList) {
                System.debug('Checking Scheme Record -> '
                             + 'AccountId: ' + sc.Account__c 
                             + ' | Scheme No: ' + sc.Scheme_Number__c);
                if (sc.Scheme_Number__c == selectedSchemeNumber 
                    && sc.Account__c != parentAcc.Id) {
                        System.debug('MATCH FOUND (Child already has scheme) -> ' + sc.Account__c);
                        childAccountsWithSameScheme.add(sc.Account__c);
                    }
            }
        }
        
        System.debug('Child Accounts with SAME Scheme: ' + childAccountsWithSameScheme);
        System.debug('Count of matched child accounts: ' + childAccountsWithSameScheme.size());
        
        
        // FILTER CHILD ACCOUNTS
        System.debug('==== BEFORE FILTERING CHILD LIST ====');
        System.debug('Total Child Accounts: ' + childRecordList.size());
        System.debug('Child List: ' + childRecordList);
        
        // FILTER CHILD ACCOUNTS
        List<Account> filteredChildList = new List<Account>();
        
        for (Account acc : childRecordList) {
            System.debug('Checking Child -> Id: ' + acc.Id + ' | Name: ' + acc.Name);
            if (!childAccountsWithSameScheme.contains(acc.Id)) {
                System.debug('INCLUDED (No scheme applied)');
                filteredChildList.add(acc);
            }else {
                
                System.debug('EXCLUDED (Scheme already applied)');
            }
        }
        System.debug('==== AFTER FILTERING ====');
        System.debug('Filtered Child Count: ' + filteredChildList.size());
        System.debug('Filtered Child List: ' + filteredChildList);
        
        childRecordList = filteredChildList;
        
        
        
        // ✅ 7. Separate Parent vs Child Schemes
        List<Scheme_Request__c> parentSchemes = new List<Scheme_Request__c>();
        List<Scheme_Request__c> childSchemes  = new List<Scheme_Request__c>();
        
        for (Scheme_Request__c sc : schemeList) {
            
            if (sc.Account__c == parentAcc.Id) {
                parentSchemes.add(sc);
            } else if(sc.Account__c == currentAcc[0].Id || parentAcc.Id == accountId) {
                childSchemes.add(sc);
            }
        }
        
        // ✅ 8. Final Response Map
        returnMap.put('parentAccountlist', currentAcc);
        returnMap.put('BundleCustomer', new List<Object>{bundleCustomer});
        returnMap.put('childrecordlist', childRecordList);
        returnMap.put('schemelistforparent', parentSchemes);
        returnMap.put('schemelistforchild', childSchemes);
        
        return returnMap;
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Object>> getParentAndChildSchemes(Id accountId) {
        
        Map<String, List<Object>> resultMap = new Map<String, List<Object>>();
        
        List<Object> parentSchemes = new List<Object>();
        List<Object> childSchemes  = new List<Object>();
        
        if(accountId == null){
            resultMap.put('parentSchemes', parentSchemes);
            resultMap.put('childSchemes', childSchemes);
            return resultMap;
        }
        
        // ✅ Step 1: Current Account
        Account currentAcc = [
            SELECT Id, ParentId, SAP_Code__c
            FROM Account
            WHERE Id = :accountId
            LIMIT 1
        ];
        
        if(currentAcc.SAP_Code__c == null){
            resultMap.put('parentSchemes', parentSchemes);
            resultMap.put('childSchemes', childSchemes);
            return resultMap;
        }
        
        // ✅ Identify Child or Parent
        Boolean isChildAccount = (currentAcc.ParentId != null);
        
        // ✅ Step 2: Decide Parent Account
        Account parentAcc;
        
        if(isChildAccount){
            parentAcc = [
                SELECT Id, SAP_Code__c
                FROM Account
                WHERE Id = :currentAcc.ParentId
                LIMIT 1
            ];
        } else {
            parentAcc = currentAcc;
        }
        
        // ✅ Step 5: Parent Scheme Query (Always)
        List<Scheme_Request__c> parentSchemeList = [
            SELECT Id, Name,Scheme_Name__c, Scheme_Number__c,Scheme_Description__c,
            Account__r.SAP_Code__c, Account__r.Name,
            Start_Date__c, End_Date__c
            FROM Scheme_Request__c
            WHERE Account__c = :parentAcc.Id
            AND Approval_Status__c = 'Approved'
            AND End_Date__c >= :System.today()
            ORDER BY End_Date__c DESC
        ];
        
        for(Scheme_Request__c sc : parentSchemeList){
            parentSchemes.add(sc);
        }
        
        // ✅ Step 6: Child Scheme Logic FIXED ✅
        
        if(isChildAccount){
            
            // ✅ If current is CHILD → Only show its own schemes
            List<Scheme_Request__c> currentChildSchemeList = [
                SELECT Id, Name,Scheme_Name__c, Scheme_Number__c,Scheme_Description__c,
                Account__r.SAP_Code__c, Account__r.Name,
                Start_Date__c, End_Date__c
                FROM Scheme_Request__c
                WHERE Account__c = :currentAcc.Id
                AND Approval_Status__c = 'Approved'
                AND End_Date__c >= :System.today()
                ORDER BY End_Date__c DESC
            ];
            
            for(Scheme_Request__c sc : currentChildSchemeList){
                childSchemes.add(sc);
            }
            
        }
        else {
            
            // ✅ If current is PARENT → Show all child schemes
            
            // ✅ Step 3: SAP API → Child SAP Codes
            Set<String> childSapCodes = new Set<String>();
            
            String sapResponse = getParentCustomer(parentAcc.SAP_Code__c);
            
            if(!String.isBlank(sapResponse)) {
                
                Map<String,Object> rootMap =
                    (Map<String,Object>) JSON.deserializeUntyped(sapResponse);
                
                if(rootMap.containsKey('d')) {
                    
                    Map<String,Object> dMap =
                        (Map<String,Object>) rootMap.get('d');
                    
                    if(dMap.containsKey('to_Children')) {
                        
                        Map<String,Object> childWrapper =
                            (Map<String,Object>) dMap.get('to_Children');
                        
                        List<Object> results =
                            (List<Object>) childWrapper.get('results');
                        
                        for(Object obj : results) {
                            
                            Map<String,Object> childMap =
                                (Map<String,Object>) obj;
                            
                            if(childMap.containsKey('ChildCustomer')) {
                                
                                childSapCodes.add(
                                    String.valueOf(childMap.get('ChildCustomer'))
                                );
                            }
                        }
                    }
                }
            }
            
            // ✅ Step 4: Fetch Child Accounts
            List<Account> childAccounts = new List<Account>();
            
            if(!childSapCodes.isEmpty()) {
                childAccounts = [
                    SELECT Id
                    FROM Account
                    WHERE SAP_Code__c IN :childSapCodes
                    AND ParentId = :parentAcc.Id
                ];
            }
            
            // ✅ Fetch All Child Schemes
            if(!childAccounts.isEmpty()) {
                
                Set<Id> childIds = new Set<Id>();
                for(Account ch : childAccounts){
                    childIds.add(ch.Id);
                }
                
                List<Scheme_Request__c> childSchemeList = [
                    SELECT Id, Name,Scheme_Name__c, Scheme_Number__c,
                    Account__r.SAP_Code__c, Account__r.Name,
                    Start_Date__c, End_Date__c
                    FROM Scheme_Request__c
                    WHERE Account__c IN :childIds
                    AND Approval_Status__c = 'Approved'
                    AND End_Date__c >= :System.today()
                    ORDER BY End_Date__c DESC
                ];
                
                for(Scheme_Request__c sc : childSchemeList){
                    childSchemes.add(sc);
                }
            }
        }
        
        // ✅ Step 7: Final Map Return
        resultMap.put('parentSchemes', parentSchemes);
        resultMap.put('childSchemes', childSchemes);
        
        return resultMap;
    }
    
    @AuraEnabled(cacheable=false)
    public static Map<String, String> checkschemedata(
        List<Object> accountdata,
        List<String> accIds,
        String schemenumber
    ) {
        Map<String, String> result = new Map<String, String>();
        
        List<Id> accountIdList = new List<Id>();
        Id childAccountId;
        Date startDate;
        
        try {
            /* -------------------------------
* 1️⃣ Read accountdata (Child flow)
* ------------------------------- */
            if (accountdata != null) {
                for (Object obj : accountdata) {
                    Map<Object, Object> dataMap = (Map<Object, Object>) obj;
                    
                    if (dataMap.containsKey('Id')) {
                        childAccountId = (Id) dataMap.get('Id');
                    }
                    
                    if (dataMap.containsKey('Start_Date__c') && dataMap.get('Start_Date__c') != null) {
                        startDate = Date.valueOf(String.valueOf(dataMap.get('Start_Date__c')));
                    }
                }
            }
            
            /* -------------------------------
* 2️⃣ Determine flow type
* accIds present → Parent flow
* accIds empty   → Child flow
* ------------------------------- */
            Boolean isChildFlow = (accIds == null || accIds.isEmpty());
            
            /* -------------------------------
* 3️⃣ Fetch account & parent
* ------------------------------- */
            Account acc = [
                SELECT Id, ParentId
                FROM Account
                WHERE Id = :childAccountId
                LIMIT 1
            ];
            
            /* -------------------------------
* 4️⃣ Decide which accounts to check
* ------------------------------- */
            Set<Id> schemeCheckAccountIds = new Set<Id>();
            
            if (isChildFlow) {
                // Child applying scheme → check child + parent
                schemeCheckAccountIds.add(acc.Id);
                if (acc.ParentId != null) {
                    schemeCheckAccountIds.add(acc.ParentId);
                }
            } else {
                // Parent applying scheme → accIds contains parent + children
                schemeCheckAccountIds.addAll((List<Id>) accIds);
            }
            
            /* -------------------------------
* 5️⃣ Query existing schemes
* ------------------------------- */
            List<Scheme_Request__c> activeSchemes = [
                SELECT Id, Name, Account__c,Scheme_Number__c, Account__r.Name, Account__r.SAP_Code__c
                FROM Scheme_Request__c
                WHERE Account__c IN :schemeCheckAccountIds
                AND End_Date__c >= :startDate
                AND scheme_number__c = :schemenumber
                AND (Approval_status__c = 'Approved' OR Scheme_applied_by_parent__c = true)
            ];
            
            /* -------------------------------
* 6️⃣ ERROR: Scheme already active
* (Parent OR Child)
* ------------------------------- */
            if (!activeSchemes.isEmpty()) {
                String schemeDetails = '';
                for (Scheme_Request__c sr : activeSchemes) {
                    schemeDetails +=
                        'Customer: ' + sr.Account__r.SAP_Code__c + ', ' ;
                }
                
                String schemeNumbers = activeSchemes[0].Scheme_Number__c;
                
                result.put('status', 'error');
                result.put(
                    'message',
                    schemeDetails + 
                    ', Scheme No: ' + schemeNumbers +', '+
                    'This scheme is already active. Please deselect this customer or choose another before proceeding.'
                );
                return result;
            }
            
            if (isChildFlow && acc.ParentId != null) {
                result.put('status', 'warning');
                result.put(
                    'message',
                    'The scheme is being applied to a child account, but it is not active on the parent account. Do you want to proceed?'
                );
                return result;
            }
            
            
            result.put('status', 'success');
            result.put('message', 'No conflicting scheme request found.');
            return result;
            
        } catch (Exception e) {
            System.debug('Error in checkschemedata: ' + e.getMessage());
            result.put('status', 'error');
            result.put('message', 'Unexpected error occurred while validating scheme.');
            return result;
        }
    }
    
    public static String getParentCustomer(String customerNumber) {
        
        String endpoint = '';
        String end_point = '';
        
        try {
            // Fetch Custom Setting
            MOU_Integration__c mouData =
                MOU_Integration__c.getInstance('parenttochildsyncingwithparam');
            
            if (mouData != null && String.isNotBlank(mouData.End_Point_URL__c)) {
                end_point = mouData.End_Point_URL__c;
            } else {
                System.debug('Endpoint not found in Custom Setting');
                return null;
            }
            
            endpoint = end_point.replace('(\'\')', '(\'' + customerNumber + '\')');
            System.debug('Final Endpoint => ' + endpoint);
            
            // Prepare HTTP request
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setTimeout(120000);
            
            // String username = 'COMM_ODATA';
            //String password = 'Welcome@123';
            
            Blob headerValue = Blob.valueOf(mouData.Username__c + ':' + mouData.Password__c);
            String authorizationHeader =
                'Basic ' + EncodingUtil.base64Encode(headerValue);
            
            req.setHeader('Authorization', authorizationHeader);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');
            
            HttpResponse res = new Http().send(req);
            
            //Success
            if (res.getStatusCode() == 200) {
                return res.getBody();
            }
            createApiErrorLog(
                'MOU scheme',
                'SAPCustomerService',
                res.getStatusCode(),
                res.getStatus(),
                'Non-200 response from SAP Parent Customer API',
                endpoint,
                res.getBody()
            );
            return null;
            
        } catch (Exception e) {
            createApiErrorLog(
                'MOU scheme',
                'SAPCustomerService',
                null,
                'EXCEPTION',
                e.getMessage() + ' | Line: ' + e.getLineNumber(),
                endpoint,
                null
            );
            return null;
        }
    }
    @future
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
        } catch (Exception ex) {
            System.debug('API Log insert failed: ' + ex.getMessage());
        }
    }  
}