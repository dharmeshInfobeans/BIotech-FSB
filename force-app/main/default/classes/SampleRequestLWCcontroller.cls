public without sharing class SampleRequestLWCcontroller {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> fetchSampleRequestProduct(Id recordId) {
        Map<String, Object> responseMap = new Map<String, Object>();
        
        // Validate recordId
        if (recordId == null) {
            responseMap.put('SampleRequestProduct', new List<Map<String, String>>()); // Return empty list if no recordId is provided
            return responseMap; 
        }
        
        string countryname;
        List<Lead__c> leadList;
        List<Account> accList;
        List<account> accountlist;
        List<Map<String, String>> sapCodeList = new List<Map<String, String>>();
        Set<String> uniqueSapCodes = new Set<String>(); // To track unique SAP codes
        List<Sample_Request_Product__c> SRPData;
        String countryValue;
        string productname ;
        if (String.isNotBlank(recordId)) {
            try {
                // Retrieve the object type dynamically
                SObjectType objType = Id.valueOf(recordId).getSObjectType();
                String objectName = objType.getDescribe().getName(); // Returns 'Lead' or 'Account'
                if (objectName == 'Lead__c') {
                    leadList = [SELECT Id,SAP_code__c,Country__c,Billing_City__c,Name,RSM__C,ZSM__c,product__c FROM Lead__c WHERE Id = :recordId LIMIT 1];
                    countryValue = leadList[0].Country__c;
                    productname = leadList[0].product__c;
                    Map<String, String> currentRecordMap = new Map<String, String>();
                    currentRecordMap.put('label', leadList[0].Sap_code__c+'-'+leadList[0].Name+'-'+leadList[0].Billing_City__c);
                    currentRecordMap.put('value', leadList[0].Sap_code__c);
                    sapCodeList.add(currentRecordMap);
                    responseMap.put('sapCodeList',sapCodeList);
                    if (String.isNotBlank(leadList[0].Sap_code__c)) {
                        responseMap.put('recordsapcode',leadList[0].Sap_code__c);          
                    } else {
                        responseMap.put('recordsapcode', null);
                    }
                    
                    
                    responseMap.put('rsmavailable',leadList[0].RSM__c);
                    responseMap.put('zsmavailable',leadList[0].ZSM__c);
                    System.debug('Lead Record: ' + leadList);
                } else if (objectName == 'Account') {
                    accList = [SELECT Id,Sap_code__C, BillingCountry,BillingCity,Name,RSM__C,ZSM__c FROM Account WHERE Id = :recordId LIMIT 1];
                    countryValue = accList[0].BillingCountry;
                    // Always include current record's SAP code
                    if (accList.size() > 0 && String.isNotBlank(accList[0].Sap_code__c)) {
                        String formattedCurrentSAP = accList[0].Sap_code__c + '-' + accList[0].Name + '-' + accList[0].BillingCity;
                        if (!uniqueSapCodes.contains(formattedCurrentSAP)) {
                            uniqueSapCodes.add(formattedCurrentSAP);
                            
                            Map<String, String> currentRecordMap = new Map<String, String>();
                            currentRecordMap.put('label', formattedCurrentSAP);
                            currentRecordMap.put('value', accList[0].Sap_code__c);
                            sapCodeList.add(currentRecordMap);
                        }
                    }
                    accountlist = [SELECT Id,Sap_code__c,BillingCity,Name FROM Account WHERE ParentId =:recordId];
                    system.debug('accountlist-------->'+accountlist);
                    if (String.isNotBlank(accList[0].Sap_code__c)) {
                        responseMap.put('recordsapcode',accList[0].Sap_code__c+'-'+accList[0].Name+'-'+accList[0].BillingCity);          
                    } else {
                        responseMap.put('recordsapcode', null);
                    }
                    
                    
                    
                    responseMap.put('rsmavailable',accList[0].RSM__c);
                    responseMap.put('zsmavailable',accList[0].ZSM__c);
                    
                    // Now add child account SAP codes if available
                    for (Account acc : accountlist) {
                        if (acc.Sap_code__c != null) {
                            String formattedChildSAP = acc.Sap_code__c + '-' + acc.Name + '-' + acc.BillingCity;
                            if (!uniqueSapCodes.contains(formattedChildSAP)) {
                                uniqueSapCodes.add(formattedChildSAP);
                                
                                Map<String, String> sapCodeMap = new Map<String, String>();
                                sapCodeMap.put('label', formattedChildSAP);
                                sapCodeMap.put('value', acc.Sap_code__c);
                                sapCodeList.add(sapCodeMap);
                            }
                        }
                    }
                    responseMap.put('sapCodeList', sapCodeList);
                    
                    /*  // If no SAP codes are found, use the current record's SAP code
if (sapCodeList.isEmpty()) {
Account currentRecord = [SELECT Sap_code__c,Name,BillingCity FROM Account WHERE Id = :recordId LIMIT 1];
Map<String, String> currentRecordMap = new Map<String, String>();
currentRecordMap.put('label', currentRecord.Sap_code__c +'-'+ currentRecord.name +'-'+currentRecord.BillingCity);
currentRecordMap.put('value', currentRecord.Sap_code__c);
sapCodeList.add(currentRecordMap);
responseMap.put('sapCodeList',sapCodeList);
}    */            
                    System.debug('Account Record: ' + accList);
                } else {
                    System.debug('Unsupported Object Type: ' + objectName);
                }
            } catch (Exception e) {
                System.debug('Error: ' + e.getMessage());
            }
        } else {
            System.debug('Invalid Record Id');
        }    
        system.debug('accList'+accList);
        
        // Validate that a Lead or Account was found and Country/BillingCountry is not null
        if (countryValue !=null) {
            // Query Sample_Request_Product__c based on the Country__c of Lead/Account
            SRPData = [
                SELECT Id, Name, Dummy_Product_Description__c
                FROM Sample_Request_Product__c
                WHERE Country__c = :countryValue
                AND Dummy_Product_Description__c != null
            ];

        } else {
            SRPData = new List<Sample_Request_Product__c>(); // Initialize to avoid null reference
        }
        
        
        System.debug('SRPData: ' + SRPData);
        
        // Populate dropdowns for the Dummy_Product_Description__c and other fields
        List<Map<String, String>> dummyProductDescriptions = new List<Map<String, String>>();
        
        // Collect unique values from SRPData
        Set<String> uniqueDescriptions = new Set<String>(); // To track unique descriptions
        for (Sample_Request_Product__c srp : SRPData) {
            if (srp.Dummy_Product_Description__c != null && !uniqueDescriptions.contains(srp.Dummy_Product_Description__c)) {
                uniqueDescriptions.add(srp.Dummy_Product_Description__c);
                Map<String, String> descriptionMap = new Map<String, String>();
                descriptionMap.put('label', srp.Dummy_Product_Description__c);
                descriptionMap.put('value', srp.Dummy_Product_Description__c);
                dummyProductDescriptions.add(descriptionMap); // Add to the list
            }
        }
        
        responseMap.put('SampleRequestProduct', dummyProductDescriptions);
        system.debug('responseMap'+responseMap.get('SampleRequestProduct'));
        system.debug('responseMap--->'+responseMap);
        
        return responseMap;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> fetchmultiplecustomerSampleRequestProduct() {
        Map<String, Object> responseMap = new Map<String, Object>();
        String countryName;
        
        // Fetching the current user's Country__c field
        User currentUser = [SELECT Country__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        if(currentUser.Country__c !=null){
            countryName = currentUser.Country__c;
        }
        
        
        
        // Validate input
        if (String.isEmpty(countryName)) {
            responseMap.put('sampleRequestProduct', new List<Map<String, String>>());
            
            return responseMap;
        }
        
        String countryValue = countryName.toLowerCase();
        List<Sample_Request_Product__c> SRPData;
        
        // Query with case-insensitive matching
        try {
            SRPData = [SELECT Id, Name, Dummy_Product_Description__c 
                       FROM Sample_Request_Product__c 
                       WHERE Country__c = :countryValue AND Dummy_Product_Description__c != null];
        } catch (Exception e) {
            System.debug('SOQL Error: ' + e.getMessage());
            SRPData = new List<Sample_Request_Product__c>();
        }
        
        System.debug('Query Result: ' + SRPData);
        
        // Prepare response
        List<Map<String, String>> dummyProductDescriptions = new List<Map<String, String>>();
        Set<String> uniqueDescriptions = new Set<String>();
        
        for (Sample_Request_Product__c srp : SRPData) {
            if (srp.Dummy_Product_Description__c != null && !uniqueDescriptions.contains(srp.Dummy_Product_Description__c)) {
                uniqueDescriptions.add(srp.Dummy_Product_Description__c);
                Map<String, String> descriptionMap = new Map<String, String>();
                descriptionMap.put('label', srp.Dummy_Product_Description__c);
                descriptionMap.put('value', srp.Dummy_Product_Description__c);
                dummyProductDescriptions.add(descriptionMap);
            }
        }
        
        responseMap.put('sampleRequestProduct', dummyProductDescriptions);
        responseMap.put('country',countryName);
        System.debug('Final Response: ' + responseMap.get('SampleRequestProduct'));
        
        return responseMap;
    }
    
    @AuraEnabled
    public static Map<String, Object> fetchDropdownOptions(
        Id recordId, 
        String productName, 
        String productModel, 
        String sphericalPower, 
        String cylindricalPower, 
        String axisangles,
        String diaptor
    ) {
        System.debug('fetchDropdownOptions--> recordId: ' + recordId + 'productName: ' + productName + 'productModel: ' + productModel + 'sphericalPower: ' + sphericalPower + 'axisangles: ' + axisangles + 'diaptor: ' + diaptor);
        
        
        Map<String, Object> responseMap = new Map<String, Object>();
        
        if (recordId == null) {
            responseMap.put('sampleRequestProducts', new List<Sample_Request_Product__c>());
            responseMap.put('dropdownOptions', new Map<String, List<Map<String, String>>>());
            return responseMap;
        }
        
        String countryName;
        List<Sample_Request_Product__c> SRPData = new List<Sample_Request_Product__c>();
        
        try {
            SObjectType objType = recordId.getSObjectType();
            String objectName = objType.getDescribe().getName();
            
            if (objectName == 'Lead__c') {
                List<Lead__c> leadList = [SELECT Id, Country__c FROM Lead__c WHERE Id = :recordId LIMIT 1];
                if (!leadList.isEmpty()) {
                    countryName = leadList[0].Country__c;
                }
            } else if (objectName == 'Account') {
                List<Account> accList = [SELECT Id, BillingCountry FROM Account WHERE Id = :recordId LIMIT 1];
                if (!accList.isEmpty()) {
                    countryName = accList[0].BillingCountry;
                }
            }
        } catch (Exception e) {
            System.debug('Error identifying object: ' + e.getMessage());
            responseMap.put('error', e.getMessage());
            return responseMap;
        }
        
        if (String.isNotBlank(countryName)) {
            // Base Query
            String query = 'SELECT Id, Name, Dummy_Product_Description__c, Product_Model__c, Spherical_Power__c, Cylinder_Power__c, Axis__c, Diaptor__c FROM Sample_Request_Product__c WHERE Country__c = :countryName';
            
            // Adding Filters Properly (Using AND instead of OR)
            if (String.isNotBlank(productName)) {
                query += ' AND Dummy_Product_Description__c = \'' + String.escapeSingleQuotes(productName) + '\'';
            }
            if (String.isNotBlank(productModel)) {
                query += ' AND Product_Model__c = \'' + String.escapeSingleQuotes(productModel) + '\'';
            }
            if (String.isNotBlank(sphericalPower)) {
                try {
                    query += ' AND Spherical_Power__c =  \'' + string.escapeSingleQuotes(sphericalPower) + '\'';
                } catch (Exception e) {
                    System.debug('Invalid Spherical Power value: ' + sphericalPower);
                }
            }
            if (String.isNotBlank(cylindricalPower)) {
                try {
                    query += ' AND Cylinder_Power__c =  \'' + string.escapeSingleQuotes(cylindricalPower) + '\'';
                } catch (Exception e) {
                    System.debug('Invalid Cylindrical Power value: ' + cylindricalPower);
                }
            }
            if (String.isNotBlank(axisangles)) {
                try {
                    query += ' AND Axis__c =  \'' + string.escapeSingleQuotes(axisangles) + '\'';
                } catch (Exception e) {
                    System.debug('Invalid Axis Angle value: ' + axisangles);
                }
            }
            if (String.isNotBlank(diaptor)) {
                try {
                    query += ' AND Diaptor__c =  \'' + string.escapeSingleQuotes(diaptor) +'\'';
                } catch (Exception e) {
                    System.debug('Invalid Diaptor value: ' + diaptor);
                }
            }
            
            // Determine ORDER BY field dynamically
            String orderByField;
            if (String.isNotBlank(productName)) {
                orderByField = 'Dummy_Product_Description__c';
            } else if (String.isNotBlank(productModel)) {
                orderByField = 'Product_Model__c';
            } else if (String.isNotBlank(sphericalPower)) {
                orderByField = 'Spherical_Power__c';
            } else if (String.isNotBlank(cylindricalPower)) {
                orderByField = 'Cylinder_Power__c';
            } else if (String.isNotBlank(axisangles)) {
                orderByField = 'Axis__c';
            } else if (String.isNotBlank(diaptor)) {
                orderByField = 'Diaptor__c';
            }
            
            // Append ORDER BY if field is selected
            if (String.isNotBlank(orderByField)) {
                query += ' ORDER BY ' + orderByField + ' ASC';
            }
            
            System.debug('Final Query: ' + query);
            
            try {
                SRPData = Database.query(query);
            } catch (Exception e) {
                System.debug('Error executing query: ' + e.getMessage());
                responseMap.put('error', e.getMessage());
                return responseMap;
            }
        }
        
        // **Collect Unique Values**
        Map<String, Set<String>> uniqueValuesMap = new Map<String, Set<String>>{
            'productModel' => new Set<String>(),
                'sphericalPower' => new Set<String>(),
                'cylindricalPower' => new Set<String>(),
                'axisAngle' => new Set<String>(),
                'diaptor' => new Set<String>()
                };
                    
                    for (Sample_Request_Product__c srp : SRPData) {
                        if (String.isNotBlank(srp.Product_Model__c)) {
                            uniqueValuesMap.get('productModel').add(srp.Product_Model__c);
                        }
                        if (String.isNotBlank(srp.Spherical_Power__c)) {
                            uniqueValuesMap.get('sphericalPower').add(srp.Spherical_Power__c);
                        }
                        if (srp.Cylinder_Power__c != null) {
                            uniqueValuesMap.get('cylindricalPower').add(String.valueOf(srp.Cylinder_Power__c));
                        }
                        if (srp.Axis__c != null) {
                            uniqueValuesMap.get('axisAngle').add(String.valueOf(srp.Axis__c));
                        }
                        if (srp.Diaptor__c != null) {
                            uniqueValuesMap.get('diaptor').add(String.valueOf(srp.Diaptor__c));
                        }
                    }
        
        // **Convert to Dropdown Format**
        Map<String, List<Map<String, String>>> dropdownOptions = new Map<String, List<Map<String, String>>>();
        
        for (String field : uniqueValuesMap.keySet()) {
            // ASC sort conditions================================
            List<String> sortedValues = new List<String>(uniqueValuesMap.get(field));
            //sortedValues.sort(); // Sort ascending
            // System.debug('ASC List '+sortedValues);
            Boolean isNumeric = true;
            for (String val : sortedValues) {
                if (!Pattern.matches('^-?\\d+(\\.\\d+)?$', val)) {
                    isNumeric = false;
                    break;
                }
            }
            
            if (isNumeric) {
                // Convert to decimals, sort, and convert back
                List<Decimal> decimalList = new List<Decimal>();
                for (String val : sortedValues) {
                    decimalList.add(Decimal.valueOf(val));
                }
                decimalList.sort();
                sortedValues.clear();
                for (Decimal d : decimalList) {
                    sortedValues.add(String.valueOf(d));
                }
            } else {
                sortedValues.sort();
            }
            //=======================================================
            
            List<Map<String, String>> dropdownList = new List<Map<String, String>>();
            for (String value : sortedValues) {
                Map<String, String> option = new Map<String, String>{
                    'label' => value,
                        'value' => value
                        };
                            dropdownList.add(option);
            }
            dropdownOptions.put(field, dropdownList);
        }
        
        responseMap.put('dropdownOptions', dropdownOptions);
        //System.debug('Final Response Map: ' + responseMap);
        return responseMap;
    }
    
    
    @AuraEnabled
    public static Map<String, Object> fetchDropdownOptionsformultiplecustomer(
        string countryValue, 
        String productName, 
        String productModel, 
        String sphericalPower, 
        String cylindricalPower, 
        String axisangles,
        String diaptor
    ) {
        System.debug('--- fetchDropdownOptions Called ---');
        System.debug('countryname: ' + countryValue);
        System.debug('productName: ' + productName);
        System.debug('productModel: ' + productModel);
        System.debug('sphericalPower: ' + sphericalPower);
        System.debug('cylindricalPower: ' + cylindricalPower);
        System.debug('axisangles: ' + axisangles);
        System.debug('diaptor: ' + diaptor);
        
        Map<String, Object> responseMap = new Map<String, Object>();
        
        if (countryValue == null) {
            responseMap.put('sampleRequestProducts', new List<Sample_Request_Product__c>());
            responseMap.put('dropdownOptions', new Map<String, List<Map<String, String>>>());
            return responseMap;
        }
        
        String countryName = countryValue.toLowerCase();
        List<Sample_Request_Product__c> SRPData = new List<Sample_Request_Product__c>();
        
        
        if (String.isNotBlank(countryName)) {
            // Base Query
            String query = 'SELECT Id, Name, Dummy_Product_Description__c, Product_Model__c, Spherical_Power__c, Cylinder_Power__c, Axis__c, Diaptor__c FROM Sample_Request_Product__c WHERE Country__c = :countryName';
            
            // Adding Filters Properly (Using AND instead of OR)
            if (String.isNotBlank(productName)) {
                query += ' AND Dummy_Product_Description__c = \'' + String.escapeSingleQuotes(productName) + '\'';
            }
            if (String.isNotBlank(productModel)) {
                query += ' AND Product_Model__c = \'' + String.escapeSingleQuotes(productModel) + '\'';
            }
            if (String.isNotBlank(sphericalPower)) {
                try {
                    query += ' AND Spherical_Power__c = \'' + string.escapeSingleQuotes(sphericalPower) +'\'';
                } catch (Exception e) {
                    System.debug('Invalid Spherical Power value: ' + sphericalPower);
                }
            }
            if (String.isNotBlank(cylindricalPower)) {
                try {
                    query += ' AND Cylinder_Power__c = \'' + string.escapeSingleQuotes(cylindricalPower) +'\'';
                } catch (Exception e) {
                    System.debug('Invalid Cylindrical Power value: ' + cylindricalPower);
                }
            }
            if (String.isNotBlank(axisangles)) {
                try {
                    query += ' AND Axis__c = \'' + string.escapeSingleQuotes(axisangles) +'\'';
                } catch (Exception e) {
                    System.debug('Invalid Axis Angle value: ' + axisangles);
                }
            }
            if (String.isNotBlank(diaptor)) {
                try {
                    query += ' AND Diaptor__c = \'' + string.escapeSingleQuotes(diaptor) +'\'';
                } catch (Exception e) {
                    System.debug('Invalid Diaptor value: ' + diaptor);
                }
            }
            
            
            // Determine ORDER BY field dynamically
            String orderByField;
            if (String.isNotBlank(productName)) {
                orderByField = 'Dummy_Product_Description__c';
            } else if (String.isNotBlank(productModel)) {
                orderByField = 'Product_Model__c';
            } else if (String.isNotBlank(sphericalPower)) {
                orderByField = 'Spherical_Power__c';
            } else if (String.isNotBlank(cylindricalPower)) {
                orderByField = 'Cylinder_Power__c';
            } else if (String.isNotBlank(axisangles)) {
                orderByField = 'Axis__c';
            } else if (String.isNotBlank(diaptor)) {
                orderByField = 'Diaptor__c';
            }
            
            // Append ORDER BY if field is selected
            if (String.isNotBlank(orderByField)) {
                query += ' ORDER BY ' + orderByField + ' ASC';
            }
            
            System.debug('Final Query: ' + query);
            
            try {
                SRPData = Database.query(query);
            } catch (Exception e) {
                System.debug('Error executing query: ' + e.getMessage());
                responseMap.put('error', e.getMessage());
                return responseMap;
            }
        }
        
        // **Collect Unique Values**
        Map<String, Set<String>> uniqueValuesMap = new Map<String, Set<String>>{
            'productModel' => new Set<String>(),
                'sphericalPower' => new Set<String>(),
                'cylindricalPower' => new Set<String>(),
                'axisAngle' => new Set<String>(),
                'diaptor' => new Set<String>()
                };
                    
                    for (Sample_Request_Product__c srp : SRPData) {
                        if (String.isNotBlank(srp.Product_Model__c)) {
                            uniqueValuesMap.get('productModel').add(srp.Product_Model__c);
                        }
                        if (String.isNotBlank(srp.Spherical_Power__c)) {
                            uniqueValuesMap.get('sphericalPower').add(srp.Spherical_Power__c);
                        }
                        if (srp.Cylinder_Power__c != null) {
                            uniqueValuesMap.get('cylindricalPower').add(String.valueOf(srp.Cylinder_Power__c));
                        }
                        if (srp.Axis__c != null) {
                            uniqueValuesMap.get('axisAngle').add(String.valueOf(srp.Axis__c));
                        }
                        if (srp.Diaptor__c != null) {
                            uniqueValuesMap.get('diaptor').add(String.valueOf(srp.Diaptor__c));
                        }
                    }
        
        // **Convert to Dropdown Format**
        Map<String, List<Map<String, String>>> dropdownOptions = new Map<String, List<Map<String, String>>>();
        
        for (String field : uniqueValuesMap.keySet()) {
            // ASC sort conditions================================
            List<String> sortedValues = new List<String>(uniqueValuesMap.get(field));
            //sortedValues.sort(); // Sort ascending
            // System.debug('ASC List '+sortedValues);
            Boolean isNumeric = true;
            for (String val : sortedValues) {
                if (!Pattern.matches('^-?\\d+(\\.\\d+)?$', val)) {
                    isNumeric = false;
                    break;
                }
            }
            
            if (isNumeric) {
                // Convert to decimals, sort, and convert back
                List<Decimal> decimalList = new List<Decimal>();
                for (String val : sortedValues) {
                    decimalList.add(Decimal.valueOf(val));
                }
                decimalList.sort();
                sortedValues.clear();
                for (Decimal d : decimalList) {
                    sortedValues.add(String.valueOf(d));
                }
            } else {
                sortedValues.sort();
            }
            //=======================================================
            
            List<Map<String, String>> dropdownList = new List<Map<String, String>>();
            for (String value : sortedValues) {
                Map<String, String> option = new Map<String, String>{
                    'label' => value,
                        'value' => value
                        };
                            dropdownList.add(option);
            }
            dropdownOptions.put(field, dropdownList);
        }
        
        responseMap.put('dropdownOptions', dropdownOptions);
        System.debug('Final Response Map: ' + responseMap);
        return responseMap;
    }
    /*
    @AuraEnabled
    public static string saveSampleRequestDataforsinglecustomer(List<Map<String, String>> finalData, Id recordId,Map<String, String> rmarkandsapcode) {
        try {
            // Retrieve SAP Code and Remark from the map
            String sapCode = rmarkandsapcode.get('sapCode');
            String remark = rmarkandsapcode.get('remark');
            system.debug('sapCode'+sapCode);
            system.debug('remark'+remark);
            System.debug('recordId: ' + recordId);
            system.debug('finalData-->'+ JSON.serialize(finalData));
            
            // Sets for unique values
            Set<String> productNameSet = new Set<String>();
            Set<String> productModelSet = new Set<String>();
            Set<String> sphericalPowerSet = new Set<String>();
            Set<string> axisAngleSet = new Set<string>();
            Set<string> cylindricalPowerSet = new Set<string>();
            Set<string> diaptorSet = new Set<string>();
            set<double> commercialQuantityset = new Set<double>();
            Map<string,double> qtyMap=new Map<string,double>();
            for (Map<String, String> row : finalData) {
                System.debug('Row Data: ' + row);
                productNameSet.add(null);
                productModelSet.add(null);
                sphericalPowerSet.add(null);
                axisAngleSet.add(null);
                cylindricalPowerSet.add(null);
                diaptorSet.add(null);
                // Adding values to respective sets
                if (String.isNotBlank(row.get('productName')) && row.get('productName')!='') {
                    productNameSet.add(row.get('productName'));
                    productNameSet.remove(null);
                    
                }
                if (String.isNotBlank(row.get('productModel')) && row.get('productModel') !='') {
                    productModelSet.add(row.get('productModel'));
                    productModelSet.remove(null);
                }
                if (String.isNotBlank(row.get('sphericalPower')) && row.get('sphericalPower') !='') {
                    sphericalPowerSet.add(row.get('sphericalPower'));
                    sphericalPowerSet.remove(null);
                }
                if (String.isNotBlank(row.get('axisAngle')) && row.get('axisAngle')!='') {
                    axisAngleSet.add(row.get('axisAngle'));
                    axisAngleSet.remove(null);
                }
                if (String.isNotBlank(row.get('cylindricalPower')) && row.get('cylindricalPower')!='') {
                    cylindricalPowerSet.add(row.get('cylindricalPower'));
                    cylindricalPowerSet.remove(null);
                }
                if (String.isNotBlank(row.get('commercialQuantity')) && row.get('commercialQuantity') !='') {
                    commercialQuantityset.add(Double.valueOf(row.get('commercialQuantity')));
                    commercialQuantityset.remove(null);
                }
                if (String.isNotBlank(row.get('diaptor')) && row.get('diaptor') !='') {
                    diaptorSet.add(row.get('diaptor'));
                    diaptorSet.remove(null);
                }
                qtyMap.put(row.get('productName')+row.get('productModel')+row.get('sphericalPower')+row.get('cylindricalPower')+row.get('axisAngle')+row.get('diaptor'),double.valueOf(row.get('commercialQuantity')));
                
                system.debug('qtyMap---634->'+qtyMap.keyset());
                
            }
            
            system.debug('qtyMap---638->'+qtyMap.keyset());
            
            // Debugging sets
            System.debug('productNameSet: ' + productNameSet);
            System.debug('productModelSet: ' + productModelSet);
            System.debug('sphericalPowerSet: ' + sphericalPowerSet);
            System.debug('axisAngleSet: ' + axisAngleSet);
            System.debug('cylindricalPowerSet: ' + cylindricalPowerSet);
            System.debug('diaptorSet: ' + diaptorSet);
            System.debug('commercialQuantityset: ' + commercialQuantityset);
            
            // Constructing dynamic WHERE conditions
            List<String> conditions = new List<String>();
            
            if (productNameSet != null && !productNameSet.isEmpty()) 
                conditions.add('Dummy_Product_Description__c IN :productNameSet');
            
            if (productModelSet != null && !productModelSet.isEmpty()) 
                conditions.add('Product_Model__c IN :productModelSet');
            
            if (sphericalPowerSet != null && !sphericalPowerSet.isEmpty()) 
                conditions.add('Spherical_power__c IN :sphericalPowerSet');
            
            if (cylindricalPowerSet != null && !cylindricalPowerSet.isEmpty()) 
                conditions.add('Cylinder_Power__c IN :cylindricalPowerSet');
            
            if (axisAngleSet != null && !axisAngleSet.isEmpty()) 
                conditions.add('Axis__c IN :axisAngleSet');
            
            if (!diaptorSet.isEmpty()) 
                conditions.add('Diaptor__c IN :diaptorSet');
            
            if (conditions.isEmpty()) {
                System.debug('Skipping query execution due to empty filter values.');
                return '';
            }
            
            // Forming the final query conditionally
            double data = 0;
            String query = 'SELECT Id, Name, Product_Quantity__c, Country__c, Sl_No__c, Divison__c, Product_Code_SAP_Code__c, Product_Model__c, Dummy_Product_Description__c, Dummy_ID_Code__c, Spherical_power__c, Hydrophilic_Size__c, Business_Vertical__c, Category__c, Sub_Category__c, Brand__c, Group_Name__c, Cylinder_Power__c, Axis__c, Diaptor__c, Priority__c FROM Sample_Request_Product__c WHERE ';
            
            // Ensure conditions are not empty
            if (!conditions.isEmpty()) {
                query += String.join(conditions, ' AND ') + ' AND ';
            }
            
            query += 'Priority__c != NULL AND Priority__c != :data ORDER BY Priority__c ASC';
            
            
            // Execute dynamic query
            System.debug('Query Executed: ' + query);
            List<Sample_Request_Product__c> saplproductlist = Database.query(query);
            System.debug('saplproductlist: ' + saplproductlist);
             System.debug('saplproductlist: ' + saplproductlist.size());
            System.debug('saplproductlist: ' + json.serialize(saplproductlist));
            system.debug('Size--->'+saplproductlist.size());
            
            // Map to store unique combinations of product attributes
            Map<String, Sample_Request_Product__c> srpdatamap = new Map<String, Sample_Request_Product__c>();
            
            for (Sample_Request_Product__c srpdata : saplproductlist) {
                String key = srpdata.Dummy_Product_Description__c + '-' + srpdata.Product_Model__c  + '-' + srpdata.Spherical_power__c + '-' + srpdata.Cylinder_Power__c+ '-' + srpdata.Axis__c + '-' + srpdata.Diaptor__c;
                system.debug('key--->' +key);
                if (!srpdatamap.containsKey(key)) {
                    srpdatamap.put(key, srpdata);
                    system.debug('key> 690' +key);
                    system.debug('key-contain-->' +json.serialize(srpdata));
                }
            }
            
            // Creating new Sample_Request_Line_Item__c records
            List<Sample_Request_Line_Item__c> newSampleRequests = new List<Sample_Request_Line_Item__c>();
            
            
            
            
            
            Sample_Request_Header__c srhrecord = new  Sample_Request_Header__c();
            srhrecord.Remarks__c = remark;
            String objectName = recordId.getSObjectType().getDescribe().getName();
            
            Account Accdata;
            Lead__c leaddata;
            if(objectName=='Account' ){
                Accdata = [select id,SAP_code__C,Name,RSM__c,ZSM__c,BillingCountry from Account where Id=:recordId];
                if(Accdata.RSM__c != null){
                    srhrecord.RSM__c =Accdata.RSM__c;
                }if(Accdata.ZSM__c != null){
                    srhrecord.ZSM__c = Accdata.ZSM__c; 
                }
                srhrecord.Date__c = system.today();
                srhrecord.Customer__c  = Accdata.Id;
                srhrecord.Ship_To_Code__c = Accdata.SAP_Code__c;
                srhrecord.Bill_To_Code__c = sapCode;
                srhrecord.country__c= Accdata.BillingCountry ;
                
                insert srhrecord;
            }else{
                leaddata = [select id,SAP_code__C,Name,RSM__c,GM_NSM__c,ZSM__c,Country__c from Lead__c where Id=:recordId];
                srhrecord.Date__c = system.today();
                srhrecord.Leads__c  = leaddata.Id;
                if (leaddata.RSM__c != null && leaddata.ZSM__c != null) {
                    srhrecord.RSM__c = leaddata.RSM__c;
                    srhrecord.ZSM__c = leaddata.ZSM__c;
                } else {
                    if (leaddata.RSM__c == null && leaddata.ZSM__c != null && leaddata.GM_NSM__c != null) {
                        srhrecord.RSM__c = leaddata.ZSM__c;
                        srhrecord.ZSM__c = leaddata.GM_NSM__c;
                    } else {
                        if (leaddata.RSM__c == null && leaddata.ZSM__c != null) {
                            srhrecord.RSM__c = leaddata.ZSM__c;
                        }
                        if (leaddata.RSM__c != null && leaddata.ZSM__c == null) {
                            srhrecord.RSM__c = leaddata.RSM__c;
                        }
                        if ((leaddata.RSM__c == null || leaddata.ZSM__c == null) && leaddata.GM_NSM__c != null) {
                            srhrecord.ZSM__c = leaddata.GM_NSM__c;
                        }
                    }
                }
                
                
                srhrecord.Ship_To_Code__c = leaddata.SAP_Code__c;
                srhrecord.Bill_To_Code__c = leaddata.SAP_Code__c;
                srhrecord.country__c= leaddata.Country__c ;
                
                insert srhrecord;
            }
            System.debug('srpdatamap'+JSON.serialize(srpdatamap));
            for (Sample_Request_Product__c srp : srpdatamap.values()) {
                //system.debug('qtyMap-->srp before if'+ srp.Dummy_Product_Description__c+srp.Product_Model__c+srp.Spherical_power__c+srp.Cylinder_Power__c+srp.Axis__c+srp.Diaptor__c);
                system.debug('qtyMap-->Keys'+ qtyMap.keyset());
                String key = 
                    (srp.Dummy_Product_Description__c != null ? srp.Dummy_Product_Description__c : '') + 
                    (srp.Product_Model__c != null ? srp.Product_Model__c : '') + 
                    (srp.Spherical_power__c != null ? srp.Spherical_power__c : '') + 
                    (srp.Cylinder_Power__c != null ? srp.Cylinder_Power__c : '') + 
                    (srp.Axis__c != null ? srp.Axis__c : '') + 
                    (srp.Diaptor__c != null ? srp.Diaptor__c : '');
                
                System.debug('Key: ' + key);
                
                if(qtyMap.containsKey(key)){
                    
                    system.debug('qtyMap-->Keys'+ qtyMap.keyset());
                    system.debug('qtyMap-->match'+ srp.Dummy_Product_Description__c+srp.Product_Model__c+srp.Spherical_power__c+srp.Cylinder_Power__c+srp.Axis__c+srp.Diaptor__c);
                    Sample_Request_Line_Item__c newRequest = new Sample_Request_Line_Item__c(
                        Dummy_Product_Description__c = srp.Dummy_Product_Description__c,
                        Product_Model__c = srp.Product_Model__c,
                        Spherical_Power__c = srp.Spherical_power__c,
                        Cylinder_Power__c = srp.Cylinder_Power__c,
                        Axis__c = srp.Axis__c,
                        Diaptor__c = srp.Diaptor__c,
                        Priority__c = srp.Priority__c,
                        Product_Quantity__c = qtyMap.get(key),
                        Country__c = srp.Country__c,
                        Sl_No__c = srp.Sl_No__c,
                        Divison__c = srp.Divison__c,
                        Product_Code_SAP_Code__c = srp.Product_Code_SAP_Code__c,
                        Dummy_ID_Code__c = srp.Dummy_ID_Code__c,
                        Hydrophilic_Size__c = srp.Hydrophilic_Size__c,
                        Business_Vertical__c = srp.Business_Vertical__c,
                        Category__c = srp.Category__c,
                        Sub_Category__c = srp.Sub_Category__c,
                        Brand__c = srp.Brand__c,
                        Group_Name__c = srp.Group_Name__c,
                        Product_Name__c = srp.Id
                    );
                    
                    newRequest.Sample_Request_Header__c = srhrecord.Id;  
                    System.debug('Object Name: ' + objectName);
                    if(objectName=='Account' ){
                        newRequest.Account__c = recordId; 
                        //newRequest.Bill_To_Code__c = Sapcode;
                        //newRequest.Sold_To_Code__c  = Accdata.SAP_code__C;
                        //newRequest.Remark__c = remark;
                        
                    }else{
                        
                        newRequest.Lead__c = recordId;
                        //newRequest.Bill_To_Code__c = sapCode;
                        //newRequest.Sold_To_Code__c = sapCode;
                        //newRequest.Remark__c = remark;
                    }
                    
                    
                    newSampleRequests.add(newRequest);
                }
            }
            
            
            // Insert new records
            
            if (!newSampleRequests.isEmpty()) {
                System.debug('Serialize data'+JSON.serialize(newSampleRequests));
                insert newSampleRequests;
                Sample_Request_Header__c srhrecorddata =[select id,Isapproval__c from Sample_Request_Header__c where Id =:srhrecord.Id];
                if(srhrecorddata !=null){
                    srhrecorddata.Isapproval__c = true;
                    update srhrecorddata;
                }
                
                System.debug('Inserted Sample_Request_Line_Item__c records: ' + newSampleRequests.size());
                return 'success';
            } else {
                System.debug('No records to insert.');
                return '';
            }
            
        } catch (Exception e) {
            System.debug('Error message'+e.getMessage()+'At line number+++++--'+e.getLineNumber());
            throw new AuraHandledException('Error processing data: ' + e.getMessage());
            
        }
    }
    */
    
     @AuraEnabled
public static String saveSampleRequestDataforsinglecustomer(List<Map<String, String>> finalData, Id recordId, Map<String, String> rmarkandsapcode) {
    try {
        // Retrieve SAP Code and Remark
        String sapCode = rmarkandsapcode.get('sapCode');
        String remark = rmarkandsapcode.get('remark');
        System.debug('sapCode: ' + sapCode);
        System.debug('remark: ' + remark);
        System.debug('recordId: ' + recordId);
        System.debug('finalData --> ' + JSON.serialize(finalData));

        // Initialize sets and map
        Set<String> productNameSet = new Set<String>();
        Set<String> productModelSet = new Set<String>();
        Set<String> sphericalPowerSet = new Set<String>();
        Set<String> axisAngleSet = new Set<String>();
        Set<String> cylindricalPowerSet = new Set<String>();
        Set<String> diaptorSet = new Set<String>();
        Set<Double> commercialQuantitySet = new Set<Double>();
        Map<String, Double> qtyMap = new Map<String, Double>();

        // Build filters & quantity map
        for (Map<String, String> row : finalData) {
            System.debug('Row Data: ' + row);

            if (String.isNotBlank(row.get('productName'))) productNameSet.add(row.get('productName'));
            if (String.isNotBlank(row.get('productModel'))) productModelSet.add(row.get('productModel'));
            if (String.isNotBlank(row.get('sphericalPower'))) sphericalPowerSet.add(row.get('sphericalPower')); else sphericalPowerSet.add(null);
            if (String.isNotBlank(row.get('axisAngle'))) axisAngleSet.add(row.get('axisAngle')); else axisAngleSet.add(null);
            if (String.isNotBlank(row.get('cylindricalPower'))) cylindricalPowerSet.add(row.get('cylindricalPower')); else cylindricalPowerSet.add(null);
            if (String.isNotBlank(row.get('diaptor'))) diaptorSet.add(row.get('diaptor')); else diaptorSet.add(null);

            if (String.isNotBlank(row.get('commercialQuantity')))
                commercialQuantitySet.add(Double.valueOf(row.get('commercialQuantity')));

            // create key for quantity mapping
            String key =
                (row.get('productName') != null ? row.get('productName') : '') +
                (row.get('productModel') != null ? row.get('productModel') : '') +
                (row.get('sphericalPower') != null ? row.get('sphericalPower') : '') +
                (row.get('cylindricalPower') != null ? row.get('cylindricalPower') : '') +
                (row.get('axisAngle') != null ? row.get('axisAngle') : '') +
                (row.get('diaptor') != null ? row.get('diaptor') : '');
            
            if (String.isNotBlank(row.get('commercialQuantity')))
                qtyMap.put(key, Double.valueOf(row.get('commercialQuantity')));
        }

        System.debug('qtyMap Keys: ' + qtyMap.keySet());

        // Build dynamic query conditions
        List<String> conditions = new List<String>();

        if (!productNameSet.isEmpty())
            conditions.add('Dummy_Product_Description__c IN :productNameSet');
        if (!productModelSet.isEmpty())
            conditions.add('Product_Model__c IN :productModelSet');

        // smart filters (include null records if null in set)
        if (!sphericalPowerSet.isEmpty()) {
            if (sphericalPowerSet.contains(null))
                conditions.add('(Spherical_power__c = NULL OR Spherical_power__c IN :sphericalPowerSet)');
            else
                conditions.add('Spherical_power__c IN :sphericalPowerSet');
        }

        if (!cylindricalPowerSet.isEmpty()) {
            if (cylindricalPowerSet.contains(null))
                conditions.add('(Cylinder_Power__c = NULL OR Cylinder_Power__c IN :cylindricalPowerSet)');
            else
                conditions.add('Cylinder_Power__c IN :cylindricalPowerSet');
        }

        if (!axisAngleSet.isEmpty()) {
            if (axisAngleSet.contains(null))
                conditions.add('(Axis__c = NULL OR Axis__c IN :axisAngleSet)');
            else
                conditions.add('Axis__c IN :axisAngleSet');
        }

        if (!diaptorSet.isEmpty()) {
            if (diaptorSet.contains(null))
                conditions.add('(Diaptor__c = NULL OR Diaptor__c IN :diaptorSet)');
            else
                conditions.add('Diaptor__c IN :diaptorSet');
        }

        if (conditions.isEmpty()) {
            System.debug('Skipping query execution — empty filter sets.');
            return '';
        }

        Double data = 0;
        String query = 'SELECT Id, Name, Product_Quantity__c, Country__c, Sl_No__c, Divison__c, ' +
                       'Product_Code_SAP_Code__c, Product_Model__c, Dummy_Product_Description__c, Dummy_ID_Code__c, ' +
                       'Spherical_power__c, Hydrophilic_Size__c, Business_Vertical__c, Category__c, Sub_Category__c, ' +
                       'Brand__c, Group_Name__c, Cylinder_Power__c, Axis__c, Diaptor__c, Priority__c ' +
                       'FROM Sample_Request_Product__c WHERE ' + String.join(conditions, ' AND ') +
                       ' AND Priority__c != NULL AND Priority__c != :data ORDER BY Priority__c ASC';

        System.debug('Query Executed: ' + query);

        List<Sample_Request_Product__c> saplproductlist = Database.query(query);
        System.debug('saplproductlist size: ' + saplproductlist.size());

        // Map unique SRP records
        Map<String, Sample_Request_Product__c> srpdatamap = new Map<String, Sample_Request_Product__c>();
        for (Sample_Request_Product__c srpdata : saplproductlist) {
            String key =
                (srpdata.Dummy_Product_Description__c != null ? srpdata.Dummy_Product_Description__c : '') +
                (srpdata.Product_Model__c != null ? srpdata.Product_Model__c : '') +
                (srpdata.Spherical_power__c != null ? srpdata.Spherical_power__c : '') +
                (srpdata.Cylinder_Power__c != null ? srpdata.Cylinder_Power__c : '') +
                (srpdata.Axis__c != null ? srpdata.Axis__c : '') +
                (srpdata.Diaptor__c != null ? srpdata.Diaptor__c : '');

            if (!srpdatamap.containsKey(key))
                srpdatamap.put(key, srpdata);
        }

        // create header
        Sample_Request_Header__c srhrecord = new Sample_Request_Header__c();
        srhrecord.Remarks__c = remark;
        String objectName = recordId.getSObjectType().getDescribe().getName();

        if (objectName == 'Account') {
            Account acc = [SELECT Id, SAP_Code__c, Name, RSM__c, ZSM__c, BillingCountry FROM Account WHERE Id = :recordId];
            srhrecord.Date__c = System.today();
            srhrecord.Customer__c = acc.Id;
            srhrecord.Ship_To_Code__c = acc.SAP_Code__c;
            srhrecord.Bill_To_Code__c = sapCode;
            srhrecord.Country__c = acc.BillingCountry;
            if (acc.RSM__c != null) srhrecord.RSM__c = acc.RSM__c;
            if (acc.ZSM__c != null) srhrecord.ZSM__c = acc.ZSM__c;
            insert srhrecord;
        } else {
            Lead__c lead = [SELECT Id, SAP_Code__c, Name, RSM__c, GM_NSM__c, ZSM__c, Country__c FROM Lead__c WHERE Id = :recordId];
            srhrecord.Date__c = System.today();
            srhrecord.Leads__c = lead.Id;
            srhrecord.Ship_To_Code__c = lead.SAP_Code__c;
            srhrecord.Bill_To_Code__c = lead.SAP_Code__c;
            srhrecord.Country__c = lead.Country__c;

            if (lead.RSM__c != null && lead.ZSM__c != null) {
                srhrecord.RSM__c = lead.RSM__c;
                srhrecord.ZSM__c = lead.ZSM__c;
            } else if (lead.ZSM__c != null && lead.GM_NSM__c != null) {
                srhrecord.RSM__c = lead.ZSM__c;
                srhrecord.ZSM__c = lead.GM_NSM__c;
            } else {
                if (lead.RSM__c != null) srhrecord.RSM__c = lead.RSM__c;
                if (lead.ZSM__c != null) srhrecord.ZSM__c = lead.ZSM__c;
                if ((lead.RSM__c == null || lead.ZSM__c == null) && lead.GM_NSM__c != null)
                    srhrecord.ZSM__c = lead.GM_NSM__c;
            }
            insert srhrecord;
        }

        // Create line items
        List<Sample_Request_Line_Item__c> newSampleRequests = new List<Sample_Request_Line_Item__c>();
        for (Sample_Request_Product__c srp : srpdatamap.values()) {
            String key =
                (srp.Dummy_Product_Description__c != null ? srp.Dummy_Product_Description__c : '') +
                (srp.Product_Model__c != null ? srp.Product_Model__c : '') +
                (srp.Spherical_power__c != null ? srp.Spherical_power__c : '') +
                (srp.Cylinder_Power__c != null ? srp.Cylinder_Power__c : '') +
                (srp.Axis__c != null ? srp.Axis__c : '') +
                (srp.Diaptor__c != null ? srp.Diaptor__c : '');

            if (qtyMap.containsKey(key)) {
                Sample_Request_Line_Item__c newRequest = new Sample_Request_Line_Item__c(
                    Dummy_Product_Description__c = srp.Dummy_Product_Description__c,
                    Product_Model__c = srp.Product_Model__c,
                    Spherical_Power__c = srp.Spherical_power__c,
                    Cylinder_Power__c = srp.Cylinder_Power__c,
                    Axis__c = srp.Axis__c,
                    Diaptor__c = srp.Diaptor__c,
                    Priority__c = srp.Priority__c,
                    Product_Quantity__c = qtyMap.get(key),
                    Country__c = srp.Country__c,
                    Sl_No__c = srp.Sl_No__c,
                    Divison__c = srp.Divison__c,
                    Product_Code_SAP_Code__c = srp.Product_Code_SAP_Code__c,
                    Dummy_ID_Code__c = srp.Dummy_ID_Code__c,
                    Hydrophilic_Size__c = srp.Hydrophilic_Size__c,
                    Business_Vertical__c = srp.Business_Vertical__c,
                    Category__c = srp.Category__c,
                    Sub_Category__c = srp.Sub_Category__c,
                    Brand__c = srp.Brand__c,
                    Group_Name__c = srp.Group_Name__c,
                    Product_Name__c = srp.Id,
                    Sample_Request_Header__c = srhrecord.Id
                );

                if (objectName == 'Account') newRequest.Account__c = recordId;
                else newRequest.Lead__c = recordId;

                newSampleRequests.add(newRequest);
            } 
        }

        if (!newSampleRequests.isEmpty()) {
            insert newSampleRequests;
            Sample_Request_Header__c srhrecorddata = [SELECT Id, Isapproval__c FROM Sample_Request_Header__c WHERE Id = :srhrecord.Id];
            if (srhrecorddata != null) {
                srhrecorddata.Isapproval__c = true;
                update srhrecorddata;
            }
            System.debug('Inserted Line Items: ' + newSampleRequests.size());
            return 'success';
        } else {
            System.debug('No records to insert.');
            return '';
        }

    } catch (Exception e) {
        System.debug('Error: ' + e.getMessage() + ' at line ' + e.getLineNumber());
        throw new AuraHandledException('Error processing data: ' + e.getMessage());
    }
}

    
    
    
    
    @AuraEnabled
    public static String saveSampleRequestDataformultiplecustomer(List<Map<String, String>> finalData, List<String> accIds,List<String> leadIds) {
        try {
            System.debug('AccList: ' + accIds);
            system.debug('leadIds:' + leadIds);
            system.debug('finalData'+ JSON.serialize(finalData));
            List<Sample_Request_Line_Item__c> newSampleRequests = new List<Sample_Request_Line_Item__c>();
            //Sample_Request_Header__c srhrecord =new  Sample_Request_Header__c();
            list<Sample_Request_Header__c> srhrecordlist = new  list<Sample_Request_Header__c>();
            List<Account> Accdatalist = [select Id,Name,RSM__c,ZSM__c,SAP_code__c,BillingCountry from Account where Id IN:accIds];
            List<lead__c> leadlistdata = [select Id,Name,RSM__c,GM_NSM__c,ZSM__c,SAP_code__c,Country__c from Lead__c where Id IN:leadIds];
            
            // Sets for unique values
            Set<String> productNameSet = new Set<String>();
            Set<String> productModelSet = new Set<String>();
            Set<String> sphericalPowerSet = new Set<String>();
            Set<String> axisAngleSet = new Set<String>();
            Set<String> cylindricalPowerSet = new Set<String>();
            Set<String> diaptorSet = new Set<String>();
            double commercialQuantityset ;
            string remarkvalue;
            
            for (Map<String, String> row : finalData) {
                System.debug('Row Data: ' + row);
                
                // Adding values to respective sets
                if (String.isNotBlank(row.get('productName'))) {
                    productNameSet.add(row.get('productName'));
                }
                if (String.isNotBlank(row.get('productModel'))) {
                    productModelSet.add(row.get('productModel'));
                }
                if (String.isNotBlank(row.get('sphericalPower'))) {
                    sphericalPowerSet.add(row.get('sphericalPower'));
                }
                if (String.isNotBlank(row.get('axisAngle'))) {
                    axisAngleSet.add(row.get('axisAngle'));
                }
                if (String.isNotBlank(row.get('cylindricalPower'))) {
                    cylindricalPowerSet.add(row.get('cylindricalPower'));
                }
                if (String.isNotBlank(row.get('diaptor'))) {
                    diaptorSet.add(row.get('diaptor'));
                }
                if (String.isNotBlank(row.get('commercialQuantity'))) {
                    commercialQuantityset=(Double.valueOf(row.get('commercialQuantity')));
                }
                if (String.isNotBlank(row.get('remark'))) {
                    remarkvalue=(string.valueOf(row.get('remark')));
                }
                
                
            }
            
            // Constructing dynamic WHERE conditions
            List<String> conditions = new List<String>();
            if (!productNameSet.isEmpty()) conditions.add('Dummy_Product_Description__c IN :productNameSet');
            if (!productModelSet.isEmpty()) conditions.add('Product_Model__c IN :productModelSet');
            if (!sphericalPowerSet.isEmpty()) conditions.add('Spherical_power__c IN :sphericalPowerSet');
            if (!cylindricalPowerSet.isEmpty()) conditions.add('Cylinder_Power__c IN :cylindricalPowerSet');
            if (!axisAngleSet.isEmpty()) conditions.add('Axis__c IN :axisAngleSet');
            if (!diaptorSet.isEmpty()) conditions.add('Diaptor__c IN :diaptorSet');
            
            if (conditions.isEmpty()) {
                System.debug('Skipping query execution due to empty filter values.');
                return '';
            }
            
            // Forming the final query conditionally
            double data = 0;
            
            String query = 'SELECT Id, Name, Product_Quantity__c, Country__c, Sl_No__c, Divison__c, Product_Code_SAP_Code__c, ' + 
                'Product_Model__c, Dummy_Product_Description__c, Dummy_ID_Code__c, Spherical_power__c, ' + 
                'Hydrophilic_Size__c, Business_Vertical__c, Category__c, Sub_Category__c, Brand__c, ' + 
                'Group_Name__c, Cylinder_Power__c, Axis__c, Diaptor__c, Priority__c ' + 
                'FROM Sample_Request_Product__c WHERE ';
            
            // Add conditions only if they exist
            if (!conditions.isEmpty()) {
                query += String.join(conditions, ' AND ') + ' AND ';
            }
            
            // Append the Priority__c conditions properly
            query += 'Priority__c != NULL AND Priority__c != :data ORDER BY Priority__c ASC';
            
            
            // Execute dynamic query
            List<Sample_Request_Product__c> saplproductlist = Database.query(query);
            System.debug('Query Executed: ' + query);
            System.debug('saplproductlist: ' + saplproductlist);
            
            // Map to store unique combinations of product attributes
            Map<String, Sample_Request_Product__c> srpdatamap = new Map<String, Sample_Request_Product__c>();
            
            
            for (Sample_Request_Product__c srpdata : saplproductlist) {
                String key = srpdata.Dummy_Product_Description__c + '-' + srpdata.Product_Model__c + '-' + 
                    srpdata.Spherical_power__c + '-' + srpdata.Cylinder_Power__c + '-' + 
                    srpdata.Axis__c + '-' + srpdata.Diaptor__c;
                if (!srpdatamap.containsKey(key)) {
                    srpdatamap.put(key, srpdata);
                }
            }
            
            if (leadlistdata.size() > 0) {
                for (Lead__c lead : leadlistdata) {
                    Sample_Request_Header__c srhrecord = new Sample_Request_Header__c();
                    srhrecord.Date__c = System.today();
                    srhrecord.Leads__c = lead.Id;
                    if (lead.RSM__c != null && lead.ZSM__c != null) {
                        srhrecord.RSM__c = lead.RSM__c;
                        srhrecord.ZSM__c = lead.ZSM__c;
                    } else {
                        if (lead.RSM__c == null && lead.ZSM__c != null && lead.GM_NSM__c != null) {
                            srhrecord.RSM__c = lead.ZSM__c;
                            srhrecord.ZSM__c = lead.GM_NSM__c;
                        } else {
                            if (lead.RSM__c == null && lead.ZSM__c != null) {
                                srhrecord.RSM__c = lead.ZSM__c;
                            }
                            if (lead.RSM__c != null && lead.ZSM__c == null) {
                                srhrecord.RSM__c = lead.RSM__c;
                            }
                            if ((lead.RSM__c == null || lead.ZSM__c == null) && lead.GM_NSM__c != null) {
                                srhrecord.ZSM__c = lead.GM_NSM__c;
                            }
                        }
                    }
                    
                    
                    srhrecord.Ship_To_Code__c = lead.SAP_Code__c;
                    srhrecord.Bill_To_Code__c = lead.SAP_Code__c;
                    srhrecord.remarks__c = remarkvalue;
                    srhrecord.Country__c = lead.Country__c;
                    srhrecordlist.add(srhrecord);
                }
            }
            
            if (Accdatalist.size() > 0) {
                for (Account acc : Accdatalist) {
                    Sample_Request_Header__c srhrecord = new Sample_Request_Header__c();
                    srhrecord.Date__c = System.today();
                    srhrecord.Customer__c = acc.Id;
                    if(acc.RSM__c != null){
                        srhrecord.RSM__c =acc.RSM__c;
                    }if(acc.ZSM__c != null){
                        srhrecord.ZSM__c = acc.ZSM__c; 
                    }
                    srhrecord.Country__c = acc.BillingCountry;
                    srhrecord.Ship_To_Code__c = acc.SAP_Code__c;
                    srhrecord.Bill_To_Code__c =  acc.SAP_Code__c;
                    srhrecord.Remarks__c = remarkvalue;
                    srhrecordlist.add(srhrecord);
                }
            }
            
            if (srhrecordlist.size() > 0) {
                insert srhrecordlist;
            }
            
            Map<Id, Id> sampleHeaderMap = new Map<Id, Id>();
            
            for (Sample_Request_Header__c srh : srhrecordlist) {
                if (srh.Leads__c != null && !sampleHeaderMap.containsKey(srh.Leads__c)) {
                    sampleHeaderMap.put(srh.Leads__c, srh.Id);
                }
                
                if (srh.Customer__c != null && !sampleHeaderMap.containsKey(srh.Customer__c)) {
                    sampleHeaderMap.put(srh.Customer__c, srh.Id);
                }
            }
            
            
            if(leadlistdata.size()>0){
                for (lead__c lead : leadlistdata) {
                    
                    for (Sample_Request_Product__c srp : srpdatamap.values()) {
                        Sample_Request_Line_Item__c newRequest = new Sample_Request_Line_Item__c();
                        newRequest.Dummy_Product_Description__c = srp.Dummy_Product_Description__c;
                        newRequest.Product_Model__c = srp.Product_Model__c;
                        newRequest.Spherical_Power__c = srp.Spherical_power__c;
                        newRequest.Cylinder_Power__c = srp.Cylinder_Power__c;
                        newRequest.Axis__c = srp.Axis__c;
                        newRequest.Sample_Request_Header__c = sampleHeaderMap.get(lead.Id);
                        newRequest.Diaptor__c = srp.Diaptor__c;
                        newRequest.Priority__c = srp.Priority__c;
                        
                        if(commercialQuantityset !=null){
                            newRequest.Product_Quantity__c = commercialQuantityset;
                        }
                        if(remarkvalue !=null){
                            //newRequest.remark__c = remarkvalue;
                        }
                        newRequest.Country__c = srp.Country__c;                    
                        newRequest.Sl_No__c = srp.Sl_No__c;
                        newRequest.Divison__c = srp.Divison__c;
                        newRequest.Product_Code_SAP_Code__c = srp.Product_Code_SAP_Code__c;
                        newRequest.Dummy_ID_Code__c = srp.Dummy_ID_Code__c;
                        newRequest.Hydrophilic_Size__c = srp.Hydrophilic_Size__c;
                        newRequest.Business_Vertical__c = srp.Business_Vertical__c;
                        newRequest.Category__c = srp.Category__c;
                        newRequest.Sub_Category__c = srp.Sub_Category__c;
                        newRequest.Brand__c = srp.Brand__c;
                        newRequest.Group_Name__c = srp.Group_Name__c;
                        newRequest.Product_Name__c = srp.Id;
                        newRequest.Lead__c = lead.Id;
                        //newRequest.RSM__c = lead.RSM__c;
                        //newRequest.ZSM__c = lead.ZSM__c;
                        //newRequest.Sold_To_Code__c = lead.SAP_Code__c;
                        //newRequest.Bill_To_Code__c = lead.SAP_Code__c;
                        
                        
                        newSampleRequests.add(newRequest);
                    }
                }
            }
            if(Accdatalist.size()>0){
                for (Account accId : Accdatalist) {
                    for (Sample_Request_Product__c srp : srpdatamap.values()) {
                        Sample_Request_Line_Item__c newRequest = new Sample_Request_Line_Item__c();
                        newRequest.Dummy_Product_Description__c = srp.Dummy_Product_Description__c;
                        newRequest.Product_Model__c = srp.Product_Model__c;
                        newRequest.Spherical_Power__c = srp.Spherical_power__c;
                        newRequest.Cylinder_Power__c = srp.Cylinder_Power__c;
                        newRequest.Axis__c = srp.Axis__c;
                        newRequest.Diaptor__c = srp.Diaptor__c;
                        newRequest.Priority__c = srp.Priority__c;
                        
                        newRequest.Sample_Request_Header__c = sampleHeaderMap.get(accId.Id);
                        if(commercialQuantityset !=null){
                            newRequest.Product_Quantity__c = commercialQuantityset;
                        }
                        if(remarkvalue !=null){
                            //newRequest.remark__c = remarkvalue;
                        }
                        newRequest.Country__c = srp.Country__c;
                        newRequest.Sl_No__c = srp.Sl_No__c;
                        newRequest.Divison__c = srp.Divison__c;
                        newRequest.Product_Code_SAP_Code__c = srp.Product_Code_SAP_Code__c;
                        newRequest.Dummy_ID_Code__c = srp.Dummy_ID_Code__c;
                        newRequest.Hydrophilic_Size__c = srp.Hydrophilic_Size__c;
                        newRequest.Business_Vertical__c = srp.Business_Vertical__c;
                        newRequest.Category__c = srp.Category__c;
                        newRequest.Sub_Category__c = srp.Sub_Category__c;
                        newRequest.Brand__c = srp.Brand__c;
                        newRequest.Group_Name__c = srp.Group_Name__c;
                        newRequest.Product_Name__c = srp.Id;
                        newRequest.Account__c = accId.Id;
                        //newRequest.RSM__c = accId.RSM__c;
                        //newRequest.ZSM__c = accId.ZSM__c;
                        //newRequest.Sold_To_Code__c = accId.SAP_Code__c;
                        // newRequest.Bill_To_Code__c = accId.SAP_Code__c;
                        
                        
                        newSampleRequests.add(newRequest);
                        
                    }
                }
            }
            // Insert new records
            if (!newSampleRequests.isEmpty()) {
                insert newSampleRequests;
                
                List<Sample_Request_Header__c> srhrecorddataList =[select id,Isapproval__c from Sample_Request_Header__c where Id in:srhrecordlist];
                for(Sample_Request_Header__c srm:srhrecorddataList) {
                    srm.Isapproval__c = true;
                }
                if(srhrecorddataList.size()>0){
                    update srhrecorddataList;
                }
                System.debug('Inserted Sample_Request_Line_Item__c records: ' + newSampleRequests.size());
                return 'success';
            } else {
                System.debug('No records to insert.');
                return '';
            }
            
        } catch (Exception e) {
            throw new AuraHandledException('Error processing data: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<string , object> getcustomerdata(string country) {
        system.debug('country'+country);
        Map<string , object> returnMap = new  Map<string , object>();
        List<Account> finalAccList=new List<Account>();
        Set<Id> accIdSet=new Set<Id>();
        Map<String,String> accIdCheckMap=new Map<String,String>();
        List<Account> acc = [Select Id , Name, E_Mail__c, Phone, SAP_Code__c,BillingCity,BillingState,BillingPostalCode, CE_CIS_Rating__c, Phakic_Rating__c, Status__c,BillingCountry 
                             from Account
                             Where CE_CIS_Rating__c != null 
                             AND Phakic_Rating__c != null 
                             AND SAP_Code__c != null 
                             AND BillingCountry =: country
                             AND Status__c = 'Activated'];
        
        List<Lead__c> leadlist = [Select Id ,Name,Email__c, Mobile__c, SAP_Code__c,City_postal_code__c,CE_CIS_Rating__c, Phakic_Rating__c,Country__c,Billing_code__c
                                  from Lead__c
                                  Where CE_CIS_Rating__c != null 
                                  AND Phakic_Rating__c != null 
                                  AND SAP_Code__c != null 
                                  AND Lead_closed__c =:false
                                  AND (Lead_stage__c != 'Unqualified' OR Lead_stage__c != 'Lost')
                                  AND Country__c  =: country ];
        
        
        
        // Adding the invoice and line items to the return map
        returnMap.put('account', acc);
        returnMap.put('leadlist',leadlist);
        return returnMap;
    }
    
    @AuraEnabled(cacheable=true)
    public static String getCountries() {
        String countryName;
        
        // Fetching the current user's Country__c field
        User currentUser = [SELECT Country__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        
        if(currentUser.Country__c !=null){
            countryName = currentUser.Country__c;
        }else{
            countryName = '';
        }
        
        
        
        return countryName;
    }
    
    
    @AuraEnabled(cacheable=true)
    public static Sample_Request_Module_labels__c getCustomLabels() {
        String language=UserInfo.getLanguage();
        Sample_Request_Module_labels__c leadTranslationLabel = Sample_Request_Module_labels__c.getValues(language);
        return leadTranslationLabel;
        
    }
    
    
    
}