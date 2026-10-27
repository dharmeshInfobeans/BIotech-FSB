public with sharing class FunctionalHeadActionController {

    private without sharing class ElevatedQuery {
        public Registration_Request__c fetchRequest(Id recordId) {
            List<Registration_Request__c> rows = [
                SELECT Id, Name, Status__c, Current_Stage__c
                FROM   Registration_Request__c
                WHERE  Id = :recordId LIMIT 1
            ];
            return rows.isEmpty() ? null : rows[0];
        }
        public void updateRequest(Registration_Request__c rec) { update rec; }
    }

    // ── Approve — moves to Leadership queue ───────────────────────────────────
    @AuraEnabled
    public static void approveRequest(Id recordId) {
        try {
            Registration_Request__c rr = new ElevatedQuery().fetchRequest(recordId);
            if (rr == null) throw new AuraHandledException('Request not found.');
            if (rr.Status__c != 'Under Functional Head Review') {
                throw new AuraHandledException(
                    'Request must be Under Functional Head Review to approve.');
            }
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id                           = recordId,
                Status__c                    = 'Submitted',
                Current_Stage__c             = 'Leadership Review',
                Functional_Head_Approved__c  = true
            ));
            RegistrationNotificationService.notifyFromApex(recordId, 'FUNCTIONAL_HEAD_APPROVED');
            RegistrationApprovalHistoryService.log(
                recordId, 'Approved by Functional Head',
                'Under Functional Head Review', 'Submitted',
                null, 'Functional Head Review'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Send Back to Distributor ───────────────────────────────────────────────
    @AuraEnabled
    public static void sendBack(Id recordId, String comments) {
        try {
            if (String.isBlank(comments)) {
                throw new AuraHandledException('Reason for sending back is required.');
            }
            Registration_Request__c rr = new ElevatedQuery().fetchRequest(recordId);
            if (rr == null) throw new AuraHandledException('Request not found.');
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id                    = recordId,
                Status__c             = 'Sent Back',
                Current_Stage__c      = 'Distributor Submission',
                Rejection_Comments__c = comments
            ));
            RegistrationNotificationService.notifyFromApex(recordId, 'SENT_BACK');
            RegistrationApprovalHistoryService.log(
                recordId, 'Sent Back to Distributor',
                'Under Functional Head Review', 'Sent Back',
                comments, 'Functional Head Review'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Reject ────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static void rejectRequest(Id recordId, String comments) {
        try {
            if (String.isBlank(comments)) {
                throw new AuraHandledException('Rejection reason is required.');
            }
            Registration_Request__c rr = new ElevatedQuery().fetchRequest(recordId);
            if (rr == null) throw new AuraHandledException('Request not found.');
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id                    = recordId,
                Status__c             = 'Rejected',
                Rejection_Comments__c = comments
            ));
            RegistrationNotificationService.notifyFromApex(recordId, 'REJECTED');
            RegistrationApprovalHistoryService.log(
                recordId, 'Request Rejected',
                'Under Functional Head Review', 'Rejected',
                comments, 'Functional Head Review'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}