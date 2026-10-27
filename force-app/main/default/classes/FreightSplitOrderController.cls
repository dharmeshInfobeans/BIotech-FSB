public class FreightSplitOrderController {
    
    //  Common variables
    public static String orderRecId { get; set; }
    public static Order__c orderData = new Order__c();
    public static Map<Id, ItemWrapper> orderItemMap = new Map<Id, ItemWrapper>();
    public static Map<String, String> modeltostockMap = new Map<String, String>();
    public static Map<Id, Order_Product__c> orderProductMap = new Map<Id, Order_Product__c>();
    public static Set<Id> productwithoutStockIdSet = new Set<Id>();
    public static Map<String, String> searchedMaterialCode = new Map<String, String>();
    
    private static String INTERNATIONAL_STRING = 'International';
    private static String PHAKIC_STRING = 'PHAKIC';
    private static String TORIC_STRING = 'TORIC';
    
    // ============================
    // 🔹 LWC Methods
    // ============================
    @AuraEnabled
    public static String getSplitOrderData(Id orderId) {
        
        // Prepare SAP request body
        fetchOrderData(orderId);
        
        RecordWrapper orderObj = new RecordWrapper();
        orderObj.Source = 'SF';
        orderObj.Customer = orderData.Account__r.SAP_Code__c;
        orderObj.ShipToParty = orderData.Consignee_Code__c;
        orderObj.SoldToParty = orderData.Account__r.SAP_Code__c;
        orderObj.ContractNumber = orderData.CONTRACT_NO__c;
        orderObj.OrderCreationDate = String.valueOf(orderData.Order_Date__c);
        orderObj.Application_Order_Number = orderData.Name;
        orderObj.Items = prepareRequestBody();
        
        RequestWrapper body = new RequestWrapper();
        body.Record = orderObj;
        
        String bodyStr = JSON.serialize(body);
        
        // Build HTTP request
        SAP_Creds__c credential = SAP_Creds__c.getValues('SAP_Fright_Split_Order');
        
        HttpRequest req = new HttpRequest();
        req.setEndpoint(credential.Endpoint__c);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Source', 'SF');
        
        String auth = EncodingUtil.base64Encode(
            Blob.valueOf(credential.Username__c + ':' + credential.Password__c)
        );
        req.setHeader('Authorization', 'Basic ' + auth);
        req.setBody(bodyStr);
        
        System.debug('SAP Request Body -> ' + bodyStr);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        String responseBody = res.getBody();
        System.debug('SAP Response Body -> ' + responseBody);
        //If (Test.isRunningTest()){
        // Fix root object vs array issue
        if (responseBody.startsWith('{') && responseBody.contains('"root":{')) {
            responseBody = responseBody.replaceFirst('"root":\\{', '"root":[{');
            responseBody = responseBody.substring(0, responseBody.length() - 1) + ']}';
        }
        //}
        
        SAPResponseRoot sapResp =
            (SAPResponseRoot) JSON.deserialize(responseBody, SAPResponseRoot.class);
        
        System.debug('Parsed SAP Response -> ' + sapResp);
        
        // ================= SAP BUSINESS ERROR =================
        if (sapResp != null &&
            sapResp.root != null &&
            !sapResp.root.isEmpty() &&
            String.valueOf(sapResp.root[0].Statuscode).trim() == '0') {
                
                String emailSubject =
                    'Freight Split Simulation Failed | Order ' + orderData.Name;
                
                // Query Order
                Order__c orderRec = [
                    SELECT Account__r.Name,
                    Account__r.SAP_Code__c,
                    Name,
                    Customer_Po_No__c,
                    CONTRACT_NO__c,
                    Proforma_Invoice_No__c,
                    Account__r.CRM_2_Email__c,
                    Account__r.CRM_Approver__r.Email,
                    Order_Approval_Date_in_ddmmmyy_Format__c,
                    OwnerId,
                    CRM_Approver__c
                    FROM Order__c
                    WHERE Id = :orderData.Id
                    LIMIT 1
                ];
                
                // Build email body        
                
                String emailBody = generateSapOrderSyncEmailBody(
                    orderRec,
                    orderProductMap,
                    productwithoutStockIdSet,
                    modeltostockMap,
                    searchedMaterialCode
                );
                
                emailBody =
                    emailBody +
                    '<b>Context:</b><br/>' +
                    'This error occurred during the SAP freight Order split simulation step.<br/><br/>' +
                    'Freight could not be calculated because split order data generation failed.<br/>' +
                    'Order has <b>NOT</b> been sent for actual creation or freight posting.<br/><br/>' +
                    '<b>Timestamp:</b><br/>' +
                    String.valueOf(System.now());
                
                // Get Order Owner Email
                List<User> users = [
                    SELECT Email, Username
                    FROM User
                    WHERE Id IN (
                      //  :orderRec.OwnerId,
                        :orderRec.CRM_Approver__c
                    )
                    OR Name = 'Komal Bhatia'
                ];
                
                List<String> ccEmails = new List<String>();
                
                for (User u : users) {
                    if (!String.isBlank(u.Email)) {
                        ccEmails.add(u.Email);
                    }
                }
                
                
                
                // ================= Combined Request + Response Attachment =================
                String combinedJson =
                    '==============================\n' +
                    ' SAP FREIGHT SPLIT SIMULATION\n' +
                    '==============================\n\n' +
                    '---------- REQUEST ----------\n' +
                    JSON.serializePretty(body) +
                    '\n\n' +
                    '---------- RESPONSE ----------\n';
                
                try {
                    combinedJson += JSON.serializePretty(
                        JSON.deserializeUntyped(responseBody)
                    );
                } catch (Exception ex) {
                    combinedJson += responseBody;
                }
                
                
                // JSON attachment
                Messaging.EmailFileAttachment jsonAttachment =
                    new Messaging.EmailFileAttachment();
                jsonAttachment.setFileName(
                    'SplitOrderRequest_' + orderData.Name + '.json'
                );
                jsonAttachment.setBody(Blob.valueOf(combinedJson));
                jsonAttachment.setContentType('application/json');
                
                // Send Email
                try {
                    Messaging.SingleEmailMessage mail =
                        new Messaging.SingleEmailMessage();
                    mail.setToAddresses(
                        new String[] { 'dharmeshkumar.vaishnav@infobeans.com' }
                    );
                    
                    if (!ccEmails.isEmpty()) {
                        mail.setCcAddresses(ccEmails);
                    }
                    mail.setSubject(emailSubject);
                    mail.setHtmlBody(emailBody);
                    mail.setFileAttachments(
                        new Messaging.EmailFileAttachment[] { jsonAttachment }
                    );
                    
                    Messaging.sendEmail(
                        new Messaging.SingleEmailMessage[] { mail }
                    );
                } catch (Exception e) {
                    System.debug(
                        'Error sending SAP error email -> ' + e.getMessage()
                    );
                }
                
                // Return error to LWC
                SAPErrorResponse err = new SAPErrorResponse();
                err.error = new SAPError();
                err.error.code = 'SAP_BUSINESS_ERROR';
                err.error.message =
                    'Error fetching split Order data from SAP';
                err.error.logID = null;
                
                return JSON.serialize(err);
            }
        
        // ================= REAL SUCCESS =================
        List<SplitOrderWrapper> lwcData =
            buildSplitOrderDetails(sapResp);
        return JSON.serialize(lwcData);
    }
    
    @AuraEnabled
    public static void saveOrderProductQuantities(Id orderId, List<ProductWrapper> products) {
        try {
            List<Order_Product__c> opToUpdate = new List<Order_Product__c>();
            for (ProductWrapper p : products) {
                if (p.orderProductId != null) {
                    opToUpdate.add(new Order_Product__c(Id = p.orderProductId, Quantity__c = p.orderQuantity));
                }
            }
            if (!opToUpdate.isEmpty()) update opToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException('Failed to save order quantities: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void saveQuantitiesAndApproveFreight(Id orderId, List<ProductWrapper> products, List<SplitWrapper> splitData) {
        try {
            // 1️⃣ Save Quantities
            List<Order_Product__c> opToUpdate = new List<Order_Product__c>();
            for (ProductWrapper p : products) {
                if (p.orderProductId != null) {
                    opToUpdate.add(new Order_Product__c(Id = p.orderProductId, Quantity__c = p.orderQuantity));
                }
            }
            if (!opToUpdate.isEmpty()) update opToUpdate;
            
            // 2️⃣ Approve Freight
            List<Split_Order__c> splitOrdersToInsert = new List<Split_Order__c>();
            for (SplitWrapper split : splitData) {
                Split_Order__c splitOrder = new Split_Order__c();
                splitOrder.Transport_Mode__c = split.transactionMode;
                splitOrder.Status__c = 'FrightApproved';
                splitOrder.Order__c = orderId;
                splitOrder.EstimationId_Temp__c = split.estimationId;
                splitOrder.quotaionId_Temp__c = split.quotaionId;
                splitOrder.RFQNumber_Temp__c = split.rfqNumber;
                splitOrder.Approx_Freight__c = Decimal.valueOf(split.approxFreight);
                splitOrder.CurrencyIsoCode = split.currencyType;
                
                if (split.orderProductIds != null && !split.orderProductIds.isEmpty()) {
                    splitOrder.Order_Product_Ids__c = String.join(split.orderProductIds, ',');
                }
                splitOrdersToInsert.add(splitOrder);
            }
            if (!splitOrdersToInsert.isEmpty()) insert splitOrdersToInsert;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving quantities and approving freight: ' + e.getMessage());
        }
    }
    
    // Convert SAP response into LWC-friendly structure
    public static List<SplitOrderWrapper> buildSplitOrderDetails(SAPResponseRoot parsedResponse) {
        List<SAPResponseWrapper> responses = parsedResponse.root;
        Set<Id> allOrderProductIds = new Set<Id>();
        for (SAPResponseWrapper resp : responses) {
            if (!String.isBlank(resp.OrderProductsId)) {
                for (String opId : resp.OrderProductsId.split('\\$\\$')) {
                    if (String.isNotBlank(opId)) allOrderProductIds.add((Id) opId.trim());
                }
            }
        }
        
        Map<Id, Order_Product__c> orderProductMapLocal = new Map<Id, Order_Product__c>(
            [SELECT Id, Name, Quantity__c, Order__r.CurrencyIsoCode,
             Agreement_Product__r.Incoterms__c, Product__r.Name
             FROM Order_Product__c WHERE Id IN :allOrderProductIds]
        );
        
        List<Split_Order__c> approvedSplitOrderLst = [SELECT Id, Status__c FROM Split_Order__c WHERE Status__c = 'FrightApproved' AND Order__c = :orderRecId];
        
        List<SplitOrderWrapper> splitWrappers = new List<SplitOrderWrapper>();
        Integer counter = 1;
        String currencyType = orderProductMapLocal.isEmpty() ? null : orderProductMapLocal.values()[0].Order__r.CurrencyIsoCode;
        Boolean showApproxFreight = false;
        
        for (SAPResponseWrapper resp : responses) {
            List<SplitOrderProductWrapperForLWC> productWrappers = new List<SplitOrderProductWrapperForLWC>();
            if (!String.isBlank(resp.OrderProductsId)) {
                for (String opId : resp.OrderProductsId.split('\\$\\$')) {
                    Id orderProdId;
                    try { orderProdId = (Id) opId.trim(); } catch (Exception e) { continue; }
                    if (orderProductMapLocal.containsKey(orderProdId)) {
                        Order_Product__c op = orderProductMapLocal.get(orderProdId);
                        System.debug('orderProductMapLocal.get(orderProdId).Agreement_Product__r.Incoterms__c)'+orderProductMapLocal.get(orderProdId).Agreement_Product__r.Incoterms__c);
                        System.debug('op.Agreement_Product__r.Incoterms__c'+op.Agreement_Product__r.Incoterms__c);
                        productWrappers.add(new SplitOrderProductWrapperForLWC(op.Id, op.Name, op.Product__r.Name,op.Agreement_Product__r.Incoterms__c, op.Quantity__c));
                    }
                }
            }
            splitWrappers.add(new SplitOrderWrapper('SP' + counter, resp.Plant, currencyType, showApproxFreight, productWrappers));
            counter++;
        }
        return splitWrappers;
    }
    
    // ============================
    // 🔹 SAP Callouts & Helpers
    // ============================
    /* 
* this method is not in use
* public static String fetchOrderSplitResponse(Id pOrderId) {
fetchOrderData(pOrderId);

RecordWrapper orderObj = new RecordWrapper();
orderObj.Source = 'SF';
orderObj.Customer = orderData.Account__r.SAP_Code__c;
orderObj.ShipToParty = orderData.Consignee_Code__c;
orderObj.SoldToParty = orderData.Account__r.SAP_Code__c;
orderObj.ContractNumber = orderData.CONTRACT_NO__c;
orderObj.OrderCreationDate = String.valueOf(orderData.Order_Date__c);
orderObj.Application_Order_Number = orderData.Name;
orderObj.Items = prepareRequestBody();

RequestWrapper body = new RequestWrapper();
body.Record = orderObj;
String bodyStr = JSON.serialize(body);
System.debug('bodyStr-->'+bodyStr);

SAP_Creds__c credential = SAP_Creds__c.getValues('SAP_Fright_Split_Order');
String username = credential.Username__c;
String password = credential.Password__c;
Blob headerValue = Blob.valueOf(username + ':' + password);
String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);

HttpRequest req = new HttpRequest();
Http http = new Http();
req.setEndpoint(credential.Endpoint__c);
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('Source', 'SF');
req.setHeader('Authorization', authorizationHeader);
req.setBody(bodyStr);

HttpResponse res = http.send(req);

if (res.getStatusCode() != 200) {
String errorMsg = 'Error from SAP → Status Code: ' + res.getStatusCode() + '\nResponse Body:\n' + res.getBody();
try { ReusableUtilityClass.sendSapErrorEmail(errorMsg); } catch (Exception e) {}
return JSON.serialize(new Map<String, Object>{ 'Statuscode' => res.getStatusCode(), 'Message' => errorMsg });
}

return res.getBody();
}
*/
    public static void fetchOrderData(Id pOrderId){
        Set<Id> productIdSet = new Set<Id>();
        Set<String> modelNameSet = new Set<String>();
        Set<Id> parentOrderProductSet = new Set<Id> ();
        Map<String, String> optoPowerMap = new Map<String, String>();
        Map<String, String> optoQuantityMap = new Map<String, String>();
        List<Product_Model__c> productModelList = new List<Product_Model__c>();
        Map<String, Decimal> plantToFreightAmtMap = new Map<String, Decimal>();
        List<Order__c> orderList = new List<Order__c>();
        String matchingMaterialCode = '';
        
        orderList = [SELECT id, CurrencyIsoCode, Name, Account__c,Account__r.Name, Account__r.SAP_Code__c,Consignee_Code__c,CONTRACT_NO__c,
                     Order_Activation_Date__c, Account__r.Company_Code__c,Customer_Po_No__c,Order_Creation_Time_Out__c, Dispatch_Through__c,
                     Order_Date__c,Freight_Amount_SplitOrder_Based__c,OwnerId,
                     (SELECT id, Name, Product__c, Product__r.Name, Product__r.Region__c,  Product__r.Category__c, Quantity__c,
                      Total_Price__c, Agreement_Product__c, Model_Txt__c,Product__r.Dummy_Product_Code__c,
                      Axis_Angle__c, Cyindrical_Power__c, Spherical_Power__c,FOC_Quantity__c,Parent_Order_Product__c,Parent_Order_Product__r.FOC_Quantity__c,
                      Agreement_Product__r.Incoterms__c, Agreement_Product__r.Payment_Terms_options__c, Agreement_Product__r.Plant__c,
                      Agreement_Product__r.Master_Agreement__r.Agreement_Signed_With__c,Agreement_Product__r.Is_Backup__c
                      FROM Order_Products__r),
                     (SELECT id, Plant__c, Plant__r.Name,Products__c
                      FROM Freight_Requests__r)
                     FROM Order__c
                     WHERE id =: pOrderId];
        if(orderList.size() > 0) {
            orderData = orderList[0];
        }
        if(orderData != null) {
            /*for(Freight_Request__c frObj : orderData.Freight_Requests__r){
if(frObj.Products__c.contains(',')) {
List<String> ProductNameList = new List<String>();
ProductNameList = frObj.Products__c.split(',');
for(String productStr : ProductNameList) {
plantToFreightAmtMap.put(frObj.Plant__r.Name+productStr, frObj.Freight_Amount__c);
}
} else {
plantToFreightAmtMap.put(frObj.Plant__r.Name+frObj.Products__c, frObj.Freight_Amount__c);
}
}*/
            
            for(Order_Product__c orderProduct: orderData.Order_Products__r) {
                ItemWrapper itemObj = new ItemWrapper();
                String plantVal = orderProduct.Agreement_Product__r?.Plant__c;
                
                itemObj.Plant =
                    String.isNotBlank(plantVal) && plantVal.startsWith('8200')
                    ? '8200'
                    : '8100';
                
                
                itemObj.Pricing = String.ValueOf(orderProduct.Total_Price__c);
                itemObj.CommercialQty = String.ValueOf(orderProduct.Quantity__c);
                itemObj.FocQty = orderProduct.FOC_Quantity__c != null ? String.ValueOf(orderProduct.FOC_Quantity__c) : String.ValueOf('0');
                itemObj.ProductModel = orderProduct.Model_Txt__c  != null ? orderProduct.Model_Txt__c  :NULL;
                itemObj.Destination = orderProduct.Name;//this is not cortrect mapping and not used in integration .this is for debug purpose
                itemObj.DispatchThrough = orderData.Dispatch_Through__c;
                
                itemObj.PaymentTerms      = orderProduct.Agreement_Product__r?.Payment_Terms_options__c;
                itemObj.Incoterms         = orderProduct.Agreement_Product__r?.Incoterms__c;
                
                // AdditionalField1 – safely take first 4 chars
                itemObj.AdditionalField1  = String.isNotBlank(plantVal) && plantVal.length() >= 4
                    ? plantVal.substring(0,4)
                    : null;
                
                // AdditionalField2 – safely check nested relationship & containsIgnoreCase
                String signedWith = orderProduct.Agreement_Product__r?.Master_Agreement__r?.Agreement_Signed_With__c;
                itemObj.AdditionalField2  = String.isNotBlank(signedWith) && signedWith.containsIgnoreCase('GMBH')
                    ? 'ZSTP'
                    : 'ZEOR';
                
                // AdditionalField3
                itemObj.AdditionalField3  = orderProduct.Product__r?.Category__c;
                
                // AdditionalField4 – safely convert Boolean to String
                itemObj.AdditionalField4  = String.valueOf(orderProduct.Agreement_Product__r?.Is_Backup__c);
                
                itemObj.AdditionalField5 = orderProduct.Id;
                orderItemMap.put(orderProduct.Id, itemObj);
                orderProductMap.put(orderProduct.Id,orderProduct);
                
                if(orderProduct.Parent_Order_Product__c != null)  {
                    parentOrderProductSet.add(orderProduct.Parent_Order_Product__c);
                }
                if(!string.isEmpty(orderProduct.Model_Txt__c)) {
                    modelNameSet.add(orderProduct.Model_Txt__c);
                }
                productIdSet.add(orderProduct.Product__c);
            }
            for(Id parentopID : parentOrderProductSet){
                ItemWrapper itemObj = orderItemMap.remove(parentopID);
                orderProductMap.remove(parentopID);
            }
            
            Map<Id, Product__c> productStockMap  = new Map<Id, Product__c> ([SELECT Id, Name, Dummy_Product_Code__c,
                                                                             (SELECT Id, Plant__c, Material_Code__c, Quantity__c, Product_Models__c
                                                                              FROM Product_Material_Stocks__r  WHERE IsActive__c = TRUE order By LastmodifiedDate Desc)
                                                                             FROM Product__c WHERE Id IN:productIdSet]);
            
            List<Product_Model__c> modelStockList = [SELECT Id, Name, Product__c, Product__r.Dummy_Product_Code__c, Text_Name__c,
                                                     (SELECT Id, Plant__c, Material_Code__c, Quantity__c, Product_Id__c
                                                      FROM Product_Material_Stocks__r  WHERE IsActive__c = TRUE  order By LastmodifiedDate Desc)
                                                     FROM Product_Model__c
                                                     WHERE Text_Name__c IN : modelNameSet AND Product__c IN:productIdSet];
            
            Map<String, List<Product_Material_Stock__c>> modelStockMap  = new Map<String, List<Product_Material_Stock__c>>();
            for(Product_Model__c modelObj : modelStockList) {
                modelStockMap.put(modelObj.Text_Name__c, modelObj.Product_Material_Stocks__r);
            }
            
             Map<String, Map<String, List<Product_Material_Stock__c>>> ProductAndmodelStockMap =
                new Map<String, Map<String, List<Product_Material_Stock__c>>>();
            
            for (Product_Model__c modelObj : modelStockList) {
                
                String productCode = modelObj.Product__r.Dummy_Product_Code__c;
                String modelName = modelObj.Text_Name__c;
                
                // Create inner map if it does not exist
                if (!ProductAndmodelStockMap.containsKey(productCode)) {
                    ProductAndmodelStockMap.put(
                        productCode,
                        new Map<String, List<Product_Material_Stock__c>>()
                    );
                }
                
                // Add model and its stock list
                
                if (ProductAndmodelStockMap.get(productCode).containsKey(modelName)) {
                    ProductAndmodelStockMap.get(productCode)
                        .get(modelName)
                        .addAll(modelObj.Product_Material_Stocks__r);
                } else {
                    ProductAndmodelStockMap.get(productCode)
                        .put(modelName, modelObj.Product_Material_Stocks__r);
                }
            }
            
            System.debug('modelStockMap>>'+modelStockMap);
            
            
            for(Order_Product__c orderProduct: orderData.Order_Products__r) {
                
                List<Product_Material_Stock__c> stockList = new List<Product_Material_Stock__c>();
                if(!String.isEmpty(orderProduct.Model_Txt__c)) {
  					// stockList = modelStockMap.get(orderProduct.Model_Txt__c);
                    stockList =
                        ProductAndmodelStockMap.get(orderProduct.Product__r.Dummy_Product_Code__c).get(orderProduct.Model_Txt__c);
                          }
                else{
                    if(productStockMap.containsKey(orderProduct.Product__c)){
                        stockList = productStockMap.get(orderProduct.Product__c).Product_Material_Stocks__r;
                    }
                }
                String materialCodeMatch = '';
                
                if(!stockList.isempty() && stockList.size() > 1) {
                    
                    if(String.valueOf(orderProduct.Spherical_Power__c) != null) {
                        String spericalpowerStr = String.valueOf(orderProduct.Spherical_Power__c);
                        String cylindrcalpowerStr = String.valueOf(orderProduct.Cyindrical_Power__c);
                        String axisAngleStr = String.ValueOf(orderProduct.Axis_Angle__c);
                        if(spericalpowerStr != null) {
                            String partialPower = '';
                            String initPower;
                            Boolean isPhakicToric = orderProduct.Product__r?.Name.toUpperCase().contains(PHAKIC_STRING) && orderProduct.Product__r?.Name.toUpperCase().contains(TORIC_STRING) && orderProduct.Product__r?.Region__c==INTERNATIONAL_STRING;
                            if(spericalpowerStr.contains('-')) {
                                partialPower = spericalpowerStr.substringBetween('-','.');
                                initPower = partialPower;
                                partialPower = partialPower.length() == 1 && isPhakicToric ? '0'+partialPower : partialPower;
                                partialPower = 'N'+partialPower;
                                spericalpowerStr = spericalpowerStr.replaceFirst(initPower,partialPower).replace('-', '');
                            }
                            else {
                                partialPower = spericalpowerStr.substringBeforeLast('.');
                                initPower = partialPower;
                                partialPower = partialPower.length() == 1 && isPhakicToric ? '0'+partialPower : partialPower;
                                partialPower = 'P'+partialPower;
                                spericalpowerStr = spericalpowerStr.replaceFirst(initPower,partialPower);
                            }
                            materialCodeMatch = spericalpowerStr;
                        }
                        if(orderProduct.Product__r?.Dummy_Product_Code__c!='EP262'  && orderProduct.Product__r?.Dummy_Product_Code__c!='EP263'){
                            if(cylindrcalpowerStr != null){
                                if(axisAngleStr != null || orderProduct.Product__r?.Dummy_Product_Code__c == 'EP266') {
                                    cylindrcalpowerStr = cylindrcalpowerStr.replace('.','');
                                    cylindrcalpowerStr = cylindrcalpowerStr.length() == 1 ? cylindrcalpowerStr+'00' : cylindrcalpowerStr;
                                    materialCodeMatch = materialCodeMatch + 'C0'+cylindrcalpowerStr;
                                } else {
                                    cylindrcalpowerStr = cylindrcalpowerStr.length() == 1 ? cylindrcalpowerStr+'.00' : cylindrcalpowerStr;
                                    materialCodeMatch = materialCodeMatch + 'C'+cylindrcalpowerStr;
                                }
                            }
                            if(axisAngleStr != null){
                                String initAxis = '';
                                axisAngleStr = 'A'+axisAngleStr;
                                axisAngleStr = axisAngleStr.substringBefore('0');
                                initAxis = axisAngleStr.substringAfter('A');
                                axisAngleStr = axisAngleStr.length() == 2 ? 'A0'+initAxis : (axisAngleStr.length()==1? 'A00':axisAngleStr);
                                    materialCodeMatch = materialCodeMatch + axisAngleStr;
                            }
                        }
                        searchedMaterialCode.put(orderProduct.Id, materialCodeMatch);
                        for(Product_Material_Stock__c stock : stockList) {
                            if(stock.Material_Code__c.contains(materialCodeMatch) ){
                                modeltostockMap.put(orderProduct.Id,stock.Material_Code__c);
                                break;
                            }
                            else {
                                modeltostockMap.put(orderProduct.Id,orderProduct.Product__r?.Dummy_Product_Code__c);
                                productwithoutStockIdSet.add(orderProduct.Id);
                            }
                        }
                    }
                    else {
                        modeltostockMap.put(orderProduct.Id,stockList[0].Material_Code__c);
                    }
                }
                else if(stockList.isempty()) {
                    modeltostockMap.put(orderProduct.Id,orderProduct.Product__r?.Dummy_Product_Code__c);
                    productwithoutStockIdSet.add(orderProduct.Id);
                }
                else {
                    modeltostockMap.put(orderProduct.Id,stockList[0].Material_Code__c);
                }
                if(!modeltostockMap.containsKey(orderProduct.Id)) {
                    modeltostockMap.put(orderProduct.Id,stockList[0].Material_Code__c);
                }
            }
        }
        
    }
    
    
    public static List<ItemWrapper> prepareRequestBody() {
        List<ItemWrapper> orderItemList = new List<ItemWrapper>();
        for (Order_Product__c orderProduct : orderData.Order_Products__r) {
            ItemWrapper itemObj = orderItemMap.get(orderProduct.Id);
            if (itemObj != null) {
                if (modeltostockMap.containsKey(orderProduct.Id)) {
                    itemObj.ProductCode = modeltostockMap.get(orderProduct.Id);
                }
                orderItemList.add(itemObj);
            }
        }
        return orderItemList;
    }
    
    public static String generateSapOrderSyncEmailBody(Order__c orderRec, 
                                                       Map<Id, Order_Product__c> orderProductMap, 
                                                       Set<Id> productwithoutStockIdSet, 
                                                       Map<String, String> modeltostockMap, 
                                                       Map<String, String> searchedMaterialCode                                                      ) {
                                                           String orderDetailsTable = '<br/><br/><table border="1">' +
                                                               '<tr><th>Order Number</th><th>Account Name</th><th>SAP Code</th>' +
                                                               '<th>Customer PO No</th><th>PFI No.</th><th>SC No.</th></tr>';
                                                           
                                                           if (orderRec != null) {
                                                               orderDetailsTable += '<tr>';
                                                               orderDetailsTable += '<td>' + orderRec.Name + '</td>';
                                                               orderDetailsTable += '<td>' + orderRec.Account__r.Name + '</td>';
                                                               orderDetailsTable += '<td>' + orderRec.Account__r.SAP_Code__c + '</td>';
                                                               orderDetailsTable += '<td>' + orderRec.Customer_Po_No__c + '</td>';
                                                               orderDetailsTable += '<td>' + orderRec.Proforma_Invoice_No__c + '</td>';
                                                               orderDetailsTable += '<td>' + orderRec.CONTRACT_NO__c + '</td>';
                                                               orderDetailsTable += '</tr>';
                                                           }
                                                           
                                                           orderDetailsTable += '</table>';
                                                           
                                                           String opDetailsTable = '<br/><br/><table border="1">' +
                                                               '<tr><th>Order Product</th><th>Product Name</th><th>Product Code</th>' +
                                                               '<th>Model</th><th>Sperical Power</th><th>Cylinder Power</th>' +
                                                               '<th>Axis</th><th>Quantity</th><th>FOC Quantity</th>' +
                                                               '<th>Material Code Mapped</th><th>Material Code Search String</th></tr>';
                                                           
                                                           // Loop over all order items, include row ONLY IF it's in productwithoutStockIdSet (error subset)
                                                           for (Id idObj : orderProductMap.keySet()) {
                                                               /*  if (!productwithoutStockIdSet.contains(idObj) && isErrorEmail) {
continue;//skipping order product which has Material Stcok Code for Error Email
}
*/            
                                                               Order_Product__c opObj = orderProductMap.get(idObj);
                                                               
                                                               opDetailsTable += '<tr>';
                                                               opDetailsTable += '<td>' + opObj.Name + '</td>';
                                                               opDetailsTable += '<td>' + opObj.Product__r.Name + '</td>';
                                                               opDetailsTable += '<td>' + opObj.Product__r.Dummy_Product_Code__c + '</td>';
                                                               opDetailsTable += '<td>' + (opObj.Model_Txt__c != null ? opObj.Model_Txt__c : '--') + '</td>';
                                                               opDetailsTable += '<td>' + (opObj.Spherical_Power__c != null ? String.valueOf(opObj.Spherical_Power__c) : '--') + '</td>';
                                                               opDetailsTable += '<td>' + (opObj.Cyindrical_Power__c != null ? String.valueOf(opObj.Cyindrical_Power__c) : '--') + '</td>';
                                                               opDetailsTable += '<td>' + (opObj.Axis_Angle__c != null ? String.valueOf(opObj.Axis_Angle__c) : '--') + '</td>';
                                                               opDetailsTable += '<td>' + (opObj.Quantity__c != null ? String.valueOf(opObj.Quantity__c) : '--') + '</td>';
                                                               opDetailsTable += '<td>' + (opObj.FOC_Quantity__c != null ? String.valueOf(opObj.FOC_Quantity__c) : '--') + '</td>';
                                                               opDetailsTable += '<td>' + (modeltostockMap.containsKey(idObj) ? modeltostockMap.get(idObj) : '--') + '</td>';
                                                               opDetailsTable += '<td>' + (searchedMaterialCode.containsKey(idObj) ? searchedMaterialCode.get(idObj) : '--') + '</td>';
                                                               opDetailsTable += '</tr>';
                                                           }
                                                           
                                                           opDetailsTable += '</table>';
                                                           
                                                           String emailBody = orderDetailsTable;
                                                           
                                                           emailBody += '<br/><br/>' + opDetailsTable;
                                                           
                                                           /* if (!String.isEmpty(errorMessagesHtml)) {
emailBody += '<br/><br/> Error Messages:<br/><br/>' +
'<table border="1" style="border-collapse:collapse;">' +
'<tr><th>Error Message</th></tr>' + errorMessagesHtml + '</table>';
}*/
                                                           
                                                           
                                                           return emailBody;
                                                       }
    
    
    
    // ============================
    // 🔹 Wrapper Classes
    // ============================
    public class ProductWrapper {
        @AuraEnabled public Id orderProductId { get; set; }
        @AuraEnabled public Decimal orderQuantity { get; set; }
    }
    
    public class SplitWrapper {
        @AuraEnabled public String splitOrderNumber { get; set; }
        @AuraEnabled public String transactionMode { get; set; }
        @AuraEnabled public String quotaionId { get; set; }
        @AuraEnabled public String rfqNumber { get; set; }
        @AuraEnabled public String estimationId { get; set; }
        @AuraEnabled public String approxFreight { get; set; }
        @AuraEnabled public String currencyType { get; set; }
        @AuraEnabled public List<String> orderProductIds { get; set; }
    }
    
    public class SplitOrderWrapper {
        public String splitOrderNumber;
        public String plantCode;
        public String currencyType;
        public Boolean showApproxFreight;
        public List<SplitOrderProductWrapperForLWC> products;
        public SplitOrderWrapper(String splitOrderNumber, String plantCode, String currencyType, Boolean showApproxFreight, List<SplitOrderProductWrapperForLWC> products) {
            this.splitOrderNumber = splitOrderNumber;
            this.plantCode = plantCode;
            this.currencyType = currencyType;
            this.showApproxFreight = showApproxFreight;
            this.products = products;
        }
    }
    
    public class SplitOrderProductWrapperForLWC {
        public Id orderProductId;
        public String orderProductNumber;
        public String orderProductName;
        public String incoterm;
        
        public Decimal orderQuantity;
        public SplitOrderProductWrapperForLWC(Id orderProductId, String orderProductNumber, String orderProductName,String incoterm, Decimal orderQuantity) {
            this.orderProductId = orderProductId;
            this.orderProductNumber = orderProductNumber;
            this.orderProductName = orderProductName;
            this.incoterm = incoterm;
            
            this.orderQuantity = orderQuantity;
        }
    }
    
    public class RequestWrapper { public RecordWrapper Record; }
    public class RecordWrapper {
        public String Source;
        public String Customer;
        public String SoldToParty;
        public String ShipToParty;
        public String OrderCreationDate;
        public String ContractNumber;
        public String Application_Order_Number;
        public List<ItemWrapper> Items;
        public String AdditionalField1;
        public String AdditionalField2;
        public String AdditionalField3;
        public String AdditionalField4;
        public String AdditionalField5;
    }
    
    public class ItemWrapper {
        public String Plant;
        public String ProductCode;
        public String DispatchThrough;
        public String Pricing;
        public String Incoterms;
        public String PaymentTerms;
        public String FocQty;
        public String CommercialQty;
        public String AdditionalField1;
        public String AdditionalField2;
        public String AdditionalField3;
        public String AdditionalField4;
        public String AdditionalField5;
        public String ProductModel;
        public String Destination;
    }
    
    public class SAPResponseRoot { public List<SAPResponseWrapper> root; }
    public class SAPResponseWrapper {
        public String Statuscode;
        public String OrderID;
        public String OrderProductsId;
        public String Plant; 
        public String SplitCondition;
        public String Message;
    }
    
    // ----------------------------
    // SAP Error Response Wrapper
    // ----------------------------
    public class SAPErrorResponse {
        @AuraEnabled public SAPError error;
    }
    
    public class SAPError {
        @AuraEnabled public String code;
        @AuraEnabled public String message;
        @AuraEnabled public String logID;
    }
    
}