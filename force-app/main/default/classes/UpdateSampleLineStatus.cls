@RestResource(urlMapping='/UpdateSampleLineStatus')
global with sharing class UpdateSampleLineStatus {

    // ════════════════════════════════════════════════════════════════════════
    // CONSTANTS
    // ════════════════════════════════════════════════════════════════════════
    private static final String  PREFIX_SMO        = 'SMO_';
    private static final String  PREFIX_SRHL       = 'SRHL_';

    private static final String  STATUS_ORDERED    = 'Ordered';
    private static final String  STATUS_EXECUTED   = 'Executed';
    private static final String  STATUS_DELIVERED  = 'Delivered';
    private static final String  STATUS_RETURNED   = 'Returned';
    private static final String  STATUS_CANCELLED  = 'Cancelled';

    private static final String  CONTENT_TYPE_JSON = 'application/json';
    private static final Integer HTTP_OK           = 200;
    private static final Integer HTTP_BAD_REQUEST  = 400;
    private static final Integer HTTP_NOT_FOUND    = 404;
    private static final Integer HTTP_SERVER_ERROR = 500;

    // ════════════════════════════════════════════════════════════════════════
    // REST ENDPOINT
    // ════════════════════════════════════════════════════════════════════════
    @HttpPost
    global static void updateStatus() {

        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;

        System.debug('=== UpdateSampleLineStatus START ===');
        System.debug('Request Body : '
            + (req.requestBody != null ? req.requestBody.toString() : 'NULL'));

        try {

            // ── Validate request body ────────────────────────────────────
            if (req.requestBody == null) {
                sendError(res, 'Request body is missing.', HTTP_BAD_REQUEST);
                return;
            }

            SampleLineStatusWrapper.RequestWrapper requestData;
            try {
                requestData = (SampleLineStatusWrapper.RequestWrapper)
                    JSON.deserialize(
                        req.requestBody.toString(),
                        SampleLineStatusWrapper.RequestWrapper.class
                    );
            } catch (Exception e) {
                sendError(res, 'Malformed JSON — ' + e.getMessage(), HTTP_BAD_REQUEST);
                return;
            }

            if (requestData == null || String.isBlank(requestData.headerId)) {
                sendError(res, 'headerId is required.', HTTP_BAD_REQUEST);
                return;
            }

            System.debug('headerId received : ' + requestData.headerId);
            System.debug('isCancelled flag  : ' + requestData.isCancelled);

            // ── Resolve SF Id (strip SMO_ prefix if present) ─────────────
            String headerId = requestData.headerId.startsWith(PREFIX_SMO)
                ? requestData.headerId.removeStart(PREFIX_SMO)
                : requestData.headerId;

            System.debug('Resolved SF Header Id : ' + headerId);

            // ── Query Header + all Non-Backup Line Items in ONE SOQL ─────
            List<Sample_Request_Header__c> headers = [
                SELECT Id,
                       SAP_status__c,
                    (SELECT Id,
                            SAP_status__c,
                            Product_Code_SAP_Code__c,
                            Serial_Number__c,
                            Batch_Number__c,
                            Product_Quantity__c,
                            Sample_Line_Order_Number__c,
                            Invoice_Number__c,
                            External_Invoice_Number__c,
                            Tracking_Number__c,
                            DeliveryNumber__c,
                            Shipping_No__c,
                            Customer_SAP_Code__c,
                            Shiping_Status__c,
                            Assigned_Date__c,
                            Assigned_Time__c,
                            Shipping_Partner__c,
                            Partner_Name__c
                     FROM   Sample_Request_Line_Items__r
                     WHERE  Is_Backup__c = false
                     ORDER BY CreatedDate ASC
                    )
                FROM  Sample_Request_Header__c
                WHERE Id = :headerId
                LIMIT 1
            ];

            if (headers.isEmpty()) {
                sendError(res, 'Header not found: ' + headerId, HTTP_NOT_FOUND);
                return;
            }

            Sample_Request_Header__c          header       = headers[0];
            List<Sample_Request_Line_Item__c> allLineItems = header.Sample_Request_Line_Items__r;

            System.debug('Header found          : ' + header.Id);
            System.debug('Header current status : ' + header.SAP_status__c);
            System.debug('Total SF line items   : ' + allLineItems.size());

            if (allLineItems == null || allLineItems.isEmpty()) {
                sendError(res, 'No line items found under header: ' + headerId, HTTP_NOT_FOUND);
                return;
            }

            // ── Collectors — ALL DML done ONCE at the end ────────────────
            List<Sample_Request_Line_Item__c>          linesToUpdate = new List<Sample_Request_Line_Item__c>();
            List<SampleLineStatusWrapper.LineResponse> lineResponses = new List<SampleLineStatusWrapper.LineResponse>();
            Boolean                                    updateHeader  = false;

            // ════════════════════════════════════════════════════════════
            // CANCELLATION FLAG — checked FIRST
            // ════════════════════════════════════════════════════════════
            if (requestData.isCancelled == true) {
                System.debug('→ isCancelled = true');

                if (header.SAP_status__c != STATUS_CANCELLED) {
                    header.SAP_status__c = STATUS_CANCELLED;
                    header.Approval_Status__c = 'Rejected';
                    updateHeader = true;
                }

                handleCancelled(allLineItems, linesToUpdate, lineResponses);

                // ── Bulk DML ─────────────────────────────────────────────
                if (updateHeader)             { update header;        }
                if (!linesToUpdate.isEmpty()) { update linesToUpdate; }

                sendSuccessResponse(res, 'Order cancelled successfully.',
                    linesToUpdate.size(), lineResponses);
                return;
            }

            // ── Validate lines array ─────────────────────────────────────
            if (requestData.lines == null || requestData.lines.isEmpty()) {
                sendError(res, 'lines array is required when isCancelled is false.', HTTP_BAD_REQUEST);
                return;
            }

            String incomingStatus = requestData.lines[0].status;
            System.debug('Incoming status      : ' + incomingStatus);
            System.debug('Incoming lines count : ' + requestData.lines.size());

            if (String.isBlank(incomingStatus)) {
                sendError(res, 'status field is required.', HTTP_BAD_REQUEST);
                return;
            }

            // ── Route to handler ─────────────────────────────────────────
            if (incomingStatus == STATUS_ORDERED) {
                System.debug('→ handleOrdered()');
                handleOrdered(allLineItems, linesToUpdate, lineResponses);

            } else if (incomingStatus == STATUS_EXECUTED) {
                System.debug('→ handleExecuted()');
                handleExecuted(requestData.lines, allLineItems, linesToUpdate, lineResponses);

            } else if (incomingStatus == STATUS_DELIVERED) {
                System.debug('→ handleDelivered()');
                handleDelivered(requestData.lines, allLineItems, linesToUpdate, lineResponses);

            } else if (incomingStatus == STATUS_RETURNED) {
                System.debug('→ handleReturned()');
                handleReturned(requestData.lines, allLineItems, linesToUpdate, lineResponses);

            } else if (incomingStatus == STATUS_CANCELLED) {
                System.debug('→ handleCancelled() via status field');
                if (header.SAP_status__c != STATUS_CANCELLED) {
                    header.SAP_status__c = STATUS_CANCELLED;
                    header.Approval_Status__c = 'Rejected';
                    updateHeader = true;
                }
                handleCancelled(allLineItems, linesToUpdate, lineResponses);

            } else {
                sendError(res, 'Unknown status received: ' + incomingStatus, HTTP_BAD_REQUEST);
                return;
            }

            // ── Single Bulk DML — NO DML inside any loop ─────────────────
            if (!linesToUpdate.isEmpty()) {
                System.debug('Bulk DML — updating ' + linesToUpdate.size() + ' lines.');
                update linesToUpdate;
            } else {
                System.debug('No lines to update.');
            }

            if (updateHeader) {
                System.debug('Updating header status.');
                update header;
            }

            sendSuccessResponse(res, 'Line status updated successfully.',
                linesToUpdate.size(), lineResponses);

            System.debug('=== UpdateSampleLineStatus END ===');

        } catch (DmlException e) {
            System.debug('DML EXCEPTION: ' + e.getMessage() + ' Line: ' + e.getLineNumber());
            sendError(res, 'DML failed — ' + e.getMessage()
                + ' [Line: ' + e.getLineNumber() + ']', HTTP_SERVER_ERROR);
        } catch (Exception e) {
            System.debug('EXCEPTION: ' + e.getMessage() + ' Line: ' + e.getLineNumber());
            sendError(res, e.getMessage()
                + ' [Line: ' + e.getLineNumber() + ']', HTTP_SERVER_ERROR);
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // HANDLER — ORDERED
    // ════════════════════════════════════════════════════════════════════════
    private static void handleOrdered(
        List<Sample_Request_Line_Item__c>          allLineItems,
        List<Sample_Request_Line_Item__c>          linesToUpdate,
        List<SampleLineStatusWrapper.LineResponse> lineResponses
    ) {
        System.debug('handleOrdered() — lines : ' + allLineItems.size());

        for (Sample_Request_Line_Item__c li : allLineItems) {
            li.SAP_status__c = STATUS_ORDERED;
            linesToUpdate.add(li);

            SampleLineStatusWrapper.LineResponse lr = new SampleLineStatusWrapper.LineResponse();
            lr.lineId           = li.Id;
            lr.lineNumber       = PREFIX_SRHL + li.Id;
            lr.status           = STATUS_ORDERED;
            lr.shipmentsUpdated = false;
            lineResponses.add(lr);
        }

        System.debug('handleOrdered() done — queued : ' + linesToUpdate.size());
    }

    // ════════════════════════════════════════════════════════════════════════
    // HANDLER — EXECUTED
    // ════════════════════════════════════════════════════════════════════════
    private static void handleExecuted(
        List<SampleLineStatusWrapper.LineRequest>  incomingLines,
        List<Sample_Request_Line_Item__c>          allLineItems,
        List<Sample_Request_Line_Item__c>          linesToUpdate,
        List<SampleLineStatusWrapper.LineResponse> lineResponses
    ) {
        System.debug('handleExecuted() — SAP lines : ' + incomingLines.size()
                   + ' | SF lines : ' + allLineItems.size());

        Map<String, List<Sample_Request_Line_Item__c>> orderedMap =
            new Map<String, List<Sample_Request_Line_Item__c>>();

        for (Sample_Request_Line_Item__c li : allLineItems) {
            if (li.SAP_status__c != STATUS_ORDERED) { continue; }

            if (String.isNotBlank(li.Serial_Number__c)) {
                String k = li.Product_Code_SAP_Code__c + '||SN||' + li.Serial_Number__c;
                if (!orderedMap.containsKey(k)) orderedMap.put(k, new List<Sample_Request_Line_Item__c>());
                orderedMap.get(k).add(li);
            }

            if (String.isNotBlank(li.Batch_Number__c)) {
                String k = li.Product_Code_SAP_Code__c + '||BN||' + li.Batch_Number__c;
                if (!orderedMap.containsKey(k)) orderedMap.put(k, new List<Sample_Request_Line_Item__c>());
                orderedMap.get(k).add(li);
            }

            String productKey = li.Product_Code_SAP_Code__c + '||PRODUCT';
            if (!orderedMap.containsKey(productKey)) orderedMap.put(productKey, new List<Sample_Request_Line_Item__c>());
            orderedMap.get(productKey).add(li);
        }

        System.debug('Ordered map keys : ' + orderedMap.size());

        Set<Id> matchedIds = new Set<Id>();

        for (SampleLineStatusWrapper.LineRequest lr : incomingLines) {

            Boolean isSerialized = String.isNotBlank(lr.serialNumber);

            Integer qtyToUpdate;
            if (isSerialized) {
                qtyToUpdate = 1;
                System.debug('Serialized — qty = 1 | serial : ' + lr.serialNumber);
            } else {
                if (String.isBlank(lr.quantity)) {
                    System.debug('SKIP: quantity missing for non-serialized : ' + lr.productCode);
                    continue;
                }
                try {
                    qtyToUpdate = Integer.valueOf(lr.quantity);
                } catch (Exception e) {
                    System.debug('SKIP: invalid quantity : ' + lr.quantity);
                    continue;
                }
                System.debug('Non-Serialized — qty : ' + qtyToUpdate + ' | batch : ' + lr.batchNumber);
            }

            List<Sample_Request_Line_Item__c> candidateList;

            if (isSerialized) {
                String serialKey = lr.productCode + '||SN||' + lr.serialNumber;
                candidateList = orderedMap.get(serialKey);
                System.debug('Serialized key : ' + serialKey);

                if (candidateList == null || candidateList.isEmpty()) {
                    candidateList = orderedMap.get(lr.productCode + '||PRODUCT');
                    System.debug('Serial not found on SF line — fallback to PRODUCT FIFO');
                }

            } else if (String.isNotBlank(lr.batchNumber)) {
                String batchKey = lr.productCode + '||BN||' + lr.batchNumber;
                candidateList = orderedMap.get(batchKey);
                System.debug('Batch key : ' + batchKey);

                if (candidateList == null || candidateList.isEmpty()) {
                    candidateList = orderedMap.get(lr.productCode + '||PRODUCT');
                    System.debug('Batch not found — fallback to PRODUCT FIFO');
                }
            } else {
                candidateList = orderedMap.get(lr.productCode + '||PRODUCT');
                System.debug('Product-only FIFO : ' + lr.productCode);
            }

            if (candidateList == null || candidateList.isEmpty()) {
                System.debug('No Ordered lines found for : ' + lr.productCode);
                continue;
            }

            Integer updatedCount = 0;

            for (Sample_Request_Line_Item__c candidate : candidateList) {
                if (matchedIds.contains(candidate.Id))  { continue; }
                if (updatedCount >= qtyToUpdate)        { break;    }

                candidate.SAP_status__c = STATUS_EXECUTED;

                if (String.isNotBlank(lr.serialNumber)) candidate.Serial_Number__c = lr.serialNumber;
                if (String.isNotBlank(lr.batchNumber))  candidate.Batch_Number__c  = lr.batchNumber;

                matchedIds.add(candidate.Id);
                linesToUpdate.add(candidate);

                SampleLineStatusWrapper.LineResponse resp = new SampleLineStatusWrapper.LineResponse();
                resp.lineId           = candidate.Id;
                resp.lineNumber       = PREFIX_SRHL + candidate.Id;
                resp.status           = STATUS_EXECUTED;
                resp.shipmentsUpdated = false;
                lineResponses.add(resp);

                updatedCount++;
            }

            System.debug('Executed ' + updatedCount + ' lines for : ' + lr.productCode);
        }

        System.debug('handleExecuted() done — queued : ' + linesToUpdate.size());
    }

    // ════════════════════════════════════════════════════════════════════════
    // HANDLER — DELIVERED
    // ════════════════════════════════════════════════════════════════════════
    private static void handleDelivered(
        List<SampleLineStatusWrapper.LineRequest>  incomingLines,
        List<Sample_Request_Line_Item__c>          allLineItems,
        List<Sample_Request_Line_Item__c>          linesToUpdate,
        List<SampleLineStatusWrapper.LineResponse> lineResponses
    ) {
        System.debug('handleDelivered() — SAP lines : ' + incomingLines.size());

        Map<String, List<Sample_Request_Line_Item__c>> executedMap =
            new Map<String, List<Sample_Request_Line_Item__c>>();

        for (Sample_Request_Line_Item__c li : allLineItems) {
            if (li.SAP_status__c != STATUS_EXECUTED) { continue; }

            if (String.isNotBlank(li.Serial_Number__c)) {
                String k = li.Product_Code_SAP_Code__c + '||SN||' + li.Serial_Number__c;
                if (!executedMap.containsKey(k)) executedMap.put(k, new List<Sample_Request_Line_Item__c>());
                executedMap.get(k).add(li);
            }

            if (String.isNotBlank(li.Batch_Number__c)) {
                String k = li.Product_Code_SAP_Code__c + '||BN||' + li.Batch_Number__c;
                if (!executedMap.containsKey(k)) executedMap.put(k, new List<Sample_Request_Line_Item__c>());
                executedMap.get(k).add(li);
            }

            String productKey = li.Product_Code_SAP_Code__c + '||PRODUCT';
            if (!executedMap.containsKey(productKey)) executedMap.put(productKey, new List<Sample_Request_Line_Item__c>());
            executedMap.get(productKey).add(li);
        }

        System.debug('Executed map keys : ' + executedMap.size());

        Set<Id> matchedIds = new Set<Id>();

        for (SampleLineStatusWrapper.LineRequest lr : incomingLines) {

            List<Sample_Request_Line_Item__c> candidateList;

            if (String.isNotBlank(lr.serialNumber)) {
                String serialKey = lr.productCode + '||SN||' + lr.serialNumber;
                candidateList = executedMap.get(serialKey);
                System.debug('Delivered serial key : ' + serialKey);

                if (candidateList == null || candidateList.isEmpty()) {
                    candidateList = executedMap.get(lr.productCode + '||PRODUCT');
                    System.debug('Serial not found — fallback to PRODUCT');
                }

            } else if (String.isNotBlank(lr.batchNumber)) {
                String batchKey = lr.productCode + '||BN||' + lr.batchNumber;
                candidateList = executedMap.get(batchKey);
                System.debug('Delivered batch key : ' + batchKey);

                if (candidateList == null || candidateList.isEmpty()) {
                    candidateList = executedMap.get(lr.productCode + '||PRODUCT');
                    System.debug('Batch not found — fallback to PRODUCT');
                }
            } else {
                candidateList = executedMap.get(lr.productCode + '||PRODUCT');
                System.debug('Delivered product-only key : ' + lr.productCode);
            }

            if (candidateList == null || candidateList.isEmpty()) {
                System.debug('No Executed lines for : ' + lr.productCode);
                continue;
            }

            for (Sample_Request_Line_Item__c li : candidateList) {
                if (matchedIds.contains(li.Id)) { continue; }

                li.SAP_status__c = STATUS_DELIVERED;

                if (lr.shipments != null && !lr.shipments.isEmpty()) {
                    applyShipmentData(li, lr.shipments[0]);
                }

                matchedIds.add(li.Id);
                linesToUpdate.add(li);

                SampleLineStatusWrapper.LineResponse resp = new SampleLineStatusWrapper.LineResponse();
                resp.lineId           = li.Id;
                resp.lineNumber       = PREFIX_SRHL + li.Id;
                resp.status           = STATUS_DELIVERED;
                resp.shipmentsUpdated = (lr.shipments != null && !lr.shipments.isEmpty());
                lineResponses.add(resp);

                System.debug('Line → Delivered : ' + li.Id);
            }
        }

        System.debug('handleDelivered() done — queued : ' + linesToUpdate.size());
    }

    // ════════════════════════════════════════════════════════════════════════
    // HANDLER — RETURNED
    // ════════════════════════════════════════════════════════════════════════
    private static void handleReturned(
        List<SampleLineStatusWrapper.LineRequest>  incomingLines,
        List<Sample_Request_Line_Item__c>          allLineItems,
        List<Sample_Request_Line_Item__c>          linesToUpdate,
        List<SampleLineStatusWrapper.LineResponse> lineResponses
    ) {
        System.debug('handleReturned() — SAP lines : ' + incomingLines.size());

        Map<String, List<Sample_Request_Line_Item__c>> eligibleMap =
            new Map<String, List<Sample_Request_Line_Item__c>>();

        for (Sample_Request_Line_Item__c li : allLineItems) {
            if (li.SAP_status__c != STATUS_DELIVERED
                && li.SAP_status__c != STATUS_EXECUTED) { continue; }

            if (String.isNotBlank(li.Serial_Number__c)) {
                String k = li.Product_Code_SAP_Code__c + '||SN||' + li.Serial_Number__c;
                if (!eligibleMap.containsKey(k)) eligibleMap.put(k, new List<Sample_Request_Line_Item__c>());
                eligibleMap.get(k).add(li);
            }

            if (String.isNotBlank(li.Batch_Number__c)) {
                String k = li.Product_Code_SAP_Code__c + '||BN||' + li.Batch_Number__c;
                if (!eligibleMap.containsKey(k)) eligibleMap.put(k, new List<Sample_Request_Line_Item__c>());
                eligibleMap.get(k).add(li);
            }

            String productKey = li.Product_Code_SAP_Code__c + '||PRODUCT';
            if (!eligibleMap.containsKey(productKey)) eligibleMap.put(productKey, new List<Sample_Request_Line_Item__c>());
            eligibleMap.get(productKey).add(li);
        }

        System.debug('Eligible map keys : ' + eligibleMap.size());

        Set<Id> matchedIds = new Set<Id>();

        for (SampleLineStatusWrapper.LineRequest lr : incomingLines) {

            Boolean isSerialized = String.isNotBlank(lr.serialNumber);

            Integer qtyToUpdate;
            if (isSerialized) {
                qtyToUpdate = 1;
                System.debug('Serialized return — qty = 1 | serial : ' + lr.serialNumber);
            } else {
                if (String.isBlank(lr.quantity)) {
                    System.debug('SKIP: quantity missing for non-serialized return : ' + lr.productCode);
                    continue;
                }
                try {
                    qtyToUpdate = Integer.valueOf(lr.quantity);
                } catch (Exception e) {
                    System.debug('SKIP: invalid return quantity : ' + lr.quantity);
                    continue;
                }
                System.debug('Non-Serialized return — qty : ' + qtyToUpdate + ' | batch : ' + lr.batchNumber);
            }

            List<Sample_Request_Line_Item__c> candidateList;

            if (isSerialized) {
                String serialKey = lr.productCode + '||SN||' + lr.serialNumber;
                candidateList = eligibleMap.get(serialKey);
                System.debug('Returned serial key : ' + serialKey);

                if (candidateList == null || candidateList.isEmpty()) {
                    candidateList = eligibleMap.get(lr.productCode + '||PRODUCT');
                    System.debug('Serial not found — fallback to PRODUCT');
                }

            } else if (String.isNotBlank(lr.batchNumber)) {
                String batchKey = lr.productCode + '||BN||' + lr.batchNumber;
                candidateList = eligibleMap.get(batchKey);
                System.debug('Returned batch key : ' + batchKey);

                if (candidateList == null || candidateList.isEmpty()) {
                    candidateList = eligibleMap.get(lr.productCode + '||PRODUCT');
                    System.debug('Batch not found — fallback to PRODUCT');
                }
            } else {
                candidateList = eligibleMap.get(lr.productCode + '||PRODUCT');
                System.debug('Returned product-only key : ' + lr.productCode);
            }

            if (candidateList == null || candidateList.isEmpty()) {
                System.debug('No Delivered/Executed lines for : ' + lr.productCode);
                continue;
            }

            Integer updatedCount = 0;

            for (Sample_Request_Line_Item__c li : candidateList) {
                if (matchedIds.contains(li.Id))  { continue; }
                if (updatedCount >= qtyToUpdate) { break;    }

                li.SAP_status__c = STATUS_RETURNED;
                matchedIds.add(li.Id);
                linesToUpdate.add(li);
                updatedCount++;

                SampleLineStatusWrapper.LineResponse resp = new SampleLineStatusWrapper.LineResponse();
                resp.lineId           = li.Id;
                resp.lineNumber       = PREFIX_SRHL + li.Id;
                resp.status           = STATUS_RETURNED;
                resp.shipmentsUpdated = false;
                lineResponses.add(resp);

                System.debug('Line → Returned : ' + li.Id + ' (' + updatedCount + '/' + qtyToUpdate + ')');
            }

            System.debug('Returned ' + updatedCount + ' lines for : ' + lr.productCode);
        }

        System.debug('handleReturned() done — queued : ' + linesToUpdate.size());
    }

    // ════════════════════════════════════════════════════════════════════════
    // HANDLER — CANCELLED
    // ════════════════════════════════════════════════════════════════════════
    private static void handleCancelled(
        List<Sample_Request_Line_Item__c>          allLineItems,
        List<Sample_Request_Line_Item__c>          linesToUpdate,
        List<SampleLineStatusWrapper.LineResponse> lineResponses
    ) {
        System.debug('handleCancelled() — lines : ' + allLineItems.size());

        for (Sample_Request_Line_Item__c li : allLineItems) {
            li.SAP_status__c = STATUS_CANCELLED;
            linesToUpdate.add(li);

            SampleLineStatusWrapper.LineResponse lr = new SampleLineStatusWrapper.LineResponse();
            lr.lineId           = li.Id;
            lr.lineNumber       = PREFIX_SRHL + li.Id;
            lr.status           = STATUS_CANCELLED;
            lr.shipmentsUpdated = false;
            lineResponses.add(lr);

            System.debug('Line → Cancelled : ' + li.Id);
        }

        System.debug('handleCancelled() done — queued : ' + linesToUpdate.size());
    }

    // ════════════════════════════════════════════════════════════════════════
    // HELPER — Apply shipment fields
    // ════════════════════════════════════════════════════════════════════════
    private static void applyShipmentData(
        Sample_Request_Line_Item__c             li,
        SampleLineStatusWrapper.ShipmentRequest s
    ) {
        if (s == null) { return; }

        li.Invoice_Number__c          = String.isNotBlank(s.invoiceNumber)
                                        ? s.invoiceNumber         : li.Invoice_Number__c;
        li.External_Invoice_Number__c = String.isNotBlank(s.externalInvoiceNumber)
                                        ? s.externalInvoiceNumber : li.External_Invoice_Number__c;
        li.Tracking_Number__c         = String.isNotBlank(s.trackingNumber)
                                        ? s.trackingNumber        : li.Tracking_Number__c;
        li.DeliveryNumber__c          = String.isNotBlank(s.deliveryNumber)
                                        ? s.deliveryNumber        : li.DeliveryNumber__c;
        li.Shipping_No__c             = String.isNotBlank(s.shippingNo)
                                        ? s.shippingNo            : li.Shipping_No__c;
        li.Shiping_Status__c          = String.isNotBlank(s.shipingStatus)
                                        ? s.shipingStatus         : li.Shiping_Status__c;
        li.Shipping_Partner__c        = String.isNotBlank(s.shippingPartner)
                                        ? s.shippingPartner       : li.Shipping_Partner__c;
        li.Partner_Name__c            = String.isNotBlank(s.partnerName)
                                        ? s.partnerName           : li.Partner_Name__c;

        if (String.isNotBlank(s.assignedDate)) {
            try {
                li.Assigned_Date__c = Date.valueOf(s.assignedDate);
            } catch (Exception e) {
                System.debug('ERROR: Invalid assignedDate : ' + s.assignedDate);
                li.Assigned_Date__c = null;
            }
        }

        if (String.isNotBlank(s.assignedTime)) {
            li.Assigned_Time__c = s.assignedTime;
        }

        System.debug('applyShipmentData() applied → line : ' + li.Id);
    }

    // ════════════════════════════════════════════════════════════════════════
    // HELPER — Send success response
    // ════════════════════════════════════════════════════════════════════════
    private static void sendSuccessResponse(
        RestResponse                               res,
        String                                     message,
        Integer                                    updatedRecords,
        List<SampleLineStatusWrapper.LineResponse> lineResponses
    ) {
        SampleLineStatusWrapper.ResponseWrapper response =
            new SampleLineStatusWrapper.ResponseWrapper();
        response.status         = 'success';
        response.message        = message;
        response.updatedRecords = updatedRecords;
        response.lines          = lineResponses;

        res.statusCode   = HTTP_OK;
        res.addHeader('Content-Type', CONTENT_TYPE_JSON);
        res.responseBody = Blob.valueOf(JSON.serialize(response));
    }

    // ════════════════════════════════════════════════════════════════════════
    // HELPER — Send error response
    // ════════════════════════════════════════════════════════════════════════
    private static void sendError(RestResponse res, String message, Integer code) {
        System.debug('ERROR — Code : ' + code + ' | ' + message);
        res.statusCode   = code;
        res.addHeader('Content-Type', CONTENT_TYPE_JSON);
        res.responseBody = Blob.valueOf(
            JSON.serialize(new Map<String, Object>{
                'status'  => 'error',
                'message' => message
            })
        );
    }
}