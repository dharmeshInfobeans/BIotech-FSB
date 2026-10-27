trigger CampaingTeamMemberTrigger on Campaign_Team_Member__c (after insert,after update) {
    if(Trigger.isAfter) {
        if(Trigger.isInsert || Trigger.isUpdate) {
            CampaignTeamMemberSharing.campaignSharing(Trigger.new, Trigger.oldMap);
        }
    }
}