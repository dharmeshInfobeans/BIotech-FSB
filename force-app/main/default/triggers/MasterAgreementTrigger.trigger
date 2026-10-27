trigger MasterAgreementTrigger on Master_Agreement__c (before insert, before update, after update) {
    String MasterAgreementTriggerIsActiveLabel = System.label.MasterAgreementTriggerIsActiveLabel;
    
    if (Trigger.isBefore) {
        for (Master_Agreement__c ma : Trigger.new) {
            if (Trigger.isInsert) {
                // Always set on insert
                ma.Agreement_Signed_With__c = ma.Agreement_Signed_With_picklist__c;
                MasterAgreementHelper.generateAgreementNumbers(Trigger.new);
                
                
                
            } else if (Trigger.isUpdate) {
                Master_Agreement__c oldMa = Trigger.oldMap.get(ma.Id);
                
                // Only set if the value actually changed
                if (ma.Agreement_Signed_With_picklist__c != oldMa.Agreement_Signed_With_picklist__c) {
                    ma.Agreement_Signed_With__c = ma.Agreement_Signed_With_picklist__c;
                }
                //only if Agreement is marked as isActive
                if (ma.Is_Active__c != oldMa.Is_Active__c && ma.Is_Active__c == true) {
                    
                    if (String.isNotEmpty(ma.Cloned_From__c) && String.isNotEmpty(oldMa.Renewed_From__c)) {
                    //only one of above 2 filed should ahve refrance to another master agreement either cloned from or renewed from.
                        ma.addError('Contact your admin to resolve this issue in "Duplicate Master Agreement For Same Vertical Error Alert Flow".');
                    } else {
                        Id refId = ma.Cloned_From__c != null ? ma.Cloned_From__c : ma.Renewed_From__c;
                        
                        if (refId != null) {
                            try {
                                Master_Agreement__c previousActiveAgreement = [
                                    SELECT Id, Agreement_Signed_With__c
                                    FROM Master_Agreement__c
                                    WHERE Id = :refId
                                ];
                                
                                if (ma.Agreement_Signed_With__c != previousActiveAgreement.Agreement_Signed_With__c) {
                                    ma.Agreement_Signed_With_Is_Changed__c = true;
                                }
                            } catch (Exception e) {
                                // Log the error if needed or surface a generic message
                                ma.addError('Error while validating the previous Master Agreement. Please contact support.');
                            }
                        }
                    }
                }
                
                
            }
        }
    }
    
    if (Trigger.isAfter && Trigger.isUpdate && MasterAgreementTriggerIsActiveLabel == 'true') {
        System.debug('processAgreementUpdates');
        //this code will no cover in test coverag unless you set MasterAgreementTriggerIsActiveLabel as true
        MasterAgreementHelper.processAgreementUpdates(Trigger.new, Trigger.oldMap);
    }
}