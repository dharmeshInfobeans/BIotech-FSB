public with sharing class FreightService {
    @AuraEnabled(cacheable=true)
    public static List<String> getTransportModesFromSAP(Id orderId) {
        // TODO: Replace with real SAP callout using Named Credential
        return new List<String>{ 'Cargo', 'Courier', 'Postal' };
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getSplitOrdersFromSAP(Id orderId) {
        // TODO: Replace with real SAP callout to fetch split orders for the given Order Id.
        List<Map<String,Object>> rows = new List<Map<String,Object>>();

        Map<String,Object> r1 = new Map<String,Object>{
            'splitOrderId' => 'SP-1',
            'productName' => 'Product A',
            'orderQuantity' => 10,
            'idealQuantity' => 12,
            'plantCode' => '',
            'forwarder' => '',
            'boxDimensions' => '',
            'netWeight' => 5,
            'approxFreight' => ''
        };

        Map<String,Object> r2 = new Map<String,Object>{
            'splitOrderId' => 'SP-2',
            'productName' => 'Product B',
            'orderQuantity' => 6,
            'idealQuantity' => 6,
            'plantCode' => '',
            'forwarder' => '',
            'boxDimensions' => '',
            'netWeight' => 3,
            'approxFreight' => ''
        };

        rows.add(r1);
        rows.add(r2);
        return rows;
    }

    @AuraEnabled
    public static Map<String, Object> getFreightDetailsFromSAP(String splitOrderId, String transportMode, Decimal orderQuantity) {
        // TODO: Replace with real SAP callout. This stub simulates a freight calc response.
        Map<String,Object> r = new Map<String,Object>();
        r.put('plantCode','PLANT01');
        r.put('forwarder','FastFreight Pvt Ltd');
        r.put('boxDimensions','40x30x20');
        r.put('netWeight', 12.5);
        r.put('approxFreight', 'USD 45.00');
        return r;
    }

    @AuraEnabled
    public static void saveOrderQuantities(Id orderId, List<Map<String,Object>> entries) {
        // entries: [{splitOrderId, orderQuantity}, ...]
        // TODO: Either persist to your Split Order custom object or call SAP middleware to update
        // This stub does nothing (simulate success)
        return;
    }

    @AuraEnabled
    public static void approveFreightOnOrder(Id orderId, List<Map<String,Object>> splitOrdersData) {
        // splitOrdersData: [{splitOrderId, plantCode, forwarder, boxDimensions, netWeight, approxFreight}, ...]

        // Example: set Freight_Approved__c = true on the Order object. Replace field API name as needed.
        try {
            // make sure Order exists
            Order__c ord = [SELECT Id, Freight_Approved__c FROM Order__c WHERE Id = :orderId LIMIT 1];
            ord.Freight_Approved__c = true;
            update ord;

            // TODO: Persist splitOrdersData into a Split Order custom object (temporary storage) as required.

        } catch (Exception e) {
            throw new AuraHandledException('Unable to approve freight: ' + e.getMessage());
        }
    }
}