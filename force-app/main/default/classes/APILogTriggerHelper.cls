public Without sharing class APILogTriggerHelper {
    
    public static void sendMouSchemeEmail(List<API_Log__c> logList) {
        
        if (logList == null || logList.isEmpty()) {
            return;
        }

        MOU_Integration__c settingRec =
            MOU_Integration__c.getInstance('getschememaster');

        if (settingRec == null || 
            String.isBlank(settingRec.Error_Log_Emails__c)) {
            return;
        }

        List<String> toEmails = settingRec.Error_Log_Emails__c.split(',');

        List<ContentVersion> cvList = new List<ContentVersion>();
        List<Blob> jsonBlobs = new List<Blob>(); 

        
        for (API_Log__c log : logList) {

            String jsonData = JSON.serializePretty(log);
            Blob jsonBlob = Blob.valueOf(jsonData);

            jsonBlobs.add(jsonBlob);

            ContentVersion cv = new ContentVersion();
            cv.Title = 'MOU_API_Log_' + log.Name;
            cv.PathOnClient = 'MOU_API_Log_' + log.Name + '.json';
            cv.VersionData = jsonBlob;

            cvList.add(cv);
        }

        insert cvList;


        Map<Id, Id> versionToDocumentMap = new Map<Id, Id>();

        for (ContentVersion cv : [
            SELECT Id, ContentDocumentId
            FROM ContentVersion
            WHERE Id IN :cvList
        ]) {
            versionToDocumentMap.put(cv.Id, cv.ContentDocumentId);
        }

        List<ContentDocumentLink> linkList = new List<ContentDocumentLink>();

        for (Integer i = 0; i < cvList.size(); i++) {

            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = versionToDocumentMap.get(cvList[i].Id);
            cdl.LinkedEntityId = logList[i].Id;
            cdl.ShareType = 'V';
            cdl.Visibility = 'AllUsers';

            linkList.add(cdl);
        }

        insert linkList;

        
        List<Messaging.SingleEmailMessage> emailList =
            new List<Messaging.SingleEmailMessage>();

        for (Integer i = 0; i < logList.size(); i++) {

            Messaging.EmailFileAttachment attachment =
                new Messaging.EmailFileAttachment();

            attachment.setFileName(
                'MOU_API_Log_' + logList[i].Name + '.json'
            );
            attachment.setBody(jsonBlobs[i]);
            attachment.setContentType('application/json');

            Messaging.SingleEmailMessage mail =
                new Messaging.SingleEmailMessage();

            mail.setToAddresses(toEmails);
            mail.setSubject('MOU Scheme API Log - ' + logList[i].Name);
            mail.setPlainTextBody(
                'Please find attached Error Log file: ' 
                + logList[i].Name
            );

            mail.setFileAttachments(
                new List<Messaging.EmailFileAttachment>{attachment}
            );

            emailList.add(mail);
        }

        if (!emailList.isEmpty()) {
            Messaging.sendEmail(emailList);
        }
    }
}