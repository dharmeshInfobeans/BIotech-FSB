public class FreightModalActionController2 {
public static String orderRecId { get; set; }
    
    @AuraEnabled
    public static String getSplitOrderData(Id orderId) {
                orderRecId=orderId;
        String sapResponse = SplitOrderRestService.fetchOrderSplitResponse(orderId);
        system.debug('sapResponse-->'+sapResponse);
        
        // If SAP sent a single object, wrap it in an array
        if (sapResponse.startsWith('{') && sapResponse.contains('\"root\":{')) {
            // Replace `"root":{` with `"root":[{`
            sapResponse = sapResponse.replaceFirst('\"root\":\\{', '\"root\":[{');
            
            // Replace the final closing brace } with ]}
            // sapResponse now ends with a single object }, we want to close the array instead
            sapResponse = sapResponse.substring(0, sapResponse.length() - 1) + ']}';
        }
        
        
        // Deserialize SAP response
        SplitOrderRestService.SAPResponseRoot sapResp =
            (SplitOrderRestService.SAPResponseRoot) JSON.deserialize(sapResponse, SplitOrderRestService.SAPResponseRoot.class);
        
        // Convert SAP response into LWC-friendly format
        List<SplitOrderWrapper> lwcData = buildSplitOrderDetails(sapResp);
        return JSON.serialize(lwcData);
    }
    
    // Save Order Quantities
    @AuraEnabled
    public static void saveOrderProductQuantities(Id orderId, List<ProductWrapper> products) {
        try {
            List<Order_Product__c> opToUpdate = new List<Order_Product__c>();
            
            for (ProductWrapper p : products) {
                if (p.orderProductId != null) {
                    opToUpdate.add(new Order_Product__c(
                        Id = p.orderProductId,
                        Quantity__c = p.orderQuantity
                    ));
                }
            }
            System.debug('opToUpdate'+opToUpdate);
            if (!opToUpdate.isEmpty()) {
                update opToUpdate;
            }
        } catch (Exception e) {
            throw new AuraHandledException('Failed to save order quantities: ' + e.getMessage());
        }
    }
    
    //  Approve Freight
    @AuraEnabled
    public static void saveQuantitiesAndApproveFreight(Id orderId, List<ProductWrapper> products, List<SplitWrapper> splitData) {
        try {
            // 1️⃣ Save Quantities
            List<Order_Product__c> opToUpdate = new List<Order_Product__c>();
            for (ProductWrapper p : products) {
                if (p.orderProductId != null) {
                    opToUpdate.add(new Order_Product__c(
                        Id = p.orderProductId,
                        Quantity__c = p.orderQuantity
                    ));
                }
            }
            if (!opToUpdate.isEmpty()) {
                update opToUpdate;
            }
    
            // 2️⃣ Approve Freight
            List<Split_Order__c> splitOrdersToInsert = new List<Split_Order__c>();
            for (SplitWrapper split : splitData) {
                Split_Order__c splitOrder = new Split_Order__c();
                splitOrder.Transport_Mode__c = split.transactionMode;
                splitOrder.Status__c = 'FrightApproved';
                splitOrder.Order__c = orderId;
                splitOrder.EstimationId_Temp__c = split.estimationId;
                splitOrder.RFQNumber_Temp__c = split.rfqNumber;
                                splitOrder.Approx_Freight__c = Decimal.valueOf(split.approxFreight);
                                splitOrder.CurrencyIsoCode = split.currencyType;

                if (split.orderProductIds != null && !split.orderProductIds.isEmpty()) {
                    splitOrder.Order_Product_Ids__c = String.join(split.orderProductIds, ',');
                }
                splitOrdersToInsert.add(splitOrder);
            }
            if (!splitOrdersToInsert.isEmpty()) {
                insert splitOrdersToInsert;
            }
    
        } catch (Exception e) {
            throw new AuraHandledException('Error saving quantities and approving freight: ' + e.getMessage());
        }
    }
    
    
    // Only LWC-related methods remain here
    public static List<SplitOrderWrapper> buildSplitOrderDetails(SplitOrderRestService.SAPResponseRoot parsedResponse) {
        List<SplitOrderRestService.SAPResponseWrapper> responses = parsedResponse.root;
        Set<Id> allOrderProductIds = new Set<Id>();
        System.debug('responses'+responses);
        for (SplitOrderRestService.SAPResponseWrapper resp : responses) {
            if (!String.isBlank(resp.OrderProductsId)) {
                for (String opId : resp.OrderProductsId.split('\\$\\$')) {
                    if (String.isNotBlank(opId)) {
                        allOrderProductIds.add((Id) opId.trim());
                    }
                }
            }
        }
        
        Map<Id, Order_Product__c> orderProductMap = new Map<Id, Order_Product__c>(
            [SELECT Id, Name, Quantity__c,Plant_Number__c,Order__r.CurrencyIsoCode,Agreement_Product__r.Incoterms__c,Product__r.Name FROM Order_Product__c WHERE Id IN :allOrderProductIds]
        );
        
        List<Split_Order__c> approvedSplitOrderLst =[Select Id,Status__c from Split_Order__c where Status__c ='FrightApproved' and Order__c =:orderRecId];
        System.debug('approvedSplitOrderLst'+approvedSplitOrderLst);
        List<SplitOrderWrapper> splitWrappers = new List<SplitOrderWrapper>();
        Integer counter = 1;
        String currencyType = orderProductMap.isEmpty() ? null : orderProductMap.values()[0].Order__r.CurrencyIsoCode;
        Boolean showApproxFreight = false;
        for (SplitOrderRestService.SAPResponseWrapper resp : responses) {
            List<SplitOrderProductWrapperForLWC> productWrappers = new List<SplitOrderProductWrapperForLWC>();
            if (!String.isBlank(resp.OrderProductsId)) {
                for (String opId : resp.OrderProductsId.split('\\$\\$')) {
                    Id orderProdId;
                    try { orderProdId = (Id) opId.trim(); } catch (Exception e) { continue; }
                    if (orderProductMap.containsKey(orderProdId)) {
                        Order_Product__c op = orderProductMap.get(orderProdId);
                        productWrappers.add(new SplitOrderProductWrapperForLWC(
                            op.Id, op.Name,op.Product__r.Name, op.Quantity__c
                        ));
                        if (
                            op.Agreement_Product__r != null &&
                            op.Agreement_Product__r.Incoterms__c != null &&
                            op.Agreement_Product__r.Incoterms__c != 'Ex-works' &&
                            op.Agreement_Product__r.Incoterms__c != 'FOB' &&
                            approvedSplitOrderLst.size() < 0 &&
                            !showApproxFreight
                        ) {
                            showApproxFreight = true;
                        }

                    }
                   
                   

                }
            }
            splitWrappers.add(new SplitOrderWrapper('SP' + counter,resp.Plant,currencyType,showApproxFreight, productWrappers));
            counter++;
        }
        return splitWrappers;
    }
    
    
    // Wrapper for saving quantity
    public class ProductWrapper {
        @AuraEnabled public Id orderProductId { get; set; }
        @AuraEnabled public Decimal orderQuantity { get; set; }
    }
    
    
    
    
    // Wrapper for approving freight
    public class SplitWrapper {
        @AuraEnabled public String splitOrderNumber { get; set; }
        @AuraEnabled public String transactionMode { get; set; }
        @AuraEnabled public String rfqNumber { get; set; }
        @AuraEnabled public String estimationId { get; set; }
                @AuraEnabled public String approxFreight { get; set; }
                @AuraEnabled public String currencyType { get; set; }

        @AuraEnabled public List<String> orderProductIds { get; set; }
    }
    // LWC Wrappers only
    public class SplitOrderWrapper {
        public String splitOrderNumber;
        public String plantCode;
        public String currencyType;
        public Boolean showApproxFreight;

        
        public List<SplitOrderProductWrapperForLWC> products;
        public SplitOrderWrapper(String splitOrderNumber,String plantCode, String currencyType,Boolean showApproxFreight,List<SplitOrderProductWrapperForLWC> products) {
            this.splitOrderNumber = splitOrderNumber;
            this.plantCode=plantCode;
            this.currencyType=currencyType;
            this.showApproxFreight=showApproxFreight;
            this.products = products;
        }
    }
    public class SplitOrderProductWrapperForLWC {
        public Id orderProductId;
        public String orderProductNumber;
                public String orderProductName;

        public Decimal orderQuantity;


        public SplitOrderProductWrapperForLWC(Id orderProductId, String orderProductNumber,String orderProductName,
                                              Decimal orderQuantity
                                             ) {
                                                 this.orderProductId = orderProductId;
                                                 this.orderProductNumber = orderProductNumber;
                                                                                                  this.orderProductName = orderProductName;

                                                 this.orderQuantity = orderQuantity;
                                             }
    }
    
    

}