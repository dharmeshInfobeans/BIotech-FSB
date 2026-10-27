@RestResource(urlMapping='/secondarysalestarget')
global with sharing class SAPSecondarySalesTargetRest {
    
    @HttpPost
    global static void createSecondarySales() {
        
        RestRequest  req = RestContext.request;
        RestResponse res = RestContext.response;
        
        Map<String, Object>                    response      = new Map<String, Object>();
        Map<String, List<Map<String, String>>> operationsMap = new Map<String, List<Map<String, String>>>();
        
        String requestBody = '';
        
        try {
            System.debug('==> Full Request Body: ' + (req.requestBody != null ? req.requestBody.toString() : 'NULL'));
            
            if (req.requestBody == null) {
                res.statusCode   = 400;
                res.responseBody = Blob.valueOf('Request body is empty');
                return;
            }
            
            requestBody = req.requestBody.toString();
            
            // ══════════════════════════════════════════════════════════════
            // STEP 1 – Deserialize & Validate
            // ══════════════════════════════════════════════════════════════
            List<SecondarySalesWrapper.SecondarySalesRequest> lstPayload =
                (List<SecondarySalesWrapper.SecondarySalesRequest>)
                JSON.deserialize(
                    requestBody,
                    List<SecondarySalesWrapper.SecondarySalesRequest>.class
                );
            
            System.debug('==> Deserialized Payload: ' + JSON.serializePretty(lstPayload));
            
            if (lstPayload == null || lstPayload.isEmpty()) {
                res.statusCode   = 400;
                res.responseBody = Blob.valueOf('Payload list is empty');
                return;
            }
            
            for (SecondarySalesWrapper.SecondarySalesRequest payload : lstPayload) {
                if (payload == null || payload.SalesOrder == null || payload.SalesOrder.Header == null) {
                    res.statusCode   = 400;
                    res.responseBody = Blob.valueOf('Invalid Payload: SalesOrder or Header is null');
                    return;
                }
                if (payload.SalesOrder.Items == null || payload.SalesOrder.Items.isEmpty()) {
                    res.statusCode   = 400;
                    res.responseBody = Blob.valueOf('Invalid Payload: Items list is null or empty for order ' + payload.SalesOrder.Header.SAPOrderNumber);
                    return;
                }
            }
            
            // ══════════════════════════════════════════════════════════════
            // STEP 2 – Collect all lookup keys for bulk queries
            // ══════════════════════════════════════════════════════════════
            Set<String> allOrderIds       = new Set<String>();
            Set<String> allSAPNumbers     = new Set<String>();
            Set<String> allShipToParties  = new Set<String>();
            Set<String> allDummyProdCodes = new Set<String>();
            
            for (SecondarySalesWrapper.SecondarySalesRequest payload : lstPayload) {
                SecondarySalesWrapper.SalesOrder data     = payload.SalesOrder;
                Boolean                          isReturn = data.Header.OrderType == 'ZRE';
                
                String orderId = (isReturn && data.Header.ReturnReferenceOrder != null)
                    ? data.Header.ReturnReferenceOrder
                    : data.Header.SAPOrderNumber;
                allOrderIds.add(orderId);
                allSAPNumbers.add(data.Header.SAPOrderNumber);
                
                if (data.Header.ReturnReferenceOrder != null) {
                    allSAPNumbers.add(data.Header.ReturnReferenceOrder);
                }
                if (data.Header.ShipToParty != null) {
                    allShipToParties.add(data.Header.ShipToParty);
                }
                
                for (SecondarySalesWrapper.Item item : data.Items) {
                    if (item.DummyProductCode != null) {
                        allDummyProdCodes.add(item.DummyProductCode);
                    }
                    if (item.Delivery != null) {
                        for (SecondarySalesWrapper.Delivery del : item.Delivery) {
                            if (del.DummyProductCode != null) {
                                allDummyProdCodes.add(del.DummyProductCode);
                            }
                        }
                    }
                }
            }
            
            // ══════════════════════════════════════════════════════════════
            // STEP 3 – Bulk Queries (zero SOQL inside any loop)
            // ══════════════════════════════════════════════════════════════
            
            Map<String, Secondary_Sales_Order__c> existingOrderMap = new Map<String, Secondary_Sales_Order__c>();
            for (Secondary_Sales_Order__c o : [
                SELECT Id, Secondary_Sales_Order_Id__c
                FROM   Secondary_Sales_Order__c
                WHERE  Secondary_Sales_Order_Id__c IN :allOrderIds
            ]) {
                existingOrderMap.put(o.Secondary_Sales_Order_Id__c, o);
            }
            
            Map<String, Secondary_Sales_Header__c> existingHeaderMap = new Map<String, Secondary_Sales_Header__c>();
            for (Secondary_Sales_Header__c h : [
                SELECT Id, SAP_Order_Number__c, Dummy_Product_Code__c
                FROM   Secondary_Sales_Header__c
                WHERE  SAP_Order_Number__c IN :allSAPNumbers
            ]) {
                existingHeaderMap.put(h.SAP_Order_Number__c, h);
            }
            
            Map<String, Account> accountMap = new Map<String, Account>();
            for (Account a : [
                SELECT Id, SAP_Code__c
                FROM   Account
                WHERE  SAP_Code__c IN :allShipToParties
                AND    RecordType.DeveloperName = 'Dealer_Portal'
            ]) {
                accountMap.put(a.SAP_Code__c, a);
            }
            
            Map<String, Product__c> productMap = new Map<String, Product__c>();
            for (Product__c p : [
                SELECT Id, Dummy_Product_Code__c
                FROM   Product__c
                WHERE  Dummy_Product_Code__c IN :allDummyProdCodes
            ]) {
                productMap.put(p.Dummy_Product_Code__c, p);
            }
            
            // ══════════════════════════════════════════════════════════════
            // STEP 4 – Build & Insert Orders
            // ══════════════════════════════════════════════════════════════
            
            List<Secondary_Sales_Order__c>        ordersToInsert = new List<Secondary_Sales_Order__c>();
            List<String>                          newOrderKeys   = new List<String>();
            List<Map<String, String>>             orderOps       = new List<Map<String, String>>();
            Map<String, Secondary_Sales_Order__c> orderByKey     = new Map<String, Secondary_Sales_Order__c>();
            
            for (SecondarySalesWrapper.SecondarySalesRequest payload : lstPayload) {
                
                SecondarySalesWrapper.SalesOrder data     = payload.SalesOrder;
                Boolean                          isReturn = data.Header.OrderType == 'ZRE';
                
                String orderId =
                    (isReturn && data.Header.ReturnReferenceOrder != null)
                    ? data.Header.ReturnReferenceOrder
                    : data.Header.SAPOrderNumber;
                
                if (orderByKey.containsKey(orderId)) continue;
                
                if (existingOrderMap.containsKey(orderId)) {
                    Secondary_Sales_Order__c existing = existingOrderMap.get(orderId);
                    orderByKey.put(orderId, existing);
                    orderOps.add(new Map<String, String>{
                        'externalId' => orderId,
                            'sfId'       => existing != null ? String.valueOf(existing.Id) : null,
                                'operation'  => 'EXISTING'
                                });
                } else {
                    Secondary_Sales_Order__c newOrder = new Secondary_Sales_Order__c(
                        Secondary_Sales_Order_Id__c     = String.isNotBlank(orderId) ? orderId : null,
                        Return_Order_Number__c          = (isReturn && String.isNotBlank(data.Header.SAPOrderNumber)) ? data.Header.SAPOrderNumber : null,
                        Ship_To_Party__c                = String.isNotBlank(data.Header.ShipToParty)   ? data.Header.ShipToParty   : null,
                        Sold_To_Party__c                = String.isNotBlank(data.Header.SoldToParty)   ? data.Header.SoldToParty   : null,
                        Order_Type__c                   = String.isNotBlank(data.Header.OrderType)     ? data.Header.OrderType     : null,
                        Secondary_Sales_Order_Status__c = isReturn ? 'Returned' : 'Open',
                        SF_Order_Number__c              = String.isNotBlank(data.Header.SFOrderNumber) ? data.Header.SFOrderNumber : null,
                        Reference_Order_Number__c       = String.isNotBlank(data.Header.ReturnReferenceOrder) ? data.Header.ReturnReferenceOrder : data.Header.SAPOrderNumber,
                        Order_Creation_Date__c          = String.isNotBlank(data.Header.OrderCreationDate) ? Date.valueOf(data.Header.OrderCreationDate) : null
                    );
                    ordersToInsert.add(newOrder);
                    newOrderKeys.add(orderId);
                    orderByKey.put(orderId, newOrder);
                    orderOps.add(new Map<String, String>{
                        'externalId' => orderId,
                            'sfId'       => null,
                            'operation'  => 'CREATED'
                            });
                }
            }
            
            if (!ordersToInsert.isEmpty()) {
                insert ordersToInsert;
                for (Integer i = 0; i < ordersToInsert.size(); i++) {
                    String key = newOrderKeys[i];
                    existingOrderMap.put(key, ordersToInsert[i]);
                    for (Map<String, String> op : orderOps) {
                        if (op.get('externalId') == key && op.get('operation') == 'CREATED' && op.get('sfId') == null) {
                            op.put('sfId', String.valueOf(ordersToInsert[i].Id));
                            break;
                        }
                    }
                }
            }
            
            operationsMap.put('Secondary_Sales_Order__c', orderOps);
            
            // ══════════════════════════════════════════════════════════════
            // STEP 5 – Build & Insert Headers
            // ══════════════════════════════════════════════════════════════
            
            List<Secondary_Sales_Header__c>        headersToInsert     = new List<Secondary_Sales_Header__c>();
            List<String>                           newHeaderKeys       = new List<String>();
            List<Map<String, String>>              headerOps           = new List<Map<String, String>>();
            Map<String, Secondary_Sales_Header__c> headerByKey         = new Map<String, Secondary_Sales_Header__c>();
            Set<String>                            processedHeaderKeys = new Set<String>();
            
            for (String k : existingHeaderMap.keySet()) {
                headerByKey.put(k, existingHeaderMap.get(k));
            }
            
            for (SecondarySalesWrapper.SecondarySalesRequest payload : lstPayload) {
                
                SecondarySalesWrapper.SalesOrder data     = payload.SalesOrder;
                Boolean                          isReturn = data.Header.OrderType == 'ZRE';
                
                String headerKey =
                    (isReturn && String.isNotBlank(data.Header.ReturnReferenceOrder))
                    ? data.Header.ReturnReferenceOrder
                    : data.Header.SAPOrderNumber;
                
                if (String.isBlank(headerKey))               continue;
                if (processedHeaderKeys.contains(headerKey)) continue;
                processedHeaderKeys.add(headerKey);
                
                if (existingHeaderMap.containsKey(headerKey)) {
                    Secondary_Sales_Header__c existing = existingHeaderMap.get(headerKey);
                    headerByKey.put(headerKey, existing);
                    headerOps.add(new Map<String, String>{
                        'externalId' => headerKey,
                            'sfId'       => existing.Id,
                            'operation'  => 'EXISTING'
                            });
                    continue;
                }
                
                String     dummyCode = (data.Items != null && !data.Items.isEmpty() && String.isNotBlank(data.Items[0].DummyProductCode)) ? data.Items[0].DummyProductCode : null;
                Account    acct      = String.isNotBlank(data.Header.ShipToParty) ? accountMap.get(data.Header.ShipToParty) : null;
                Product__c prod      = String.isNotBlank(dummyCode)               ? productMap.get(dummyCode)               : null;
                
                Secondary_Sales_Header__c newHeader = new Secondary_Sales_Header__c(
                    SAP_Order_Number__c   = headerKey,
                    Order_Type__c         = String.isNotBlank(data.Header.OrderType)   ? data.Header.OrderType   : null,
                    Dummy_Product_Code__c = dummyCode,
                    Ship_To_Party__c      = String.isNotBlank(data.Header.ShipToParty) ? data.Header.ShipToParty : null,
                    Sold_To_Party__c      = String.isNotBlank(data.Header.SoldToParty) ? data.Header.SoldToParty : null,
                    Account__c            = acct != null ? acct.Id : null,
                    Product__c            = prod != null ? prod.Id : null
                );
                
                headersToInsert.add(newHeader);
                newHeaderKeys.add(headerKey);
                headerByKey.put(headerKey, newHeader);
                headerOps.add(new Map<String, String>{
                    'externalId' => headerKey,
                        'sfId'       => '',
                        'operation'  => 'CREATED'
                        });
            }
            
            if (!headersToInsert.isEmpty()) {
                insert headersToInsert;
                for (Integer i = 0; i < headersToInsert.size(); i++) {
                    String key = newHeaderKeys[i];
                    existingHeaderMap.put(key, headersToInsert[i]);
                    headerByKey.put(key, headersToInsert[i]);
                    for (Map<String, String> op : headerOps) {
                        if (op.get('externalId') == key && op.get('operation') == 'CREATED' && op.get('sfId') == '') {
                            op.put('sfId', headersToInsert[i].Id);
                            break;
                        }
                    }
                }
            }
            
            operationsMap.put('Secondary_Sales_Header__c', headerOps);
            
            // ══════════════════════════════════════════════════════════════
            // STEP 6 – Build & Insert Order Lines
            // ══════════════════════════════════════════════════════════════
            
            Set<Id> allOrderSfIds = new Set<Id>();
            for (Secondary_Sales_Order__c o : orderByKey.values()) {
                if (o != null && o.Id != null) allOrderSfIds.add(o.Id);
            }
            
            Map<String, Secondary_Sales_Order_Line__c> existingLineMap = new Map<String, Secondary_Sales_Order_Line__c>();
            for (Secondary_Sales_Order_Line__c l : [
                SELECT Id, External_Order_Line_Key__c, Secondary_Sales_Order__c
                FROM   Secondary_Sales_Order_Line__c
                WHERE  Secondary_Sales_Order__c IN :allOrderSfIds
            ]) {
                existingLineMap.put(l.External_Order_Line_Key__c, l);
            }
            
            List<Secondary_Sales_Order_Line__c>        linesToInsert     = new List<Secondary_Sales_Order_Line__c>();
            List<String>                               newLineKeys       = new List<String>();
            List<Map<String, String>>                  lineOps           = new List<Map<String, String>>();
            Map<String, Secondary_Sales_Order_Line__c> lineByKey         = new Map<String, Secondary_Sales_Order_Line__c>();
            Set<String>                                processedLineKeys = new Set<String>();
            
            for (String k : existingLineMap.keySet()) {
                lineByKey.put(k, existingLineMap.get(k));
            }
            
            for (SecondarySalesWrapper.SecondarySalesRequest payload : lstPayload) {
                
                SecondarySalesWrapper.SalesOrder data     = payload.SalesOrder;
                Boolean                          isReturn = data.Header.OrderType == 'ZRE';
                
                String orderId =
                    (isReturn && String.isNotBlank(data.Header.ReturnReferenceOrder))
                    ? data.Header.ReturnReferenceOrder
                    : data.Header.SAPOrderNumber;
                
                Secondary_Sales_Order__c orderRec = orderByKey.get(orderId);
                if (orderRec == null || orderRec.Id == null) continue;
                
                for (SecondarySalesWrapper.Item item : data.Items) {
                    
                    if (item == null || String.isBlank(item.MaterialNumber)) continue;
                    
                    String lineKey = orderId + item.MaterialNumber;
                    
                    if (processedLineKeys.contains(lineKey)) continue;
                    processedLineKeys.add(lineKey);
                    
                    if (existingLineMap.containsKey(lineKey)) {
                        Secondary_Sales_Order_Line__c existing = existingLineMap.get(lineKey);
                        lineByKey.put(lineKey, existing);
                        lineOps.add(new Map<String, String>{
                            'externalId' => lineKey,
                                'sfId'       => existing.Id,
                                'operation'  => 'EXISTING'
                                });
                        continue;
                    }
                    
                    Secondary_Sales_Order_Line__c newLine = new Secondary_Sales_Order_Line__c(
                        Secondary_Sales_Order__c   = orderRec.Id,
                        External_Order_Line_Key__c = lineKey,
                        Order_Item_Number__c       = String.isNotBlank(item.OrderItemNumber) ? item.OrderItemNumber : null,
                        Order_Date__c =
                        String.isNotBlank(item.OrderDate)
                        ? Date.valueOf(item.OrderDate)
                        : String.isNotBlank(item.ReturnDate)
                        ? Date.valueOf(item.ReturnDate)
                        : null,                        Material_Number__c         = item.MaterialNumber,
                        Dummy_Product_Code__c      = item.DummyProductCode,
                        Plant__c                   = item.Plant,
                        Ordered_Quantity__c =
                        String.isNotBlank(item.OrderQuantity)
                        ? Decimal.valueOf(item.OrderQuantity)
                        : String.isNotBlank(item.ReturnQuantity)
                        ? Decimal.valueOf(item.ReturnQuantity)
                        : null,
                        
                        Return_Quantity__c =
                        (isReturn && String.isNotBlank(item.ReturnQuantity))
                        ? Decimal.valueOf(item.ReturnQuantity)
                        : null,
                        Return_Date__c             = (isReturn && String.isNotBlank(item.ReturnDate))   ? Date.valueOf(item.ReturnDate) : null,
                        Return_Reason__c =
                        (isReturn && String.isNotBlank(item.ReturnReason))
                        ? item.ReturnReason
                        : null
                    );
                    
                    linesToInsert.add(newLine);
                    newLineKeys.add(lineKey);
                    lineByKey.put(lineKey, newLine);
                    lineOps.add(new Map<String, String>{
                        'externalId' => lineKey,
                            'sfId'       => '',
                            'operation'  => 'CREATED'
                            });
                }
            }
            
            if (!linesToInsert.isEmpty()) {
                insert linesToInsert;
                for (Integer i = 0; i < linesToInsert.size(); i++) {
                    String key = newLineKeys[i];
                    existingLineMap.put(key, linesToInsert[i]);
                    lineByKey.put(key, linesToInsert[i]);
                    for (Map<String, String> op : lineOps) {
                        if (op.get('externalId') == key && op.get('operation') == 'CREATED' && op.get('sfId') == '') {
                            op.put('sfId', linesToInsert[i].Id);
                            break;
                        }
                    }
                }
            }
            
            operationsMap.put('Secondary_Sales_Order_Line__c', lineOps);
            
            // ══════════════════════════════════════════════════════════════
            // STEP 7 – Build & Insert Line Items + Deliveries
            // ══════════════════════════════════════════════════════════════
            
            Set<Id> allHeaderSfIds = new Set<Id>();
            for (Secondary_Sales_Header__c h : headerByKey.values()) {
                if (h != null && h.Id != null) allHeaderSfIds.add(h.Id);
            }
            
            Map<String, Secondary_Sales_Delivery__c> existingDeliveryMap = new Map<String, Secondary_Sales_Delivery__c>();
            for (Secondary_Sales_Delivery__c d : [
                SELECT Id, External_Delivery_Key__c
                FROM   Secondary_Sales_Delivery__c
                WHERE  Secondary_Sales_Order__c IN :allOrderSfIds
            ]) {
                existingDeliveryMap.put(d.External_Delivery_Key__c, d);
            }
            
            Map<String, Secondary_Sales_Line_Item__c> existingLineItemMap = new Map<String, Secondary_Sales_Line_Item__c>();
            for (Secondary_Sales_Line_Item__c li : [
                SELECT Id, Material_Number__c, Type__c, Secondary_Sales_Header__c
                FROM   Secondary_Sales_Line_Item__c
                WHERE  Secondary_Sales_Header__c IN :allHeaderSfIds
            ]) {
                String liKey = String.valueOf(li.Secondary_Sales_Header__c) + li.Material_Number__c + li.Type__c;
                existingLineItemMap.put(liKey, li);
            }
            
            List<Secondary_Sales_Line_Item__c> lineItemsToInsert     = new List<Secondary_Sales_Line_Item__c>();
            List<Secondary_Sales_Delivery__c>  deliveriesToInsert    = new List<Secondary_Sales_Delivery__c>();
            List<Map<String, String>>          lineItemOps           = new List<Map<String, String>>();
            List<Map<String, String>>          deliveryOps           = new List<Map<String, String>>();
            List<String>                       newLineItemKeys       = new List<String>();
            List<String>                       newDeliveryKeys       = new List<String>();
            Set<String>                        processedLineItemKeys = new Set<String>();
            Set<String>                        processedDeliveryKeys = new Set<String>();
            
            for (SecondarySalesWrapper.SecondarySalesRequest payload : lstPayload) {
                
                SecondarySalesWrapper.SalesOrder data     = payload.SalesOrder;
                Boolean                          isReturn = data.Header.OrderType == 'ZRE';
                
                String orderId =
                    (isReturn && data.Header.ReturnReferenceOrder != null)
                    ? data.Header.ReturnReferenceOrder
                    : data.Header.SAPOrderNumber;
                
                Secondary_Sales_Order__c  orderRec  = orderByKey.get(orderId);
                Secondary_Sales_Header__c headerRec = headerByKey.get(orderId);
                
                if (orderRec == null || orderRec.Id == null || headerRec == null || headerRec.Id == null) continue;
                
                for (SecondarySalesWrapper.Item item : data.Items) {
                    
                    if (item == null || String.isBlank(item.MaterialNumber)) continue;
                    
                    Product__c itemProd = String.isNotBlank(item.DummyProductCode) ? productMap.get(item.DummyProductCode) : null;
                    
                    String liType  = isReturn ? 'Return Goods' : 'Open';
                    String openKey = String.valueOf(headerRec.Id) + item.MaterialNumber + liType;
                    
                    if (!existingLineItemMap.containsKey(openKey) && !processedLineItemKeys.contains(openKey)) {
                        
                        lineItemsToInsert.add(new Secondary_Sales_Line_Item__c(
                            Secondary_Sales_Header__c = headerRec.Id,
                            Plant__c                  = item.Plant,
                            Material_Number__c        = item.MaterialNumber,
                            Dummy_Product_Code__c     = item.DummyProductCode,
                            Product__c                = itemProd != null ? itemProd.Id : null,
                            Quantity__c =
                            String.isNotBlank(item.OrderQuantity)
                            ? Decimal.valueOf(item.OrderQuantity)
                            : String.isNotBlank(item.ReturnQuantity)
                            ? Decimal.valueOf(item.ReturnQuantity)
                            : null,
                            Return_Quantity__c =
                            (isReturn && String.isNotBlank(item.ReturnQuantity))
                            ? Decimal.valueOf(item.ReturnQuantity)
                            : null,
                            Return_Reason__c =
                            (isReturn && String.isNotBlank(item.ReturnReason))
                            ? item.ReturnReason
                            : null,
                            Date__c                   = String.isNotBlank(item.OrderDate) ? Date.valueOf(item.OrderDate) : String.isNotBlank(item.ReturnDate) ? Date.valueOf(item.ReturnDate) : null,
                            Type__c                   = liType
                        ));
                        
                        newLineItemKeys.add(openKey);
                        processedLineItemKeys.add(openKey);
                        lineItemOps.add(new Map<String, String>{
                            'externalId' => openKey,
                                'sfId'       => '',
                                'operation'  => 'CREATED'
                                });
                        
                    } else {
                        Secondary_Sales_Line_Item__c existing = existingLineItemMap.get(openKey);
                        lineItemOps.add(new Map<String, String>{
                            'externalId' => openKey,
                                'sfId'       => existing != null ? existing.Id : '',
                                    'operation'  => 'EXISTING'
                                    });
                    }
                    
                    if (item.Delivery != null && !item.Delivery.isEmpty()) {
                        
                        for (SecondarySalesWrapper.Delivery del : item.Delivery) {
                            
                            if (del == null || String.isBlank(del.DeliveryNumber)) continue;
                            
                            String extDeliveryKey = orderId + item.MaterialNumber + del.DeliveryNumber;
                            
                            if (existingDeliveryMap.containsKey(extDeliveryKey) || processedDeliveryKeys.contains(extDeliveryKey)) {
                                Secondary_Sales_Delivery__c existing = existingDeliveryMap.get(extDeliveryKey);
                                deliveryOps.add(new Map<String, String>{
                                    'externalId' => extDeliveryKey,
                                        'sfId'       => existing != null ? existing.Id : '',
                                            'operation'  => 'EXISTING'
                                            });
                                continue;
                            }
                            
                            // Old code logic — uses existingLineMap only
                            Secondary_Sales_Order_Line__c lineRec = existingLineMap.get(orderId + item.MaterialNumber);
                            
                            deliveriesToInsert.add(new Secondary_Sales_Delivery__c(
                                Secondary_Sales_Order__c       = orderRec.Id,
                                Secondary_Sales_Order_Line__c  = lineRec != null ? lineRec.Id : null,
                                External_Delivery_Key__c       = extDeliveryKey,
                                Secondary_Sales_Delivery_Id__c = del.DeliveryNumber,
                                Delivery_Status__c             = isReturn ? 'Return' : 'Delivered',
                                Dummy_Product_Code__c          = item.DummyProductCode,
                                Material_Number__c             = del.MaterialNumber,
                                Delivered_Quantity__c =
                                String.isNotBlank(del.DeliveryQTY)
                                ? Decimal.valueOf(del.DeliveryQTY)
                                : null,
                                PGI_Date__c =
                                String.isNotBlank(del.PGIDate)
                                ? Date.valueOf(del.PGIDate)
                                : null
                            ));
                            
                            newDeliveryKeys.add(extDeliveryKey);
                            processedDeliveryKeys.add(extDeliveryKey);
                            deliveryOps.add(new Map<String, String>{
                                'externalId' => extDeliveryKey,
                                    'sfId'       => '',
                                    'operation'  => 'CREATED'
                                    });
                            
                            // ✅ In Transit — ONLY for ZSTP / ZEOR (NOT ZRE)
                            if (!isReturn && String.isNotBlank(del.MaterialNumber)) {
                                
                                String delDummyCode  = String.isNotBlank(del.DummyProductCode) ? del.DummyProductCode : item.DummyProductCode;
                                Product__c delProd   = String.isNotBlank(delDummyCode) ? productMap.get(delDummyCode) : null;
                                String inTransitKey  = String.valueOf(headerRec.Id) + del.MaterialNumber + 'In Transit';
                                
                                if (!existingLineItemMap.containsKey(inTransitKey) && !processedLineItemKeys.contains(inTransitKey)) {
                                    
                                    lineItemsToInsert.add(new Secondary_Sales_Line_Item__c(
                                        Secondary_Sales_Header__c = headerRec.Id,
                                        Plant__c                  = item.Plant,
                                        Material_Number__c        = del.MaterialNumber,
                                        Dummy_Product_Code__c     = String.isNotBlank(delDummyCode) ? delDummyCode : null,
                                        Product__c                = delProd != null ? delProd.Id : null,
                                        Quantity__c =
                                        String.isNotBlank(item.OrderQuantity)
                                        ? Decimal.valueOf(item.OrderQuantity)
                                        : String.isNotBlank(item.ReturnQuantity)
                                        ? Decimal.valueOf(item.ReturnQuantity)
                                        : null,
                                        Type__c                   = 'In Transit',
                                        Date__c                   = String.isNotBlank(del.PGIDate) ? Date.valueOf(del.PGIDate) : null
                                    ));
                                    
                                    newLineItemKeys.add(inTransitKey);
                                    processedLineItemKeys.add(inTransitKey);
                                    lineItemOps.add(new Map<String, String>{
                                        'externalId' => inTransitKey,
                                            'sfId'       => '',
                                            'operation'  => 'CREATED'
                                            });
                                } else {
                                    Secondary_Sales_Line_Item__c existing = existingLineItemMap.get(inTransitKey);
                                    lineItemOps.add(new Map<String, String>{
                                        'externalId' => inTransitKey,
                                            'sfId'       => existing != null ? existing.Id : '',
                                                'operation'  => 'EXISTING'
                                                });
                                }
                            }
                        }
                    }
                }
            }
            
            if (!lineItemsToInsert.isEmpty()) {
                insert lineItemsToInsert;
                for (Integer i = 0; i < lineItemsToInsert.size(); i++) {
                    String key = newLineItemKeys[i];
                    existingLineItemMap.put(key, lineItemsToInsert[i]);
                    for (Map<String, String> op : lineItemOps) {
                        if (op.get('externalId') == key && op.get('operation') == 'CREATED' && op.get('sfId') == '') {
                            op.put('sfId', lineItemsToInsert[i].Id);
                            break;
                        }
                    }
                }
            }
            
            if (!deliveriesToInsert.isEmpty()) {
                insert deliveriesToInsert;
                for (Integer i = 0; i < deliveriesToInsert.size(); i++) {
                    String key = newDeliveryKeys[i];
                    existingDeliveryMap.put(key, deliveriesToInsert[i]);
                    for (Map<String, String> op : deliveryOps) {
                        if (op.get('externalId') == key && op.get('operation') == 'CREATED' && op.get('sfId') == '') {
                            op.put('sfId', deliveriesToInsert[i].Id);
                            break;
                        }
                    }
                }
            }
            
            operationsMap.put('Secondary_Sales_Line_Item__c', lineItemOps);
            operationsMap.put('Secondary_Sales_Delivery__c',  deliveryOps);
            
            // ══════════════════════════════════════════════════════════════
            // STEP 8 – Build Response + Enqueue Queueable
            // ══════════════════════════════════════════════════════════════
            response.put('operations', operationsMap);
            response.put('counts', new Map<String, Integer>{
                'Orders'     => operationsMap.containsKey('Secondary_Sales_Order__c')      ? operationsMap.get('Secondary_Sales_Order__c').size()      : 0,
                    'Headers'    => operationsMap.containsKey('Secondary_Sales_Header__c')     ? operationsMap.get('Secondary_Sales_Header__c').size()     : 0,
                        'OrderLines' => operationsMap.containsKey('Secondary_Sales_Order_Line__c') ? operationsMap.get('Secondary_Sales_Order_Line__c').size() : 0,
                            'LineItems'  => operationsMap.containsKey('Secondary_Sales_Line_Item__c')  ? operationsMap.get('Secondary_Sales_Line_Item__c').size()  : 0,
                                'Deliveries' => operationsMap.containsKey('Secondary_Sales_Delivery__c')   ? operationsMap.get('Secondary_Sales_Delivery__c').size()   : 0
                                    });
            response.put('status',  'SUCCESS');
            response.put('message', 'Secondary Sales Order processed successfully');
            
            Id jobId = System.enqueueJob(new SAPSecondarySalesQueueable(requestBody));
            response.put('jobId', jobId);
            
            res.statusCode   = 200;
            res.responseBody = Blob.valueOf(JSON.serializePretty(response));
            System.debug('==> Response: ' + JSON.serializePretty(response));
            
        } catch (Exception e) {
            System.debug('==> Exception: ' + e.getMessage() + ' | Line: ' + e.getLineNumber() + ' | Stack: ' + e.getStackTraceString());
            res.statusCode   = 500;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'status'     => 'ERROR',
                    'message'    => e.getMessage(),
                    'lineNumber' => e.getLineNumber(),
                    'stackTrace' => e.getStackTraceString()
                    }));
        }
    }
}