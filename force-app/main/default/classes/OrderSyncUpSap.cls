public class OrderSyncUpSap {

    private static final Map<String, String> COMPANY_CODE_BY_COUNTRY =
        new Map<String, String>{
            'ES' => '5600',
            'IN' => '1000',
            'TR' => '4000',
            'MA' => '9800',
            'CO' => '4500',
            'DE' => '5500'
        };

    @InvocableMethod(
        label='Sync Order to SAP'
        description='Sends approved sample orders to SAP'
    )
    public static void processRecord(List<Sample_Request_Header__c> records) {

        if (records == null || records.isEmpty()) {
            return;
        }

        Set<Id> recordIds = new Set<Id>();

        for (Sample_Request_Header__c rec : records) {
            if (rec.Id != null) {
                recordIds.add(rec.Id);
            }
        }

        if (!recordIds.isEmpty()) {
            syncOrderData(recordIds);
        }
    }

    @future(callout=true)
    public static void syncOrderData(Set<Id> recordIds) {
        syncOrderDataSync(recordIds, false);
    }

    public static void syncOrderDataSync(Set<Id> recordIds) {
        syncOrderDataSync(recordIds, false);
    }

    public static void syncOrderDataSync(Set<Id> recordIds, Boolean isManualRetry) {

        if (recordIds == null || recordIds.isEmpty()) {
            return;
        }

        Sample_request_Module_Integration__c config =
            Sample_request_Module_Integration__c.getInstance('Order sync to SAP');

        if (config == null) {
            System.debug('ERROR: Integration config "Order sync to SAP" is missing.');
            return;
        }

        List<Sample_Request_Header__c> queriedHeaders = [
            SELECT
                Id, Date__c, Remarks__c, Ship_To_Code__c, Bill_To_Code__c,
                Customer__r.BillingCountry, Message__c, orderNumSAP__c,
                SAP_status__c, Status_Code__c, Request_Body__c,
                First_Failure_Time__c, Retry_Count__c, BackUp_Order_Number__c
            FROM Sample_Request_Header__c
            WHERE Id IN :recordIds
        ];

        if (queriedHeaders.isEmpty()) {
            return;
        }

        // Idempotency guard: never resend a header to SAP once it has already
        // been confirmed Ordered with a real SAP order number. Without this,
        // any retry (manual or scheduled) on a record that was actually
        // created in SAP - but got mismarked Failed due to a matching/parsing
        // issue on our side - would submit a duplicate order to SAP.
        List<Sample_Request_Header__c> headers = new List<Sample_Request_Header__c>();

        for (Sample_Request_Header__c h : queriedHeaders) {
            if (h.SAP_status__c == 'Ordered' && String.isNotBlank(h.orderNumSAP__c)) {
                System.debug(
                    'Skipping header ' + h.Id +
                    ': already Ordered in SAP with order number ' + h.orderNumSAP__c +
                    ' - refusing to resend to avoid a duplicate SAP order.'
                );
                continue;
            }
            headers.add(h);
        }

        if (headers.isEmpty()) {
            return;
        }

        Set<String> countries = new Set<String>();

        for (Sample_Request_Header__c h : headers) {
            if (h.Customer__r != null && String.isNotBlank(h.Customer__r.BillingCountry)) {
                countries.add(h.Customer__r.BillingCountry);
            }
        }

        Map<String, Boolean> countryEnabledMap = new Map<String, Boolean>();

        for (SAP_Country_Config__mdt cc : [
            SELECT Country__c
            FROM SAP_Country_Config__mdt
            WHERE Country__c IN :countries
            AND Is_SAP_Enabled__c = true
        ]) {
            countryEnabledMap.put(cc.Country__c, true);
        }

        Map<Id, List<Sample_Request_Line_Item__c>> lineItemsByHeader =
            new Map<Id, List<Sample_Request_Line_Item__c>>();

        for (Sample_Request_Line_Item__c li : [
            SELECT
                Sample_Request_Header__c, Plant_code__c, Product_Code_SAP_Code__c,
                Product_Quantity__c, AdditionalField1__c, AdditionalField2__c,
                AdditionalField3__c, AdditionalField4__c, AdditionalField5__c,
                Sample_Line_Order_Number__c, Is_Backup__c
            FROM Sample_Request_Line_Item__c
            WHERE Sample_Request_Header__c IN :recordIds
        ]) {

            Id hId = li.Sample_Request_Header__c;

            if (!lineItemsByHeader.containsKey(hId)) {
                lineItemsByHeader.put(hId, new List<Sample_Request_Line_Item__c>());
            }

            lineItemsByHeader.get(hId).add(li);
        }

        List<Sample_Request_Header__c> validHeaders = new List<Sample_Request_Header__c>();
        List<Sample_Request_Header__c> invalidHeaders = new List<Sample_Request_Header__c>();
        Map<Id, String> invalidReasons = new Map<Id, String>();
        Map<Id, String> companyCodeByHeader = new Map<Id, String>();

        for (Sample_Request_Header__c h : headers) {

            String country = h.Customer__r != null ? h.Customer__r.BillingCountry : null;

            if (String.isBlank(country)) {
                invalidHeaders.add(h);
                invalidReasons.put(h.Id, 'Country missing on Account');
                continue;
            }

            if (!countryEnabledMap.containsKey(country)) {
                invalidHeaders.add(h);
                invalidReasons.put(h.Id, 'Country not enabled for SAP: ' + country);
                continue;
            }

            String companyCode = COMPANY_CODE_BY_COUNTRY.get(country.toUpperCase());

            if (String.isBlank(companyCode)) {
                invalidHeaders.add(h);
                invalidReasons.put(h.Id, 'No CompanyCode mapping for country: ' + country);
                continue;
            }

            companyCodeByHeader.put(h.Id, companyCode);
            validHeaders.add(h);
        }

        List<Sample_Request_Header__c> headersToUpdate = new List<Sample_Request_Header__c>();
        List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();

        for (Sample_Request_Header__c h : invalidHeaders) {

            String reason = invalidReasons.get(h.Id);

            h.Status_Code__c = 'ERROR';
            h.Message__c = reason;

            headersToUpdate.add(h);

            System.debug('Skipping header ' + h.Id + ': ' + reason);

            logsToInsert.add(
                buildLog(h.Id, config.End_Point_URL__c, null, reason, 'Failed')
            );
        }

        if (validHeaders.isEmpty()) {
            bulkDml(headersToUpdate, logsToInsert);
            return;
        }

        List<Object> recordList = new List<Object>();
        Map<Id, String> requestBodyByHeader = new Map<Id, String>();

        for (Sample_Request_Header__c h : validHeaders) {

            Date dt = h.Date__c != null ? h.Date__c : System.today();

            String formattedDate =
                String.valueOf(dt.year()) +
                String.valueOf(dt.month()).leftPad(2, '0') +
                String.valueOf(dt.day()).leftPad(2, '0');

            List<Sample_Request_Line_Item__c> lis =
                lineItemsByHeader.containsKey(h.Id)
                    ? lineItemsByHeader.get(h.Id)
                    : new List<Sample_Request_Line_Item__c>();

            Map<String, Map<String, Object>> mergedItemMap = new Map<String, Map<String, Object>>();

            for (Sample_Request_Line_Item__c li : lis) {

                Boolean isBackup = li.Is_Backup__c == true;

                String mergeKey = safe(li.Product_Code_SAP_Code__c) + '|' + isBackup;

                Decimal lineQty = li.Product_Quantity__c != null ? li.Product_Quantity__c : 0;

                if (!mergedItemMap.containsKey(mergeKey)) {

                    mergedItemMap.put(mergeKey, new Map<String, Object>{
                        'Plant' => safe(li.Plant_code__c),
                        'ProductCode' => safe(li.Product_Code_SAP_Code__c),
                        'CommercialQty' => lineQty,
                        'AdditionalField1' => safe(li.AdditionalField1__c),
                        'AdditionalField2' => safe(li.Sample_Line_Order_Number__c),
                        'AdditionalField3' => safe(li.AdditionalField3__c),
                        'AdditionalField4' => safe(li.AdditionalField4__c),
                        'AdditionalField5' => safe(li.AdditionalField5__c),
                        'BackupOrder' => isBackup
                    });

                } else {

                    Map<String, Object> existing = mergedItemMap.get(mergeKey);
                    Decimal existingQty = (Decimal) existing.get('CommercialQty');
                    existing.put('CommercialQty', existingQty + lineQty);
                }
            }

            List<Object> itemList = new List<Object>();
            itemList.addAll(mergedItemMap.values());

            System.debug('Header ' + h.Id + ': SF lines = ' + lis.size() + ' -> SAP merged lines = ' + itemList.size());

            String companyCode = companyCodeByHeader.get(h.Id);
            String appOrderNumber = 'SMO_' + h.Id;

            Map<String, Object> recordData = new Map<String, Object>{
                'Source' => 'SF',
                'ShipToParty' => safe(h.Ship_To_Code__c),
                'OrderCreationDate' => formattedDate,
                'CompanyCode' => companyCode,
                'Application_Order_Number' => appOrderNumber,
                'SoldToParty' => safe(h.Bill_To_Code__c),
                'AdditionalField1' => safe(h.Remarks__c),
                'Items' => itemList
            };

            recordList.add(recordData);

            String singlePayload = JSON.serialize(
                new Map<String, Object>{ 'Record' => new List<Object>{ recordData } }
            );

            requestBodyByHeader.put(h.Id, singlePayload);
            h.Request_Body__c = singlePayload;
        }

        String responseBody = '';
        Integer responseCode = 0;

        String batchRequestBody = JSON.serialize(
            new Map<String, Object>{ 'Record' => recordList }
        );

        System.debug('Batch Request JSON: ' + batchRequestBody);

        try {

            HttpRequest req = new HttpRequest();

            req.setEndpoint(config.End_Point_URL__c);
            req.setMethod('POST');
            req.setTimeout(120000);
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Accept', 'application/json');

            Blob authBlob = Blob.valueOf(safe(config.User_name__c) + ':' + safe(config.Password__c));

            req.setHeader('Authorization', 'Basic ' + EncodingUtil.base64Encode(authBlob));

            req.setBody(batchRequestBody);

            HttpResponse res = new Http().send(req);

            responseCode = res.getStatusCode();
            responseBody = res.getBody();

            System.debug('Response Status: ' + responseCode);
            System.debug('Response Body: ' + responseBody);

        } catch (Exception ex) {

            System.debug('CALLOUT EXCEPTION: ' + ex.getMessage());

            for (Sample_Request_Header__c h : validHeaders) {

                h.SAP_status__c = 'Failed';
                h.Status_Code__c = 'ERROR';
                h.Message__c = ex.getMessage();

                if (h.First_Failure_Time__c == null) {
                    h.First_Failure_Time__c = DateTime.now();
                }

                h.Retry_Count__c = getRetryCount(h) + 1;

                headersToUpdate.add(h);

                logsToInsert.add(
                    buildLog(h.Id, config.End_Point_URL__c, requestBodyByHeader.get(h.Id), ex.getMessage(), 'Failed')
                );
            }

            bulkDml(headersToUpdate, logsToInsert);
            return;
        }

        // Preferred correlation: match by Application_Order_Number when SAP echoes it back.
        Map<String, Map<String, Object>> mainRespByOrderNumber = new Map<String, Map<String, Object>>();
        Map<String, Map<String, Object>> backupRespByOrderNumber = new Map<String, Map<String, Object>>();

        // Fallback correlation: SAP's real responses often omit Application_Order_Number
        // entirely, so we also keep the raw parsed list in request order to fall back
        // to positional matching - this is what actually happens in production today.
        List<Map<String, Object>> mainRespList = new List<Map<String, Object>>();
        List<Map<String, Object>> backupRespList = new List<Map<String, Object>>();

        Boolean parseSuccess = false;

        if (responseCode == 200 && String.isNotBlank(responseBody)) {

            try {

                Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                List<Object> responseList = (List<Object>) responseMap.get('Record');

                if (responseList != null) {

                    for (Object respObj : responseList) {

                        Map<String, Object> respItem = (Map<String, Object>) respObj;

                        String orderNum = (String) respItem.get('Application_Order_Number');
                        String msgText = (String) respItem.get('message');

                        Boolean isBackupMsg =
                            String.isNotBlank(msgText) && msgText.containsIgnoreCase('Back Up Order Number');

                        if (isBackupMsg) {
                            backupRespList.add(respItem);
                            if (String.isNotBlank(orderNum)) {
                                backupRespByOrderNumber.put(orderNum, respItem);
                            }
                        } else {
                            mainRespList.add(respItem);
                            if (String.isNotBlank(orderNum)) {
                                mainRespByOrderNumber.put(orderNum, respItem);
                            }
                        }
                    }

                    parseSuccess = true;
                }

            } catch (Exception parseEx) {
                System.debug('Response parse error: ' + parseEx.getMessage());
            }
        }

        for (Integer i = 0; i < validHeaders.size(); i++) {

            Sample_Request_Header__c h = validHeaders[i];
            String appOrderNumber = 'SMO_' + h.Id;
            String logStatus = 'Failed';

            // Try exact match by Application_Order_Number first; fall back to
            // position in the response list only if SAP didn't echo the key back.
            Map<String, Object> resp = parseSuccess ? mainRespByOrderNumber.get(appOrderNumber) : null;
            if (resp == null && parseSuccess && i < mainRespList.size()) {
                resp = mainRespList[i];
            }

            Map<String, Object> backupResp = parseSuccess ? backupRespByOrderNumber.get(appOrderNumber) : null;
            if (backupResp == null && parseSuccess && i < backupRespList.size()) {
                backupResp = backupRespList[i];
            }

            if (responseCode == 200 && resp != null) {

                Object statusCodeObj = resp.get('statuscode');

                Integer statusCode = (statusCodeObj instanceof Integer)
                    ? (Integer) statusCodeObj
                    : Integer.valueOf(String.valueOf(statusCodeObj));

                String message = (String) resp.get('message');

                String orderNumber =
                    (resp.containsKey('OrderNumber') && resp.get('OrderNumber') != null)
                        ? String.valueOf(resp.get('OrderNumber'))
                        : '';

                h.Status_Code__c = String.valueOf(statusCode);
                h.Message__c = message;
                h.orderNumSAP__c = orderNumber;

                if (backupResp != null) {

                    String backupMsg = (String) backupResp.get('message');

                    if (String.isNotBlank(backupMsg)) {

                        Pattern p = Pattern.compile('(\\d+)');
                        Matcher m = p.matcher(backupMsg);

                        if (m.find()) {
                            h.BackUp_Order_Number__c = m.group(1);
                            System.debug('Extracted Backup Order Number: ' + m.group(1));
                        }
                    }
                }

                if (statusCode == 1) {

                    h.SAP_status__c = 'Ordered';
                    logStatus = 'Success';
                    h.First_Failure_Time__c = null;

                    if (String.isBlank(orderNumber)) {
                        h.Message__c = 'SAP confirmed success but did not return an order number - needs manual follow-up';
                    }

                } else {

                    if (String.isNotBlank(message) && message.containsIgnoreCase('block')) {
                        h.SAP_status__c = 'Blocked';
                    } else {
                        h.SAP_status__c = 'Failed';
                    }

                    if (h.First_Failure_Time__c == null) {
                        h.First_Failure_Time__c = DateTime.now();
                    }
                }

            } else {

                h.SAP_status__c = 'Failed';
                h.Status_Code__c = String.valueOf(responseCode);
                h.Message__c = responseBody;

                if (h.First_Failure_Time__c == null) {
                    h.First_Failure_Time__c = DateTime.now();
                }
            }

            h.Retry_Count__c = getRetryCount(h) + 1;

            headersToUpdate.add(h);

            logsToInsert.add(
                buildLog(h.Id, config.End_Point_URL__c, requestBodyByHeader.get(h.Id), responseBody, logStatus)
            );
        }

        bulkDml(headersToUpdate, logsToInsert);
    }

    private static Integer getRetryCount(Sample_Request_Header__c h) {

        if (h.Retry_Count__c == null) {
            return 0;
        }

        return Integer.valueOf(String.valueOf(h.Retry_Count__c));
    }

    private static Integration_Log__c buildLog(
        Id headerId, String endpointUrl, String requestBody, String responseBody, String status
    ) {

        return new Integration_Log__c(
            RecordId__c = headerId,
            Sample_Request_Header__c = headerId,
            Object_Name__c = 'Sample_Request_Header__c',
            EndPoint_URL__c = endpointUrl,
            Request_Body__c = requestBody,
            Response_Body__c = responseBody,
            Status__c = status
        );
    }

    private static void bulkDml(
        List<Sample_Request_Header__c> headersToUpdate, List<Integration_Log__c> logsToInsert
    ) {

        try {

            if (!headersToUpdate.isEmpty()) {
                update headersToUpdate;
            }

            if (!logsToInsert.isEmpty()) {
                insert logsToInsert;
            }

        } catch (Exception ex) {
            System.debug('BULK DML ERROR: ' + ex.getMessage());
        }
    }

    private static String safe(Object val) {
        return val != null ? String.valueOf(val) : '';
    }
}