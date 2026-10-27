public with sharing class GenericUploadController {
    
    /* =========================================================
SAMPLE CSV GENERATOR (METADATA + FALLBACK + RECORD TYPE LABEL FIX)
========================================================= */
    @AuraEnabled
    public static String generateSampleCSV(String objectApiName, String templateType) {
        
        List<String> visibleColumns = new List<String>();
        
        // Try metadata config (do not fail if missing)
        List<Data_Upload_Template_Config__mdt> configs =
            [SELECT Object_Columns_Visible__c
             FROM Data_Upload_Template_Config__mdt
             WHERE Object_API_Name__c = :objectApiName AND Template_Type__c = :templateType
             LIMIT 1];
        
        System.debug('objectApiName => ' + objectApiName);
        System.debug('templateType => ' + templateType);
        System.debug('configs => ' + configs);
        
        if (!configs.isEmpty()
            && String.isNotBlank(configs[0].Object_Columns_Visible__c)) {
                
                visibleColumns =
                    (List<String>) JSON.deserialize(
                        configs[0].Object_Columns_Visible__c,
                        List<String>.class
                    );
            }
        
        Schema.SObjectType objType =
            Schema.getGlobalDescribe().get(objectApiName);
        Map<String, Schema.SObjectField> fieldMap =
            objType.getDescribe().fields.getMap();
        
        List<String> apiNames = new List<String>();
        List<String> labels = new List<String>();
        
        // Use metadata-defined columns if present
        if (!visibleColumns.isEmpty()) {
            
            for (String fieldApi : visibleColumns) {
                if (!fieldMap.containsKey(fieldApi)) continue;
                
                Schema.DescribeFieldResult d =
                    fieldMap.get(fieldApi).getDescribe();
                
                if (d.isCreateable() && !d.isCalculated()) {
                    apiNames.add(fieldApi);
                    
                    // Special label for RecordTypeId
                    if (fieldApi == 'RecordTypeId') {
                        labels.add('Record Type Name');
                    } else {
                        labels.add(d.getLabel());
                    }
                }
            }
        }
        // Fallback to all createable fields
        else {
            for (Schema.SObjectField f : fieldMap.values()) {
                
                Schema.DescribeFieldResult d = f.getDescribe();
                
                if (d.isCreateable()
                    && !d.isCalculated()
                    && !d.getName().endsWith('__pc')
                    && !d.getName().endsWith('__pr')) {
                        
                        apiNames.add(d.getName());
                        
                        if (d.getName() == 'RecordTypeId') {
                            labels.add('Record Type Name');
                        } else {
                            labels.add(d.getLabel());
                        }
                    }
            }
        }
        
        String csv =
            '##API_NAMES##\n' +
            String.join(apiNames, ',') + '\n' +
            '##LABELS##\n' +
            String.join(labels, ',') + '\n' +
            '##DATA##\n';
        
        return csv;
    }
    
    
    @AuraEnabled
    public static String uploadRecords(String objectApiName, String csvBody) {
        
        /* ================= NORMALIZE CSV ================= */
        csvBody = csvBody
            .replace('\uFEFF', '')
            .replace('\r\n', '\n')
            .replace('\r', '\n');
        
        List<String> rows = csvBody.split('\n');
        
        if (rows.isEmpty()) {
            return 'Row,Status,RecordId,FailureReason\n';
        }
        
        /* ================= FIND MARKERS ================= */
        Integer apiRowIndex  = -1;
        Integer dataRowIndex = -1;
        
        for (Integer i = 0; i < rows.size(); i++) {
            String r = rows[i].trim();
            if (r.contains('##API_NAMES##')) apiRowIndex  = i + 1;
            if (r.contains('##DATA##'))      dataRowIndex = i + 1;
        }
        
        if (apiRowIndex < 0 || dataRowIndex < 0 || apiRowIndex >= rows.size()) {
            throw new AuraHandledException(
                'Invalid CSV format. Please use the sample file.'
            );
        }
        
        List<String> headers = parseCsvRow(rows[apiRowIndex]);
        
        /* ================= DESCRIBE OBJECT ================= */
        Schema.SObjectType objType =
            Schema.getGlobalDescribe().get(objectApiName);
        Map<String, Schema.SObjectField> fieldMap =
            objType.getDescribe().fields.getMap();
        
        /* ================= DESIGNATION TEXT FIELD → USER FIELD MAPPING ================= */
        // For text fields that store a designation/title
        // and need to be mapped to an actual User lookup field
        Map<String, String> designationToUserFieldMap = new Map<String, String>{
            'Owner_Designation__c' => 'OwnerId'
                };
                    
                    /* ================= LOOKUP FIELD DETECTION ================= */
                    Map<String, Schema.DescribeFieldResult> lookupFields     = new Map<String, Schema.DescribeFieldResult>();
        Map<String, Schema.DescribeFieldResult> userLookupFields = new Map<String, Schema.DescribeFieldResult>();
        
        for (String field : headers) {
            // Skip designation text fields - handled separately
            if (designationToUserFieldMap.containsKey(field)) continue;
            
            if (!fieldMap.containsKey(field)) continue;
            
            Schema.DescribeFieldResult d = fieldMap.get(field).getDescribe();
            
            if (d.getType() == Schema.DisplayType.REFERENCE
                && field != 'RecordTypeId') {
                    
                    // Check ALL reference types (handles polymorphic like OwnerId)
                    Boolean isUserLookup = false;
                    for (Schema.SObjectType refType : d.getReferenceTo()) {
                        if (refType.getDescribe().getName() == 'User') {
                            isUserLookup = true;
                            break;
                        }
                    }
                    
                    if (isUserLookup) {
                        userLookupFields.put(field, d);
                    } else {
                        lookupFields.put(field, d);
                    }
                }
        }
        
        /* ================= RECORD TYPE ================= */
        Integer     rtIndex         = headers.indexOf('RecordTypeId');
        Set<String> recordTypeNames = new Set<String>();
        
        if (rtIndex >= 0) {
            for (Integer i = dataRowIndex; i < rows.size(); i++) {
                if (String.isBlank(rows[i])) continue;
                List<String> values = parseCsvRow(rows[i]);
                if (values.size() > rtIndex && !String.isBlank(values[rtIndex])) {
                    recordTypeNames.add(values[rtIndex].trim());
                }
            }
        }
        
        Map<String, Id> recordTypeNameToId = new Map<String, Id>();
        if (!recordTypeNames.isEmpty()) {
            for (RecordType rt : [
                SELECT Id, Name
                FROM RecordType
                WHERE SObjectType = :objectApiName
                AND Name IN :recordTypeNames
            ]) {
                recordTypeNameToId.put(rt.Name, rt.Id);
            }
        }
        
        /* ================= COLLECT ALL TITLES FROM CSV ================= */
        // Collect from both designation text fields and user lookup fields
        Set<String> allTitles = new Set<String>();
        
        for (Integer i = dataRowIndex; i < rows.size(); i++) {
            if (String.isBlank(rows[i])) continue;
            List<String> values = parseCsvRow(rows[i]);
            
            for (Integer j = 0; j < headers.size(); j++) {
                String h = headers[j];
                if ((designationToUserFieldMap.containsKey(h)
                     || userLookupFields.containsKey(h))
                    && j < values.size()
                    && !String.isBlank(values[j])) {
                        allTitles.add(values[j].trim());
                    }
            }
        }
        
        /* ================= QUERY ACTIVE USERS BY TITLE (1 SOQL) ================= */
        Map<String, Id>      titleToUserId   = new Map<String, Id>();
        Map<String, Boolean> duplicateTitles = new Map<String, Boolean>();
        
        if (!allTitles.isEmpty()) {
            Map<String, List<Id>> titleToIds = new Map<String, List<Id>>();
            
            for (User u : [
                SELECT Id, Title
                FROM User
                WHERE Title IN :allTitles
                AND IsActive = true
            ]) {
                if (!titleToIds.containsKey(u.Title)) {
                    titleToIds.put(u.Title, new List<Id>());
                }
                titleToIds.get(u.Title).add(u.Id);
            }
            
            for (String title : titleToIds.keySet()) {
                if (titleToIds.get(title).size() == 1) {
                    titleToUserId.put(title, titleToIds.get(title)[0]);
                } else {
                    duplicateTitles.put(title, true);
                }
            }
        }
        
        /* ================= COLLECT OTHER LOOKUP VALUES FROM CSV ================= */
        Map<String, Set<String>> lookupValues = new Map<String, Set<String>>();
        
        for (String f : lookupFields.keySet()) {
            lookupValues.put(f, new Set<String>());
        }
        
        for (Integer i = dataRowIndex; i < rows.size(); i++) {
            if (String.isBlank(rows[i])) continue;
            List<String> values = parseCsvRow(rows[i]);
            
            for (Integer j = 0; j < headers.size(); j++) {
                String field = headers[j];
                if (lookupFields.containsKey(field)
                    && j < values.size()
                    && !String.isBlank(values[j])) {
                        lookupValues.get(field).add(values[j].trim());
                    }
            }
        }
        
        /* ================= RESOLVE OTHER LOOKUPS (DUPLICATE-SAFE) ================= */
        Map<String, Map<String, Id>> resolvedLookups       = new Map<String, Map<String, Id>>();
        Map<String, Set<String>>     duplicateLookupValues = new Map<String, Set<String>>();
        
        for (String field : lookupFields.keySet()) {
            
            Set<String> lookupSet = lookupValues.get(field);
            if (lookupSet.isEmpty()) continue;
            
            Schema.SObjectType refType =
                lookupFields.get(field).getReferenceTo()[0];
            
            String soql =
                'SELECT Id, Name FROM ' +
                refType.getDescribe().getName() +
                ' WHERE Name IN :lookupSet';
            
            List<SObject> recs = Database.query(soql);
            
            Map<String, List<Id>> nameToIds = new Map<String, List<Id>>();
            for (SObject s : recs) {
                String name = (String) s.get('Name');
                if (!nameToIds.containsKey(name)) {
                    nameToIds.put(name, new List<Id>());
                }
                nameToIds.get(name).add((Id) s.get('Id'));
            }
            
            Map<String, Id> resolved   = new Map<String, Id>();
            Set<String>     duplicates = new Set<String>();
            
            for (String name : nameToIds.keySet()) {
                if (nameToIds.get(name).size() == 1) {
                    resolved.put(name, nameToIds.get(name)[0]);
                } else {
                    duplicates.add(name);
                }
            }
            
            resolvedLookups.put(field, resolved);
            duplicateLookupValues.put(field, duplicates);
        }
        
        /* ================= REQUIRED FIELDS ================= */
        Set<String> requiredFields = new Set<String>();
        for (Schema.SObjectField f : fieldMap.values()) {
            Schema.DescribeFieldResult d = f.getDescribe();
            if (!d.isNillable() && !d.isDefaultedOnCreate()) {
                requiredFields.add(d.getName());
            }
        }
        
        /* ================= PROCESS ROWS ================= */
        List<SObject>             toInsert = new List<SObject>();
        List<Map<String, String>> results  = new List<Map<String, String>>();
        
        for (Integer i = dataRowIndex; i < rows.size(); i++) {
            
            if (String.isBlank(rows[i])) continue;
            List<String> values = parseCsvRow(rows[i]);
            
            SObject sobj  = objType.newSObject();
            String  error = '';
            
            for (Integer j = 0; j < headers.size(); j++) {
                
                String field = headers[j];
                String value = j < values.size() ? values[j].trim() : '';
                
                /* ---- Designation Text → OwnerId (resolve by Title) ---- */
                if (designationToUserFieldMap.containsKey(field)) {
                    if (String.isBlank(value)) continue;
                    
                    String targetField = designationToUserFieldMap.get(field);
                    
                    if (duplicateTitles.containsKey(value)) {
                        error += 'Multiple active users found with title "'
                            + value + '"; ';
                    } else if (!titleToUserId.containsKey(value)) {
                        error += 'No active user found with title "'
                            + value + '"; ';
                    } else {
                        try {
                            sobj.put(targetField, titleToUserId.get(value));
                        } catch (Exception e) {
                            error += 'Could not set ' + targetField
                                + ': ' + e.getMessage() + '; ';
                        }
                    }
                    continue;
                }
                
                /* ---- User Lookup → resolve by Title + IsActive ---- */
                if (userLookupFields.containsKey(field)) {
                    if (String.isBlank(value)) continue;
                    
                    if (duplicateTitles.containsKey(value)) {
                        error += 'Multiple active users found with title "'
                            + value + '"; ';
                    } else if (!titleToUserId.containsKey(value)) {
                        error += 'No active user found with title "'
                            + value + '"; ';
                    } else {
                        try {
                            sobj.put(field, titleToUserId.get(value));
                        } catch (Exception e) {
                            error += 'Could not set ' + field
                                + ': ' + e.getMessage() + '; ';
                        }
                    }
                    continue;
                }
                
                if (String.isBlank(value)) {
                    if (requiredFields.contains(field)) {
                        error += field + ' is required; ';
                    }
                    continue;
                }
                
                /* ---- Record Type ---- */
                if (field == 'RecordTypeId') {
                    if (!recordTypeNameToId.containsKey(value)) {
                        error += 'Invalid Record Type: ' + value + '; ';
                    } else {
                        sobj.put('RecordTypeId', recordTypeNameToId.get(value));
                    }
                    continue;
                }
                
                /* ---- Other Lookup → resolve by Name ---- */
                if (lookupFields.containsKey(field)) {
                    if (duplicateLookupValues.get(field).contains(value)) {
                        error += 'Multiple records found for ' + field
                            + ' with value "' + value + '"; ';
                        continue;
                    }
                    Map<String, Id> mapIds = resolvedLookups.get(field);
                    if (mapIds == null || !mapIds.containsKey(value)) {
                        error += 'Lookup not found for ' + field
                            + ': ' + value + '; ';
                    } else {
                        sobj.put(field, mapIds.get(value));
                    }
                    continue;
                }
                
                if (!fieldMap.containsKey(field)) continue;
                
                Schema.DescribeFieldResult d =
                    fieldMap.get(field).getDescribe();
                
                try {
                    if (d.getType() == Schema.DisplayType.DATE) {
                        List<String> p = value.split('-');
                        sobj.put(field,
                                 Date.newInstance(
                                     Integer.valueOf(p[2]),
                                     Integer.valueOf(p[1]),
                                     Integer.valueOf(p[0])
                                 )
                                );
                    }
                    else if (d.getType() == Schema.DisplayType.DATETIME) {
                        List<String> dt  = value.split(' ');
                        List<String> dte = dt[0].split('-');
                        Integer h = dt.size() > 1
                            ? Integer.valueOf(dt[1].split(':')[0]) : 0;
                        Integer m = dt.size() > 1
                            ? Integer.valueOf(dt[1].split(':')[1]) : 0;
                        sobj.put(field,
                                 DateTime.newInstance(
                                     Integer.valueOf(dte[2]),
                                     Integer.valueOf(dte[1]),
                                     Integer.valueOf(dte[0]),
                                     h, m, 0
                                 )
                                );
                    }
                    else {
                        switch on d.getType() {
                            when DOUBLE, CURRENCY, PERCENT {
                                sobj.put(field, Decimal.valueOf(value));
                            }
                            when INTEGER {
                                sobj.put(field, Integer.valueOf(value));
                            }
                            when BOOLEAN {
                                sobj.put(
                                    field,
                                    value.equalsIgnoreCase('true')
                                    || value == '1'
                                    || value.equalsIgnoreCase('yes')
                                );
                            }
                            when else {
                                sobj.put(field, value);
                            }
                        }
                    }
                } catch (Exception e) {
                    error += field + ' has invalid value; ';
                }
            }
            
            Map<String, String> rowResult = new Map<String, String>{
                'Row'    => String.valueOf(i + 1),
                    'Status' => error == '' ? 'Success' : 'Failed',
                        'Reason' => error
                        };
                            results.add(rowResult);
            
            if (error == '') {
                toInsert.add(sobj);
            }
        }
        
        /* ================= INSERT ================= */
        Database.SaveResult[] srList = Database.insert(toInsert, false);
        
        Integer idx = 0;
        for (Map<String, String> r : results) {
            if (r.get('Status') == 'Success') {
                if (srList[idx].isSuccess()) {
                    r.put('RecordId', srList[idx].getId());
                } else {
                    r.put('Status', 'Failed');
                    r.put('Reason', srList[idx].getErrors()[0].getMessage());
                }
                idx++;
            }
        }
        
        /* ================= RESPONSE ================= */
        String response = 'Row,Status,RecordId,FailureReason\n';
        
        for (Map<String, String> r : results) {
            response +=
                r.get('Row')    + ',' +
                r.get('Status') + ',' +
                (r.containsKey('RecordId') ? r.get('RecordId') : '') + ',' +
                (r.containsKey('Reason')   ? r.get('Reason')   : '') + '\n';
        }
        
        return response;
    }
    
    
    
    private static List<String> parseCsvRow(String row) {
        
        List<String> result = new List<String>();
        if (row == null) return result;
        
        Boolean inQuotes = false;
        String current = '';
        
        for (Integer i = 0; i < row.length(); i++) {
            String ch = row.substring(i, i + 1);
            
            if (ch == '"') {
                
                // Handle escaped quotes ("")
                if (inQuotes && i + 1 < row.length()
                    && row.substring(i + 1, i + 2) == '"') {
                        current += '"';
                        i++; // skip next quote
                    } else {
                        inQuotes = !inQuotes;
                    }
                
            } else if (ch == ',' && !inQuotes) {
                result.add(current);
                current = '';
            } else {
                current += ch;
            }
        }
        
        result.add(current);
        return result;
    }
    
}