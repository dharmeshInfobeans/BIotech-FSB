trigger campaignUpdateProduct on Campaign_Line_Item__c (after insert, after update, after delete) {
    CampaignUpdateProductHelper.updateFocusProducts(Trigger.new, Trigger.old, Trigger.isDelete,Trigger.isUpdate);
}