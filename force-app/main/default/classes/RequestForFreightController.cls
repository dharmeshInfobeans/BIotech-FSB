public class RequestForFreightController
{
    @AuraEnabled
    public static Boolean updateFreightStatus(String pOrderId)
    {
        list <Freight_Request__c> requestToUpdate = new list <Freight_Request__c>();
        List<Order__c> orderFreightRequestForList = new List<Order__c>();
        requestToUpdate = [SELECT Id, Status__c FROM Freight_Request__c WHERE Order__c=:pOrderId];
        orderFreightRequestForList = [Select Id, Status__c FROM Order__c WHERE ID =:pOrderId LIMIT 1];
        Order__c orderFreightRequestFor = new Order__c();
        Boolean freightRequestedSuccessfully = false;
        if(requestToUpdate.size() > 0)
        {
            orderFreightRequestFor = orderFreightRequestForList[0];
            orderFreightRequestFor.Status__c = 'Freight Requested';
            system.debug('BG >>> orderFreightRequestFor : '+orderFreightRequestFor);
            for(Freight_Request__c fR:requestToUpdate){
                fR.Status__c= 'Requested';
                fR.Freight_Requested_date__c = system.today();
            }
            try{
                update requestToUpdate;
                system.debug('BG >>> orderFreightRequestFor : '+orderFreightRequestFor);
                update orderFreightRequestFor;
                system.debug('BG >>> orderFreightRequestFor : '+orderFreightRequestFor);
                freightRequestedSuccessfully = true;
            }catch(Exception e){
                System.debug('RQ FOR FREI Error--------->'+ e.getMessage());
                throw e;
            }

        }

        return freightRequestedSuccessfully;
    }

    @AuraEnabled
    public static Boolean fetchOrderStatus(String orderId)
    {
        Boolean isValidStatus = false;
        Order__c orderObj = [SELECT Id, Status__c FROM Order__c WHERE id=:orderId];
        if(orderObj!=null)
        {
            if(orderObj.Status__c == 'Draft') {
                isValidStatus = true;
            }
        }
        return isValidStatus;
    }

    @AuraEnabled
    public static responseCls fetchStatus_Requests(String orderId)
    {
        responseCls responseInst = new responseCls();
        Order__c orderObj = [SELECT Id, Status__c, Consignee_Name__c FROM Order__c WHERE id=:orderId];

        if(orderObj!=null)
        {
            if(orderObj.Status__c == 'Draft') {
                responseInst.isValidStatus = true;
            }
            if(orderObj.Consignee_Name__c != null){
                responseInst.consigneePresent = true;
            }
        }
        list <Freight_Request__c> requestAvailable = [SELECT Id, Status__c,Freight_Requested_date__c FROM Freight_Request__c WHERE Order__c=:orderId];
        if(requestAvailable!=null && requestAvailable.size() > 0)
        {
            responseInst.frPresent = true;
        }
        system.debug('BG >>> responseInst : '+responseInst);
        List<Order_Product__c> orderProducts = [SELECT Id,Order__c FROM Order_Product__c WHERE Order__c =:orderId AND Incart__c = true ];
        if(orderProducts!=null&&orderProducts.size()>0){
            responseInst.inCartProductPresent=true;
        }

        if(requestAvailable!=null && !responseInst.inCartProductPresent && responseInst.isValidStatus && responseInst.consigneePresent && responseInst.frPresent)
        {
            for(Freight_Request__c fR:requestAvailable){
                fR.Status__c= 'Requested';
                fR.Freight_Requested_date__c = system.today();
                orderObj.Status__c = 'Freight Requested';
                system.debug('BG >>> responseInst : '+responseInst);
            }
            try{
                update requestAvailable;
                update orderObj;
                system.debug('BG >>> responseInst : '+responseInst);
                responseInst.updatesSucces = true;
            }catch(Exception e){
                System.debug('RQ FOR FREI Error--------->'+ e.getMessage());
                throw e;
            }

        }
        return responseInst;
    }
    @AuraEnabled
    public static Boolean fetchFreightRequests(String orderId)
    {
        Boolean isValidStatus = false;
        list <Freight_Request__c> requestAvailable = [SELECT Id, Status__c FROM Freight_Request__c WHERE Order__c=:orderId];
        if(requestAvailable!=null && requestAvailable.size() > 0)
        {
            isValidStatus = true;
        }
        return isValidStatus;
    }

    public class responseCls {
        @AuraEnabled public Boolean isValidStatus{get;set;}
        @AuraEnabled public Boolean frPresent{get;set;}
        @AuraEnabled public Boolean consigneePresent{get;set;}
        @AuraEnabled public Boolean updatesSucces{get;set;}
        @AuraEnabled public Boolean inCartProductPresent{get;set;}
        public responseCls() {
            isValidStatus  = false;
            frPresent = false;
            updatesSucces = false;
            consigneePresent = false;
            inCartProductPresent = false;
        }
    }
}