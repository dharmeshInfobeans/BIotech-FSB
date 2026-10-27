public with sharing class SplitFreightController {
    
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getSplitOrderDetails(Id orderId) {
        // Normally you'd call SAP with orderId. For demo, return mock.
        return new Map<String, String>{
            'orderNumber' => orderId,
            'destination' => 'Delhi',
            'weight' => '1400 KG',
            'volume' => '9 CBM'
        };
    }

    @AuraEnabled
    public static Map<String, String> getFreightForMode(Id orderId, String mode) {
        return new Map<String, String>{
            'freightCost' => (mode == 'Air') ? '₹28,000' : '₹15,500',
            'eta' => (mode == 'Air') ? '2 Days' : '4 Days',
            'carrier' => (mode == 'Air') ? 'FedEx' : 'Blue Dart',
            'remarks' => 'Includes GST and handling charges.'
        };
    }
}