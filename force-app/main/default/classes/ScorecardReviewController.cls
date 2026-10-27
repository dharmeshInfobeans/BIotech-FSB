/**
 * Controller class for Scorecard Review Component
 * Handles fetching submission details and approve/reject operations
 */
public without sharing class ScorecardReviewController {
    
    /**
     * Get Scorecard Submission Details with all Answers
     * Used to display submission review
     * 
     * @param submissionId - Scorecard_Submission__c record ID
     * @return SubmissionReviewWrapper - Complete submission data with answers
     */
    @AuraEnabled
    public static SubmissionReviewWrapper getSubmissionDetails(String submissionId) {
        try {
            if (String.isBlank(submissionId)) {
                throw new AuraHandledException('Submission ID is required');
            }
            
            // Get Submission record
            List<Scorecard_Submission__c> submissions = [
                SELECT Id, Name, Scorecard_Lead__c, Scorecard_Lead__r.Name, Scorecard_Lead__r.City__c,
                       Status__c, Total_Score__c, Smart_Form_Data__c, CreatedDate,
                       CreatedBy.Name, LastModifiedDate, Approver_1__c, Approver_2__c,
                       Status_Approver_1__c, Status_Approver_2__c
                FROM Scorecard_Submission__c 
                WHERE Id = :submissionId 
                LIMIT 1
            ];
            
            if (submissions.isEmpty()) {
                throw new AuraHandledException('Submission not found');
            }
            
            Scorecard_Submission__c submission = submissions[0];
            
            // Get all Answer records
            List<Scorecard_Answer__c> answers = [
                SELECT Id, Question_Key_c__c, Sec_Category__c, Ans_Option_Key__c,
                       Score__c, Weighted_Score__c, AnswerText__c, CreatedDate
                FROM Scorecard_Answer__c 
                WHERE Scorecard_Submission__c = :submissionId
                ORDER BY CreatedDate ASC
            ];
            
            // Get metadata for questions and sections
            Map<String, Scorecard_Question__mdt> questionMap = Scorecard_Question__mdt.getAll();
            Map<String, Scorecard_Section__mdt> sectionMap = Scorecard_Section__mdt.getAll();
            Map<String, Scorecard_Ans_Option__mdt> optionMap = Scorecard_Ans_Option__mdt.getAll();
            system.debug('Option Map Size: ' + optionMap);
            // Parse JSON data if available
            Map<String, Object> jsonData = new Map<String, Object>();
            Map<String, Object> jsonAnswersMap = new Map<String, Object>();
            if (String.isNotBlank(submission.Smart_Form_Data__c)) {
                try {
                    // Clean the JSON string to remove HTML entities and malformed content
                    String cleanedJsonString = cleanJsonString(submission.Smart_Form_Data__c);
                    jsonData = (Map<String, Object>) JSON.deserializeUntyped(cleanedJsonString);
                    // Extract answers array from JSON
                    if (jsonData.containsKey('answers') && jsonData.get('answers') instanceof List<Object>) {
                        List<Object> jsonAnswers = (List<Object>) jsonData.get('answers');
                        system.debug('JSON Answers Size: ' + jsonAnswers.size());
                        for (Object jsonAnswerObj : jsonAnswers) {
                            if (jsonAnswerObj instanceof Map<String, Object>) {
                                Map<String, Object> jsonAnswer = (Map<String, Object>) jsonAnswerObj;
                                String qKey = (String) jsonAnswer.get('questionKey');
                                if (String.isNotBlank(qKey)) {
                                    jsonAnswersMap.put(qKey, jsonAnswer);
                                }
                            }
                        }
                    }
                } catch (Exception e) {
                    system.debug('Error parsing JSON: ' + e.getMessage());
                    system.debug('Stack Trace: ' + e.getStackTraceString());
                }
            }
            
            // Build wrapper
            SubmissionReviewWrapper wrapper = new SubmissionReviewWrapper();
            wrapper.submissionId = submission.Id;
            wrapper.submissionName = submission.Name;
            wrapper.leadId = submission.Scorecard_Lead__c;
            wrapper.leadName = submission.Scorecard_Lead__r != null ? submission.Scorecard_Lead__r.Name : '';
            wrapper.city = submission.Scorecard_Lead__r != null && submission.Scorecard_Lead__r.City__c != null ? submission.Scorecard_Lead__r.City__c : '';
            wrapper.status = submission.Status__c;
            wrapper.totalScore = submission.Total_Score__c;
            wrapper.createdDate = submission.CreatedDate;
            wrapper.createdBy = submission.CreatedBy != null ? submission.CreatedBy.Name : '';
            wrapper.lastModifiedDate = submission.LastModifiedDate;
            wrapper.approver1Id = submission.Approver_1__c;
            wrapper.approver2Id = submission.Approver_2__c;
            wrapper.statusApprover1 = submission.Status_Approver_1__c;
            wrapper.statusApprover2 = submission.Status_Approver_2__c;
            wrapper.currentUserId = UserInfo.getUserId();
            wrapper.jsonData = jsonData;
            
            // Build answer wrappers with answer text from JSON
            List<AnswerReviewWrapper> answerWrappers = new List<AnswerReviewWrapper>();
            Map<String, Decimal> sectionWeightages = new Map<String, Decimal>();
            
            for (Scorecard_Answer__c answer : answers) {
                AnswerReviewWrapper answerWrapper = new AnswerReviewWrapper();
                answerWrapper.answerId = answer.Id;
                answerWrapper.questionKey = answer.Question_Key_c__c;
                answerWrapper.sectionKey = answer.Sec_Category__c;
                answerWrapper.selectedOptions = answer.Ans_Option_Key__c != null ? 
                    answer.Ans_Option_Key__c.split(';') : new List<String>();
                answerWrapper.score = answer.Score__c != null ? answer.Score__c : 0;
                answerWrapper.weightedScore = answer.Weighted_Score__c != null ? answer.Weighted_Score__c : 0;
                
                // Get question label from metadata
                Scorecard_Question__mdt question = questionMap.get(answer.Question_Key_c__c);
                if (question != null) {
                    answerWrapper.questionLabel = question.Label;
                    answerWrapper.questionText = question.QuestionText__c;
                    answerWrapper.questionType = question.Question_Type__c;
                }
                
                // Get section label and weightage from metadata
                Scorecard_Section__mdt section = sectionMap.get(answer.Sec_Category__c);
                if (section != null) {
                    answerWrapper.sectionLabel = section.Label;
                    answerWrapper.sectionWeightage = section.Weightage__c;
                    sectionWeightages.put(answer.Sec_Category__c, section.Weightage__c);
                }
                
                // Get Answer Text directly from AnswerText__c field on Scorecard_Answer__c
                List<String> optionAnswerTexts = new List<String>();
                
                // Check if JSON has ifYesCount for this question
                Boolean hasIfYesCount = false;
                String ifYesCountValue = null;
                
                Object jsonAnswerObj = jsonAnswersMap.get(answer.Question_Key_c__c);
                if (jsonAnswerObj != null && jsonAnswerObj instanceof Map<String, Object>) {
                    Map<String, Object> jsonAnswer = (Map<String, Object>) jsonAnswerObj;
                    if (jsonAnswer.containsKey('ifYesCount')) {
                        Object ifYesCountObj = jsonAnswer.get('ifYesCount');
                        if (ifYesCountObj != null) {
                            ifYesCountValue = String.valueOf(ifYesCountObj).trim();
                            if (String.isNotBlank(ifYesCountValue) && ifYesCountValue != 'null' && ifYesCountValue != '') {
                                hasIfYesCount = true;
                                system.debug('Found ifYesCount for question ' + answer.Question_Key_c__c + ': ' + ifYesCountValue);
                            }
                        }
                    }
                }
                
                // Priority: Use ifYesCount if available, otherwise use AnswerText__c, then fallback to metadata
                if (hasIfYesCount && String.isNotBlank(ifYesCountValue)) {
                    // Replace answer text with "Yes : {count}" format with better spacing
                    optionAnswerTexts.add('Yes : ' + ifYesCountValue);
                    system.debug('Using ifYesCount for question ' + answer.Question_Key_c__c + ': Yes : ' + ifYesCountValue);
                } else if (String.isNotBlank(answer.AnswerText__c)) {
                    // Split by semicolon to handle multiple answers (for multi-select questions)
                    optionAnswerTexts = answer.AnswerText__c.split(';');
                    // Trim whitespace from each answer text
                    for (Integer i = 0; i < optionAnswerTexts.size(); i++) {
                        optionAnswerTexts[i] = optionAnswerTexts[i].trim();
                    }
                } else {
                    // Fallback: If AnswerText__c is blank, try to get from metadata
                    if (answerWrapper.selectedOptions != null && !answerWrapper.selectedOptions.isEmpty()) {
                        for (String optionKey : answerWrapper.selectedOptions) {
                            Scorecard_Ans_Option__mdt option = optionMap.get(optionKey);
                            if (option != null) {
                                if (String.isNotBlank(option.Answer__c)) {
                                    optionAnswerTexts.add(option.Answer__c);
                                } else if (String.isNotBlank(option.Label)) {
                                    optionAnswerTexts.add(option.Label);
                                } else {
                                    optionAnswerTexts.add(optionKey);
                                }
                            } else {
                                optionAnswerTexts.add(optionKey);
                            }
                        }
                    }
                }
                
                answerWrapper.selectedOptionLabels = optionAnswerTexts;
                
                answerWrappers.add(answerWrapper);
            }
            
            wrapper.answers = answerWrappers;
            wrapper.sectionWeightages = sectionWeightages;
            
            return wrapper;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching submission details: ' + e.getMessage());
        }
    }

    /**
     * Approve Scorecard Submission
     * 
     * @param submissionId - Scorecard_Submission__c record ID
     * @param comment - Approval comment
     * @param approverId - User ID who is approving (optional)
     * @return String - Updated submission ID
     */
    @AuraEnabled
    public static String approveSubmission(String submissionId, String comment, String approverId) {
        try {
            if (String.isBlank(submissionId)) {
                throw new AuraHandledException('Submission ID is required');
            }
            
            Scorecard_Submission__c submission = [
                SELECT Id, Name, Status__c, Approver_1__c, Approver_2__c, Approval_History_Data__c, Total_Score__c,
                       Status_Approver_1__c, Status_Approver_2__c
                FROM Scorecard_Submission__c 
                WHERE Id = :submissionId 
                LIMIT 1
            ];
            
            // Set approver if provided
            String currentUserId = String.isNotBlank(approverId) ? approverId : UserInfo.getUserId();
            
            // Parse existing approval history JSON data and migrate to rounds structure if needed
            Map<String, Object> approvalHistoryData = parseApprovalHistoryData(submission.Approval_History_Data__c);
            approvalHistoryData = migrateToRoundsStructure(approvalHistoryData);
            
            // Get current round and approver data from current round
            Map<String, Object> currentRound = getCurrentRound(approvalHistoryData);
            Map<String, Object> approver1Data = getApproverDataFromCurrentRound(approvalHistoryData, 'approver1');
            Map<String, Object> approver2Data = getApproverDataFromCurrentRound(approvalHistoryData, 'approver2');
            
            // Determine which approver is approving
            Boolean isApprover1 = (submission.Approver_1__c != null && submission.Approver_1__c == currentUserId);
            Boolean isApprover2 = (submission.Approver_2__c != null && submission.Approver_2__c == currentUserId);
            
            // If approver fields are not set, assign them
            if (submission.Approver_1__c == null) {
                submission.Approver_1__c = currentUserId;
                isApprover1 = true;
            } else if (submission.Approver_2__c == null && submission.Approver_1__c != currentUserId) {
                submission.Approver_2__c = currentUserId;
                isApprover2 = true;
            }
            
            // Check if approver has already made a decision in the current round
            // Note: In a new round (after Approver 2 rejects), approvers can review again
            if (isApprover1) {
                // Check status in current round only (previous rounds are preserved, but allow new review)
                String approver1StatusFromJson = approver1Data.containsKey('status') ? (String) approver1Data.get('status') : null;
                // Only prevent if they've already approved or rejected in THIS round
                if (approver1StatusFromJson == 'Approved' || approver1StatusFromJson == 'Rejected') {
                    throw new AuraHandledException('You have already ' + approver1StatusFromJson.toLowerCase() + ' this submission in the current round. You cannot approve or reject it again.');
                }
            } else if (isApprover2) {
                // Check status in current round only
                String approver2StatusFromJson = approver2Data.containsKey('status') ? (String) approver2Data.get('status') : null;
                // Only prevent if they've already approved or rejected in THIS round
                if (approver2StatusFromJson == 'Approved' || approver2StatusFromJson == 'Rejected') {
                    throw new AuraHandledException('You have already ' + approver2StatusFromJson.toLowerCase() + ' this submission in the current round. You cannot approve or reject it again.');
                }
            } else {
                // User is not an approver
                throw new AuraHandledException('You are not authorized to approve this submission.');
            }
            
            // Store approval data for the appropriate approver in current round
            Datetime approvalDate = Datetime.now();
            if (isApprover1) {
                approver1Data.put('status', 'Approved');
                approver1Data.put('comment', String.isNotBlank(comment) ? comment : '');
                approver1Data.put('approvedBy', currentUserId);
                approver1Data.put('approvedDate', approvalDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
                currentRound.put('approver1', approver1Data);
                submission.Status_Approver_1__c = 'Approved';
            } else {
                approver2Data.put('status', 'Approved');
                approver2Data.put('comment', String.isNotBlank(comment) ? comment : '');
                approver2Data.put('approvedBy', currentUserId);
                approver2Data.put('approvedDate', approvalDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
                currentRound.put('approver2', approver2Data);
                submission.Status_Approver_2__c = 'Approved';
            }
            
            // Also preserve the other approver's data if it exists
            if (!isApprover1 && !approver1Data.isEmpty()) {
                currentRound.put('approver1', approver1Data);
            }
            if (!isApprover2 && !approver2Data.isEmpty()) {
                currentRound.put('approver2', approver2Data);
            }
            
            // Save the current round to approval history
            saveRound(approvalHistoryData, currentRound);
            
            // Determine overall status based on both approvers (from current round after update)
            String approver1Status = approver1Data.containsKey('status') ? (String) approver1Data.get('status') : null;
            String approver2Status = approver2Data.containsKey('status') ? (String) approver2Data.get('status') : null;
            
            if (isApprover1) {
                // Approver 1 approved - check if Approver 2 is needed
                if (submission.Approver_2__c != null) {
                    if (approver2Status == 'Approved') {
                        // Both approved - final approval
                        submission.Status__c = 'Approved';
                    } else if (approver2Status == 'Rejected') {
                        // Approver 2 already rejected
                        submission.Status__c = 'Rejected';
                    } else {
                        // Waiting for Approver 2
                        submission.Status__c = 'Approver 2';
                    }
                } else {
                    // Only one approver needed - final approval
                    submission.Status__c = 'Approved';
                }
            } else if (isApprover2) {
                // Approver 2 approved - check Approver 1 status
                if (approver1Status == 'Approved') {
                    // Both approved - final approval
                    submission.Status__c = 'Approved';
                } else if (approver1Status == 'Rejected') {
                    // Approver 1 already rejected
                    submission.Status__c = 'Rejected';
                } else {
                    // Approver 1 hasn't approved yet (shouldn't happen, but handle it)
                    submission.Status__c = 'Approver 1';
                }
            }
            
            // Update Approval_History_Data__c with complete JSON (NOT Smart_Form_Data__c)
            // Serialize JSON and ensure it's clean (no HTML encoding)
            String jsonString = JSON.serialize(approvalHistoryData);
            submission.Approval_History_Data__c = jsonString;
            
            update submission;
            
            // If Approver 1 approved and Approver 2 exists, send email and notification to Approver 2
            if (isApprover1 && submission.Approver_2__c != null && submission.Status__c == 'Approver 2') {
                // Get Approver 1's comment from current round
                String approver1Comment = approver1Data.containsKey('comment') ? (String) approver1Data.get('comment') : '';
                sendApprover2Notification(submission, 'Approved', approver1Comment);
            }
            
            return submission.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error approving submission: ' + e.getMessage());
        }
    }

    /**
     * Reject Scorecard Submission
     * 
     * @param submissionId - Scorecard_Submission__c record ID
     * @param comment - Rejection comment (required)
     * @param rejectorId - User ID who is rejecting (optional)
     * @return String - Updated submission ID
     */
    @AuraEnabled
    public static String rejectSubmission(String submissionId, String comment, String rejectorId) {
        try {
            if (String.isBlank(submissionId)) {
                throw new AuraHandledException('Submission ID is required');
            }
            
            if (String.isBlank(comment)) {
                throw new AuraHandledException('Rejection comment is required');
            }
            
            Scorecard_Submission__c submission = [
                SELECT Id, Name, Status__c, Approver_1__c, Approver_2__c, Approval_History_Data__c, Total_Score__c,
                       Status_Approver_1__c, Status_Approver_2__c, Scorecard_Lead__c, Scorecard_Lead__r.OwnerId,
                       Scorecard_Lead__r.Email__c, Scorecard_Lead__r.FirstName__c, Scorecard_Lead__r.LastName__c,
                       Smart_Form_URL__c
                FROM Scorecard_Submission__c 
                WHERE Id = :submissionId 
                LIMIT 1
            ];
            
            String currentUserId = String.isNotBlank(rejectorId) ? rejectorId : UserInfo.getUserId();
            
            // Parse existing approval history JSON data and migrate to rounds structure if needed
            Map<String, Object> approvalHistoryData = parseApprovalHistoryData(submission.Approval_History_Data__c);
            approvalHistoryData = migrateToRoundsStructure(approvalHistoryData);
            
            // Get current round and approver data from current round
            Map<String, Object> currentRound = getCurrentRound(approvalHistoryData);
            Map<String, Object> approver1Data = getApproverDataFromCurrentRound(approvalHistoryData, 'approver1');
            Map<String, Object> approver2Data = getApproverDataFromCurrentRound(approvalHistoryData, 'approver2');
            
            // Determine which approver is rejecting
            Boolean isApprover1 = (submission.Approver_1__c != null && submission.Approver_1__c == currentUserId);
            Boolean isApprover2 = (submission.Approver_2__c != null && submission.Approver_2__c == currentUserId);
            
            // If approver fields are not set, assign them
            if (submission.Approver_1__c == null) {
                submission.Approver_1__c = currentUserId;
                isApprover1 = true;
            } else if (submission.Approver_2__c == null && submission.Approver_1__c != currentUserId) {
                submission.Approver_2__c = currentUserId;
                isApprover2 = true;
            }
            
            // Check if approver has already made a decision in the current round
            // Note: In a new round (after Approver 2 rejects), approvers can review again
            if (isApprover1) {
                // Check status in current round only (previous rounds are preserved, but allow new review)
                String approver1StatusFromJson = approver1Data.containsKey('status') ? (String) approver1Data.get('status') : null;
                // Only prevent if they've already rejected in THIS round (approval allows new review in new round)
                if (approver1StatusFromJson == 'Rejected') {
                    throw new AuraHandledException('You have already rejected this submission in the current round. You cannot reject it again.');
                }
            } else if (isApprover2) {
                // Check status in current round only
                String approver2StatusFromJson = approver2Data.containsKey('status') ? (String) approver2Data.get('status') : null;
                // Only prevent if they've already rejected in THIS round
                if (approver2StatusFromJson == 'Rejected') {
                    throw new AuraHandledException('You have already rejected this submission in the current round. You cannot reject it again.');
                }
            } else {
                // User is not an approver
                throw new AuraHandledException('You are not authorized to reject this submission.');
            }
            
            // Store rejection data for the appropriate approver in current round
            Datetime rejectionDate = Datetime.now();
            if (isApprover1) {
                approver1Data.put('status', 'Rejected');
                approver1Data.put('comment', comment);
                approver1Data.put('rejectedBy', currentUserId);
                approver1Data.put('rejectedDate', rejectionDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
                currentRound.put('approver1', approver1Data);
                
                // Preserve Approver 2's data if it exists
                if (!approver2Data.isEmpty()) {
                    currentRound.put('approver2', approver2Data);
                }
                
                // Save the round with Approver 1's rejection data
                saveRound(approvalHistoryData, currentRound);
                
                submission.Status_Approver_1__c = 'Rejected';
                submission.Status__c = 'Draft'; // Set status to Draft so customer can refill the form
            } else {
                // Approver 2 rejects
                approver2Data.put('status', 'Rejected');
                approver2Data.put('comment', comment);
                approver2Data.put('rejectedBy', currentUserId);
                approver2Data.put('rejectedDate', rejectionDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
                currentRound.put('approver2', approver2Data);
                
                // Preserve Approver 1's data if it exists in current round
                if (!approver1Data.isEmpty()) {
                    currentRound.put('approver1', approver1Data);
                }
                
                // Save current round before creating new one
                saveRound(approvalHistoryData, currentRound);
                
                submission.Status_Approver_2__c = 'Rejected';
                
                // Create new round for re-review
                Integer newRoundNumber = getCurrentRoundNumber(approvalHistoryData) + 1;
                approvalHistoryData.put('currentRound', newRoundNumber);
                
                // Create new round map
                Map<String, Object> newRound = new Map<String, Object>();
                newRound.put('roundNumber', newRoundNumber);
                saveRound(approvalHistoryData, newRound);
                
                // Reset approver status fields to allow re-approval in new round
                submission.Status_Approver_1__c = null;
                submission.Status_Approver_2__c = null;
                submission.Status__c = 'Approver 1'; // Go back to Approver 1 for re-review
            }
            
            // Update Approval_History_Data__c with complete JSON (NOT Smart_Form_Data__c)
            // Serialize JSON and ensure it's clean (no HTML encoding)
            String jsonString = JSON.serialize(approvalHistoryData);
            submission.Approval_History_Data__c = jsonString;
            
            update submission;
            
            // If Approver 1 rejects, send email and notification to Scorecard_Lead Owner with comment
            // Also create a Task for the Owner
            // Also send HTML email to customer (Scorecard_Lead__c) informing them to refill the form
            if (isApprover1 && submission.Scorecard_Lead__c != null) {
                sendLeadOwnerNotification(submission, 'Rejected', comment);
                createTaskForOwner(submission, comment, currentUserId);
                sendCustomerRejectionEmail(submission, comment);
            }
            
            // If Approver 2 rejects, send email and notification to Approver 1 with comment for re-review
            // Status is already set to 'Approver 1' above to allow re-review
            if (isApprover2 && submission.Approver_1__c != null) {
                sendApprover1Notification(submission, 'Rejected', comment);
            }
            
            return submission.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error rejecting submission: ' + e.getMessage());
        }
    }

    /**
     * Get Approval History for a submission
     * Returns approval/rejection data for both approvers from Approval_History_Data__c JSON field
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getApprovalHistory(String submissionId) {
        try {
            if (String.isBlank(submissionId)) {
                throw new AuraHandledException('Submission ID is required');
            }
            
            Scorecard_Submission__c submission = [
                SELECT Id, Status__c, Approver_1__c, Approver_2__c, Approval_History_Data__c,
                       Approver_1__r.Name, Approver_2__r.Name
                FROM Scorecard_Submission__c 
                WHERE Id = :submissionId 
                LIMIT 1
            ];
            
            Map<String, Object> result = new Map<String, Object>();
            Map<String, Object> approvalHistoryData = new Map<String, Object>();
            
            // Parse approval history JSON data and migrate to rounds structure if needed
            approvalHistoryData = parseApprovalHistoryData(submission.Approval_History_Data__c);
            approvalHistoryData = migrateToRoundsStructure(approvalHistoryData);
            
            // Get all rounds
            List<Object> rounds = (List<Object>) approvalHistoryData.get('rounds');
            if (rounds == null) {
                rounds = new List<Object>();
            }
            
            // Build rounds data with approver names
            List<Map<String, Object>> roundsData = new List<Map<String, Object>>();
            for (Object roundObj : rounds) {
                if (roundObj instanceof Map<String, Object>) {
                    Map<String, Object> round = (Map<String, Object>) roundObj;
                    Map<String, Object> roundData = new Map<String, Object>();
                    roundData.putAll(round);
                    
                    // Add approver names if approver data exists
                    if (round.containsKey('approver1')) {
                        Map<String, Object> approver1Data = (Map<String, Object>) round.get('approver1');
                        if (submission.Approver_1__r != null && !approver1Data.containsKey('approverName')) {
                            approver1Data.put('approverName', submission.Approver_1__r.Name);
                        }
                        roundData.put('approver1', approver1Data);
                    }
                    
                    if (round.containsKey('approver2')) {
                        Map<String, Object> approver2Data = (Map<String, Object>) round.get('approver2');
                        if (submission.Approver_2__r != null && !approver2Data.containsKey('approverName')) {
                            approver2Data.put('approverName', submission.Approver_2__r.Name);
                        }
                        roundData.put('approver2', approver2Data);
                    }
                    
                    roundsData.add(roundData);
                }
            }
            
            result.put('rounds', roundsData);
            result.put('currentRound', approvalHistoryData.containsKey('currentRound') ? approvalHistoryData.get('currentRound') : 1);
            result.put('currentStatus', submission.Status__c);
            result.put('approver1Id', submission.Approver_1__c);
            result.put('approver2Id', submission.Approver_2__c);
            
            // For backward compatibility, also include current round approver data at top level
            Map<String, Object> currentRound = getCurrentRound(approvalHistoryData);
            if (submission.Approver_1__c != null) {
                Map<String, Object> approver1Data = getApproverDataFromCurrentRound(approvalHistoryData, 'approver1');
                if (submission.Approver_1__r != null) {
                    approver1Data.put('approverName', submission.Approver_1__r.Name);
                }
                if (!approver1Data.containsKey('status')) {
                    approver1Data.put('status', 'Pending');
                }
                result.put('approver1', approver1Data);
            }
            
            if (submission.Approver_2__c != null) {
                Map<String, Object> approver2Data = getApproverDataFromCurrentRound(approvalHistoryData, 'approver2');
                if (submission.Approver_2__r != null) {
                    approver2Data.put('approverName', submission.Approver_2__r.Name);
                }
                if (!approver2Data.containsKey('status')) {
                    approver2Data.put('status', 'Pending');
                }
                result.put('approver2', approver2Data);
            }
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching approval history: ' + e.getMessage());
        }
    }

    // Wrapper class for submission review
    public class SubmissionReviewWrapper {
        @AuraEnabled public String submissionId;
        @AuraEnabled public String submissionName;
        @AuraEnabled public String leadId;
        @AuraEnabled public String leadName;
        @AuraEnabled public String city;
        @AuraEnabled public String status;
        @AuraEnabled public Decimal totalScore;
        @AuraEnabled public DateTime createdDate;
        @AuraEnabled public String createdBy;
        @AuraEnabled public DateTime lastModifiedDate;
        @AuraEnabled public String approver1Id;
        @AuraEnabled public String approver2Id;
        @AuraEnabled public String statusApprover1;
        @AuraEnabled public String statusApprover2;
        @AuraEnabled public String currentUserId;
        @AuraEnabled public Map<String, Object> jsonData;
        @AuraEnabled public List<AnswerReviewWrapper> answers;
        @AuraEnabled public Map<String, Decimal> sectionWeightages;
    }

    // Wrapper class for answer review
    public class AnswerReviewWrapper {
        @AuraEnabled public String answerId;
        @AuraEnabled public String questionKey;
        @AuraEnabled public String questionLabel;
        @AuraEnabled public String questionText;
        @AuraEnabled public String questionType;
        @AuraEnabled public String sectionKey;
        @AuraEnabled public String sectionLabel;
        @AuraEnabled public Decimal sectionWeightage;
        @AuraEnabled public List<String> selectedOptions;
        @AuraEnabled public List<String> selectedOptionLabels;
        @AuraEnabled public Decimal score;
        @AuraEnabled public Decimal weightedScore;
    }
    
    /**
     * Send email and notification to Approver 2 when Approver 1 makes a decision
     * 
     * @param submission - Scorecard_Submission__c record
     * @param decision - 'Approved' or 'Rejected'
     * @param approver1Comment - Comment from Approver 1 (optional)
     */
    private static void sendApprover2Notification(Scorecard_Submission__c submission, String decision, String approver1Comment) {
        try {
            if (submission.Approver_2__c == null) {
                return;
            }
            
            // Query Approver 2 user details
            List<User> approver2Users = [
                SELECT Id, Name, Email, FirstName, LastName
                FROM User
                WHERE Id = :submission.Approver_2__c
                AND IsActive = true
                LIMIT 1
            ];
            
            if (approver2Users.isEmpty() || String.isBlank(approver2Users[0].Email)) {
                System.debug('Approver 2 not found or email is blank');
                return;
            }
            
            User approver2 = approver2Users[0];
            system.debug('Sending notification to Approver 2: ' + approver2.Name + ' (' + approver2.Email + ')');
            String orgUrl = URL.getOrgDomainUrl().toExternalForm();
            String recordUrl = orgUrl + '/lightning/r/Scorecard_Submission__c/' + submission.Id + '/view';
            
            // Build email body based on decision
            String emailSubject = '';
            String emailBody = '';
            
            if (decision == 'Approved') {
                emailSubject = 'Scorecard Submission Approved by Approver 1 - Requires Your Approval - ' + submission.Name;
                emailBody = buildApprover2EmailBody(submission, approver2, recordUrl, 'approved', approver1Comment);
            } else if (decision == 'Rejected') {
                emailSubject = 'Scorecard Submission Rejected by Approver 1 - ' + submission.Name;
                emailBody = buildApprover2EmailBody(submission, approver2, recordUrl, 'rejected', approver1Comment);
            }
            
            // Send email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ approver2.Email });
          
            email.setSubject(emailSubject);
            email.setPlainTextBody(emailBody);
            
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
            
            // Send custom notification
            CustomNotificationType notificationType = getCustomNotificationType('Scorecard_Approval_Notification');
            if (notificationType != null) {
                try {
                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    
                    if (decision == 'Approved') {
                        notification.setTitle('Scorecard Submission Requires Your Approval');
                        String notificationBody = 'Approver 1 has approved the scorecard submission "' + submission.Name + '". It now requires your approval.';
                        if (String.isNotBlank(approver1Comment)) {
                            notificationBody += '\n\nApprover 1 Comment: ' + approver1Comment;
                        }
                        notification.setBody(notificationBody);
                    } else {
                        notification.setTitle('Scorecard Submission Rejected');
                        String notificationBody = 'Approver 1 has rejected the scorecard submission "' + submission.Name + '".';
                        if (String.isNotBlank(approver1Comment)) {
                            notificationBody += '\n\nApprover 1 Comment: ' + approver1Comment;
                        }
                        notification.setBody(notificationBody);
                    }
                    
                    notification.setNotificationTypeId(notificationType.Id);
                    notification.setTargetId(submission.Id);
                    
                    Set<String> recipientIds = new Set<String>{ String.valueOf(approver2.Id) };
                    notification.send(recipientIds);
                } catch (Exception e) {
                    System.debug('Error sending custom notification to Approver 2: ' + e.getMessage());
                }
            }
            
        } catch (Exception e) {
            System.debug('Error sending notification to Approver 2: ' + e.getMessage());
            // Don't throw exception - notification failure shouldn't block approval
        }
    }
    
    /**
     * Build email body for Approver 2 notification
     */
    private static String buildApprover2EmailBody(Scorecard_Submission__c submission, User approver2, String recordUrl, String action, String approver1Comment) {
        String body = 'Dear ' + (approver2.FirstName != null ? approver2.FirstName : approver2.Name) + ',\n\n';
        
        if (action == 'approved') {
            body += 'Approver 1 has approved the scorecard submission. It now requires your review and approval.\n\n';
        } else if (action == 'rejected') {
            body += 'Approver 1 has rejected the scorecard submission.\n\n';
        }
        
        // Include Approver 1's comment if available
        if (String.isNotBlank(approver1Comment)) {
            body += 'Approver 1 Comment:\n';
            body += approver1Comment + '\n\n';
        }
        
        body += 'Submission Details:\n';
        body += 'Submission Name: ' + (submission.Name != null ? submission.Name : submission.Id) + '\n';
        body += 'Current Status: ' + submission.Status__c + '\n';
        
        // Query submission again to get Total_Score__c if needed
        try {
            Scorecard_Submission__c subWithScore = [
                SELECT Total_Score__c 
                FROM Scorecard_Submission__c 
                WHERE Id = :submission.Id 
                LIMIT 1
            ];
            if (subWithScore.Total_Score__c != null) {
                body += 'Total Score: ' + subWithScore.Total_Score__c + '\n';
            }
        } catch (Exception e) {
            System.debug('Error fetching Total_Score__c: ' + e.getMessage());
        }
        
        body += '\n';
        
        if (action == 'approved') {
            body += 'Please review and approve/reject the scorecard submission by clicking the link below:\n';
        } else {
            body += 'You can view the submission details by clicking the link below:\n';
        }
        
        body += recordUrl + '\n\n';
        body += 'Thank you,\n';
        body += 'Biotech Healthcare CRM Team';
        
        return body;
    }
    
    /**
     * Send email and notification to Approver 1 when Approver 2 rejects
     * 
     * @param submission - Scorecard_Submission__c record
     * @param decision - 'Rejected'
     * @param approver2Comment - Comment from Approver 2
     */
    private static void sendApprover1Notification(Scorecard_Submission__c submission, String decision, String approver2Comment) {
        try {
            if (submission.Approver_1__c == null) {
                return;
            }
            
            // Query Approver 1 user details
            List<User> approver1Users = [
                SELECT Id, Name, Email, FirstName, LastName
                FROM User
                WHERE Id = :submission.Approver_1__c
                AND IsActive = true
                LIMIT 1
            ];
            
            if (approver1Users.isEmpty() || String.isBlank(approver1Users[0].Email)) {
                System.debug('Approver 1 not found or email is blank');
                return;
            }
            
            User approver1 = approver1Users[0];
            String orgUrl = URL.getOrgDomainUrl().toExternalForm();
            String recordUrl = orgUrl + '/lightning/r/Scorecard_Submission__c/' + submission.Id + '/view';
            
            // Build email body
            String emailSubject = 'Scorecard Submission Rejected by Approver 2 - Requires Re-Review - ' + submission.Name;
            String emailBody = buildApprover1EmailBody(submission, approver1, recordUrl, approver2Comment);
            
            // Send email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
             email.setToAddresses(new List<String>{ approver1.Email });
            
            email.setSubject(emailSubject);
            email.setPlainTextBody(emailBody);
            
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
            
            // Send custom notification
            CustomNotificationType notificationType = getCustomNotificationType('Scorecard_Approval_Notification');
            if (notificationType != null) {
                try {
                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    notification.setTitle('Scorecard Submission Rejected by Approver 2');
                    
                    String notificationBody = 'Approver 2 has rejected the scorecard submission "' + submission.Name + '". Please review the rejection comment and take appropriate action.';
                    if (String.isNotBlank(approver2Comment)) {
                        notificationBody += '\n\nApprover 2 Comment: ' + approver2Comment;
                    }
                    notification.setBody(notificationBody);
                    
                    notification.setNotificationTypeId(notificationType.Id);
                    notification.setTargetId(submission.Id);
                    
                    Set<String> recipientIds = new Set<String>{ String.valueOf(approver1.Id) };
                    notification.send(recipientIds);
                } catch (Exception e) {
                    System.debug('Error sending custom notification to Approver 1: ' + e.getMessage());
                }
            }
            
        } catch (Exception e) {
            System.debug('Error sending notification to Approver 1: ' + e.getMessage());
            // Don't throw exception - notification failure shouldn't block rejection
        }
    }
    
    /**
     * Build email body for Approver 1 notification when Approver 2 rejects
     */
    private static String buildApprover1EmailBody(Scorecard_Submission__c submission, User approver1, String recordUrl, String approver2Comment) {
        String body = 'Dear ' + (approver1.FirstName != null ? approver1.FirstName : approver1.Name) + ',\n\n';
        
        body += 'Approver 2 has rejected the scorecard submission. Please review the rejection comment and take appropriate action.\n\n';
        
        // Include Approver 2's comment
        if (String.isNotBlank(approver2Comment)) {
            body += 'Approver 2 Comment:\n';
            body += approver2Comment + '\n\n';
        }
        
        body += 'Submission Details:\n';
        body += 'Submission Name: ' + (submission.Name != null ? submission.Name : submission.Id) + '\n';
        body += 'Current Status: ' + submission.Status__c + '\n';
        
        // Query submission again to get Total_Score__c if needed
        try {
            Scorecard_Submission__c subWithScore = [
                SELECT Total_Score__c 
                FROM Scorecard_Submission__c 
                WHERE Id = :submission.Id 
                LIMIT 1
            ];
            if (subWithScore.Total_Score__c != null) {
                body += 'Total Score: ' + subWithScore.Total_Score__c + '\n';
            }
        } catch (Exception e) {
            System.debug('Error fetching Total_Score__c: ' + e.getMessage());
        }
        
        body += '\n';
        body += 'Please review the submission details by clicking the link below:\n';
        body += recordUrl + '\n\n';
        body += 'Thank you,\n';
        body += 'Biotech Healthcare CRM Team';
        
        return body;
    }
    
    /**
     * Send email and notification to Scorecard_Lead Owner when Approver 1 rejects
     * 
     * @param submission - Scorecard_Submission__c record
     * @param decision - 'Rejected'
     * @param approver1Comment - Comment from Approver 1
     */
    private static void sendLeadOwnerNotification(Scorecard_Submission__c submission, String decision, String approver1Comment) {
        try {
            if (submission.Scorecard_Lead__c == null || submission.Scorecard_Lead__r.OwnerId == null) {
                return;
            }
            
            // Query Scorecard_Lead Owner user details
            List<User> leadOwnerUsers = [
                SELECT Id, Name, Email, FirstName, LastName
                FROM User
                WHERE Id = :submission.Scorecard_Lead__r.OwnerId
                AND IsActive = true
                LIMIT 1
            ];
            
            if (leadOwnerUsers.isEmpty() || String.isBlank(leadOwnerUsers[0].Email)) {
                System.debug('Scorecard_Lead Owner not found or email is blank');
                return;
            }
            
            User leadOwner = leadOwnerUsers[0];
            String orgUrl = URL.getOrgDomainUrl().toExternalForm();
            String recordUrl = orgUrl + '/lightning/r/Scorecard_Submission__c/' + submission.Id + '/view';
            String leadRecordUrl = orgUrl + '/lightning/r/Scorecard_Lead__c/' + submission.Scorecard_Lead__c + '/view';
            
            // Build email body
            String emailSubject = 'Scorecard Submission Rejected - Request Customer to Refill Form - ' + submission.Name;
            String emailBody = buildLeadOwnerEmailBody(submission, leadOwner, recordUrl, leadRecordUrl, approver1Comment);
            
            // Send email
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
             email.setToAddresses(new List<String>{ leadOwner.Email });
            
            email.setSubject(emailSubject);
            email.setPlainTextBody(emailBody);
            
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
            
            // Send custom notification
            CustomNotificationType notificationType = getCustomNotificationType('Scorecard_Approval_Notification');
            if (notificationType != null) {
                try {
                    Messaging.CustomNotification notification = new Messaging.CustomNotification();
                    notification.setTitle('Scorecard Submission Rejected by Approver 1');
                    
                    String notificationBody = 'The scorecard submission "' + submission.Name + '" has been rejected by Approver 1. Please request the customer to refill the form.';
                    if (String.isNotBlank(approver1Comment)) {
                        notificationBody += '\n\nApprover 1 Comment: ' + approver1Comment;
                    }
                    notification.setBody(notificationBody);
                    
                    notification.setNotificationTypeId(notificationType.Id);
                    notification.setTargetId(submission.Id);
                    
                    Set<String> recipientIds = new Set<String>{ String.valueOf(leadOwner.Id) };
                    notification.send(recipientIds);
                } catch (Exception e) {
                    System.debug('Error sending custom notification to Lead Owner: ' + e.getMessage());
                }
            }
            
        } catch (Exception e) {
            System.debug('Error sending notification to Lead Owner: ' + e.getMessage());
            // Don't throw exception - notification failure shouldn't block rejection
        }
    }
    
    /**
     * Send HTML email to customer (Scorecard_Lead__c) when Approver 1 rejects the form
     * Uses the same HTML template from static resource but with modified rejection message
     * 
     * @param submission - Scorecard_Submission__c record with related Scorecard_Lead__c
     * @param approver1Comment - Comment from Approver 1 (not included in customer email for privacy)
     */
    private static void sendCustomerRejectionEmail(Scorecard_Submission__c submission, String approver1Comment) {
        try {
            if (submission.Scorecard_Lead__c == null || String.isBlank(submission.Scorecard_Lead__r.Email__c)) {
                System.debug('Cannot send customer rejection email: Scorecard Lead email is blank for submission: ' + submission.Id);
                return;
            }
            
            // Get HTML email template from static resource
            String htmlBody = getEmailTemplateFromStaticResource('ScorecardRejectionEmailTemplate');
            
            if (String.isBlank(htmlBody)) {
                System.debug('Email template not found in static resource: ScorecardRejectionEmailTemplate');
                return;
            }
            
            // Replace merge fields with actual values
            String emailBody = replaceMergeFieldsForRejection(htmlBody, submission, approver1Comment);
            
            // Create email message
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ submission.Scorecard_Lead__r.Email__c });
            email.setSubject('Distributor Scorecard Form - Action Required');
            email.setHtmlBody(emailBody);
            
            // Send email
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
            
            if (results[0].isSuccess()) {
                System.debug('Customer rejection email sent successfully to: ' + submission.Scorecard_Lead__r.Email__c);
            } else {
                System.debug('Error sending customer rejection email: ' + results[0].getErrors());
            }
            
        } catch (Exception e) {
            System.debug('Error sending customer rejection email: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            // Don't throw exception - email failure shouldn't block rejection process
        }
    }
    
    /**
     * Get HTML email template from static resource
     * @param resourceName - Name of the static resource
     * @return String - HTML content of the template
     */
    private static String getEmailTemplateFromStaticResource(String resourceName) {
        try {
            StaticResource sr = [
                SELECT Id, Body
                FROM StaticResource
                WHERE Name = :resourceName
                LIMIT 1
            ];
            
            return sr.Body.toString();
        } catch (Exception e) {
            System.debug('Error retrieving static resource ' + resourceName + ': ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Replace merge fields in HTML template with actual values for rejection email
     * Supported merge fields:
     * {LeadFirstName} - First name of the lead
     * {SmartFormURL} - Smart Form URL from the submission record
     * {Approver1Comment} - Comment from Approver 1 explaining the rejection
     * 
     * @param htmlBody - HTML template content
     * @param submission - Scorecard_Submission__c record with related Scorecard_Lead__c
     * @param approver1Comment - Comment from Approver 1
     * @return String - HTML content with replaced merge fields
     */
    private static String replaceMergeFieldsForRejection(String htmlBody, Scorecard_Submission__c submission, String approver1Comment) {
        String result = htmlBody;
        
        // Replace Lead FirstName
        if (submission.Scorecard_Lead__r.FirstName__c != null) {
            result = result.replace('{LeadFirstName}', submission.Scorecard_Lead__r.FirstName__c);
        } else {
            result = result.replace('{LeadFirstName}', '');
        }
        
        // Replace Smart Form URL
        if (submission.Smart_Form_URL__c != null && String.isNotBlank(submission.Smart_Form_URL__c)) {
            result = result.replace('{SmartFormURL}', submission.Smart_Form_URL__c);
        } else {
            // If Smart_Form_URL__c is not populated, construct URL from org domain and lead ID
            String orgUrl = URL.getOrgDomainUrl().toExternalForm();
            String smartFormUrl = orgUrl + '/lightning/n/Scorecard_Form?leadId=' + submission.Scorecard_Lead__c;
            result = result.replace('{SmartFormURL}', smartFormUrl);
            System.debug('Warning: Smart_Form_URL__c is empty for submission: ' + submission.Id + ', using constructed URL');
        }
        
        // Replace Approver 1 Comment - Escape HTML and preserve line breaks
        String commentText = '';
        if (String.isNotBlank(approver1Comment)) {
            // Escape HTML entities
            commentText = approver1Comment.replace('&', '&amp;')
                                          .replace('<', '&lt;')
                                          .replace('>', '&gt;')
                                          .replace('"', '&quot;')
                                          .replace('\'', '&#39;');
            // Convert line breaks to <br> tags
            commentText = commentText.replace('\n', '<br>');
        } else {
            commentText = 'No specific comment provided.';
        }
        result = result.replace('{Approver1Comment}', commentText);
        
        return result;
    }
    
    /**
     * Build email body for Lead Owner notification when Approver 1 rejects
     */
    private static String buildLeadOwnerEmailBody(Scorecard_Submission__c submission, User leadOwner, String submissionRecordUrl, String leadRecordUrl, String approver1Comment) {
        String body = 'Dear ' + (leadOwner.FirstName != null ? leadOwner.FirstName : leadOwner.Name) + ',\n\n';
        
        body += 'The scorecard submission has been rejected by Approver 1. Please request the customer to refill the form.\n\n';
        
        // Include Approver 1's rejection comment
        if (String.isNotBlank(approver1Comment)) {
            body += 'Approver 1 Comment:\n';
            body += approver1Comment + '\n\n';
        }
        
        body += 'Submission Details:\n';
        body += 'Submission Name: ' + (submission.Name != null ? submission.Name : submission.Id) + '\n';
        body += 'Current Status: ' + submission.Status__c + '\n';
        
        // Query submission again to get Total_Score__c if needed
        try {
            Scorecard_Submission__c subWithScore = [
                SELECT Total_Score__c 
                FROM Scorecard_Submission__c 
                WHERE Id = :submission.Id 
                LIMIT 1
            ];
            if (subWithScore.Total_Score__c != null) {
                body += 'Total Score: ' + subWithScore.Total_Score__c + '\n';
            }
        } catch (Exception e) {
            System.debug('Error fetching Total_Score__c: ' + e.getMessage());
        }
        
        body += '\n';
        body += 'Action Required:\n';
        body += 'Please contact the customer and request them to refill the scorecard form based on the feedback provided above.\n\n';
        body += 'You can view the submission details by clicking the link below:\n';
        body += submissionRecordUrl + '\n\n';
        body += 'You can view the Lead record by clicking the link below:\n';
        body += leadRecordUrl + '\n\n';
        body += 'Thank you,\n';
        body += 'Biotech Healthcare CRM Team';
        
        return body;
    }
    
    /**
     * Parse Approval History Data JSON with cleaning
     * Helper method to parse and clean JSON from Approval_History_Data__c field
     */
    private static Map<String, Object> parseApprovalHistoryData(String jsonString) {
        Map<String, Object> approvalHistoryData = new Map<String, Object>();
        if (String.isNotBlank(jsonString)) {
            try {
                String cleanedJson = cleanJsonString(jsonString);
                approvalHistoryData = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);
                System.debug('Parsed approval history data: ' + JSON.serialize(approvalHistoryData));
            } catch (Exception e) {
                System.debug('Error parsing Approval_History_Data__c JSON: ' + e.getMessage());
                System.debug('Stack Trace: ' + e.getStackTraceString());
                System.debug('Original JSON string (first 500 chars): ' + (jsonString.length() > 500 ? jsonString.substring(0, 500) : jsonString));
            }
        }
        return approvalHistoryData;
    }
    
    /**
     * Get Approver Data from Approval History Data Map
     * Creates a deep copy to preserve all existing fields
     */
    private static Map<String, Object> getApproverData(Map<String, Object> approvalHistoryData, String approverKey) {
        Map<String, Object> approverData = new Map<String, Object>();
        if (approvalHistoryData != null && approvalHistoryData.containsKey(approverKey)) {
            Object approverObj = approvalHistoryData.get(approverKey);
            if (approverObj != null && approverObj instanceof Map<String, Object>) {
                Map<String, Object> existingApprover = (Map<String, Object>) approverObj;
                // Deep copy to preserve all existing fields
                approverData.putAll(existingApprover);
                System.debug('Copied ' + approverKey + ' data: ' + JSON.serialize(approverData));
            }
        } else {
            System.debug('No existing data found for ' + approverKey);
        }
        return approverData;
    }
    
    /**
     * Migrate old approval history format to new rounds-based format
     * Backward compatibility: converts old {approver1: {...}, approver2: {...}} to rounds array
     */
    private static Map<String, Object> migrateToRoundsStructure(Map<String, Object> approvalHistoryData) {
        // Check if already in rounds format
        if (approvalHistoryData.containsKey('rounds') && approvalHistoryData.get('rounds') instanceof List<Object>) {
            return approvalHistoryData;
        }
        
        // Migrate old format to new format
        Map<String, Object> approver1Data = getApproverData(approvalHistoryData, 'approver1');
        Map<String, Object> approver2Data = getApproverData(approvalHistoryData, 'approver2');
        
        // Only create a round if there's actual data
        if (!approver1Data.isEmpty() || !approver2Data.isEmpty()) {
            Map<String, Object> round1 = new Map<String, Object>();
            round1.put('roundNumber', 1);
            if (!approver1Data.isEmpty()) {
                round1.put('approver1', approver1Data);
            }
            if (!approver2Data.isEmpty()) {
                round1.put('approver2', approver2Data);
            }
            
            List<Object> rounds = new List<Object>{ round1 };
            approvalHistoryData.put('rounds', rounds);
            approvalHistoryData.put('currentRound', 1);
            
            // Remove old format keys
            approvalHistoryData.remove('approver1');
            approvalHistoryData.remove('approver2');
        } else {
            // Initialize rounds array if empty
            approvalHistoryData.put('rounds', new List<Object>());
            approvalHistoryData.put('currentRound', 1);
        }
        
        return approvalHistoryData;
    }
    
    /**
     * Get current round number from approval history data
     */
    private static Integer getCurrentRoundNumber(Map<String, Object> approvalHistoryData) {
        if (approvalHistoryData.containsKey('currentRound')) {
            Object currentRoundObj = approvalHistoryData.get('currentRound');
            if (currentRoundObj instanceof Integer) {
                return (Integer) currentRoundObj;
            } else if (currentRoundObj instanceof Decimal) {
                return ((Decimal) currentRoundObj).intValue();
            }
        }
        return 1; // Default to round 1
    }
    
    /**
     * Get current round data from approval history
     */
    private static Map<String, Object> getCurrentRound(Map<String, Object> approvalHistoryData) {
        List<Object> rounds = (List<Object>) approvalHistoryData.get('rounds');
        if (rounds == null || rounds.isEmpty()) {
            return new Map<String, Object>();
        }
        
        Integer currentRoundNum = getCurrentRoundNumber(approvalHistoryData);
        
        // Find the round with matching roundNumber
        for (Object roundObj : rounds) {
            if (roundObj instanceof Map<String, Object>) {
                Map<String, Object> round = (Map<String, Object>) roundObj;
                Object roundNumObj = round.get('roundNumber');
                Integer roundNum = (roundNumObj instanceof Integer) ? (Integer) roundNumObj : 
                                  (roundNumObj instanceof Decimal) ? ((Decimal) roundNumObj).intValue() : null;
                
                if (roundNum != null && roundNum == currentRoundNum) {
                    return round;
                }
            }
        }
        
        // If current round doesn't exist, create it
        Map<String, Object> newRound = new Map<String, Object>();
        newRound.put('roundNumber', currentRoundNum);
        rounds.add(newRound);
        return newRound;
    }
    
    /**
     * Save round data to approval history
     */
    private static void saveRound(Map<String, Object> approvalHistoryData, Map<String, Object> roundData) {
        List<Object> rounds = (List<Object>) approvalHistoryData.get('rounds');
        if (rounds == null) {
            rounds = new List<Object>();
            approvalHistoryData.put('rounds', rounds);
        }
        
        Integer roundNum = (Integer) roundData.get('roundNumber');
        if (roundNum == null) {
            roundNum = getCurrentRoundNumber(approvalHistoryData);
            roundData.put('roundNumber', roundNum);
        }
        
        // Find and update existing round, or add new one
        Boolean found = false;
        for (Integer i = 0; i < rounds.size(); i++) {
            Object roundObj = rounds[i];
            if (roundObj instanceof Map<String, Object>) {
                Map<String, Object> round = (Map<String, Object>) roundObj;
                Object roundNumObj = round.get('roundNumber');
                Integer existingRoundNum = (roundNumObj instanceof Integer) ? (Integer) roundNumObj : 
                                          (roundNumObj instanceof Decimal) ? ((Decimal) roundNumObj).intValue() : null;
                
                if (existingRoundNum != null && existingRoundNum == roundNum) {
                    rounds[i] = roundData; // Update existing round
                    found = true;
                    break;
                }
            }
        }
        
        if (!found) {
            rounds.add(roundData); // Add new round
        }
    }
    
    /**
     * Get approver data from current round
     */
    private static Map<String, Object> getApproverDataFromCurrentRound(Map<String, Object> approvalHistoryData, String approverKey) {
        Map<String, Object> currentRound = getCurrentRound(approvalHistoryData);
        if (currentRound.containsKey(approverKey)) {
            Object approverObj = currentRound.get(approverKey);
            if (approverObj instanceof Map<String, Object>) {
                Map<String, Object> approverData = new Map<String, Object>();
                approverData.putAll((Map<String, Object>) approverObj);
                return approverData;
            }
        }
        return new Map<String, Object>();
    }
    
    /**
     * Clean JSON string to handle HTML entities and malformed JSON
     */
    private static String cleanJsonString(String jsonString) {
        if (String.isBlank(jsonString)) {
            return jsonString;
        }
        
        String cleaned = jsonString.trim();
        
        // Remove HTML entities (common ones)
        cleaned = cleaned.replace('&amp;', '&');  // Must be first
        cleaned = cleaned.replace('&quot;', '"');
        cleaned = cleaned.replace('&lt;', '<');
        cleaned = cleaned.replace('&gt;', '>');
        cleaned = cleaned.replace('&apos;', '\'');
        
        // Remove any leading/trailing whitespace or non-printable characters
        cleaned = cleaned.replaceAll('^[\\s\\u00A0]*', '').replaceAll('[\\s\\u00A0]*$', '');
        
        // Ensure JSON starts with { and ends with }
        if (!cleaned.startsWith('{')) {
            Integer startIndex = cleaned.indexOf('{');
            if (startIndex >= 0) {
                cleaned = cleaned.substring(startIndex);
            }
        }
        
        if (!cleaned.endsWith('}')) {
            Integer endIndex = cleaned.lastIndexOf('}');
            if (endIndex >= 0) {
                cleaned = cleaned.substring(0, endIndex + 1);
            }
        }
        
        return cleaned;
    }
    
    /**
     * Create a Task for the Scorecard_Lead Owner when Approver 1 rejects
     * 
     * @param submission - Scorecard_Submission__c record
     * @param comment - Rejection comment from Approver 1
     * @param approverId - ID of the approver who rejected
     */
    private static void createTaskForOwner(Scorecard_Submission__c submission, String comment, String approverId) {
        try {
            // Query the Lead to get Owner ID
            List<Scorecard_Lead__c> leads = [
                SELECT Id, OwnerId, Name, Owner.Name
                FROM Scorecard_Lead__c 
                WHERE Id = :submission.Scorecard_Lead__c 
                LIMIT 1
            ];
            
            if (leads.isEmpty() || leads[0].OwnerId == null) {
                System.debug('Lead not found or Owner not set for submission: ' + submission.Id);
                return;
            }
            
            Scorecard_Lead__c lead = leads[0];
            
            // Query approver name
            String approverName = 'Approver 1';
            if (String.isNotBlank(approverId)) {
                List<User> approvers = [SELECT Id, Name FROM User WHERE Id = :approverId LIMIT 1];
                if (!approvers.isEmpty()) {
                    approverName = approvers[0].Name;
                }
            }
            
            // Build task subject
            String taskSubject = 'Scorecard Submission Rejected: ' + submission.Name;
            
            // Build task description
            String taskDescription = 'The scorecard submission "' + submission.Name + '" has been rejected by ' + approverName + '.\n\n';
            if (String.isNotBlank(comment)) {
                taskDescription += 'Rejection Comment: ' + comment + '\n\n';
            }
            taskDescription += 'Please contact the customer to request them to refill the form.\n\n';
            taskDescription += 'Submission ID: ' + submission.Id + '\n';
            taskDescription += 'Lead: ' + lead.Name;
            
            // Create Task
            Task newTask = new Task();
            newTask.OwnerId = lead.OwnerId; // Assign to Lead Owner
            newTask.Subject = taskSubject;
            newTask.Description = taskDescription;
            newTask.Status = 'Not Started';
            newTask.Priority = 'High';
            
            // Relate task to the Lead (WhatId)
            newTask.WhatId = lead.Id;
            
            // Set ActivityDate to today
            newTask.ActivityDate = Date.today();
            
            // Insert the task
            insert newTask;
            
            System.debug('Task created for Lead Owner: ' + newTask.Id);
            
        } catch (Exception e) {
            System.debug('Error creating task for Owner: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            // Don't throw exception - task creation failure shouldn't block rejection
        }
    }
    
    /**
     * Get custom notification type by developer name
     */
    private static CustomNotificationType getCustomNotificationType(String developerName) {
        try {
            List<CustomNotificationType> notificationTypes = [
                SELECT Id, DeveloperName
                FROM CustomNotificationType
                WHERE DeveloperName = :developerName
                LIMIT 1
            ];
            
            return notificationTypes.isEmpty() ? null : notificationTypes[0];
        } catch (Exception e) {
            System.debug('Error retrieving custom notification type: ' + e.getMessage());
            return null;
        }
    }
}