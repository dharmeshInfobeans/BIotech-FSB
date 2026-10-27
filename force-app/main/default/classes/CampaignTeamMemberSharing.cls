public class CampaignTeamMemberSharing {
    public static void campaignSharing(List<Campaign_Team_Member__c> newList,Map<Id,Campaign_Team_Member__c> oldMap) {
        List<Target__Share> targetShareList=new List<Target__Share>();     
        Map<String,List<String>> camMap=new Map<String,List<String>>();
        Set<Id> parentSet = new Set<Id>();
        Set<Id> userSet = new Set<Id>();
        for(Campaign_Team_Member__c cmp:newList) {
            if(cmp.User__c!=null) {
                if(camMap.containsKey(cmp.Campaigns__c)) {
                    List<string> userId=camMap.get(cmp.Campaigns__c);
                    userId.add(cmp.User__c);
                    camMap.put(cmp.Campaigns__c,userId);
                } else {
                    List<String> userId=new List<String>();
                    userId.add(cmp.User__c);
                    camMap.put(cmp.Campaigns__c,userId);
                }
                
            }
        }   
        System.debug('Campaing Map'+camMap);
        
        List<Campaign__c> campaignList=[SELECT id,Target__c,Target__r.User__c from Campaign__c where Id in:camMap.keySet()];
        for(Campaign__c cam:campaignList) {
            if(camMap.containsKey(cam.Id)) {
                for(String use:camMap.get(cam.Id)) {
                    Target__Share targetShare = new Target__Share();
                    targetShare.ParentId = cam.Target__c;
                    targetShare.UserOrGroupId=use;
                    system.debug('id'+cam.Target__c);
                    System.debug('User'+cam.Target__r.User__c);
                    targetShare.AccessLevel= 'Edit';
                    targetShareList.add(targetShare);
                   
                }
                
            }
            
        }
        if(targetShareList.size()>0) {
            System.debug('TargetShareList'+targetShareList+'size'+targetShareList.size());
            insert targetShareList;
        }
        
        
        
    }
}