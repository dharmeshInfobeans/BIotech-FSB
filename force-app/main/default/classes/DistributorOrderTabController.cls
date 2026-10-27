public with sharing class DistributorOrderTabController {

    public class OrderTabStatus {
        @AuraEnabled public Boolean isUnlocked;
        @AuraEnabled public String  requestId;
        @AuraEnabled public String  requestName;
        @AuraEnabled public String  status;
        @AuraEnabled public List<ProductOrderStatus> products;
    }

    public class ProductOrderStatus {
        @AuraEnabled public String  productId;
        @AuraEnabled public String  productName;
        @AuraEnabled public Boolean orderUnlocked;
        @AuraEnabled public String  certificateStatus;
        @AuraEnabled public List<OrderSummary> orders;
    }

    public class OrderSummary {
        @AuraEnabled public String  orderId;
        @AuraEnabled public String  orderName;
        @AuraEnabled public String  status;
        @AuraEnabled public String  orderDate;
        @AuraEnabled public Decimal totalQty;
        @AuraEnabled public String  customerPoNo;
    }

    @AuraEnabled
    public static OrderTabStatus getOrderTabStatus() {
        Id userId    = UserInfo.getUserId();
        Id accountId = new ElevatedQuery().getAccountId(userId);

        OrderTabStatus s = new OrderTabStatus();
        s.isUnlocked = false;
        s.products   = new List<ProductOrderStatus>();

        if (accountId == null) return s;

        List<Registration_Request__c> requests = new ElevatedQuery().getActiveRequest(accountId);
        if (requests.isEmpty()) return s;

        Registration_Request__c rr = requests[0];
        s.requestId   = rr.Id;
        s.requestName = rr.Name;
        s.status      = rr.Status__c;

        Boolean anyUnlocked = rr.No_Registration__c;
        Map<Id, ProductOrderStatus> productMap = new Map<Id, ProductOrderStatus>();
        List<Id> unlockedProductIds = new List<Id>();

        List<Registration_Request_Product__c> products = new ElevatedQuery().getProducts(rr.Id);
        for (Registration_Request_Product__c p : products) {
            ProductOrderStatus pos = new ProductOrderStatus();
            pos.productId        = p.Product__c;
            pos.productName      = p.Product__r.Name;
            pos.orderUnlocked    = p.Order_Unlocked__c;
            pos.certificateStatus = p.Certificate_Status__c;
            pos.orders           = new List<OrderSummary>();
            s.products.add(pos);
            productMap.put(p.Product__c, pos);
            if (p.Order_Unlocked__c) {
                anyUnlocked = true;
                unlockedProductIds.add(p.Product__c);
            }
        }
        s.isUnlocked = anyUnlocked;

        if (!unlockedProductIds.isEmpty()) {
            Set<String> seen = new Set<String>();
            List<Order_Product__c> orderLines = new ElevatedQuery().getOrderProducts(accountId, unlockedProductIds);
            for (Order_Product__c op : orderLines) {
                if (!productMap.containsKey(op.Product__c)) continue;
                String orderId = op.Order__r.Id;
                if (seen.contains(orderId + String.valueOf(op.Product__c))) continue;
                seen.add(orderId + String.valueOf(op.Product__c));
                OrderSummary os = new OrderSummary();
                os.orderId      = orderId;
                os.orderName    = op.Order__r.Name;
                os.status       = op.Order__r.Status__c;
                os.orderDate    = op.Order__r.Order_Date__c != null
                                  ? String.valueOf(op.Order__r.Order_Date__c) : null;
                os.totalQty     = op.Order__r.Total_Qty__c;
                os.customerPoNo = op.Order__r.Customer_Po_No__c;
                productMap.get(op.Product__c).orders.add(os);
            }
        }

        return s;
    }

    private without sharing class ElevatedQuery {

        public Id getAccountId(Id userId) {
            List<User> users = [SELECT AccountId FROM User WHERE Id = :userId LIMIT 1];
            return users.isEmpty() ? null : users[0].AccountId;
        }

        public List<Registration_Request__c> getActiveRequest(Id accountId) {
            return [
                SELECT Id, Name, No_Registration__c, Status__c
                FROM   Registration_Request__c
                WHERE  Account__c        = :accountId
                AND    Parent_Request__c = null
                AND    Status__c        NOT IN ('Rejected', 'Sent Back')
                ORDER BY LastModifiedDate DESC
                LIMIT  1
            ];
        }

        public List<Registration_Request_Product__c> getProducts(Id requestId) {
            return [
                SELECT Id, Product__c, Product__r.Name, Order_Unlocked__c, Certificate_Status__c
                FROM   Registration_Request_Product__c
                WHERE  Registration_Request__c = :requestId
                ORDER BY Product__r.Name
            ];
        }

        public List<Order_Product__c> getOrderProducts(Id accountId, List<Id> productIds) {
            return [
                SELECT Product__c,
                       Order__r.Id, Order__r.Name, Order__r.Status__c,
                       Order__r.Order_Date__c, Order__r.Total_Qty__c, Order__r.Customer_Po_No__c
                FROM   Order_Product__c
                WHERE  Order__r.Account__c = :accountId
                AND    Product__c IN :productIds
                ORDER BY Order__r.Order_Date__c DESC NULLS LAST
                LIMIT  100
            ];
        }
    }
}