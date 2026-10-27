public class ContentVersionHelper {
    
    public static void genratepublicurl(List<ContentVersion> newlist){
        Set<Id> contentDocumentIds = new Set<Id>();
        Map<Id, ContentVersion> materialToVersionMap = new Map<Id, ContentVersion>();
        for (ContentVersion cv : newlist) {
            contentDocumentIds.add(cv.ContentDocumentId);
        }
        if (!contentDocumentIds.isEmpty()) {
            List<ContentDocumentLink> docLinks = [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE ContentDocumentId IN :contentDocumentIds
            ];
            for (ContentDocumentLink link : docLinks) {
                if (link.LinkedEntityId.getSObjectType() == Campaign__c.SObjectType) {
                    for (ContentVersion cv : newlist) {
                        if (cv.ContentDocumentId == link.ContentDocumentId) {
                            materialToVersionMap.put(link.LinkedEntityId, cv);
                            break;
                        }
                    }
                }
            }
            List<ContentDistribution> distsToInsert = new List<ContentDistribution>();
            for (Id materialId : materialToVersionMap.keySet()) {
                ContentDistribution dist = new ContentDistribution();
                dist.Name = materialToVersionMap.get(materialId).Title;
                dist.ContentVersionId = materialToVersionMap.get(materialId).id;
                dist.PreferencesAllowViewInBrowser = true;
                dist.PreferencesAllowOriginalDownload = false;
                dist.PreferencesNotifyOnVisit = false;
                dist.PreferencesAllowPDFDownload  = false;
                distsToInsert.add(dist);
                
            }
            if (!distsToInsert.isEmpty()) {
                insert distsToInsert;
                
                List<ContentDistribution> distList = [
                    SELECT Id, DistributionPublicUrl, ContentVersionId
                    FROM ContentDistribution
                    WHERE Id IN :distsToInsert
                ];
                List<Campaign__c> materialsToUpdate = new List<Campaign__c>();
                for (Id materialId : materialToVersionMap.keySet()) {
                    Id versionId = materialToVersionMap.get(materialId).Id;
                    for (ContentDistribution dist : distList) {
                        if (dist.ContentVersionId == versionId) {
                            materialsToUpdate.add(new Campaign__c(
                                Id = materialId,
                                Content_version_Id__c = versionId,
                                Public_File_Url__c = dist.DistributionPublicUrl
                            ));
                            break;
                        }
                    }
                }
                if (!materialsToUpdate.isEmpty()) {
                    update materialsToUpdate;
                } 
            } 
        } 
    }
    
}