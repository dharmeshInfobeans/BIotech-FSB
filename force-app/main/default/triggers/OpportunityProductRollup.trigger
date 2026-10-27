trigger OpportunityProductRollup on Opportunity_Product__c (after insert, after update, after delete, after undelete) {

    Set<Id> oppIds = new Set<Id>();

    if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) {
        for (Opportunity_Product__c op : Trigger.new) {
            if (op.Opportunity__c != null) {
                oppIds.add(op.Opportunity__c);
            }
        }
    }

    if (Trigger.isUpdate || Trigger.isDelete) {
        for (Opportunity_Product__c op : Trigger.old) {
            if (op.Opportunity__c != null) {
                oppIds.add(op.Opportunity__c);
            }
        }
    }

    if (oppIds.isEmpty()) {
        return;
    }

    Map<Id, Set<String>> productGroupMap = new Map<Id, Set<String>>();
    Map<Id, Set<String>> productFamilyMap = new Map<Id, Set<String>>();

    for (Id oid : oppIds) {
        productGroupMap.put(oid, new Set<String>());
        productFamilyMap.put(oid, new Set<String>());
    }

    for (Opportunity_Product__c op : [
        SELECT Id, Opportunity__c, Product_Group_Name__c, Product_Family__c
        FROM Opportunity_Product__c
        WHERE Opportunity__c IN :oppIds
    ]) {
        if (String.isNotBlank(op.Product_Group_Name__c)) {
            productGroupMap.get(op.Opportunity__c).add(op.Product_Group_Name__c);
        }
        if (String.isNotBlank(op.Product_Family__c)) {
            productFamilyMap.get(op.Opportunity__c).add(op.Product_Family__c);
        }
    }

    Map<Id, Opportunity__c> oppsMap = new Map<Id, Opportunity__c>([
        SELECT Id, Opps_Products__c, Opps_Product_Family__c
        FROM Opportunity__c
        WHERE Id IN :oppIds
    ]);

    List<Opportunity__c> oppsToUpdate = new List<Opportunity__c>();

    for (Id oid : oppIds) {
        Opportunity__c opp = oppsMap.get(oid);
        if (opp == null) {
            continue;
        }
        opp.Opps_Products__c = String.join(new List<String>(productGroupMap.get(oid)), ', ');
        opp.Opps_Product_Family__c = String.join(new List<String>(productFamilyMap.get(oid)), ', ');
        oppsToUpdate.add(opp);
    }

    if (!oppsToUpdate.isEmpty()) {
        update oppsToUpdate;
    }
}