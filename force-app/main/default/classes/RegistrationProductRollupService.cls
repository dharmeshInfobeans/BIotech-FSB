public with sharing class RegistrationProductRollupService {

    public static void rollupProductList(Set<Id> requestIds) {
        if (requestIds == null || requestIds.isEmpty()) return;

        Map<Id, List<String>> namesByRequest = new Map<Id, List<String>>();
        for (Id rid : requestIds) {
            namesByRequest.put(rid, new List<String>());
        }

        for (Registration_Request_Product__c rrp : [
            SELECT Registration_Request__c, Product__r.Name
            FROM   Registration_Request_Product__c
            WHERE  Registration_Request__c IN :requestIds
            ORDER BY Product__r.Name
        ]) {
            List<String> names = namesByRequest.get(rrp.Registration_Request__c);
            if (names != null && rrp.Product__r.Name != null) {
                names.add(rrp.Product__r.Name);
            }
        }

        List<Registration_Request__c> toUpdate = new List<Registration_Request__c>();
        for (Id rid : requestIds) {
            List<String> names = namesByRequest.get(rid);
            String csv = names.isEmpty() ? null : String.join(names, ', ');
            if (csv != null && csv.length() > 255) {
                csv = csv.substring(0, 252) + '...';
            }
            toUpdate.add(new Registration_Request__c(
                Id             = rid,
                Product_List__c = csv
            ));
        }

        if (!toUpdate.isEmpty()) {
            new ElevatedWriter().doUpdate(toUpdate);
        }
    }

    private without sharing class ElevatedWriter {
        void doUpdate(List<Registration_Request__c> recs) {
            update recs;
        }
    }
}