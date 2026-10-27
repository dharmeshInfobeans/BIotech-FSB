public without sharing class SampleRequestApprovalProcess {
    
    public static void createApprovalRecord(List<Sample_Request_Line_Item__c> lineItemList,Id headerId,String role,Boolean isInsert){
        Set<Id> productIdSet  = new Set<Id>();
        String userId ='';
        String account = '';
        String contact = '';
        Map<String,Integer> mapOfTotalSampleQuantity = new Map<String,Integer>();
        Map<String,Integer> mapOfApprovedQuantity = new Map<String,Integer>();
        Map<String,Integer> mapOfRoleApproval = new Map<String,Integer>();
        Map<String,Integer> mapOfSampleApproved = new Map<String,Integer>();
        Decimal previousLevel = 0;
        Decimal approverLimit = 0;
        String headerName = '';
        Integer currentApproverLevel = 0;
        String currentApproverName = '';
        Id  currentApprovalChainId= null;
        Boolean sentToNextApprover = isInsert;
        Boolean toUpdateTransaction = false;
        Approval_Chain__c nextApprover = null;
        Boolean isOverLimit = false;
        List<sObject> recordsToUpsert = new List<sObject>();
        if(lineItemList.get(0).Product_M__r.Product_Group__r.Vertical__c == 'ORTHOPAEDICS'){
            List<AggregateResult> results = [SELECT COUNT(Id) ApprovedQuantity, Product_M__r.Product_Group__r.Vertical__c, CALENDAR_MONTH(CreatedDate) CreatedMonth, CALENDAR_YEAR(CreatedDate) CreatedYear FROM Sample_Request_Line_Item__c WHERE Is_Backup__c = false AND Product_M__r.Product_Group__r.Vertical__c = 'ORTHOPAEDICS' AND CALENDAR_MONTH(CreatedDate) =:lineItemList.get(0).CreatedDate.month() AND CALENDAR_YEAR(CreatedDate) =: lineItemList.get(0).CreatedDate.year() AND Approval_Status__c = 'Approved' AND Sample_Request_Header__c !=: headerId GROUP BY Product_M__r.Product_Group__r.Vertical__c, CALENDAR_MONTH(CreatedDate), CALENDAR_YEAR(CreatedDate)];
            Product_Monthly_Sample_Limit__mdt prdLimit = [select Limit__c from Product_Monthly_Sample_Limit__mdt where DeveloperName = 'ORTHOPAEDICS'];
            if(prdLimit != null){
                isOverLimit = !results.isEmpty() && ((Integer) results[0].get('ApprovedQuantity') + lineItemList.size() > prdLimit.Limit__c);
            }
        }
        for(Sample_Request_Line_Item__c lineItem :lineItemList){
      account = lineItem.Sample_Request_Header__r.Customer__c;
            contact = lineItem.Sample_Request_Header__r.Contact__c;
            userId = lineItem.CreatedById;
            productIdSet.add(lineItem.Product_Group__c);
        }
        
        List<AggregateResult> approvedLimitList = [SELECT Count(Id) ApprovedQuantity,Product_Group__c FROM Sample_Request_Line_Item__c WHERE Approval_Status__c = 'Approved' AND SAP_status__c != 'Returned' AND SAP_status__c != 'Cancelled' AND Sample_Request_Header__r.Customer__c =:account AND Sample_Request_Header__r.Contact__c =:contact AND Product_Group__c IN: productIdSet GROUP BY Product_Group__c];      
        List<Approval_Chain__c> approvalChainList = [SELECT Id,Approval_Limit__c,Approver__c,Approver__r.Name,Level__c,Role__c,Is_Active__c,Status__c,Sample_Request_Header__r.Name FROM Approval_Chain__c WHERE Sample_Request_Header__c =:headerId AND Is_Active__c = true ORDER BY Level__c ASC,Priority__c DESC];
        if(!approvalChainList.isEmpty()) headerName = (String)approvalChainList.get(0).Sample_Request_Header__r.Name;
        if(role != 'CMD'){
            if(!isInsert){    
                /*for(Approval_Chain__c approvalChain : approvalChainList){
if(approvalChain.Role__c == role){
currentApproverLevel = (Integer)approvalChain.Level__c;
currentApproverName = (String)approvalChain.Approver__r.Name;
currentApprovalChainId = approvalChain.Id;
approvalChain.Status__c = 'Approved';
recordsToUpsert.add(approvalChain);
}
if(approvalChain.Level__c != previousLevel){
approverLimit += approvalChain.Approval_Limit__c != null ? approvalChain.Approval_Limit__c : 0;
mapOfRoleApproval.put(approvalChain.Role__c , (Integer)approverLimit);
previousLevel = approvalChain.Level__c;
}
System.debug('mapOfRoleApproval : '+mapOfRoleApproval);
}*/
                for(Approval_Chain__c approvalChain : approvalChainList){
                    if(approvalChain.Role__c == role){
                        currentApproverLevel = (Integer)approvalChain.Level__c;
                        currentApproverName = (String)approvalChain.Approver__r.Name;
                        currentApprovalChainId = approvalChain.Id;
                        approvalChain.Status__c = 'Approved';
                        recordsToUpsert.add(approvalChain);
                    }
                    
                    // Only bump the running total when we move to a new level
                    if(approvalChain.Level__c != previousLevel){
                        approverLimit += approvalChain.Approval_Limit__c != null ? approvalChain.Approval_Limit__c : 0;
                        previousLevel = approvalChain.Level__c;
                    }
                    
                    // But ALWAYS record this role against the current cumulative limit
                    mapOfRoleApproval.put(approvalChain.Role__c, (Integer)approverLimit);
                    
                    System.debug('mapOfRoleApproval : '+mapOfRoleApproval);
                }
                
                for(AggregateResult approvedProductQuantity :approvedLimitList){
                    mapOfApprovedQuantity.put((String)approvedProductQuantity.get('Product_Group__c'),(Integer)approvedProductQuantity.get('ApprovedQuantity'));
                }
                System.debug('mapOfApprovedQuantity:'+mapOfApprovedQuantity);
                for(Sample_Request_Line_Item__c lineItem :lineItemList){
                    System.debug('mapOfTotalSampleQuantity : '+mapOfTotalSampleQuantity);
                    if(!lineItem.Is_Backup__c && lineItem.Approval_Status__c != 'Approved'){
                        System.debug('mapOfTotalSampleQuantity : '+mapOfTotalSampleQuantity);
                        if(!mapOfTotalSampleQuantity.containsKey(lineItem.Product_Group__c))mapOfTotalSampleQuantity.put(lineItem.Product_Group__c,(mapOfApprovedQuantity.containsKey((String)lineItem.get('Product_Group__c')) ? mapOfApprovedQuantity.get((String)lineItem.get('Product_Group__c')) : 0));
                        mapOfTotalSampleQuantity.put(lineItem.Product_Group__c,mapOfTotalSampleQuantity.get(lineItem.Product_Group__c) + 1);
                    }
                }
                System.debug('mapOfTotalSampleQuantity : '+mapOfTotalSampleQuantity);
                for(String lineItem : mapOfTotalSampleQuantity.keySet()){
                    if(!mapOfApprovedQuantity.containsKey(lineItem)){
                        mapOfApprovedQuantity.put(lineItem,0);
                    }
                    if(mapOfRoleApproval.get(role) > mapOfApprovedQuantity.get(lineItem)){
                        Integer previousApproved = mapOfApprovedQuantity.get(lineItem);
                        mapOfApprovedQuantity.put(lineItem,mapOfRoleApproval.get(role)-mapOfApprovedQuantity.get(lineItem) >= mapOfTotalSampleQuantity.get(lineItem)  ? mapOfTotalSampleQuantity.get(lineItem) : mapOfRoleApproval.get(role));
                        if(mapOfApprovedQuantity.get(lineItem) < mapOfTotalSampleQuantity.get(lineItem)) sentToNextApprover = true;
                        mapOfSampleApproved.put(lineItem,mapOfApprovedQuantity.get(lineItem) - previousApproved);
                    }
                    else{
                        sentToNextApprover = true;
                    }
                }
                System.debug('mapOfSampleApproved :'+mapOfSampleApproved);
                for(Sample_Request_Line_Item__c lineItem : lineItemList){
                    if(mapOfSampleApproved.containsKey(lineItem.Product_Group__c) && mapOfSampleApproved.get(lineItem.Product_Group__c) > 0 && lineItem.Approval_Status__c != 'Approved' && !lineItem.Is_Backup__c){
                        lineItem.Approval_Status__c = 'Approved';
                        lineItem.Approved_On__c = Date.today();
                        mapOfSampleApproved.put(lineItem.Product_Group__c , mapOfSampleApproved.get(lineItem.Product_Group__c) -1);
                        recordsToUpsert.add(lineItem);
                    }
                }
            }
            if(sentToNextApprover || isOverLimit){
                System.debug('sentToNextApprover '+sentToNextApprover);
                System.debug('isOverLimit '+isOverLimit);
                sentToNextApprover = true;
                if(!isInsert){
                    List<Org_Role_Hierarchy_Assignment__c> rhList = [select Org_Role_Hierarchy__c, Org_Role_Hierarchy__r.RSM__c,  Org_Role_Hierarchy__r.GM__c, Org_Role_Hierarchy__r.NSM__c, Org_Role_Hierarchy__r.DM__c, Org_Role_Hierarchy__r.GSRO__c, Org_Role_Hierarchy__r.AGM_PD__c, Org_Role_Hierarchy__r.AGMMEPMT__c, Org_Role_Hierarchy__r.AMM__c, Org_Role_Hierarchy__r.BDM__c, Org_Role_Hierarchy__r.BMR__c, Org_Role_Hierarchy__r.CM__c, Org_Role_Hierarchy__r.Head_PMT_PD__c, Org_Role_Hierarchy__r.HMCA__c, Org_Role_Hierarchy__r.KAM__c, Org_Role_Hierarchy__r.MME__c, Org_Role_Hierarchy__r.NMM__c, Org_Role_Hierarchy__r.PM__c, Org_Role_Hierarchy__r.RM__c, Org_Role_Hierarchy__r.RMML__c, Org_Role_Hierarchy__r.RMMMENA__c, Org_Role_Hierarchy__r.SAE__c, Org_Role_Hierarchy__r.SDE__c, Org_Role_Hierarchy__r.SEM__c, Org_Role_Hierarchy__r.SEMP__c, Org_Role_Hierarchy__r.SEMW__c, Org_Role_Hierarchy__r.SMME__c, Org_Role_Hierarchy__r.SMMNCZ__c, Org_Role_Hierarchy__r.SMMS__c, Org_Role_Hierarchy__r.SMMW__c, Org_Role_Hierarchy__r.SSE__c, Org_Role_Hierarchy__r.TM__c, Org_Role_Hierarchy__r.ZSM__c from Org_Role_Hierarchy_Assignment__c where Account__c =: account and (Org_Role_Hierarchy__r.BDM__c = : userId OR Org_Role_Hierarchy__r.CM__c = : userId OR  Org_Role_Hierarchy__r.DM__c = : userId OR Org_Role_Hierarchy__r.GM__c = : userId OR Org_Role_Hierarchy__r.GSRO__c = : userId OR Org_Role_Hierarchy__r.KAM__c =: userId OR Org_Role_Hierarchy__r.NSM__c = : userId OR Org_Role_Hierarchy__r.RM__c = : userId OR Org_Role_Hierarchy__r.RSM__c =: userId OR Org_Role_Hierarchy__r.SAE__c = : userId OR Org_Role_Hierarchy__r.SDE__c = : userId OR Org_Role_Hierarchy__r.SSE__c = : userId OR Org_Role_Hierarchy__r.TM__c =: userId OR  Org_Role_Hierarchy__r.ZSM__c = : userId ) LIMIT 1];
                    if(rhList.IsEmpty()){
                        rhList =  [select Org_Role_Hierarchy__c, Org_Role_Hierarchy__r.RSM__c,  Org_Role_Hierarchy__r.GM__c, Org_Role_Hierarchy__r.NSM__c, Org_Role_Hierarchy__r.DM__c, Org_Role_Hierarchy__r.GSRO__c, Org_Role_Hierarchy__r.AGM_PD__c, Org_Role_Hierarchy__r.AGMMEPMT__c, Org_Role_Hierarchy__r.AMM__c, Org_Role_Hierarchy__r.BDM__c, Org_Role_Hierarchy__r.BMR__c, Org_Role_Hierarchy__r.CM__c, Org_Role_Hierarchy__r.Head_PMT_PD__c, Org_Role_Hierarchy__r.HMCA__c, Org_Role_Hierarchy__r.KAM__c, Org_Role_Hierarchy__r.MME__c, Org_Role_Hierarchy__r.NMM__c, Org_Role_Hierarchy__r.PM__c, Org_Role_Hierarchy__r.RM__c, Org_Role_Hierarchy__r.RMML__c, Org_Role_Hierarchy__r.RMMMENA__c, Org_Role_Hierarchy__r.SAE__c, Org_Role_Hierarchy__r.SDE__c, Org_Role_Hierarchy__r.SEM__c, Org_Role_Hierarchy__r.SEMP__c, Org_Role_Hierarchy__r.SEMW__c, Org_Role_Hierarchy__r.SMME__c, Org_Role_Hierarchy__r.SMMNCZ__c, Org_Role_Hierarchy__r.SMMS__c, Org_Role_Hierarchy__r.SMMW__c, Org_Role_Hierarchy__r.SSE__c, Org_Role_Hierarchy__r.TM__c, Org_Role_Hierarchy__r.ZSM__c from Org_Role_Hierarchy_Assignment__c where Account__c =: account and Org_Role_Hierarchy__r.Division__c = 'GT' AND Org_Role_Hierarchy__r.Sub_Division__c = 'GT' LIMIT 1];
                    }
                    if(rhList.isEmpty()){
                        AuraHandledException e = new AuraHandledException(userId +'Test'+account +'Org Role Hierarchy is not configured for this account. Please configure it before creating a sample request.');
                        e.setMessage('Org Role Hierarchy is not configured for this account. Please configure it before creating a sample request.');
                        throw e;
                    }
                    Org_Role_Hierarchy_Assignment__c roleHeirarchy = rhList[0];
                    approvalChainList = !isInsert ? roleHeirarchy != null ? approvalChainVerify(approvalChainList,roleHeirarchy) : approvalChainList : approvalChainList;
                }
                for(Approval_Chain__c approvalChain : approvalChainList){
                    System.debug(approvalChain.Role__c + ' ' + approvalChain.Level__c + ' ' + nextApprover + currentApproverLevel);
                    if(approvalChain.Approver__c!=null &&(nextApprover == null || nextApprover.Level__c > approvalChain.Level__c) && approvalChain.Level__c > currentApproverLevel)  nextApprover = approvalChain;
                }
                if(nextApprover != null){
                    nextApprover.Status__c = 'Pending';
                    recordsToUpsert.add(nextApprover);
                }
                
                
                System.debug('nextApprover : ' + nextApprover);
                for(Sample_Request_Line_Item__c lineItem : lineItemList){
                    if(!lineItem.Is_Backup__c){
                        recordsToUpsert.add( new Approver_Comment__c(
                            Sample_Request_Line_Item__c = lineItem.Id,
                            Role__c = nextApprover.Role__c,
                            Approver_Name__c = nextApprover.Approver__c,
                            Approval_Status__c = 'Pending'));
                    }
                }  
            }
            else{
                recordsToUpsert.add(new Sample_Request_Header__c(
                    Id =headerId,
                    Approval_Status__c = 'Approved'));
                
            }
        }
        else{
            if(!lineItemList.isEmpty()){
                for(Approval_Chain__c approvalChain : approvalChainList){
                    if(approvalChain.Role__c == role){
                        currentApproverLevel = (Integer)approvalChain.Level__c;
                        currentApproverName = (String)approvalChain.Approver__r.Name;
                        currentApprovalChainId = approvalChain.Id;
                        approvalChain.Status__c = 'Approved';
                        recordsToUpsert.add(approvalChain);
                        
                        break;
                    }
                }
                for(Sample_Request_Line_Item__c lineItem : lineItemList){
                    if(lineItem.Approval_Status__c != 'Approved' && !lineItem.Is_Backup__c){
                        if(!mapOfApprovedQuantity.containsKey(lineItem.Product_Group__c))mapOfApprovedQuantity.put(lineItem.Product_Group__c,0);
                        lineItem.Approval_Status__c = 'Approved';
                        lineItem.Approved_On__c = Date.today();
                        mapOfApprovedQuantity.put(lineItem.Product_Group__c,mapOfApprovedQuantity.get(lineItem.Product_Group__c)+1);
                        recordsToUpsert.add(lineItem);                
                    }
                }
                recordsToUpsert.add(new Sample_Request_Header__c(
                    Id = headerId,
                    Approval_Status__c = 'Approved'
                ));
            }
        }
        if(!recordsToUpsert.isEmpty()){    
            Database.upsert(recordsToUpsert);
            sendMailAndNotification(headerId,currentApprovalChainId,userId,nextApprover != null && nextApprover.Approver__c != null ? nextApprover.Approver__c : null,!sentToNextApprover,role,currentApproverName,headerName,true);
            System.debug('currentApprovalChainId'+currentApprovalChainId);
            //if(!sentToNextApprover)  SampleOrderApprovalEmailBuilder.sendApprovalEmail(headerId);
            //sendMailAndNotification(headerId,currentApprovalChainId,userId,'0056F00000BgrE5QAJ',!sentToNextApprover,role,currentApproverName,headerName,true);
        }
    }
    
    public static void restoreLimitOnReject(List<Sample_Request_Line_Item__c> lineItemList,String role){
        List<sObject> recordsToUpsert = new List<sObject>();
        if(!lineItemList.isEmpty()){
            recordsToUpsert.add(new Sample_Request_Header__c(
                Id = lineItemList.get(0).Sample_Request_Header__c,
                Approval_Status__c = 'Rejected'
            ));
            for(Sample_Request_Line_Item__c lineItem : lineItemList){
                lineItem.Approval_Status__c = 'Rejected';
                recordsToUpsert.add(lineItem);
            }
            List<Approval_Chain__c> approvalChain = [SELECT Id,Approver__r.Name FROM Approval_Chain__c WHERE Sample_Request_Header__c =:lineItemList.get(0).Sample_Request_Header__c AND Role__c =: role LIMIT 1];
            if(!approvalChain.isEmpty()){
                recordsToUpsert.add(new Approval_Chain__c(
                    Id = approvalChain.get(0).Id,
                    Status__c = 'Rejected'));
            }
            if(!recordsToUpsert.isEmpty()) {
                Database.upsert(recordsToUpsert);
                sendMailAndNotification(lineItemList.get(0).Sample_Request_Header__c,approvalChain.get(0).Id,lineItemList.get(0).CreatedById,null,true,role,approvalChain.get(0).Approver__r.Name,lineItemList.get(0).Sample_Request_Header__r.Name,false);
                // sendMailAndNotification(lineItemList.get(0).Sample_Request_Header__c,approvalChain.get(0).Id,'0056F00000BgrE5QAJ',null,true,role,approvalChain.get(0).Approver__r.Name,lineItemList.get(0).Sample_Request_Header__r.Name,false);
                
            }
        }
    }
    public static void createApprovalChain(List<Org_Role_Hierarchy_Assignment__c> rhList,String country,String vertical,Id sampleHeaderId,List<Sample_Request_Line_Item__c> lineItemRecords,Id countryAdminId){
        Decimal lastLevel = 0;
        Org_Role_Hierarchy_Assignment__c roleHeirarchy = rhList[0];
        List<Approval_Level__c> approvalLevelList = [SELECT Level__c,Role__c,Approval_Limit__c,Priority__c FROM Approval_Level__c WHERE Approval_Configuration__r.Name =: country.toUpperCase() AND Approval_Configuration__r.Vertical__c =: vertical AND Approval_Configuration__r.Start_Date__c <=: Date.today() AND Approval_Configuration__r.End_Date__c >=: Date.today() ORDER BY Level__c ASC];
        List<Approval_Chain__c> approvalChainList = new List<Approval_Chain__c>();
        // User countryAdmin = [SELECT Id FROM User WHERE Country__c =: country AND Is_Country_Admin__c = TRUE LIMIT 1];
        // Map<String,String> mapOfRole = new Map<String,String>{'Regional Sales Manager'=>'RSM__c','Zonal Sales Manager'=>'ZSM__c','National Sales Manager'=>'NSM__c','General Manager'=>'GM__c','Divisional Manager'=>'DM__c','Global Sales Revenue Officer'=>'GSRO__c'};
        Map<String,String> mapOfRole = new Map<String,String>{'Business Development Nanager'=>'BDM__c','Product Manager'=>'PM__c', 'Cluster Manager'=>'CM__c', 'Divisional Manager'=>'DM__c', 'General Manager'=>'GM__c', 'Global Sales Revenue Officer'=>'GSRO__c', 'Key Account Manager'=>'KAM__c','National Sales Manager'=>'NSM__c', 'Refractive Manager'=>'RM__c', 'Regional Sales Manager'=>'RSM__c', 'Sales Account Executive'=>'SAE__c', 'Sales Development Executive'=>'SDE__c', 'Senior Sales Executive'=>'SSE__c', 'Tender Manager'=>'TM__c', 'Zonal Sales Manager'=>'ZSM__c'};  
            Map<String,Id> mapOfUser = new Map<String,Id>();
        
        for(Approval_Level__c level :approvalLevelList){
            String roleField = mapOfRole.get(level.Role__c);
            if(roleField == null) continue;
            
            Id approverId = (Id) roleHeirarchy.Org_Role_Hierarchy__r.get(roleField);
            mapOfUser.put(level.Role__c,approverId);
        }
        
        if(!approvalLevelList.isEmpty()){      
            for(Approval_Level__c approvalLevel : approvalLevelList){
                approvalChainList.add(new Approval_Chain__c(
                    Sample_Request_Header__c=sampleHeaderId,
                    Level__c=approvalLevel.Level__c,
                    Role__c=approvalLevel.Role__c,
                    Is_Active__c=true,
                    Approver__c= mapOfUser.containsKey(approvalLevel.Role__c) ? mapOfUser.get(approvalLevel.Role__c) : null,
                    Priority__c = approvalLevel.Priority__c,
                    Approval_Limit__c = approvalLevel.Approval_Limit__c,
                    Status__c = ''));
                lastLevel = approvalLevel.Level__c;
            }
        }
        approvalChainList.add(new Approval_Chain__c(
            Role__c = 'CMD',
            Sample_Request_Header__c=sampleHeaderId,
            Level__c=lastLevel+1,
            Is_Active__c=true,
            Approver__c = countryAdminId,
            Status__c = ''));
        if(!approvalChainList.isEmpty()) insert approvalChainList;
        SampleRequestApprovalProcess.createApprovalRecord(lineItemRecords,sampleHeaderId,null,true);
    }

    public static List<Approval_Chain__c> approvalChainVerify(List<Approval_Chain__c>  approvalChainList,Org_Role_Hierarchy_Assignment__c roleHeirarchy){
        Boolean toUpdate = false;
        //  Map<String,String> mapOfRole = new Map<String,String>{'Regional Sales Manager'=>'RSM__c','Zonal Sales Manager'=>'ZSM__c','National Sales Manager'=>'NSM__c','General Manager'=>'GM__c','Divisional Manager'=>'DM__c','Global Sales Revenue Officer'=>'GSRO__c'};
        Map<String,String> mapOfRole = new Map<String,String>{'Business Development Nanager'=>'BDM__c','Product Manager'=>'PM__c', 'Cluster Manager'=>'CM__c', 'Divisional Manager'=>'DM__c', 'General Manager'=>'GM__c', 'Global Sales Revenue Officer'=>'GSRO__c', 'Key Account Manager'=>'KAM__c','National Sales Manager'=>'NSM__c', 'Refractive Manager'=>'RM__c', 'Regional Sales Manager'=>'RSM__c', 'Sales Account Executive'=>'SAE__c', 'Sales Development Executive'=>'SDE__c', 'Senior Sales Executive'=>'SSE__c', 'Tender Manager'=>'TM__c', 'Zonal Sales Manager'=>'ZSM__c'};  
            Map<String,Id> mapOfUser = new Map<String,Id>();
        
        for(Approval_Chain__c level :approvalChainList){
            String roleField = mapOfRole.get(level.Role__c);
            if(roleField == null) continue;
            
            Id approverId = (Id) roleHeirarchy.Org_Role_Hierarchy__r.get(roleField);
            mapOfUser.put(level.Role__c,approverId);
            
        }
        if(!approvalChainList.isEmpty()){      
            for(Approval_Chain__c approvalChainRecord : approvalChainList){
                if(approvalChainRecord.Status__c != 'Approved' && approvalChainRecord.Role__c != 'CMD'){
                    if(mapOfUser.containsKey(approvalChainRecord.Role__c) && approvalChainRecord.Approver__c != mapOfUser.get(approvalChainRecord.Role__c)){
                        approvalChainRecord.Approver__c = mapOfUser.get(approvalChainRecord.Role__c);
                        toUpdate = true;
                    }else if(!mapOfUser.containsKey(approvalChainRecord.Role__c) && approvalChainRecord.Approver__c != null){
                        approvalChainRecord.Approver__c = null;
                        toUpdate = true; 
                    }
                }
            }
        }
        if(toUpdate) update approvalChainList;
        return approvalChainList;
    }
    
    public static void sendMailAndNotification(Id recordId,Id currentApprovalChainId,Id headerCreatedById,Id userId,Boolean IsApprovalProcessComplete,String role,String approverName,String headerName,Boolean isApproved) {
        String orgUrl = System.URL.getOrgDomainUrl().toExternalForm();
        String recordLink = orgUrl + '/' + recordId;
        List<String> listOfEmailTemplate= new List<String>();
        if(role != null && approverName != ''){
            listOfEmailTemplate.add('Sample_Request_Approved_Template');
        }
        if(!IsApprovalProcessComplete){
            listOfEmailTemplate.add('Sample_Request_Approval_Template');
        }
        List<EmailTemplate> emailTemplateList = [SELECT Id,Subject,DeveloperName FROM EmailTemplate WHERE DeveloperName IN:listOfEmailTemplate];
        OrgWideEmailAddress[] owea = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'crmhelpdesk@biotechhealthcare.com' LIMIT 1];
        List<Messaging.SingleEmailMessage> mailToSend = new List<Messaging.SingleEmailMessage>();
        
        if(listOfEmailTemplate.contains('Sample_Request_Approved_Template') && headerCreatedById != null){
            EmailTemplate emailTemplateForAction = new EmailTemplate();
            for(EmailTemplate template : emailTemplateList){
                if(template.DeveloperName == 'Sample_Request_Approved_Template'){
                    emailTemplateForAction = template;
                    break;
                }
            }
            if(emailTemplateForAction != null){
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setTemplateId(emailTemplateForAction.Id);
                mail.setTargetObjectId(headerCreatedById); 
                mail.setWhatId(currentApprovalChainId);
                mail.setSaveAsActivity(false);
                if (!owea.isEmpty()) {
                    mail.setOrgWideEmailAddressId(owea[0].Id);
                }
                mailToSend.add(mail);
            }
            
        }
        
        if(listOfEmailTemplate.contains('Sample_Request_Approval_Template') && userId != null){
            EmailTemplate emailTemplateForApproval = new EmailTemplate();
            for(EmailTemplate template : emailTemplateList){
                if(template.DeveloperName == 'Sample_Request_Approval_Template'){
                    emailTemplateForApproval = template;
                    break;
                }
            }
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setTemplateId(emailTemplateForApproval.Id);
            mail.setTargetObjectId(userId); 
            mail.setWhatId(recordId);
            mail.setSaveAsActivity(false);
            if (!owea.isEmpty()) {
                mail.setOrgWideEmailAddressId(owea[0].Id);
            }
            mailToSend.add(mail);
        }
        
        if(!mailToSend.isEmpty()) Messaging.sendEmail( mailToSend );
        
        CustomNotificationType notifType = [SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Sample_Header_Notification' LIMIT 1];
        if(!IsApprovalProcessComplete){
            
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle('Action Required: Sample Request');
            notification.setBody('A new sample request '+headerName+ ' has been submitted and is pending your approval. Please review and take action.');
            
            notification.setNotificationTypeId(notifType.Id);
            notification.setTargetId(recordId);
            
            notification.send(new Set<String>{ userId });
        }
        if(role != null && approverName != '' && headerCreatedById != null){
            Messaging.CustomNotification notification = new Messaging.CustomNotification();
            notification.setTitle(isApproved ? 'Sample Request Approved' : 'Sample Request Rejected');
            notification.setBody('Your sample request ' + headerName + ' has been ' + 
                                 (isApproved ? 'approved' : 'rejected') + 
                                 ' by ' + approverName + ' (' + role + ').' +
                                 (isApproved && !IsApprovalProcessComplete ? ' It has been forwarded for further approval.' : ''));
            
            notification.setNotificationTypeId(notifType.Id);
            notification.setTargetId(recordId);
            
            notification.send(new Set<String>{ headerCreatedById });
        }
    }
    
}