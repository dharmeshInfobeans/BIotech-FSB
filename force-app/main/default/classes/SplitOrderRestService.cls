public class SplitOrderRestService {
    //this classs is not used curretly anywhere dummy class
    public static Order__c orderData = new Order__c();
    public static Map<Id, ItemWrapper> orderItemMap = new Map<Id, ItemWrapper>();
    public static Map<String, String> modeltostockMap = new Map<String, String>();
    public static Boolean runOnceAPI = false;
    public static Map<Id, Order_Product__c> orderProductMap = new Map<Id, Order_Product__c>();
    public static Set<Id> productwithoutStockIdSet = new Set<Id>();
    public static Map<String,String> searchedMaterialCode = new Map<String,String>();
    
    private static String INTERNATIONAL_STRING = 'International';
    private static String PHAKIC_STRING = 'PHAKIC';
    private static String TORIC_STRING = 'TORIC';
    
    public static String fetchOrderSplitResponse(Id pOrderId) {
        //    try {
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
        
        
        
        SAP_Creds__c credential = SAP_Creds__c.getValues('SAP_Fright_Split_Order');
        // Authentication
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
        System.debug('BG >>> bodyStr : ' + bodyStr);
        
        HttpResponse res = http.send(req);
        System.debug('res'+res);
        System.debug('res.getBody(): ' + res.getBody());
        String decodedBody = EncodingUtil.urlDecode(res.getBody(), 'UTF-8');
        
        System.debug('res.getBody(): ' + decodedBody);
        
        
        // Handle non-200 responses
        if (res.getStatusCode() != 200) {
            
            // Build error message
            String errorMsg = 'Error from SAP → ' +
                '\nStatus Code: ' + res.getStatusCode() +
                '\nResponse Body:\n' + res.getBody();
            
            // Send error email
            try {
                ReusableUtilityClass.sendSapErrorEmail(errorMsg);
            } catch (Exception e) {
                System.debug('Error while sending SAP error email: ' + e.getMessage());
                
            }
            
            // Return error JSON to caller
            return JSON.serialize(new Map<String, Object>{
                'Statuscode' => res.getStatusCode(),
                    'Message'    => errorMsg
                    });
        }
        
        return res.getBody();
        
        /* } catch (Exception ex) {
System.debug('ex'+ex);

return JSON.serialize(new Map<String, Object>{
'Statuscode' => -1,
'Message'    => 'Exception: ' + ex.getMessage()
});
}*/
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
        
        orderList = [SELECT id, CurrencyIsoCode, Name, Account__c, Account__r.SAP_Code__c,Consignee_Code__c,CONTRACT_NO__c,
                     Order_Activation_Date__c, Account__r.Company_Code__c,Customer_Po_No__c,Order_Creation_Time_Out__c, Dispatch_Through__c,Order_Date__c,
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
           /* for(Freight_Request__c frObj : orderData.Freight_Requests__r){
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
                itemObj.Destination = '';
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
            for(Order_Product__c orderProduct: orderData.Order_Products__r) {
                
                List<Product_Material_Stock__c> stockList = new List<Product_Material_Stock__c>();
                if(!String.isEmpty(orderProduct.Model_Txt__c)) {
                    stockList = modelStockMap.get(orderProduct.Model_Txt__c);
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
    
    public static List<ItemWrapper> prepareRequestBody(){
        List<ItemWrapper> orderItemList = new List<ItemWrapper>();
        
        for(Order_Product__c orderProduct : orderData.Order_Products__r){
            ItemWrapper itemObj = orderItemMap.get(orderProduct.Id);
            if(itemObj != null) {
                if(modeltostockMap.containsKey(orderProduct.Id)) {
                    itemObj.ProductCode = modeltostockMap.get(orderProduct.Id);
                }
                orderItemList.add(itemObj);
            }
        }
        return orderItemList;
    }
    
    // Wrapper Classes
    public class RequestWrapper { 
        public RecordWrapper Record; 
    }
    
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
    }
    
}