public with sharing class RegistrationApprovalController {

    public class RequestInfo {
        @AuraEnabled public Id     recordId;
        @AuraEnabled public String status;
        @AuraEnabled public String currentStage;
        @AuraEnabled public String name;
    }

    // Elevated read + write — OWD is Private; CRM/Leadership users are not always the record owner
    private without sharing class ElevatedQuery {
        public Registration_Request__c fetchRequest(Id recordId) {
            List<Registration_Request__c> rows = [
                SELECT Id, Name, Status__c, Current_Stage__c
                FROM   Registration_Request__c
                WHERE  Id = :recordId
                LIMIT  1
            ];
            return rows.isEmpty() ? null : rows[0];
        }
        public void updateRequest(Registration_Request__c rec) {
            update rec;
        }
    }

    @AuraEnabled
    public static RequestInfo getRequestInfo(Id recordId) {
        if (recordId == null) return null;
        Registration_Request__c rr = new ElevatedQuery().fetchRequest(recordId);
        if (rr == null) return null;
        RequestInfo info    = new RequestInfo();
        info.recordId       = rr.Id;
        info.name           = rr.Name;
        info.status         = rr.Status__c;
        info.currentStage   = rr.Current_Stage__c;
        return info;
    }

    // ── CRM: forward to Leadership for initial review ──────────────────────────
    @AuraEnabled
    public static void forwardToLeadership(Id recordId) {
        try {
            Registration_Request__c rr = new ElevatedQuery().fetchRequest(recordId);
            if (rr == null) throw new AuraHandledException('Request not found.');
            String fromStatus = rr.Status__c;
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id        = recordId,
                Status__c = 'Under Leadership Review'
            ));
            RegistrationNotificationService.notifyFromApex(recordId, 'LEADERSHIP_REVIEW');
            RegistrationApprovalHistoryService.log(
                recordId,
                'Forwarded to Leadership',
                fromStatus,
                'Under Leadership Review',
                null,
                'CRM Review'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Legacy alias ───────────────────────────────────────────────────────────
    @AuraEnabled
    public static void approveRequest(Id recordId) {
        processApproval(recordId);
    }

    // ── Leadership approval — directly submits to Regulatory in one step ─────
    @AuraEnabled
    public static void processApproval(Id recordId) {
        try {
            Registration_Request__c rr = new ElevatedQuery().fetchRequest(recordId);
            if (rr == null) throw new AuraHandledException('Request not found.');

            if (rr.Status__c == 'Submitted' || rr.Status__c == 'Under Leadership Review') {
                new ElevatedQuery().updateRequest(new Registration_Request__c(
                    Id               = recordId,
                    Status__c        = 'Submitted to Regulatory',
                    Current_Stage__c = 'Regulatory Processing'
                ));
                RegistrationNotificationService.notifyFromApex(recordId, 'SUBMITTED_TO_REGULATORY');
                RegistrationApprovalHistoryService.log(
                    recordId,
                    'Approved & Submitted to Regulatory',
                    rr.Status__c,
                    'Submitted to Regulatory',
                    null,
                    'Leadership Review'
                );
            } else {
                throw new AuraHandledException(
                    'Cannot approve from current status: ' + rr.Status__c);
            }
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Submit to Regulatory (after full Leadership/Management approval) ────────
    @AuraEnabled
    public static void submitToRegulatory(Id recordId) {
        try {
            Registration_Request__c rr = new ElevatedQuery().fetchRequest(recordId);
            if (rr == null) throw new AuraHandledException('Request not found.');
            if (rr.Status__c != 'Approved by Leadership') {
                throw new AuraHandledException(
                    'Request must be Approved by Leadership before submitting to Regulatory.');
            }
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id               = recordId,
                Status__c        = 'Submitted to Regulatory',
                Current_Stage__c = 'Regulatory Processing'
            ));
            RegistrationNotificationService.notifyFromApex(recordId, 'SUBMITTED_TO_REGULATORY');
            RegistrationApprovalHistoryService.log(
                recordId,
                'Submitted to Regulatory',
                'Approved by Leadership',
                'Submitted to Regulatory',
                null,
                'Regulatory Processing'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Send Back to Distributor (mandatory comments) ──────────────────────────
    @AuraEnabled
    public static void sendBack(Id recordId, String comments) {
        try {
            if (String.isBlank(comments)) {
                throw new AuraHandledException('Reason for sending back is required.');
            }
            Registration_Request__c rr = new ElevatedQuery().fetchRequest(recordId);
            if (rr == null) throw new AuraHandledException('Request not found.');
            String fromStatus = rr.Status__c;
            String fromStage  = String.isNotBlank(rr.Current_Stage__c) ? rr.Current_Stage__c : 'Leadership Review';
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id                    = recordId,
                Status__c             = 'Sent Back',
                Rejection_Comments__c = comments
            ));
            RegistrationNotificationService.notifyFromApex(recordId, 'SENT_BACK');
            RegistrationApprovalHistoryService.log(
                recordId,
                'Sent Back to Distributor',
                fromStatus,
                'Sent Back',
                comments,
                fromStage
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Reject (mandatory comments) ────────────────────────────────────────────
    @AuraEnabled
    public static void rejectRequest(Id recordId, String comments) {
        try {
            if (String.isBlank(comments)) {
                throw new AuraHandledException('Rejection reason is required.');
            }
            Registration_Request__c rr = new ElevatedQuery().fetchRequest(recordId);
            if (rr == null) throw new AuraHandledException('Request not found.');
            String fromStatus = rr.Status__c;
            String fromStage  = String.isNotBlank(rr.Current_Stage__c) ? rr.Current_Stage__c : 'Leadership Review';
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id                    = recordId,
                Status__c             = 'Rejected',
                Rejection_Comments__c = comments
            ));
            RegistrationNotificationService.notifyFromApex(recordId, 'REJECTED');
            RegistrationApprovalHistoryService.log(
                recordId,
                'Request Rejected',
                fromStatus,
                'Rejected',
                comments,
                fromStage
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── On Hold ────────────────────────────────────────────────────────────────
    @AuraEnabled
    public static void setOnHold(Id recordId) {
        try {
            Registration_Request__c rr = new ElevatedQuery().fetchRequest(recordId);
            if (rr == null) throw new AuraHandledException('Request not found.');
            String fromStatus = rr.Status__c;
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id        = recordId,
                Status__c = 'On Hold'
            ));
            RegistrationApprovalHistoryService.log(
                recordId,
                'Placed On Hold',
                fromStatus,
                'On Hold',
                null,
                'Leadership Review'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Resume from On Hold (returns to Submitted for CRM to re-route) ─────────
    @AuraEnabled
    public static void resumeFromHold(Id recordId) {
        try {
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id        = recordId,
                Status__c = 'Submitted'
            ));
            RegistrationApprovalHistoryService.log(
                recordId,
                'Resumed from On Hold',
                'On Hold',
                'Submitted',
                null,
                'CRM Review'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Re-submit a Sent Back request to Leadership ────────────────────────────
    @AuraEnabled
    public static void resubmitToLeadership(Id recordId) {
        try {
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id        = recordId,
                Status__c = 'Under Leadership Review'
            ));
            RegistrationNotificationService.notifyFromApex(recordId, 'LEADERSHIP_REVIEW');
            RegistrationApprovalHistoryService.log(
                recordId,
                'Re-submitted to Leadership',
                'Sent Back',
                'Under Leadership Review',
                null,
                'CRM Review'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
}