trigger LeadProductRollup on Lead_Product__c (after insert, after update, after delete, after undelete) {

    Set<Id> leadIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Lead_Product__c lp : Trigger.new) {
            if (lp.Leads__c != null) {
                leadIds.add(lp.Leads__c);
            }
        }
    }

    if (Trigger.isUpdate || Trigger.isDelete) {
        for (Lead_Product__c lp : Trigger.old) {
            if (lp.Leads__c != null) {
                leadIds.add(lp.Leads__c);
            }
        }
    }

    if (leadIds.isEmpty()) {
        return;
    }

    Map<Id, Set<String>> productGroupMap = new Map<Id, Set<String>>();
    Map<Id, Set<String>> productFamilyMap = new Map<Id, Set<String>>();

    for (Id lid : leadIds) {
        productGroupMap.put(lid, new Set<String>());
        productFamilyMap.put(lid, new Set<String>());
    }

    for (Lead_Product__c lp : [
        SELECT Id, Leads__c, Product_Group_Name__c, Product_Family__c
        FROM Lead_Product__c
        WHERE Leads__c IN :leadIds
    ]) {
        if (String.isNotBlank(lp.Product_Group_Name__c)) {
            productGroupMap.get(lp.Leads__c).add(lp.Product_Group_Name__c);
        }
        if (String.isNotBlank(lp.Product_Family__c)) {
            productFamilyMap.get(lp.Leads__c).add(lp.Product_Family__c);
        }
    }

    Map<Id, Lead__c> leadsMap = new Map<Id, Lead__c>([
        SELECT Id, Lead_Products__c, Lead_Product_Family__c
        FROM Lead__c
        WHERE Id IN :leadIds
    ]);

    List<Lead__c> leadsToUpdate = new List<Lead__c>();

    for (Id lid : leadIds) {
        Lead__c ld = leadsMap.get(lid);
        if (ld == null) {
            continue;
        }
        ld.Lead_Products__c = String.join(new List<String>(productGroupMap.get(lid)), ', ');
        ld.Lead_Product_Family__c = String.join(new List<String>(productFamilyMap.get(lid)), ', ');
        leadsToUpdate.add(ld);
    }

    if (!leadsToUpdate.isEmpty()) {
       update leadsToUpdate;
    }
}