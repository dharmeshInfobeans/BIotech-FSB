public with sharing class RegulatoryActionController {

    public class RequestStatus {
        @AuraEnabled public String  requestId;
        @AuraEnabled public String  requestName;
        @AuraEnabled public String  status;
        @AuraEnabled public String  currentStage;
        @AuraEnabled public Boolean certificateUploaded;
        @AuraEnabled public String  basketId;
        @AuraEnabled public String  basketName;
        @AuraEnabled public String  basketStatus;
    }

    @AuraEnabled(cacheable=true)
    public static RequestStatus getRequestStatus(Id recordId) {
        Registration_Request__c rr = new ElevatedQuery().getRequest(recordId);
        List<Document_Basket__c> baskets = new ElevatedQuery().getBasket(rr.Id);

        RequestStatus rs         = new RequestStatus();
        rs.requestId             = rr.Id;
        rs.requestName           = rr.Name;
        rs.status                = rr.Status__c;
        rs.currentStage          = rr.Current_Stage__c;
        rs.certificateUploaded   = rr.Certificate_Uploaded__c;
        if (!baskets.isEmpty()) {
            rs.basketId     = baskets[0].Id;
            rs.basketName   = baskets[0].Name;
            rs.basketStatus = baskets[0].Status__c;
        }
        return rs;
    }

    // ── Start Regulatory Review ────────────────────────────────────────────────
    @AuraEnabled
    public static void startReview(Id recordId) {
        try {
            ElevatedQuery eq = new ElevatedQuery();
            Registration_Request__c rr = eq.getRequest(recordId);
            if (rr.Status__c != 'Submitted to Regulatory') {
                throw new AuraHandledException(
                    'Request must be Submitted to Regulatory before starting review.');
            }
            // Create Document Basket if it doesn't exist yet
            List<Document_Basket__c> existing = eq.getBasket(recordId);
            if (existing.isEmpty()) {
                eq.insertBasket(new Document_Basket__c(
                    Registration_Request__c = recordId,
                    Status__c               = 'Under Review',
                    Submission_Date__c      = Datetime.now()
                ));
            } else {
                Document_Basket__c b = existing[0];
                b.Status__c          = 'Under Review';
                b.Submission_Date__c = Datetime.now();
                eq.updateBasket(b);
            }
            eq.updateRequest(new Registration_Request__c(
                Id               = recordId,
                Status__c        = 'Under Regulatory Review',
                Current_Stage__c = 'Regulatory Processing'
            ));
            RegistrationApprovalHistoryService.log(
                recordId, 'Regulatory Review Started',
                'Submitted to Regulatory', 'Under Regulatory Review',
                null, 'Regulatory Processing'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Resume Review after distributor provides additional documents ──────────
    @AuraEnabled
    public static void resumeReview(Id recordId) {
        try {
            ElevatedQuery eq = new ElevatedQuery();
            Registration_Request__c rr = eq.getRequest(recordId);
            if (rr.Status__c != 'Additional Documents Requested'
                && rr.Status__c != 'Pending Customer Response') {
                throw new AuraHandledException(
                    'Request must be in Additional Documents Requested status to resume.');
            }
            eq.updateRequest(new Registration_Request__c(
                Id        = recordId,
                Status__c = 'Under Regulatory Review'
            ));
            updateBasketStatus(recordId, 'Under Review', null);
            RegistrationApprovalHistoryService.log(
                recordId, 'Regulatory Review Resumed',
                rr.Status__c, 'Under Regulatory Review',
                null, 'Regulatory Processing'
            );
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Save Forecast Week ────────────────────────────────────────────────────
    @AuraEnabled
    public static void saveForecastWeek(Id recordId, Integer weekNum, Integer yr) {
        try {
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id               = recordId,
                Forecast_Week__c = weekNum,
                Forecast_Year__c = yr
            ));
            RegistrationNotificationService.notifyFromApex(recordId, 'FORECAST_WEEK_UPDATED');
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Mark Registration as Completed ────────────────────────────────────────
    @AuraEnabled
    public static void markCompleted(Id recordId, String remarks) {
        try {
            ElevatedQuery eq = new ElevatedQuery();
            Registration_Request__c rr = eq.getRequestWithAccount(recordId);
            if (rr.Status__c != 'Under Regulatory Review') {
                throw new AuraHandledException(
                    'Request must be Under Regulatory Review to mark as Completed.');
            }
            Date today = Date.today();
            Integer completionWeek = (today.dayOfYear() - 1) / 7 + 1;
            Registration_Request__c updateRec = new Registration_Request__c(
                Id                       = recordId,
                Status__c                = 'Completed',
                Current_Stage__c         = 'Completed',
                Actual_Completion_Week__c = completionWeek,
                Actual_Completion_Year__c = today.year()
            );
            eq.updateRequest(updateRec);
            updateBasketStatus(recordId, 'Approved', remarks);

            List<Registration_Request_Product__c> products = eq.getProductsForRequest(recordId);
            List<Registration_Request_Product__c> prodUpdates = new List<Registration_Request_Product__c>();
            for (Registration_Request_Product__c p : products) {
                prodUpdates.add(new Registration_Request_Product__c(
                    Id                    = p.Id,
                    Certificate_Status__c = 'Pending Upload'
                ));
            }
            if (!prodUpdates.isEmpty()) {
                eq.updateProducts(prodUpdates);
            }

            RegistrationApprovalHistoryService.log(
                recordId, 'Registration Completed',
                'Under Regulatory Review', 'Completed',
                remarks, 'Regulatory Processing'
            );
            RegistrationNotificationService.notifyFromApex(recordId, 'COMPLETED');
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Mark Certificate Uploaded ─────────────────────────────────────────────
    @AuraEnabled
    public static void markCertificateUploaded(Id recordId) {
        try {
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id                      = recordId,
                Certificate_Uploaded__c = true
            ));
            RegistrationApprovalHistoryService.log(
                recordId, 'Registration Certificate Uploaded',
                null, null, null, 'Regulatory Processing'
            );
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Reset certificate (delete file + clear flag) ─────────────────────────
    @AuraEnabled
    public static void resetCertificateUploaded(Id recordId, Id contentDocumentId) {
        try {
            ElevatedQuery eq = new ElevatedQuery();
            if (contentDocumentId != null) {
                eq.deleteDoc(new ContentDocument(Id = contentDocumentId));
            }
            eq.updateRequest(new Registration_Request__c(
                Id                      = recordId,
                Certificate_Uploaded__c = false
            ));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Delete an uploaded document ───────────────────────────────────────────
    @AuraEnabled
    public static void deleteDocument(Id contentDocumentId) {
        try {
            new ElevatedQuery().deleteDoc(new ContentDocument(Id = contentDocumentId));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Link uploaded doc to a product+docType slot on Request_Document__c ──────
    @AuraEnabled
    public static void linkDocumentToSlot(Id requestId, String productName, String docType, String contentDocumentId) {
        try {
            new ElevatedWriter().linkSlot(requestId, productName, docType, contentDocumentId);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Update RA Remarks on basket ────────────────────────────────────────────
    @AuraEnabled
    public static void updateRARemarks(Id basketId, String remarks) {
        try {
            new ElevatedQuery().updateBasket(new Document_Basket__c(
                Id            = basketId,
                RA_Remarks__c = remarks
            ));
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Reject Registration Request ───────────────────────────────────────────
    @AuraEnabled
    public static void rejectRegistrationRequest(Id requestId, String comments) {
        try {
            if (String.isBlank(comments)) {
                throw new AuraHandledException('A reason is required when rejecting a request.');
            }
            ElevatedQuery eq = new ElevatedQuery();
            Registration_Request__c rr = eq.getRequest(requestId);
            if (rr.Status__c == 'Rejected' || rr.Status__c == 'Completed') {
                throw new AuraHandledException('This request cannot be rejected in its current state.');
            }
            eq.updateRequest(new Registration_Request__c(
                Id                    = requestId,
                Status__c             = 'Rejected',
                Current_Stage__c      = 'Rejected',
                Rejection_Comments__c = comments
            ));
            updateBasketStatus(requestId, 'Rejected', null);
            RegistrationApprovalHistoryService.log(
                requestId, 'Request Rejected by Regulatory Team',
                rr.Status__c, 'Rejected',
                comments, 'Regulatory Processing'
            );
            RegistrationNotificationService.notifyFromApex(requestId, 'REJECTED');
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Return Registration Request to Distributor ────────────────────────────
    @AuraEnabled
    public static void returnRegistrationRequest(Id requestId, String comments) {
        try {
            if (String.isBlank(comments)) {
                throw new AuraHandledException('A comment is required when returning a request.');
            }
            ElevatedQuery eq = new ElevatedQuery();
            Registration_Request__c rr = eq.getRequest(requestId);
            if (rr.Status__c == 'Sent Back' || rr.Status__c == 'Completed' || rr.Status__c == 'Rejected') {
                throw new AuraHandledException('This request cannot be returned in its current state.');
            }
            eq.updateRequest(new Registration_Request__c(
                Id                    = requestId,
                Status__c             = 'Sent Back',
                Rejection_Comments__c = comments
            ));
            updateBasketStatus(requestId, 'Documents Submitted', null);
            RegistrationApprovalHistoryService.log(
                requestId, 'Request Returned to Distributor',
                rr.Status__c, 'Sent Back',
                comments, 'Regulatory Processing'
            );
            RegistrationNotificationService.notifyFromApex(requestId, 'SENT_BACK');
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Return Additional Document Request to Distributor ─────────────────────
    @AuraEnabled
    public static void returnAdditionalRequest(Id childRequestId, String comments) {
        try {
            if (String.isBlank(comments)) {
                throw new AuraHandledException('A comment is required when returning a request.');
            }
            ElevatedQuery eq = new ElevatedQuery();
            Registration_Request__c rr = eq.getRequest(childRequestId);
            if (rr.Status__c == 'Sent Back' || rr.Status__c == 'Completed' || rr.Status__c == 'Rejected') {
                throw new AuraHandledException('This request cannot be returned in its current state.');
            }
            eq.updateRequest(new Registration_Request__c(
                Id                    = childRequestId,
                Status__c             = 'Sent Back',
                Rejection_Comments__c = comments
            ));
            RegistrationApprovalHistoryService.log(
                childRequestId, 'Additional Request Returned to Distributor',
                rr.Status__c, 'Sent Back',
                comments, 'Regulatory Processing'
            );
            RegistrationNotificationService.notifyFromApex(childRequestId, 'SENT_BACK');
        } catch (AuraHandledException ahe) {
            throw ahe;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Private: update basket status ─────────────────────────────────────────
    private static void updateBasketStatus(Id requestId, String newStatus, String raRemarks) {
        updateBasketStatus(requestId, newStatus, raRemarks, null);
    }

    private static void updateBasketStatus(Id requestId, String newStatus, String raRemarks, Date dueDate) {
        ElevatedQuery eq = new ElevatedQuery();
        List<Document_Basket__c> baskets = eq.getBasket(requestId);
        if (baskets.isEmpty()) return;
        Document_Basket__c b = baskets[0];
        b.Status__c = newStatus;
        if (String.isNotBlank(raRemarks)) b.RA_Remarks__c = raRemarks;
        if (dueDate != null) b.Due_Date__c = dueDate;
        if (newStatus == 'Documents Submitted' || newStatus == 'Under Review') {
            b.Submission_Date__c = Datetime.now();
        }
        if (newStatus == 'Approved') {
            b.Approved_Date__c = Datetime.now();
        }
        eq.updateBasket(b);
    }

    // ── Update Valid From / Valid To ───────────────────────────────────────────
    @AuraEnabled
    public static void updateValidDates(Id requestId, String validFromDate, String validToDate) {
        try {
            Date fromDate = Date.valueOf(validFromDate);
            Date toDate   = Date.valueOf(validToDate);
            if (toDate <= fromDate) {
                throw new AuraHandledException('Valid To must be after Valid From.');
            }
            new ElevatedQuery().updateRequest(new Registration_Request__c(
                Id                        = requestId,
                Certificate_Valid_From__c = fromDate,
                Certificate_Valid_To__c   = toDate
            ));
        } catch (AuraHandledException e) {
            throw e;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    // ── Without-sharing inner class — all DML goes through here ───────────────
    private without sharing class ElevatedQuery {
        public Registration_Request__c getRequest(Id recordId) {
            return [
                SELECT Id, Name, Status__c, Current_Stage__c, Certificate_Uploaded__c
                FROM   Registration_Request__c
                WHERE  Id = :recordId LIMIT 1
            ];
        }
        public Registration_Request__c getRequestWithAccount(Id recordId) {
            return [
                SELECT Id, Name, Status__c, Current_Stage__c, Certificate_Uploaded__c, Account__c
                FROM   Registration_Request__c
                WHERE  Id = :recordId LIMIT 1
            ];
        }
        public List<Document_Basket__c> getBasket(Id requestId) {
            return [
                SELECT Id, Name, Status__c, RA_Remarks__c
                FROM   Document_Basket__c
                WHERE  Registration_Request__c = :requestId
                ORDER BY CreatedDate DESC LIMIT 1
            ];
        }
        public List<Registration_Request_Product__c> getProductsForRequest(Id requestId) {
            return [
                SELECT Id FROM Registration_Request_Product__c
                WHERE  Registration_Request__c = :requestId
            ];
        }
        public void updateRequest(Registration_Request__c rec) { update rec; }
        public void updateBasket(Document_Basket__c rec)       { update rec; }
        public void insertBasket(Document_Basket__c rec)       { insert rec; }
        public void deleteDoc(ContentDocument doc)             { delete doc; }
        public void updateProducts(List<Registration_Request_Product__c> recs) { update recs; }
    }

    private without sharing class ElevatedWriter {
        public void linkSlot(Id requestId, String productName, String docType, String contentDocumentId) {
            List<Request_Document__c> docs = [
                SELECT Id
                FROM   Request_Document__c
                WHERE  Registration_Request_Product__r.Registration_Request__c = :requestId
                AND    Registration_Request_Product__r.Product__r.Name         = :productName
                AND    Document_Type__c                                        = :docType
                LIMIT  1
            ];
            if (docs.isEmpty()) return;
            docs[0].Uploaded_Document_Id__c = contentDocumentId;
            update docs[0];
        }
    }
}