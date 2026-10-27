// Separate top level class — not inner
public without sharing class FileDistributionService {
    
    public static String getOrCreatePublicUrl(String contentDocumentId) {
        
        // Check if distribution already exists
        List<ContentDistribution> existing = [
            SELECT Id, DistributionPublicUrl
            FROM ContentDistribution
            WHERE ContentDocumentId = :contentDocumentId
            LIMIT 1
        ];
        
        if (!existing.isEmpty()) {
            return existing[0].DistributionPublicUrl;
        }
        
        // Get latest ContentVersion
        ContentVersion cv = [
            SELECT Id FROM ContentVersion
            WHERE ContentDocumentId = :contentDocumentId
            AND IsLatest = true
            LIMIT 1
        ];
        
        // Create public distribution
        ContentDistribution cd              = new ContentDistribution();
        cd.Name                             = 'Guest Public Preview';
        cd.ContentVersionId                 = cv.Id;
        cd.PreferencesAllowViewInBrowser    = true;
        cd.PreferencesLinkLatestVersion     = true;
        cd.PreferencesNotifyOnVisit         = false;
        cd.PreferencesPasswordRequired      = false;
        cd.PreferencesAllowOriginalDownload = true;
        insert cd;
        
        cd = [SELECT DistributionPublicUrl FROM ContentDistribution WHERE Id = :cd.Id];
        return cd.DistributionPublicUrl;
    }
}