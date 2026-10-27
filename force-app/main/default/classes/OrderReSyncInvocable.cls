public class OrderReSyncInvocable {
    
    public static Order__c orderData = new Order__c();
    public static Map<Id, Item> orderItemMap = new Map<Id, Item>();
    public static Map<String, String> modeltostockMap = new Map<String, String>();
    public static Boolean runOnceAPI = false;
    public static Map<Id, Order_Product__c> orderProductMap = new Map<Id, Order_Product__c>();
    public static Set<Id> productwithoutStockIdSet = new Set<Id>();
    public static Map<String,String> searchedMaterialCode = new Map<String,String>();
    
    
    private static String INTERNATIONAL_STRING = 'International';
    private static String PHAKIC_STRING = 'PHAKIC';
    private static String TORIC_STRING = 'TORIC';
    
    
    @InvocableMethod(label='Resync Order')
    public static void resyncOrder(List<Id> pOrderIdLst) {
        
        
        HttpResponse resObj = new HttpResponse();
        fetchOrderData(pOrderIdLst[0]);
        try {
            
            resObj = pushOrderData();
            system.debug('BG >>> resObj : '+resObj);
            // set body
        }
        catch (Exception e) {
            system.debug('BG >>> e: '+e.getMessage());
            if(String.valueOf(e.getMessage()).equalsignoreCase('Read timed out') && !orderData.Order_Creation_Time_Out__c) {
                //resObj = pushOrderData(); //make callout from flow
                Order__c orderInstance = new Order__c();
                orderInstance.Id = orderData.Id;
                orderInstance.Order_Creation_Time_Out__c = true;
                orderInstance.Error_Timestamp__c = System.now();
                update orderInstance;
            }
        }
        OrderCreatedResponse orderResponse;
        System.debug('resObj'+resObj);
        if(resObj.getStatusCode() == 200){
            orderResponse = (OrderCreatedResponse) JSON.deserialize(resObj.getBody(), OrderCreatedResponse.class);
        }
        
        //orderResponse.orderSFNumber = orderData.Name;
        insertSplittedOrderFromSAP(orderResponse);
        system.debug('BG >>> orderResponse : '+orderResponse);
    }
    
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
        Map<String, String> orderProductIdVsSplitOrderId = new Map<String, String>();
        
        // Order__c orderInstance = [Select id,Order_Creation_Time_Out__c from Order__c where id =:pOrderId ];
        // orderInstance.Order_Creation_Time_Out__c = false;
        // update orderInstance;
        
        orderList = [SELECT id, CurrencyIsoCode, Name, Account__c, Account__r.SAP_Code__c,Consignee_Code__c,CONTRACT_NO__c,
                     Order_Activation_Date__c, Account__r.Company_Code__c, Customer_Po_No__c,Order_Creation_Time_Out__c, Dispatch_Through__c,
                     (SELECT id, Name, Product__c, Product__r.Name, Product__r.Region__c,  Product__r.Category__c, Quantity__c,
                      Total_Price__c, Agreement_Product__c, Model_Txt__c,Product__r.Dummy_Product_Code__c,
                      Axis_Angle__c, Cyindrical_Power__c, Spherical_Power__c,FOC_Quantity__c,Parent_Order_Product__c,Parent_Order_Product__r.FOC_Quantity__c,
                      Agreement_Product__r.Incoterms__c, Agreement_Product__r.Payment_Terms_options__c, Agreement_Product__r.Plant__c,
                      Agreement_Product__r.Master_Agreement__r.Agreement_Signed_With__c,Agreement_Product__r.Is_Backup__c
                      FROM Order_Products__r),
                     (SELECT id, Freight_Amount__c,Plant__c, Plant__r.Name,Products__c
                      FROM Freight_Requests__r)
                     FROM Order__c
                     WHERE id =: pOrderId];
        if(orderList.size() > 0) {
            orderData = orderList[0];
        }
        Map<String, Split_Order__c> splitOrderIdVsRecord =
            new Map<String, Split_Order__c>([
                SELECT Id, RFQNumber_Temp__c, EstimationId_Temp__c, Transport_Mode__c, Order_Product_Ids__c
                FROM Split_Order__c
                WHERE Order__c = :pOrderId
            ]);
        
        
        for (Split_Order__c sp : splitOrderIdVsRecord.values()) {
            if (String.isNotBlank(sp.Order_Product_Ids__c)) {
                for (String opId : sp.Order_Product_Ids__c.split(',')) {
                    opId = opId.trim();
                    if (String.isNotBlank(opId)) {
                        orderProductIdVsSplitOrderId.put(opId, sp.Id);
                    }
                }
                
            }
        }
        
        if(orderData != null) {
            for(Freight_Request__c frObj : orderData.Freight_Requests__r){
                String freightMapKey = '';
                //System.debug('frObj.Products__c'+frObj.Products__c);
                if(frObj.Products__c.contains(',')) {
                    List<String> ProductNameList = new List<String>();
                    ProductNameList = frObj.Products__c.split(',');
                    for(String productStr : ProductNameList) {
                        plantToFreightAmtMap.put(frObj.Plant__r.Name+productStr, frObj.Freight_Amount__c);
                    }
                } else {
                    plantToFreightAmtMap.put(frObj.Plant__r.Name+frObj.Products__c, frObj.Freight_Amount__c);
                }
            }
            
            for(Order_Product__c orderProduct: orderData.Order_Products__r) {
                //System.debug('orderProduct'+orderData.Order_Products__r);
                //System.debug('orderProduct'+orderProduct.Agreement_Product__r.Plant__c);
                
                Item itemObj = new Item();
                itemObj.Plant = orderProduct.Agreement_Product__r.Plant__c.startsWith('8200') ? '8200' : '8100'; //String.ValueOf(orderProduct.Product__r.Plant__r.Name).substring(0,4);
                itemObj.Pricing = String.ValueOf(orderProduct.Total_Price__c);
                //  itemObj.Freight = plantToFreightAmtMap.get(orderProduct.Agreement_Product__r.Plant__c+orderProduct.Product__r.Name) != null ? String.ValueOf(plantToFreightAmtMap.get(orderProduct.Agreement_Product__r.Plant__c+orderProduct.Product__r.Name)) : String.ValueOf('0');
                itemObj.Incoterms = orderProduct.Agreement_Product__r.Incoterms__c;
                itemObj.PaymentTerms = orderProduct.Agreement_Product__r.Payment_Terms_options__c;
                itemObj.FocQty = orderProduct.FOC_Quantity__c != null ? String.ValueOf(orderProduct.FOC_Quantity__c) : String.ValueOf('0');
                itemObj.CommercialQty = String.ValueOf(orderProduct.Quantity__c);
                itemObj.DispatchThrough = orderData.Dispatch_Through__c;
                itemObj.additionalField1 = String.ValueOf(orderProduct.Agreement_Product__r.Plant__c).substring(0,4);
                itemObj.additionalField2 = orderProduct.Agreement_Product__r.Master_Agreement__r.Agreement_Signed_With__c.containsIgnoreCase('GMBH') ? 'ZSTP' : 'ZEOR';
                itemObj.additionalField3 = orderProduct.Product__r.Category__c;
                itemObj.additionalField4 = String.valueOf(orderProduct.Agreement_Product__r.Is_Backup__c);
                itemObj.AdditionalField5 = orderProduct.Name;
                itemObj.ProductModel = orderProduct.Model_Txt__c;
                Split_Order__c splitOrderRec = null;
                String splitOrderId = orderProductIdVsSplitOrderId.get(orderProduct.Id);
                if (splitOrderId != null) {
                    splitOrderRec = splitOrderIdVsRecord.get(splitOrderId);
                }
                itemObj.RFQNumber     = splitOrderRec?.RFQNumber_Temp__c;
                itemObj.EstimationId  = splitOrderRec?.EstimationId_Temp__c;
                itemObj.QuotaionId  = splitOrderRec?.quotaionId_Temp__c;
                itemObj.TransactionMode = splitOrderRec?.Transport_Mode__c;
                itemObj.Freight = String.valueOf(splitOrderRec?.Approx_Freight__c);
                
                
                
                orderItemMap.put(orderProduct.Id, itemObj);
                orderProductMap.put(orderProduct.Id,orderProduct);
                
                if(orderProduct.Parent_Order_Product__c != null)  {
                    System.debug('orderProduct.Parent_Order_Product__c'+orderProduct.Name+orderProduct.Parent_Order_Product__c);
                    parentOrderProductSet.add(orderProduct.Parent_Order_Product__c);
                }
                if(!string.isEmpty(orderProduct.Model_Txt__c)) {
                    modelNameSet.add(orderProduct.Model_Txt__c);
                }
                productIdSet.add(orderProduct.Product__c);
            }
            for(Id parentopID : parentOrderProductSet){
                Item itemObj = orderItemMap.remove(parentopID);
                orderProductMap.remove(parentopID);
                
                System.debug('itemObj'+itemObj);
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
                
                System.debug('DV >>> orderProduct'+orderProduct.Name);
                
                List<Product_Material_Stock__c> stockList = new List<Product_Material_Stock__c>();
                String mapKey = orderProduct.Product__c+'-'+orderProduct.Model_Txt__c+'-'+orderProduct.Spherical_Power__c;
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
                //System.debug('stockList'+stockList);
                if(!stockList.isempty() && stockList.size() > 1) {
                    System.debug('stockList114'+stockList);
                    
                    if(String.valueOf(orderProduct.Spherical_Power__c) != null) {
                        System.debug('DV >>> Infobeans line 130');
                        String spericalpowerStr = String.valueOf(orderProduct.Spherical_Power__c);
                        String cylindrcalpowerStr = String.valueOf(orderProduct.Cyindrical_Power__c);
                        String axisAngleStr = String.valueOf(orderProduct.Axis_Angle__c);
                        if(spericalpowerStr != null) {
                            String partialPower = '';
                            String initPower;
                            Boolean isPhakicToric = orderProduct.Product__r.Name.toUpperCase().contains(PHAKIC_STRING) && orderProduct.Product__r.Name.toUpperCase().contains(TORIC_STRING) && orderProduct.Product__r.Region__c==INTERNATIONAL_STRING;
                            //System.debug('orderProduct.Product__r.Name.toUpperCase().contains(PHAKIC_STRING) >>>'+orderProduct.Product__r.Name.toUpperCase().contains(PHAKIC_STRING));
                            //System.debug('orderProduct.Product__r.Name.toUpperCase().contains(TORIC_STRING) >>>'+orderProduct.Product__r.Name.toUpperCase().contains(TORIC_STRING));
                            //System.debug('orderProduct.Product__r.Region__c >>>>'+orderProduct.Product__r.Region__c);
                            //System.debug('orderProduct.Product__r.Name >>> '+orderProduct.Product__r.Name);
                            //System.debug('isPhakicToric >>> '+isPhakicToric);
                            if(spericalpowerStr.contains('-')) {
                                partialPower = spericalpowerStr.substringBetween('-','.');
                                initPower = partialPower;
                                // if(partialPower.length()==1){
                                //     if(isPhakicToric){
                                //         partialPower='0'+partialPower;
                                //     }
                                // }
                                partialPower = partialPower.length() == 1 && isPhakicToric ? '0'+partialPower : partialPower;
                                partialPower = 'N'+partialPower;
                                //System.debug('partialPower >>> '+partialPower);
                                spericalpowerStr = spericalpowerStr.replaceFirst(initPower,partialPower).replace('-', '');
                            }
                            else {
                                partialPower = spericalpowerStr.substringBeforeLast('.');
                                initPower = partialPower;
                                // if(partialPower.length()==1){
                                //     if(isPhakicToric){
                                //         partialPower='0'+partialPower;
                                //     }
                                // }
                                partialPower = partialPower.length() == 1 && isPhakicToric ? '0'+partialPower : partialPower;
                                partialPower = 'P'+partialPower;
                                //System.debug('partialPower >>> '+partialPower);
                                spericalpowerStr = spericalpowerStr.replaceFirst(initPower,partialPower);
                            }
                            materialCodeMatch = spericalpowerStr;
                        }
                        if(orderProduct.Product__r.Dummy_Product_Code__c!='EP262'  && orderProduct.Product__r.Dummy_Product_Code__c!='EP263'){
                            if(cylindrcalpowerStr != null){
                                if(axisAngleStr != null || orderProduct.Product__r.Dummy_Product_Code__c == 'EP266') {
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
                                //system.debug('BG >>> materialCodeMatch2 : '+materialCodeMatch);
                            }
                        }
                        system.debug('BG >>> materialCodeMatch : '+materialCodeMatch);
                        system.debug('BG >>> orderProduct.Name : '+orderProduct.Name);
                        searchedMaterialCode.put(orderProduct.Id, materialCodeMatch);
                        for(Product_Material_Stock__c stock : stockList) {
                            //System.debug('BG >>>  stock.Material_Code__c : '+stock.Material_Code__c);
                            //system.debug('BG >>> materialCodeMatch : '+materialCodeMatch);
                            if(stock.Material_Code__c.contains(materialCodeMatch) ){
                                //matchingMaterialCode = stock.Material_Code__c;
                                modeltostockMap.put(orderProduct.Id,stock.Material_Code__c);
                                //system.debug('BG >>> if');
                                break;
                            }
                            else {
                                modeltostockMap.put(orderProduct.Id,orderProduct.Product__r.Dummy_Product_Code__c);
                                //productwithoutStockIdMap.put(orderProduct.Id,orderProduct);
                                productwithoutStockIdSet.add(orderProduct.Id);
                                //system.debug('BG >>> else');
                            }
                        }
                    }
                    else {
                        modeltostockMap.put(orderProduct.Id,stockList[0].Material_Code__c);
                    }
                }
                else if(stockList.isempty()) {
                    //System.debug('stockList177'+stockList);
                    
                    modeltostockMap.put(orderProduct.Id,orderProduct.Product__r.Dummy_Product_Code__c);
                    // productwithoutStockIdMap.put(orderProduct.Id,orderProduct);
                    productwithoutStockIdSet.add(orderProduct.Id);
                    
                } else {
                    //System.debug('stockList183'+stockList);
                    
                    modeltostockMap.put(orderProduct.Id,stockList[0].Material_Code__c);
                }
                if(!modeltostockMap.containsKey(orderProduct.Id)) {
                    modeltostockMap.put(orderProduct.Id,stockList[0].Material_Code__c);
                }
            }
        }
        
    }
    
    public static HttpResponse pushOrderData() {
        HttpRequest req = new HttpRequest();
        HttpResponse res = new HttpResponse();
        Http http = new Http();  //
        
        SAP_Creds__c credential = SAP_Creds__c.getValues('SAP_Quality');
        req.setEndpoint(credential.Endpoint__c);
        req.setMethod('POST');
        
        String username = credential.Username__c;
        String password = credential.Password__c;
        Blob headerValue = Blob.valueOf(username + ':' + password);
        String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);
        //String authorizationHeader = 'BASIC cGl1c2VyOldlbGNvbWVAMTIz';
        req.setHeader('Authorization', authorizationHeader);
        //req.setEndpoint('');
        req.setMethod('POST');
        req.setHeader('Source', 'SF');
        req.setHeader('Content-Type', 'text/plain');
        OrderRecord orderObj = new OrderRecord();
        orderObj.Source = 'SF';
        orderObj.Customer = orderData.Account__r.SAP_Code__c;  // 1000;
        orderObj.ShipToParty = orderData.Consignee_Code__c;
        orderObj.SoldToParty = orderData.Account__r.SAP_Code__c;   //'1000000';
        orderObj.Customer_PO = orderData.Customer_Po_No__c;
        orderObj.ContractNumber = orderData.CONTRACT_NO__c;
        orderObj.OrderCreationDate = String.valueOf(system.today()).replaceAll('-', '');//String.ValueOf(orderData.Order_Activation_Date__c);
        orderObj.Company_Code = orderData.Account__r.Company_Code__c;   //'1000';
        orderObj.Application_Order_Number =  orderData.Name;  //'SF-00010051';
        orderObj.Items = prepareRequestBody();
        bodyWrapper body = new bodyWrapper();
        body.Record.add(orderObj);
        
        String bodyStr = JSON.serialize(body);
        req.setBody(bodyStr);
        system.debug('BG >>> bodyStr : '+bodyStr);
        system.debug('BG >>> header : '+req);
        req.setTimeout(120000);
        //        req.setTimeout(30000);
        
        res = http.send(req);
        //system.debug('Response status is:'+res.getStatusCode());
        //system.debug('BG >>> res : '+res.getBody());
        
        return res;
    }
    
    
    public static list<Item> prepareRequestBody(){
        
        List<Item> orderItemList = new List<Item>();
        
        for(Order_Product__c orderProduct : orderData.Order_Products__r){
            Item itemObj = orderItemMap.get(orderProduct.Id);
            System.debug('orderProduct->Name'+orderProduct.Name+'ItemObj'+itemObj);
            if(itemObj != null) {
                //if(!String.isEmpty(orderProduct.Model_Txt__c)) {
                //System.debug('orderProduct.Id>>'+orderProduct.Id +' '+'productCode>>'+modeltostockMap.get(orderProduct.Id));
                if(modeltostockMap.containsKey(orderProduct.Id)) {
                    itemObj.ProductCode = modeltostockMap.get(orderProduct.Id);
                    //itemObj.ProductCode = 'FG0277';
                }
                
                orderItemList.add(itemObj);
            }
        }
        //System.debug('orderItemList'+orderItemList);
        return orderItemList;
        
    }
    
    
    public static void insertSplittedOrderFromSAP(OrderCreatedResponse pSplittedOrder) {
        //system.debug('BG >>> 1');
        String errorMessagesHtml = ''; //'Error Messages:<br/><br/><table border="1px solid black" border-collapse="collapse"><tr><th>Error Message</th></tr>';
        // Initialize the order details table
        
        List<OrderLineItem__c> oliListToInsert = new List<OrderLineItem__c>();
        Map<Id, Order_Product__c> opUpdateMap = new Map<Id, Order_Product__c>();
        
        List<String> productcodeList = new List<String>();
        Set<string> productCodeSet = new Set<String>();
        Set<string> orderProductSet = new Set<String>();
        Map<String, String> opNameVsSplitOrderNoSap = new Map<String, String>();
        
        Order__c orderInstance;
        Boolean orderSyncFailed =false;
        if(pSplittedOrder != null && pSplittedOrder.Record != null && !pSplittedOrder.Record.isEmpty()){
            system.debug('BG >>> pSplittedOrder'+pSplittedOrder);
            for(SplitOrderClass splitOrderCls :pSplittedOrder.Record) {
                System.debug('splitOrderCls'+splitOrderCls);
                if(splitOrderCls.OrderNumber != null) {
                    
                    String input = splitOrderCls.OrderNumber;
                    
                    List<String> parts = input.split('\\$\\$');
                    
                    String orderNumber   = parts.size() > 0 ? parts[0] : null;
                    String rfqNumberValue     = parts.size() > 1 ? parts[1] : null;
                    String estimationIdValue  = parts.size() > 2 ? parts[2] : null;
                    String TransportmodeValue         = parts.size() > 3 ? parts[3] : null;
                    System.debug(orderNumber+','+rfqNumberValue+','+estimationIdValue+','+TransportmodeValue);
                    
                    OrderLineItem__c oliObj = new OrderLineItem__c();
                    
                    productcodeList  = new List<String>();
                    productCodeSet = new Set<String>();
                    if(splitOrderCls.SplitCondition != null) {
                        if(splitOrderCls.SplitCondition.contains(',')) {
                            productcodeList = splitOrderCls.SplitCondition.split(',');
                            for(integer i = 0; i<productcodeList.size() ; i++){
                                productCodeSet.add(productcodeList[i].substringBetween('-', '$$'));
                                orderProductSet.add(productcodeList[i].substringAfter('$$'));
                                // opNameVsSplitOrderNoSap.put(productcodeList[i].substringAfter('$$'),splitOrderCls.OrderNumber);
                                opNameVsSplitOrderNoSap.put(productcodeList[i].substringAfter('$$'),orderNumber);
                                
                            }
                        }
                        else {
                            productCodeSet.add(splitOrderCls.SplitCondition.substringBetween('-', '$$'));
                            orderProductSet.add(splitOrderCls.SplitCondition.substringAfter('$$'));
                            //opNameVsSplitOrderNoSap.put(splitOrderCls.SplitCondition.substringAfter('$$'),splitOrderCls.OrderNumber);
                            opNameVsSplitOrderNoSap.put(splitOrderCls.SplitCondition.substringAfter('$$'),orderNumber);
                            
                        }
                    }
                    System.debug('opNameVsSplitOrderNoSap'+opNameVsSplitOrderNoSap);
                    if(productCodeSet.size() > 1 ) {
                        oliObj.Products__c = string.join(productCodeSet,',');
                    }
                    else{
                        oliObj.Products__c = string.join(productCodeSet,',').remove(',');
                    }
                    oliObj.Order_Num_SAP__c = orderNumber;
                    oliObj.Order__c = orderData.Id;
                    oliObj.Status__c = 'Ordered';
                    oliObj.CurrencyIsoCode = orderData.CurrencyIsoCode;
                    oliObj.RFQNumber__c = rfqNumberValue;
                    oliObj.EstimationId__c = estimationIdValue;
                    oliObj.Transport_Mode__c = TransportmodeValue;
                    oliListToInsert.add(oliObj);
                    
                }
                else {
                    errorMessagesHtml += '<tr><td>' + splitOrderCls.message + '</td></tr>';
                    orderInstance = new Order__c();
                    orderInstance.Id = orderData.Id;
                    orderInstance.Order_Creation_Time_Out__c = true;
                    orderInstance.Error_Timestamp__c = System.now();
                    orderSyncFailed=true;
                }
                
            }
            
            system.debug('BG >>> oliListToInsert : '+oliListToInsert);
            if(!oliListToInsert.isempty()) {
                upsert oliListToInsert Order_Num_SAP__c;
            }    
            // Order instance will be null in case of no failed split order meaning sales order is succefuly synced
            // Hence we are instializing order in below code
            if(orderInstance == null) {
                orderInstance = new Order__c();
                orderInstance.Id = orderData.Id;
            }
            orderInstance.Synced_to_SAP__c = !orderSyncFailed ;
            update orderInstance;
            
            
            //logic for maiting synced op records track
            List<Order_Product__c> opLst = [
                SELECT Id,Name,Order_Num_SAP__c 
                FROM Order_Product__c 
                WHERE Name IN :orderProductSet
            ];                            
            system.debug('BG >>> opLst : '+opLst);
            
            //system.debug('BG >>> oliObj : '+oliObj);
            for(Order_Product__c  opRec:opLst){
                opRec.Order_Num_SAP__c=opNameVsSplitOrderNoSap.get(opRec.Name);
                opUpdateMap.put(opRec.Id, opRec); // Ensures each Id only appears once
            }
            
            //system.debug('BG >>>  opUpdateMap: '+opUpdateMap);
            if(!opUpdateMap.isempty()) {
                update opUpdateMap.values();
            }
            
            Order__c orderRec;
            if (pSplittedOrder != null && pSplittedOrder.Record != null && !pSplittedOrder.Record.isEmpty()) {
                orderRec = [SELECT Account__r.Name, Account__r.SAP_Code__c, Name, Customer_Po_No__c ,CONTRACT_NO__c
                            ,Proforma_Invoice_No__c,Account__r.CRM_2_Email__c,
                            Account__r.CRM_Approver__r.Email,Order_Approval_Date_in_ddmmmyy_Format__c
                            FROM Order__c
                            WHERE Id =: orderData.Id
                            LIMIT 1];
            }
            
            String emailBody = generateSapOrderSyncEmailBody(
                orderRec,
                orderProductMap,
                productwithoutStockIdSet,
                modeltostockMap,
                searchedMaterialCode,
                opNameVsSplitOrderNoSap,
                errorMessagesHtml, // accumulated <tr><td>error message</td></tr>
                orderSyncFailed // or true if it’s a success email
            );
            
            if(!String.isEmpty(emailBody)){
                BatchUpsertEmail__mdt mdt = BatchUpsertEmail__mdt.getInstance('StockUpdateJob');
                List<String> recipientEmails = New List<String>();
                recipientEmails = mdt.Emails__c.split(',');
                
                if (orderRec.Account__r != null) {
                    // Add CRM_2_Email__c if not blank
                    if (String.isNotBlank(orderRec.Account__r.CRM_2_Email__c)) {
                        recipientEmails.add(orderRec.Account__r.CRM_2_Email__c.trim());
                    }
                    
                    // Add CRM Approver Email if related user exists and email is not blank
                    if (orderRec.Account__r.CRM_Approver__r != null &&
                        String.isNotBlank(orderRec.Account__r.CRM_Approver__r.Email)) {
                            recipientEmails.add(orderRec.Account__r.CRM_Approver__r.Email.trim());
                        }
                }
                
                // String emailErrorBody = orderDetailsTable +'<br/><br/> Error Messages:<br/><br/><table border="1px solid black" border-collapse="collapse"><tr><th>Error Message</th></tr>'+emailBody+'</table>';
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                // String[] toAddresses = new String[]{mdt.RecipientEmail__c};
                OrgWideEmailAddress[] owea = [select Id from OrgWideEmailAddress where DisplayName = 'CRM HelpDesk'];
                //Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                if ( owea.size() > 0 ) {
                    mail.setOrgWideEmailAddressId(owea.get(0).Id);
                }
                mail.setToAddresses(recipientEmails);
                String subject = 'Order Summary'+' '+orderRec.Name+' '+orderRec.Account__r.Name+' '+'PFI/'+orderRec.CONTRACT_NO__c;
                mail.setSubject(subject);
                mail.setHtmlBody(emailBody);
                Messaging.SendEmailResult[] mailResults = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
                System.debug('mailResults'+mailResults);
            }
        }
        
    }
    
    private static String generateSapOrderSyncEmailBody(
        Order__c orderRec, 
        Map<Id, Order_Product__c> orderProductMap, 
        Set<Id> productwithoutStockIdSet, 
        Map<String, String> modeltostockMap, 
        Map<String, String> searchedMaterialCode, 
        Map<String, String> opNameVsSplitOrderNoSap,
        String errorMessagesHtml,
        Boolean isErrorEmail
    ) {
        String orderDetailsTable = '<br/><br/><table border="1">' +
            '<tr><th>Order Number</th><th>Order Approval Date</th><th>Account Name</th><th>SAP Code</th>' +
            '<th>Customer PO No</th><th>PFI No.</th><th>SC No.</th></tr>';
        
        if (orderRec != null) {
            orderDetailsTable += '<tr>';
            orderDetailsTable += '<td>' + orderRec.Name + '</td>';
            orderDetailsTable += '<td>' + orderRec.Order_Approval_Date_in_ddmmmyy_Format__c + '</td>';
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
            '<th>Material Code Mapped</th><th>Material Code Search String</th><th>SAP Order No</th></tr>';
        
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
            opDetailsTable += '<td>' + (opNameVsSplitOrderNoSap.containsKey(opObj.Name) ? opNameVsSplitOrderNoSap.get(opObj.Name) : '--') + '</td>';
            opDetailsTable += '</tr>';
        }
        
        opDetailsTable += '</table>';
        
        String emailBody = orderDetailsTable;
        
        emailBody += '<br/><br/>' + opDetailsTable;
        
        if (!String.isEmpty(errorMessagesHtml)) {
            emailBody += '<br/><br/> Error Messages:<br/><br/>' +
                '<table border="1" style="border-collapse:collapse;">' +
                '<tr><th>Error Message</th></tr>' + errorMessagesHtml + '</table>';
        }
        
        
        return emailBody;
    }
    
    
    public class bodyWrapper {
        List<OrderRecord> Record = new List<OrderRecord>();
    }
    
    public class OrderRecord {
        public String Source;
        public String Customer;
        public String SoldToParty;
        public String ShipToParty;
        public String OrderCreationDate;
        public String Company_Code;
        public String ContractNumber;
        public String Customer_PO;
        public String Application_Order_Number;
        public List<Item> Items;
        public String AdditionalField1;
        public String AdditionalField2;
        public String AdditionalField3;
        public String AdditionalField4;
        public String AdditionalField5;
    }
    
    public class Item {
        public String Plant;
        public String ProductCode;
        public String DispatchThrough;
        public String Pricing;
        public String Freight;
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
        public String RFQNumber;
        public String EstimationId;
        public String TransactionMode;
        public String QuotaionId;
        
        //public String parentItem;
        
    }
    
    public class OrderCreatedResponse {
        //public String orderSFNumber;
        public List<SplitOrderClass> Record;
        
    }
    
    public class SplitOrderClass {
        public String OrderNumber;
        public string statuscode;
        public String message;
        public String SplitCondition;
        public String RFQNumber;
        public String EstimationId;
        public String TransportMode;
        public String FrightAmount;
    }
    
    
}