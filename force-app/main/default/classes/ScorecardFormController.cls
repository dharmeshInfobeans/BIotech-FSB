public without sharing class ScorecardFormController {
    @AuraEnabled(cacheable=true)
    public static  List<SectionWrapper> getScorecardStructure() {

        Map<String, Scorecard_Section__mdt> sectionMap = Scorecard_Section__mdt.getAll();
        Map<String, Scorecard_Question__mdt> questionMap = Scorecard_Question__mdt.getAll();
        Map<String, Scorecard_Ans_Option__mdt> optionMap = Scorecard_Ans_Option__mdt.getAll();
        
        // SectionKey → List<QuestionWrapper>
        Map<String, List<QuestionWrapper>> sectionToQuestions = new Map<String, List<QuestionWrapper>>();

        // Step 1: Prepare Questions and their Options
        for (Scorecard_Question__mdt q : questionMap.values()) {
            // Include all questions (active and inactive) for admin configuration
            QuestionWrapper qw = new QuestionWrapper();
            qw.questionKey = q.DeveloperName;
            qw.questionLabel = q.Label;
            qw.isMandatory = q.Is_Mandatory__c;
            qw.isActive = q.Is_Active__c;
            qw.questionType = q.Question_Type__c;
            qw.questionText = q.QuestionText__c;

            // Build Options List
            List<OptionWrapper> optList = new List<OptionWrapper>();
            for (Scorecard_Ans_Option__mdt opt : optionMap.values()) {

                // FIX: Match by DeveloperName
                if (opt.Question__r.DeveloperName == q.DeveloperName && opt.Is_Active__c) {
                    optList.add(new OptionWrapper(
                        opt.DeveloperName,
                        opt.Label,
                        opt.Score__c,
                        opt.Answer__c
                    ));
                }
            }
            qw.options = optList;

            // Add Question under its Section
            String sectionKey = q.Section__r.DeveloperName;

            if (!sectionToQuestions.containsKey(sectionKey)) {
                sectionToQuestions.put(sectionKey, new List<QuestionWrapper>());
            }
            sectionToQuestions.get(sectionKey).add(qw);
        }


        // Step 2: Wrap all Sections → Questions → Options
        List<SectionWrapper> finalList = new List<SectionWrapper>();

        for (Scorecard_Section__mdt section : sectionMap.values()) {
            if (!section.Is_Active__c) continue;

            SectionWrapper sw = new SectionWrapper();
            sw.sectionKey = section.DeveloperName;
            sw.sectionLabel = section.Label;
            sw.weightage = section.Weightage__c;
            sw.order = section.Order__c != null ? section.Order__c : 999; // Default to 999 if null

            if (sectionToQuestions.containsKey(section.DeveloperName)) {
                sw.questions = sectionToQuestions.get(section.DeveloperName);
            } else {
                sw.questions = new List<QuestionWrapper>();
            }

            finalList.add(sw);
        }
        
        // Sort sections by Order field
        finalList.sort(new SectionOrderComparator());
        
        System.debug('FINAL STRUCTURE: ' + JSON.serialize(finalList));
			return finalList;
        
    }


    // Wrapper Classes
    public class SectionWrapper {
        @AuraEnabled public String sectionKey;
        @AuraEnabled public String sectionLabel;
        @AuraEnabled public Decimal weightage;
        @AuraEnabled public Decimal order;
        @AuraEnabled public List<QuestionWrapper> questions;
    }
    
    // Comparator class for sorting sections by Order
    public class SectionOrderComparator implements Comparator<SectionWrapper> {
        public Integer compare(SectionWrapper s1, SectionWrapper s2) {
            if (s1.order == null && s2.order == null) return 0;
            if (s1.order == null) return 1;
            if (s2.order == null) return -1;
            if (s1.order > s2.order) return 1;
            if (s1.order < s2.order) return -1;
            return 0;
        }
    }
        
    public class QuestionWrapper {
        @AuraEnabled public String questionKey;
        @AuraEnabled public String questionLabel;
        @AuraEnabled public Boolean isMandatory;
        @AuraEnabled public Boolean isActive;
        @AuraEnabled public String questionType;
        @AuraEnabled public String questionText;
        @AuraEnabled public List<OptionWrapper> options;
    }

    public class OptionWrapper  {
        @AuraEnabled public String optionKey;
        @AuraEnabled public String optionLabel;
        @AuraEnabled public Decimal score;
        @AuraEnabled public String Answer;

        public OptionWrapper(String k, String l, Decimal s, String a) {
            optionKey = k;
            optionLabel = l;
            score = s;
            Answer = a;
        }
    }

    // Method to update Section Weightage
    @AuraEnabled
    public static String updateSectionWeightage(String sectionKey, Decimal weightage) {
        try {
            // Get the existing section to preserve the label
            Scorecard_Section__mdt section = Scorecard_Section__mdt.getInstance(sectionKey);
            if (section == null) {
                throw new AuraHandledException('Section not found: ' + sectionKey);
            }

            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            customMetadata.fullName = 'Scorecard_Section__mdt.' + sectionKey;
            customMetadata.label = section.Label;

            Metadata.CustomMetadataValue weightageField = new Metadata.CustomMetadataValue();
            weightageField.field = 'Weightage__c';
            weightageField.value = weightage;
            customMetadata.values.add(weightageField);

            Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
            deployContainer.addMetadata(customMetadata);

            Id jobId = Metadata.Operations.enqueueDeployment(deployContainer, null);
            return jobId;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating weightage: ' + e.getMessage());
        }
    }

    // Method to update Answer Option Score
    @AuraEnabled
    public static String updateOptionScore(String optionKey, Decimal score) {
        try {
            Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
            customMetadata.fullName = 'Scorecard_Ans_Option__mdt.' + optionKey;
            customMetadata.label = optionKey;

            Metadata.CustomMetadataValue scoreField = new Metadata.CustomMetadataValue();
            scoreField.field = 'Score__c';
            scoreField.value = score;
            customMetadata.values.add(scoreField);

            Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
            deployContainer.addMetadata(customMetadata);

            Id jobId = Metadata.Operations.enqueueDeployment(deployContainer, null);
            return jobId;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating score: ' + e.getMessage());
        }
    }

    /**
     * Get Submission Status by Lead ID
     * Returns the status of the submission for the given lead
     * 
     * @param leadId - Scorecard_Lead__c record ID
     * @return String - Submission status (Draft, Submitted, Approved, Rejected, etc.) or null if no submission exists
     */
    @AuraEnabled(cacheable=true)
    public static String getSubmissionStatus(String leadId) {
        try {
            if (String.isBlank(leadId)) {
                return null;
            }
            
            List<Scorecard_Submission__c> submissions = [
                SELECT Id, Status__c
                FROM Scorecard_Submission__c 
                WHERE Scorecard_Lead__c = :leadId 
                ORDER BY CreatedDate DESC 
                LIMIT 1
            ];
            
            if (submissions.isEmpty()) {
                return null;
            }
            
            return submissions[0].Status__c;
        } catch (Exception e) {
            System.debug('Error fetching submission status: ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Get Draft Submission Data by Lead ID
     * Returns the Smart_Form_Data__c JSON when status is Draft
     * 
     * @param leadId - Scorecard_Lead__c record ID
     * @return String - Smart_Form_Data__c JSON or null if no draft submission exists
     */
    /**
     * Get Submission Data for a Lead (for both draft and submitted forms)
     * 
     * @param leadId - Scorecard_Lead__c record ID
     * @param draftOnly - If true, only returns data when status is Draft. If false, returns latest submission data regardless of status.
     * @return String - Smart_Form_Data__c JSON or null if no submission exists
     */
    @AuraEnabled(cacheable=true)
    public static String getSubmissionData(String leadId, Boolean draftOnly) {
        try {
            if (String.isBlank(leadId)) {
                return null;
            }
            
            // Query submission with related lead data
            List<Scorecard_Submission__c> submissions;
            if (draftOnly) {
                submissions = [
                    SELECT Id, Status__c, Smart_Form_Data__c, Total_Score__c, CreatedDate,
                           Scorecard_Lead__c, Scorecard_Lead__r.Company__c, Scorecard_Lead__r.FirstName__c,
                           Scorecard_Lead__r.LastName__c, Scorecard_Lead__r.Email__c, Scorecard_Lead__r.Mobile__c,
                           Scorecard_Lead__r.Region__c
                    FROM Scorecard_Submission__c 
                    WHERE Scorecard_Lead__c = :leadId 
                    AND Status__c = 'Draft'
                    ORDER BY CreatedDate DESC 
                    LIMIT 1
                ];
            } else {
                submissions = [
                    SELECT Id, Status__c, Smart_Form_Data__c, Total_Score__c, CreatedDate,
                           Scorecard_Lead__c, Scorecard_Lead__r.Company__c, Scorecard_Lead__r.FirstName__c,
                           Scorecard_Lead__r.LastName__c, Scorecard_Lead__r.Email__c, Scorecard_Lead__r.Mobile__c,
                           Scorecard_Lead__r.Region__c
                    FROM Scorecard_Submission__c 
                    WHERE Scorecard_Lead__c = :leadId 
                    ORDER BY CreatedDate DESC 
                    LIMIT 1
                ];
            }
            
            if (submissions.isEmpty()) {
                return null;
            }
            
            Scorecard_Submission__c submission = submissions[0];
            
            // Use the same logic as getDraftSubmissionData to process the submission
            return processSubmissionData(submission);
            
        } catch (Exception e) {
            System.debug('Error fetching submission data: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            return null;
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static String getDraftSubmissionData(String leadId) {
        return getSubmissionData(leadId, true);
    }
    
    /**
     * Process submission data to return JSON string
     * Shared logic for both draft and submitted forms
     */
    @TestVisible
    private static String processSubmissionData(Scorecard_Submission__c submission) {
        try {
            // Priority 1: If Smart_Form_Data__c exists and is valid JSON, return it directly
            if (String.isNotBlank(submission.Smart_Form_Data__c)) {
                try {
                    // Clean the JSON string first (handle HTML entities)
                    String cleanedJson = cleanJsonStringForDraft(submission.Smart_Form_Data__c);
                    
                    // Validate it's valid JSON by attempting to parse it
                    Map<String, Object> testParse = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);
                    
                    // Check if it has the expected structure (accountInfo, submissionInfo, answers)
                    if (testParse.containsKey('accountInfo') && testParse.containsKey('submissionInfo') && testParse.containsKey('answers')) {
                        // If parsing succeeds and structure is correct, return the cleaned JSON
                        System.debug('Returning Smart_Form_Data__c (valid JSON structure found)');
                        return cleanedJson;
                    } else {
                        System.debug('Smart_Form_Data__c exists but missing expected structure, will reconstruct');
                    }
                } catch (Exception e) {
                    System.debug('Smart_Form_Data__c is not valid JSON, will reconstruct: ' + e.getMessage());
                    // Fall through to reconstruction logic
                }
            }
            
            // Priority 2: Reconstruct JSON from Scorecard_Answer__c records and Lead data
            // This handles cases where Smart_Form_Data__c is missing or invalid
            String reconstructedJson = reconstructDraftJSON(submission);
            if (String.isNotBlank(reconstructedJson)) {
                return reconstructedJson;
            }
            
            // Priority 3: If Smart_Form_Data__c exists but reconstruction failed, return it anyway (let frontend handle it)
            if (String.isNotBlank(submission.Smart_Form_Data__c)) {
                System.debug('Returning Smart_Form_Data__c as fallback (reconstruction failed)');
                return cleanJsonStringForDraft(submission.Smart_Form_Data__c);
            }
            
            return null;
            
        } catch (Exception e) {
            System.debug('Error processing submission data: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            return null;
        }
    }
    
    /**
     * Clean JSON string to handle HTML entities (similar to ScorecardReviewController.cleanJsonString)
     */
    @testVisible
    private static String cleanJsonStringForDraft(String jsonString) {
        if (String.isBlank(jsonString)) {
            return jsonString;
        }
        
        String cleaned = jsonString.trim();
        
        // Decode HTML entities
        cleaned = cleaned.replace('&amp;', '&');  // Must be first
        cleaned = cleaned.replace('&quot;', '"');
        cleaned = cleaned.replace('&lt;', '<');
        cleaned = cleaned.replace('&gt;', '>');
        cleaned = cleaned.replace('&apos;', '\'');
        
        // Remove leading/trailing whitespace
        cleaned = cleaned.replaceAll('^[\\s\\u00A0]+', '').replaceAll('[\\s\\u00A0]+$', '');
        
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
            } else if (cleaned.endsWith(']')) {
                // If it ends with ], we might be missing the closing }
                // Check if we need to append }
                Integer lastBraceIndex = cleaned.lastIndexOf('}');
                Integer lastBracketIndex = cleaned.lastIndexOf(']');
                if (lastBracketIndex > lastBraceIndex && cleaned.startsWith('{')) {
                    cleaned = cleaned + '}';
                }
            }
        }
        
        return cleaned;
    }
    
    /**
     * Reconstruct draft JSON structure from stored data (Scorecard_Answer__c records and Lead data)
     * This creates the same JSON structure as submitScorecardForm expects
     */
    @testVisible
    private static String reconstructDraftJSON(Scorecard_Submission__c submission) {
        try {
            // Get Lead data
            Scorecard_Lead__c lead = submission.Scorecard_Lead__r;
            
            // Build accountInfo
            Map<String, Object> accountInfo = new Map<String, Object>();
            accountInfo.put('accountName', lead.Company__c != null ? lead.Company__c : '');
            
            // Build contactName from FirstName and LastName
            String contactName = '';
            if (String.isNotBlank(lead.FirstName__c) || String.isNotBlank(lead.LastName__c)) {
                List<String> nameParts = new List<String>();
                if (String.isNotBlank(lead.FirstName__c)) {
                    nameParts.add(lead.FirstName__c);
                }
                if (String.isNotBlank(lead.LastName__c)) {
                    nameParts.add(lead.LastName__c);
                }
                contactName = String.join(nameParts, ' ').trim();
            }
            accountInfo.put('contactName', contactName);
            accountInfo.put('contactEmail', lead.Email__c != null ? lead.Email__c : '');
            accountInfo.put('contactPhone', lead.Mobile__c != null ? lead.Mobile__c : '');
            accountInfo.put('language', 'en'); // Default language
            
            // Build submissionInfo
            Map<String, Object> submissionInfo = new Map<String, Object>();
            submissionInfo.put('submittedDate', submission.CreatedDate != null ? 
                submission.CreatedDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') : 
                Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
            submissionInfo.put('submittedDateTime', submission.CreatedDate != null ? 
                submission.CreatedDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') : 
                Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
            submissionInfo.put('isDraft', true);
            
            // Get Answer records
            List<Scorecard_Answer__c> answers = [
                SELECT Id, Question_Key_c__c, Sec_Category__c, Ans_Option_Key__c,
                       Score__c, Weighted_Score__c, AnswerText__c, CreatedDate
                FROM Scorecard_Answer__c 
                WHERE Scorecard_Submission__c = :submission.Id
                ORDER BY CreatedDate ASC
            ];
            
            // Get metadata for questions, sections, and options
            Map<String, Scorecard_Question__mdt> questionMap = Scorecard_Question__mdt.getAll();
            Map<String, Scorecard_Section__mdt> sectionMap = Scorecard_Section__mdt.getAll();
            Map<String, Scorecard_Ans_Option__mdt> optionMap = Scorecard_Ans_Option__mdt.getAll();
            
            // Build answers array
            List<Map<String, Object>> answersList = new List<Map<String, Object>>();
            Map<String, Decimal> sectionScores = new Map<String, Decimal>();
            Decimal totalScore = 0;
            
            for (Scorecard_Answer__c answer : answers) {
                Map<String, Object> answerMap = new Map<String, Object>();
                
                // Question information
                Scorecard_Question__mdt question = questionMap.get(answer.Question_Key_c__c);
                if (question != null) {
                    answerMap.put('questionKey', answer.Question_Key_c__c);
                    answerMap.put('questionLabel', question.Label);
                    answerMap.put('questionText', question.QuestionText__c);
                    answerMap.put('questionType', question.Question_Type__c);
                    answerMap.put('isMandatory', question.Is_Mandatory__c);
                } else {
                    answerMap.put('questionKey', answer.Question_Key_c__c);
                    answerMap.put('questionLabel', answer.Question_Key_c__c);
                    answerMap.put('questionText', answer.Question_Key_c__c);
                    answerMap.put('questionType', 'Picklist');
                    answerMap.put('isMandatory', false);
                }
                
                // Section information
                Scorecard_Section__mdt section = sectionMap.get(answer.Sec_Category__c);
                if (section != null) {
                    answerMap.put('sectionKey', answer.Sec_Category__c);
                    answerMap.put('sectionLabel', section.Label);
                    answerMap.put('sectionWeightage', section.Weightage__c != null ? section.Weightage__c : 0);
                } else {
                    answerMap.put('sectionKey', answer.Sec_Category__c);
                    answerMap.put('sectionLabel', answer.Sec_Category__c);
                    answerMap.put('sectionWeightage', 0);
                }
                
                // Selected option keys (split by semicolon)
                List<String> selectedOptionKeys = new List<String>();
                if (String.isNotBlank(answer.Ans_Option_Key__c)) {
                    selectedOptionKeys = answer.Ans_Option_Key__c.split(';');
                    for (Integer i = 0; i < selectedOptionKeys.size(); i++) {
                        selectedOptionKeys[i] = selectedOptionKeys[i].trim();
                    }
                }
                answerMap.put('selectedOptionKeys', selectedOptionKeys);
                
                // Selected option values (build from option keys and metadata)
                List<Map<String, Object>> selectedOptionValues = new List<Map<String, Object>>();
                for (String optionKey : selectedOptionKeys) {
                    Scorecard_Ans_Option__mdt option = optionMap.get(optionKey);
                    if (option != null) {
                        Map<String, Object> optionValue = new Map<String, Object>();
                        optionValue.put('optionKey', option.DeveloperName);
                        optionValue.put('optionLabel', option.Label);
                        optionValue.put('answerText', String.isNotBlank(option.Answer__c) ? option.Answer__c : option.Label);
                        optionValue.put('score', option.Score__c != null ? option.Score__c : 0);
                        selectedOptionValues.add(optionValue);
                    }
                }
                answerMap.put('selectedOptionValues', selectedOptionValues);
                
                // Score
                answerMap.put('score', answer.Score__c != null ? answer.Score__c : 0);
                
                // ifYesCount - check if we can determine this from AnswerText__c
                // If AnswerText contains "Yes, " or "Yes : " pattern, extract the count
                String ifYesCount = null;
                if (String.isNotBlank(answer.AnswerText__c)) {
                    String answerText = answer.AnswerText__c;
                    if (answerText.startsWith('Yes, ') || answerText.startsWith('Yes : ')) {
                        String countStr = answerText.contains('Yes, ') ? 
                            answerText.substringAfter('Yes, ') : 
                            answerText.substringAfter('Yes : ');
                        countStr = countStr.trim();
                        if (String.isNotBlank(countStr)) {
                            ifYesCount = countStr;
                        }
                    }
                }
                answerMap.put('ifYesCount', ifYesCount);
                
                // Answered date
                answerMap.put('answeredDate', answer.CreatedDate != null ? 
                    answer.CreatedDate.format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'') : 
                    Datetime.now().format('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\''));
                
                answersList.add(answerMap);
                
                // Calculate section scores
                String sectionKey = answer.Sec_Category__c;
                Decimal sectionScore = answer.Score__c != null ? answer.Score__c : 0;
                if (!sectionScores.containsKey(sectionKey)) {
                    sectionScores.put(sectionKey, 0);
                }
                sectionScores.put(sectionKey, sectionScores.get(sectionKey) + sectionScore);
                
                // Add to total score (weighted)
                Decimal sectionWeightage = section != null && section.Weightage__c != null ? section.Weightage__c : 0;
                Decimal weightedScore = (sectionScore * sectionWeightage / 100).setScale(2, RoundingMode.HALF_UP);
                totalScore += weightedScore;
            }
            
            // Build sectionScores map with totalScore and weightedScore
            Map<String, Map<String, Object>> sectionScoresMap = new Map<String, Map<String, Object>>();
            for (String sectionKey : sectionScores.keySet()) {
                Scorecard_Section__mdt section = sectionMap.get(sectionKey);
                Decimal sectionWeightage = section != null && section.Weightage__c != null ? section.Weightage__c : 0;
                Decimal sectionTotalScore = sectionScores.get(sectionKey);
                Decimal sectionWeightedScore = (sectionTotalScore * sectionWeightage / 100).setScale(2, RoundingMode.HALF_UP);
                
                Map<String, Object> sectionScoreData = new Map<String, Object>();
                sectionScoreData.put('totalScore', sectionTotalScore);
                sectionScoreData.put('weightedScore', sectionWeightedScore);
                sectionScoresMap.put(sectionKey, sectionScoreData);
            }
            
            // Build final JSON structure
            Map<String, Object> draftJSON = new Map<String, Object>();
            draftJSON.put('accountInfo', accountInfo);
            draftJSON.put('submissionInfo', submissionInfo);
            draftJSON.put('answers', answersList);
            draftJSON.put('sectionScores', sectionScoresMap);
            draftJSON.put('totalScore', totalScore.setScale(2, RoundingMode.HALF_UP));
            
            // Serialize to JSON string
            String jsonString = JSON.serialize(draftJSON);
            System.debug('Reconstructed draft JSON length: ' + jsonString.length());
            
            return jsonString;
            
        } catch (Exception e) {
            System.debug('Error reconstructing draft JSON: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            // Return null if reconstruction fails
            return null;
        }
    }
    
    /**
     * Get Scorecard Lead details by Lead ID
     * 
     * @param leadId - Scorecard_Lead__c record ID
     * @return Map<String, Object> - Lead data including Account Name, Region, Email, Phone
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getLeadDetails(String leadId) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            if (String.isBlank(leadId)) {
                return result;
            }
            
            List<Scorecard_Lead__c> leads = [
                SELECT Id, Name, Company__c, Email__c, Mobile__c, 
                       FirstName__c, LastName__c, Region__c, Country__c
                FROM Scorecard_Lead__c 
                WHERE Id = :leadId 
                LIMIT 1
            ];
            
            if (!leads.isEmpty()) {
                Scorecard_Lead__c lead = leads[0];
                
                // Account Name (Company)
                result.put('accountName', lead.Company__c != null ? lead.Company__c : '');
                
                // Region
                result.put('region', lead.Region__c != null ? lead.Region__c : '');
                
                // Country
                result.put('country', lead.Country__c != null ? lead.Country__c : '');
                
                // Email
                result.put('email', lead.Email__c != null ? lead.Email__c : '');
                
                // Phone (use Mobile__c)
                result.put('phone', lead.Mobile__c != null ? lead.Mobile__c : '');
                
                // Contact Name (FirstName + LastName)
                String contactName = '';
                if (String.isNotBlank(lead.FirstName__c) || String.isNotBlank(lead.LastName__c)) {
                    List<String> nameParts = new List<String>();
                    if (String.isNotBlank(lead.FirstName__c)) {
                        nameParts.add(lead.FirstName__c);
                    }
                    if (String.isNotBlank(lead.LastName__c)) {
                        nameParts.add(lead.LastName__c);
                    }
                    contactName = String.join(nameParts, ' ').trim();
                }
                result.put('contactName', contactName);
            }
            
        } catch (Exception e) {
            System.debug('Error fetching lead details: ' + e.getMessage());
            throw new AuraHandledException('Error fetching lead details: ' + e.getMessage());
        }
        
        return result;
    }


    /**
     * Submit Scorecard Form Data
     * Creates Scorecard_Submission__c record and related Scorecard_Answer__c records
     * Stores full JSON in Smart_Form_Data__c field
     * Links to Scorecard_Lead__c record via Leads__c master-detail field
     * 
     * @param scorecardDataJSON - Complete JSON structure from prepareScorecardAnswerJSON()
     * @param leadId - Scorecard_Lead__c record ID from URL parameters (optional)
     * @return String - Submission record ID
     */
    @AuraEnabled
    public static String submitScorecardForm(String scorecardDataJSON, String leadId) {
        try {
            system.debug('=== Starting submitScorecardForm ===');
            system.debug('Lead ID received: ' + leadId);
            system.debug('JSON length: ' + scorecardDataJSON);
            
            // Deserialize the JSON data
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(scorecardDataJSON);
            system.debug('JSON deserialized successfully');
            
            // Extract submission info
            Map<String, Object> submissionInfo = (Map<String, Object>) data.get('submissionInfo');
            Boolean isDraft = submissionInfo != null ? (Boolean) submissionInfo.get('isDraft') : false;
            
            // Extract scores
            Decimal totalScore = data.get('totalScore') != null ? Decimal.valueOf(String.valueOf(data.get('totalScore'))) : 0;
            
            // Extract answers array
            List<Object> answers = (List<Object>) data.get('answers');
            
            // Check if Scorecard_Lead__c is provided (required for create/update logic)
            if (String.isBlank(leadId)) {
                throw new AuraHandledException('Scorecard_Lead__c ID is required for submission');
            }
            
            // Verify Scorecard_Lead__c exists
            // Using "without sharing" class allows querying records even if guest user doesn't have direct access
            system.debug('Verifying Scorecard_Lead__c ID: ' + leadId);
            
            List<Scorecard_Lead__c> leadRecords = [
                SELECT Id, Name, Email__c, Company__c 
                FROM Scorecard_Lead__c 
                WHERE Id = :leadId 
                LIMIT 1
            ];
            
            if (leadRecords.isEmpty()) {
                system.debug('Scorecard_Lead__c not found for ID: ' + leadId);
                 throw new AuraHandledException('Scorecard_Lead__c record not found with ID: ' + leadId);
                // Double-check with COUNT query to see if it's an access issue
                // try {
                //     Integer recordCount = [
                //         SELECT COUNT() 
                //         FROM Scorecard_Lead__c 
                //         WHERE Id = :leadId
                //     ];
                //     system.debug('Record count for ID ' + leadId + ': ' + recordCount);
                //     if (recordCount > 0) {
                //         throw new AuraHandledException('Scorecard_Lead__c record exists but cannot be accessed. Please verify the Lead ID or contact administrator.');
                //     } else {
                //         throw new AuraHandledException('Scorecard_Lead__c record not found with ID: ' + leadId);
                //     }
                // } catch (Exception e) {
                //     system.debug('Error checking record count: ' + e.getMessage());
                 //  throw new AuraHandledException('Scorecard_Lead__c record not found with ID: ' + leadId + '. Error: ' );
                // }
            }
            
            system.debug('Scorecard_Lead__c found: ' + leadRecords[0].Name);
            
            // Check if submission already exists for this Scorecard_Lead__c
            // Use ALL ROWS to check even if user doesn't have access to see it
            List<Scorecard_Submission__c> existingSubmissions = new List<Scorecard_Submission__c>();
            try {
                existingSubmissions = [
                    SELECT Id, Status__c, Total_Score__c, Smart_Form_Data__c,Approver_1__c,Approver_2__c
                    FROM Scorecard_Submission__c 
                    WHERE Scorecard_Lead__c = :leadId 
                    ORDER BY CreatedDate DESC 
                    LIMIT 1
                ];
            } catch (QueryException e) {
                system.debug('Query Exception checking existing submissions: ' + e.getMessage());
                // If query fails due to access, assume no existing submission
                existingSubmissions = new List<Scorecard_Submission__c>();
            }
            
            Scorecard_Submission__c submission;
            Boolean isUpdate = false;
            
            if (!existingSubmissions.isEmpty()) {
                // Update existing submission
                submission = existingSubmissions[0];
                isUpdate = true;
                system.debug('Found existing submission: ' + submission.Id + ' - will update');
                
                // Delete existing answer records ONLY if this is final submission (not draft)
                // Drafts don't create answer records, so we only delete on final submission
                if (!isDraft) {
                    List<Scorecard_Answer__c> existingAnswers = [
                        SELECT Id 
                        FROM Scorecard_Answer__c 
                        WHERE Scorecard_Submission__c = :submission.Id
                    ];
                    if (!existingAnswers.isEmpty()) {
                        delete existingAnswers;
                        system.debug('Deleted ' + existingAnswers.size() + ' existing answer records');
                    }
                }
            } else {
                // Create new submission
                submission = new Scorecard_Submission__c();
                submission.Scorecard_Lead__c = leadId;
                system.debug('Creating new submission for Scorecard_Lead__c: ' + leadId);
            }
            
            // Set Status field - Draft for drafts, Submitted for final submissions
            if (isDraft != null) {
                submission.Status__c = isDraft ? 'Draft' : 'Submitted';
                submission.Status_Approver_1__c = '';
                submission.Status_Approver_2__c = '';
            } else {
                submission.Status__c = 'Submitted';
                submission.Status_Approver_1__c = '';
                submission.Status_Approver_2__c = '';
            }
            
            // Set Score field (default to 0 if null)
            submission.Total_Score__c = totalScore != null ? totalScore : 0;
            
            // Store full JSON in Smart_Form_Data__c field (Rich Text Area)
            // Limit to 32768 characters for Rich Text Area
            if (String.isNotBlank(scorecardDataJSON)) {
                if (scorecardDataJSON.length() > 32768) {
                    submission.Smart_Form_Data__c = scorecardDataJSON.substring(0, 32765) + '...';
                    system.debug('Warning: JSON truncated to fit Rich Text Area limit');
                } else {
                    submission.Smart_Form_Data__c = scorecardDataJSON;
                    system.debug('Full JSON stored in Smart_Form_Data__c: ' + submission.Smart_Form_Data__c);
                }
            }
            
            // Insert or Update the submission record
            try {
                if (isUpdate) {
                      submission.Status_Approver_1__c = '';
                        submission.Status_Approver_2__c = '';
                    update submission;
                    system.debug('Submission updated successfully with ID: ' + submission.Id);
                } else {
                      submission.Status_Approver_1__c = '';
                         submission.Status_Approver_2__c = '';
                    insert submission;
                    system.debug('Submission created successfully with ID: ' + submission.Id);
                }
            } catch (DmlException e) {
                system.debug('DML Error ' + (isUpdate ? 'updating' : 'inserting') + ' submission: ' + e.getMessage());
                // system.debug('DML Exception Type: ' + e.getTypeName());
                // system.debug('Number of DML Errors: ' + e.getNumDml());
                
                // String errorMessage = 'Error ' + (isUpdate ? 'updating' : 'creating') + ' submission';
                // if (e.getNumDml() > 0) {
                //     String dmlMsg = e.getDmlMessage(0);
                //     if (String.isNotBlank(dmlMsg)) {
                //         errorMessage += ': ' + dmlMsg;
                //     }
                //     List<String> fieldNames = e.getDmlFieldNames(0);
                //     if (fieldNames != null && !fieldNames.isEmpty()) {
                //         errorMessage += ' | Fields: ' + String.join(fieldNames, ', ');
                //     }
                // } else {
                //     errorMessage += ': ' + e.getMessage();
                // }
                
                // system.debug('Final Error Message: ' + errorMessage);
                throw new AuraHandledException(e.getMessage());
            } catch (Exception e) {
                system.debug('General Exception ' + (isUpdate ? 'updating' : 'inserting') + ' submission: ' + e.getMessage());
                system.debug('Exception Type: ' + e.getTypeName());
                throw new AuraHandledException('Error ' + (isUpdate ? 'updating' : 'creating') + ' submission: ' + e.getMessage());
            }
            
            // Create Scorecard_Answer__c records (Child records) ONLY on final submission
            // Skip answer record creation for drafts
            List<Scorecard_Answer__c> answerRecords = new List<Scorecard_Answer__c>();
            
            // Only create answer records if this is NOT a draft
            if (!isDraft) {
                if (answers != null && !answers.isEmpty()) {
                for (Object answerObj : answers) {
                    Map<String, Object> answer = (Map<String, Object>) answerObj;
                    
                    Scorecard_Answer__c answerRecord = new Scorecard_Answer__c();
                    
                    // Link to parent submission
                    answerRecord.Scorecard_Submission__c = submission.Id;
                    
                    // Question Information - using actual field name Question_Key__c
                    answerRecord.Question_Key_c__c = (String) answer.get('questionKey');
                    
                    // Section Information - using Sec_Category__c field
                    answerRecord.Sec_Category__c = (String) answer.get('sectionKey');
                    
                    // Answer Information - using Ans_Option_Key__c field
                    List<Object> selectedOptionKeys = (List<Object>) answer.get('selectedOptionKeys');
                    if (selectedOptionKeys != null && !selectedOptionKeys.isEmpty()) {
                        // Join multiple options with semicolon
                        List<String> optionKeysList = new List<String>();
                        for (Object opt : selectedOptionKeys) {
                            optionKeysList.add(String.valueOf(opt));
                        }
                        answerRecord.Ans_Option_Key__c = String.join(optionKeysList, ';');
                    }
                    
                    // Answer Text from selectedOptionValues array
                    List<Object> selectedOptionValues = (List<Object>) answer.get('selectedOptionValues');
                    if (selectedOptionValues != null && !selectedOptionValues.isEmpty()) {
                        List<String> answerTexts = new List<String>();
                        for (Object optionValueObj : selectedOptionValues) {
                            if (optionValueObj instanceof Map<String, Object>) {
                                Map<String, Object> optionValue = (Map<String, Object>) optionValueObj;
                                String answerText = (String) optionValue.get('answerText');
                                if (String.isNotBlank(answerText)) {
                                    answerTexts.add(answerText);
                                }
                            }
                        }
                        if (!answerTexts.isEmpty()) {
                            // Join multiple answer texts with semicolon
                            answerRecord.AnswerText__c = String.join(answerTexts, ';');
                        }
                    }
                    
                    // Score Information
                    if (answer.get('score') != null) {
                        answerRecord.Score__c = Decimal.valueOf(String.valueOf(answer.get('score')));
                    }
                    
                    // Calculate Weighted Score (Score * Section Weightage / 100)
                    Decimal sectionWeightage = answer.get('sectionWeightage') != null ? 
                        Decimal.valueOf(String.valueOf(answer.get('sectionWeightage'))) : 0;
                    Decimal questionScore = answer.get('score') != null ? 
                        Decimal.valueOf(String.valueOf(answer.get('score'))) : 0;
                    
                    if (sectionWeightage > 0 && questionScore > 0) {
                        // Use setScale(2) to preserve 2 decimal places for exact calculation
                        answerRecord.Weighted_Score__c = (questionScore * sectionWeightage / 100).setScale(2, RoundingMode.HALF_UP);
                    } else {
                        answerRecord.Weighted_Score__c = questionScore != null ? questionScore.setScale(2, RoundingMode.HALF_UP) : 0;
                    }
                    
                    answerRecords.add(answerRecord);
                }
            }
            
                // Insert all answer records
                if (!answerRecords.isEmpty()) {
                    try {
                        insert answerRecords;
                        system.debug('Inserted ' + answerRecords.size() + ' answer records');
                    } catch (DmlException e) {
                        system.debug('DML Error inserting answers: ' + e.getMessage());
                        // system.debug('DML Exception Type: ' + e.getTypeName());
                        // system.debug('Number of DML Errors: ' + e.getNumDml());
                        
                        // String errorMessage = 'Error creating answer records';
                        // if (e.getNumDml() > 0) {
                        //     Integer failedIndex = e.getDmlIndex(0);
                        //     String dmlMsg = e.getDmlMessage(0);
                        //     if (String.isNotBlank(dmlMsg)) {
                        //         errorMessage += ': ' + dmlMsg;
                        //     }
                        //     List<String> fieldNames = e.getDmlFieldNames(0);
                        //     if (fieldNames != null && !fieldNames.isEmpty()) {
                        //         errorMessage += ' | Fields: ' + String.join(fieldNames, ', ');
                        //     }
                        //     if (failedIndex >= 0 && failedIndex < answerRecords.size()) {
                        //         system.debug('Failed record index: ' + failedIndex);
                        //         try {
                        //             system.debug('Failed record: ' + JSON.serialize(answerRecords[failedIndex]));
                        //         } catch (Exception jsonEx) {
                        //             system.debug('Could not serialize failed record');
                        //         }
                        //     }
                        // } else {
                        //     errorMessage += ': ' + e.getMessage();
                        // }
                        
                        // system.debug('Final Error Message: ' + errorMessage);
                         throw new AuraHandledException( e.getMessage());
                    } catch (Exception e) {
                        system.debug('General Exception inserting answers: ' + e.getMessage());
                        system.debug('Exception Type: ' + e.getTypeName());
                        throw new AuraHandledException('Error creating answer records: ' + e.getMessage());
                    }
                } else {
                    system.debug('No answer records to create');
                }
            } else {
                system.debug('Skipping answer record creation - this is a draft');
            }
            
            // Create Section Score records if needed (optional - depends on your data model)
            // You can create Scorecard_Section_Score__c records here if such object exists
            
            // Send confirmation email to customer for final submission (not draft)
            if (!isDraft) {
                try {
                    sendSubmissionConfirmationEmail(submission.Id, leadId);
                } catch (Exception emailEx) {
                    // Log email error but don't fail the submission
                    system.debug('Error sending confirmation email: ' + emailEx.getMessage());
                    system.debug('Stack Trace: ' + emailEx.getStackTraceString());
                }
            }
            
            system.debug('=== submitScorecardForm completed successfully ===');
            system.debug('Submission ID: ' + submission.Id);
            return submission.Id;
            
        } catch (DmlException e) {
            // system.debug('=== DML Exception in submitScorecardForm ===');
            // system.debug('DML Exception Type: ' + e.getTypeName());
            // system.debug('DML Exception Message: ' + e.getMessage());
            // system.debug('Number of DML Errors: ' + e.getNumDml());
            
            // String errorMsg = 'Error submitting scorecard';
            // if (e.getNumDml() > 0) {
            //     String dmlMsg = e.getDmlMessage(0);
            //     system.debug('DML Message[0]: ' + dmlMsg);
            //     system.debug('DML Status Code[0]: ' + e.getDmlStatusCode(0));
            //     system.debug('DML Type[0]: ' + e.getDmlType(0));
                
            //     List<String> fieldNames = e.getDmlFieldNames(0);
            //     system.debug('DML Fields[0]: ' + fieldNames);
                
            //     if (String.isNotBlank(dmlMsg)) {
            //         errorMsg += ': ' + dmlMsg;
            //     }
            //     if (fieldNames != null && !fieldNames.isEmpty()) {
            //         errorMsg += ' | Fields: ' + String.join(fieldNames, ', ');
            //     }
            // } else {
            //     errorMsg += ': ' + e.getMessage();
            // }
            
            system.debug('Final Error Message: ');
            throw new AuraHandledException(e.getMessage());
        } catch (Exception e) {
            // system.debug('=== General Exception in submitScorecardForm ===');
            // system.debug('Exception Type: ' + e.getTypeName());
            // system.debug('Exception Message: ' + e.getMessage());
            // system.debug('Stack Trace: ' + e.getStackTraceString());
            // system.debug('Line Number: ' + e.getLineNumber());
            // system.debug('Cause: ' + e.getCause());
            
            // String errorMsg = 'Error submitting scorecard: ' + e.getMessage();
            // if (e.getTypeName() != null) {
            //     errorMsg += ' | Type: ' + e.getTypeName();
            // }
            // if (e.getLineNumber() != null) {
            //     errorMsg += ' | Line: ' + e.getLineNumber();
            // }
            
            // system.debug('Final Error Message: ' + errorMsg);
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * Save Draft Scorecard Form Data
     * Only updates the JSON in submission record, does NOT create answer records
     * Answer records are only created on final submission
     * 
     * @param scorecardDataJSON - Complete JSON structure from prepareScorecardAnswerJSON()
     * @param leadId - Scorecard_Lead__c record ID from URL parameters (optional)
     * @return String - Submission record ID
     */
    @AuraEnabled
    public static String saveDraftScorecard(String scorecardDataJSON, String leadId) {
        try {
            system.debug('=== Starting saveDraftScorecard (JSON only, no answer records) ===');
            system.debug('Lead ID received: ' + leadId);
            
            // Deserialize the JSON data
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(scorecardDataJSON);
            
            // Extract submission info and ensure isDraft is true
            Map<String, Object> submissionInfo = (Map<String, Object>) data.get('submissionInfo');
            if (submissionInfo != null) {
                submissionInfo.put('isDraft', true);
            } else {
                data.put('submissionInfo', new Map<String, Object>{ 'isDraft' => true });
            }
            
            // Extract scores
            Decimal totalScore = data.get('totalScore') != null ? Decimal.valueOf(String.valueOf(data.get('totalScore'))) : 0;
            
            // Check if Scorecard_Lead__c is provided
            if (String.isBlank(leadId)) {
                throw new AuraHandledException('Scorecard_Lead__c ID is required for draft save');
            }
            
            // Verify Scorecard_Lead__c exists
            List<Scorecard_Lead__c> leadRecords = [
                SELECT Id, Name 
                FROM Scorecard_Lead__c 
                WHERE Id = :leadId 
                LIMIT 1
            ];
            
            if (leadRecords.isEmpty()) {
                throw new AuraHandledException('Scorecard_Lead__c record not found with ID: ' + leadId);
            }
            
            // Check if submission already exists for this Scorecard_Lead__c
            List<Scorecard_Submission__c> existingSubmissions = new List<Scorecard_Submission__c>();
            try {
                existingSubmissions = [
                    SELECT Id, Status__c, Total_Score__c, Smart_Form_Data__c
                    FROM Scorecard_Submission__c 
                    WHERE Scorecard_Lead__c = :leadId 
                    ORDER BY CreatedDate DESC 
                    LIMIT 1
                ];
            } catch (QueryException e) {
                system.debug('Query Exception checking existing submissions: ' + e.getMessage());
                existingSubmissions = new List<Scorecard_Submission__c>();
            }
            
            Scorecard_Submission__c submission;
            Boolean isUpdate = false;
            
            if (!existingSubmissions.isEmpty()) {
                // Update existing submission
                submission = existingSubmissions[0];
                isUpdate = true;
                system.debug('Found existing submission: ' + submission.Id + ' - will update JSON only');
            } else {
                // Create new submission
                submission = new Scorecard_Submission__c();
                submission.Scorecard_Lead__c = leadId;
                system.debug('Creating new submission for Scorecard_Lead__c: ' + leadId);
            }
            
            // Set Status to Draft
            submission.Status__c = 'Draft';
            
            // Set Score field
            submission.Total_Score__c = totalScore != null ? totalScore : 0;
            
            // Store full JSON in Smart_Form_Data__c field (Rich Text Area)
            // Limit to 32768 characters for Rich Text Area
            String draftJSON = JSON.serialize(data);
            if (String.isNotBlank(draftJSON)) {
                if (draftJSON.length() > 32768) {
                    submission.Smart_Form_Data__c = draftJSON.substring(0, 32765) + '...';
                    system.debug('Warning: JSON truncated to fit Rich Text Area limit');
                } else {
                    submission.Smart_Form_Data__c = draftJSON;
                }
            }
            
            // Insert or Update the submission record (NO ANSWER RECORDS CREATED)
            if (isUpdate) {
                update submission;
                system.debug('Draft submission updated successfully with ID: ' + submission.Id);
            } else {
                insert submission;
                system.debug('Draft submission created successfully with ID: ' + submission.Id);
            }
            
            system.debug('=== saveDraftScorecard completed successfully (JSON only) ===');
            return submission.Id;
            
        } catch (Exception e) {
            system.debug('=== Exception in saveDraftScorecard ===');
            system.debug('Exception Message: ' + e.getMessage());
            system.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error saving draft: ' + e.getMessage());
        }
    }

    /**
     * Update existing Scorecard Submission
     * 
     * @param submissionId - Existing Scorecard_Submission__c record ID
     * @param scorecardDataJSON - Updated JSON structure
     * @return String - Updated submission record ID
     */
    @AuraEnabled
    public static String updateScorecardForm(String submissionId, String scorecardDataJSON) {
        try {
            // Check if submission exists
            Scorecard_Submission__c existingSubmission = [
                SELECT Id, Status__c, Scorecard_Lead__c
                FROM Scorecard_Submission__c 
                WHERE Id = :submissionId 
                LIMIT 1
            ];
            
            // Delete existing answer records
            List<Scorecard_Answer__c> existingAnswers = [
                SELECT Id 
                FROM Scorecard_Answer__c 
                WHERE Scorecard_Submission__c = :submissionId
            ];
            if (!existingAnswers.isEmpty()) {
                delete existingAnswers;
            }
            
            // Deserialize the JSON data
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(scorecardDataJSON);
            
            // Extract account info
            Map<String, Object> accountInfo = (Map<String, Object>) data.get('accountInfo');
            Map<String, Object> submissionInfo = (Map<String, Object>) data.get('submissionInfo');
            Decimal totalScore = data.get('totalScore') != null ? Decimal.valueOf(String.valueOf(data.get('totalScore'))) : 0;
            List<Object> answers = (List<Object>) data.get('answers');
            
            // Update submission record
            Boolean isDraft = submissionInfo != null ? (Boolean) submissionInfo.get('isDraft') : false;
            existingSubmission.Status__c = isDraft ? 'Draft' : 'Submitted';
            existingSubmission.Total_Score__c = totalScore;
            existingSubmission.Smart_Form_Data__c = scorecardDataJSON;
            
            update existingSubmission;
            
            // Create new answer records
            List<Scorecard_Answer__c> answerRecords = new List<Scorecard_Answer__c>();
            
            if (answers != null && !answers.isEmpty()) {
                for (Object answerObj : answers) {
                    Map<String, Object> answer = (Map<String, Object>) answerObj;
                    
                    Scorecard_Answer__c answerRecord = new Scorecard_Answer__c();
                    answerRecord.Scorecard_Submission__c = existingSubmission.Id;
                    answerRecord.Question_Key_c__c = (String) answer.get('questionKey');
                    answerRecord.Sec_Category__c = (String) answer.get('sectionKey');
                    
                    List<Object> selectedOptionKeys = (List<Object>) answer.get('selectedOptionKeys');
                    if (selectedOptionKeys != null && !selectedOptionKeys.isEmpty()) {
                        List<String> optionKeysList = new List<String>();
                        for (Object opt : selectedOptionKeys) {
                            optionKeysList.add(String.valueOf(opt));
                        }
                        answerRecord.Ans_Option_Key__c = String.join(optionKeysList, ';');
                    }
                    
                    // Answer Text from selectedOptionValues array
                    List<Object> selectedOptionValues = (List<Object>) answer.get('selectedOptionValues');
                    if (selectedOptionValues != null && !selectedOptionValues.isEmpty()) {
                        List<String> answerTexts = new List<String>();
                        for (Object optionValueObj : selectedOptionValues) {
                            if (optionValueObj instanceof Map<String, Object>) {
                                Map<String, Object> optionValue = (Map<String, Object>) optionValueObj;
                                String answerText = (String) optionValue.get('answerText');
                                if (String.isNotBlank(answerText)) {
                                    answerTexts.add(answerText);
                                }
                            }
                        }
                        if (!answerTexts.isEmpty()) {
                            // Join multiple answer texts with semicolon
                            answerRecord.AnswerText__c = String.join(answerTexts, ';');
                        }
                    }
                    
                    if (answer.get('score') != null) {
                        answerRecord.Score__c = Decimal.valueOf(String.valueOf(answer.get('score')));
                    }
                    
                    // Calculate Weighted Score
                    Decimal sectionWeightage = answer.get('sectionWeightage') != null ? 
                        Decimal.valueOf(String.valueOf(answer.get('sectionWeightage'))) : 0;
                    Decimal questionScore = answer.get('score') != null ? 
                        Decimal.valueOf(String.valueOf(answer.get('score'))) : 0;
                    
                    if (sectionWeightage > 0 && questionScore > 0) {
                        // Use setScale(2) to preserve 2 decimal places for exact calculation
                        answerRecord.Weighted_Score__c = (questionScore * sectionWeightage / 100).setScale(2, RoundingMode.HALF_UP);
                    } else {
                        answerRecord.Weighted_Score__c = questionScore != null ? questionScore.setScale(2, RoundingMode.HALF_UP) : 0;
                    }
                    
                    answerRecords.add(answerRecord);
                }
            }
            
            if (!answerRecords.isEmpty()) {
                insert answerRecords;
            }
            
            // Send confirmation email to customer for final submission (not draft)
            if (!isDraft && existingSubmission.Scorecard_Lead__c != null) {
                try {
                    sendSubmissionConfirmationEmail(existingSubmission.Id, existingSubmission.Scorecard_Lead__c);
                } catch (Exception emailEx) {
                    // Log email error but don't fail the update
                    system.debug('Error sending confirmation email: ' + emailEx.getMessage());
                    system.debug('Stack Trace: ' + emailEx.getStackTraceString());
                }
            }
            
            return existingSubmission.Id;
            
        } catch (DmlException e) {
            throw new AuraHandledException('Error updating scorecard: ' + e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Error updating scorecard: ' + e.getMessage());
        }
    }

    // Method to batch update multiple options
    @AuraEnabled
    public static String batchUpdateOptionScores(Map<String, Decimal> optionScoreMap) {
        try {
            // Get all options to preserve labels
            Map<String, Scorecard_Ans_Option__mdt> optionMap = Scorecard_Ans_Option__mdt.getAll();
            
            Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
            
            for (String optionKey : optionScoreMap.keySet()) {
                Scorecard_Ans_Option__mdt option = optionMap.get(optionKey);
                if (option == null) {
                    System.debug('Warning: Option not found: ' + optionKey);
                    continue;
                }

                Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
                customMetadata.fullName = 'Scorecard_Ans_Option__mdt.' + optionKey;
                customMetadata.label = option.Label;

                Metadata.CustomMetadataValue scoreField = new Metadata.CustomMetadataValue();
                scoreField.field = 'Score__c';
                scoreField.value = optionScoreMap.get(optionKey);
                customMetadata.values.add(scoreField);

                deployContainer.addMetadata(customMetadata);
            }

            if (deployContainer.getMetadata().isEmpty()) {
                throw new AuraHandledException('No valid options found to update');
            }

            Id jobId = Metadata.Operations.enqueueDeployment(deployContainer, null);
            return jobId;
        } catch (Exception e) {
            throw new AuraHandledException('Error batch updating scores: ' + e.getMessage());
        }
    }

    // Method to batch update multiple questions (Is_Mandatory__c and Is_Active__c)
    @AuraEnabled
    public static String batchUpdateQuestions(Map<String, Map<String, Object>> questionUpdates) {
        try {
            Map<String, Scorecard_Question__mdt> questionMap = Scorecard_Question__mdt.getAll();
            Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
            
            for (String questionKey : questionUpdates.keySet()) {
                Scorecard_Question__mdt question = questionMap.get(questionKey);
                if (question == null) {
                    System.debug('Warning: Question not found: ' + questionKey);
                    continue;
                }

                Map<String, Object> updates = questionUpdates.get(questionKey);
                Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
                customMetadata.fullName = 'Scorecard_Question__mdt.' + questionKey;
                customMetadata.label = question.Label;

                if (updates.containsKey('isMandatory')) {
                    Metadata.CustomMetadataValue mandatoryField = new Metadata.CustomMetadataValue();
                    mandatoryField.field = 'Is_Mandatory__c';
                    mandatoryField.value = updates.get('isMandatory');
                    customMetadata.values.add(mandatoryField);
                }

                if (updates.containsKey('isActive')) {
                    Metadata.CustomMetadataValue activeField = new Metadata.CustomMetadataValue();
                    activeField.field = 'Is_Active__c';
                    activeField.value = updates.get('isActive');
                    customMetadata.values.add(activeField);
                }

                if (!customMetadata.values.isEmpty()) {
                    deployContainer.addMetadata(customMetadata);
                }
            }

            if (deployContainer.getMetadata().isEmpty()) {
                throw new AuraHandledException('No valid questions found to update');
            }

            Id jobId = Metadata.Operations.enqueueDeployment(deployContainer, null);
            return jobId;
        } catch (Exception e) {
            throw new AuraHandledException('Error batch updating questions: ' + e.getMessage());
        }
    }

    /**
     * Get all available regions from Region_Approver__c object
     * Gets picklist values if Region__c is a picklist, otherwise gets existing values
     * @return List<Map<String, String>> - List of regions with label and value
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getAvailableRegions() {
        try {
            List<Map<String, String>> regions = new List<Map<String, String>>();
            Set<String> regionSet = new Set<String>();
            
            // Try to get picklist values first
            Schema.DescribeFieldResult fieldDescribe = Region_Approver__c.Region__c.getDescribe();
            if (fieldDescribe.getType() == Schema.DisplayType.PICKLIST) {
                // Get all picklist values
                List<Schema.PicklistEntry> picklistEntries = fieldDescribe.getPicklistValues();
                for (Schema.PicklistEntry entry : picklistEntries) {
                    if (entry.isActive()) {
                        regionSet.add(entry.getValue());
                    }
                }
            } else {
                // If it's not a picklist, get distinct values from existing records
                List<Region_Approver__c> existingRecords = [
                    SELECT Region__c 
                    FROM Region_Approver__c 
                    WHERE Region__c != null 
                    ORDER BY Region__c
                ];
                
                for (Region_Approver__c ra : existingRecords) {
                    if (String.isNotBlank(ra.Region__c)) {
                        regionSet.add(ra.Region__c);
                    }
                }
            }
            
            // Convert to sorted list of maps for LWC
            List<String> sortedRegions = new List<String>(regionSet);
            sortedRegions.sort();
            
            for (String region : sortedRegions) {
                Map<String, String> regionMap = new Map<String, String>();
                regionMap.put('label', region);
                regionMap.put('value', region);
                regions.add(regionMap);
            }
            
            return regions;
        } catch (Exception e) {
            System.debug('Error getting regions: ' + e.getMessage());
            throw new AuraHandledException('Error getting regions: ' + e.getMessage());
        }
    }

    /**
     * Get Scorecard JSON from Region_Approver__c by region
     * Returns the ScoreCard_JSON__c field value for the given region
     * 
     * @param region - Region value to look up
     * @return String - ScoreCard_JSON__c JSON string or null if not found
     */
    @AuraEnabled(cacheable=true)
    public static String getRegionScorecardJSON(String region) {
        try {
            if (String.isBlank(region)) {
                return null;
            }
            
            List<Region_Approver__c> approvers = [
                SELECT Id, Region__c, ScoreCard_JSON__c
                FROM Region_Approver__c 
                WHERE Region__c = :region 
                LIMIT 1
            ];
            
            if (!approvers.isEmpty() && String.isNotBlank(approvers[0].ScoreCard_JSON__c)) {
                return approvers[0].ScoreCard_JSON__c;
            }
            
            return null;
        } catch (Exception e) {
            System.debug('Error getting region scorecard JSON: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            return null;
        }
    }
    
    /**
     * Get Region Approver record for a specific region
     * @param region - Region name/value
     * @return Map<String, Object> - Contains approver1Id, approver2Id, recordId if exists
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getRegionApprover(String region) {
        try {
            Map<String, Object> result = new Map<String, Object>();
            
            if (String.isBlank(region)) {
                return result;
            }
            
            List<Region_Approver__c> approvers = [
                SELECT Id, Region__c, Approver_1__c, Approver_2__c,
                       Approver_1__r.Name, Approver_2__r.Name
                FROM Region_Approver__c 
                WHERE Region__c = :region 
                LIMIT 1
            ];
            
            if (!approvers.isEmpty()) {
                Region_Approver__c ra = approvers[0];
                result.put('recordId', ra.Id);
                result.put('region', ra.Region__c);
                result.put('approver1Id', ra.Approver_1__c);
                result.put('approver2Id', ra.Approver_2__c);
                result.put('approver1Name', ra.Approver_1__r != null ? ra.Approver_1__r.Name : null);
                result.put('approver2Name', ra.Approver_2__r != null ? ra.Approver_2__r.Name : null);
            }
            
            return result;
        } catch (Exception e) {
            System.debug('Error getting region approver: ' + e.getMessage());
            throw new AuraHandledException('Error getting region approver: ' + e.getMessage());
        }
    }

    /**
     * Save/Upsert Region Approver record
     * @param region - Region name/value
     * @param approver1Id - User ID for Approver 1
     * @param approver2Id - User ID for Approver 2 (optional)
     * @param recordId - Existing record ID if updating (optional)
     * @return String - Record ID
     */
    /**
     * Generate JSON string from scorecard structure (same as getScorecardStructure but returns JSON string)
     * This method generates the complete scorecard structure JSON for saving to Region_Approver__c
     */
    public static String generateScorecardJSON() {
        try {
            // Get the scorecard structure using the existing method
            List<SectionWrapper> scorecardStructure = getScorecardStructure();
            
            // Serialize to JSON string
            String jsonString = JSON.serialize(scorecardStructure);
            
            System.debug('Generated Scorecard JSON length: ' + jsonString);
            return jsonString;
        } catch (Exception e) {
            System.debug('Error generating scorecard JSON: ' + e.getMessage());
            throw new AuraHandledException('Error generating scorecard JSON: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String saveRegionApprover(String region, String approver1Id, String approver2Id, String recordId) {
        try {
            if (String.isBlank(region)) {
                throw new AuraHandledException('Region is required');
            }
            
            if (String.isBlank(approver1Id)) {
                throw new AuraHandledException('Approver 1 is required');
            }
            
            // Generate the scorecard JSON structure
            String scorecardJSON = generateScorecardJSON();
            system.debug('Scorecard JSON generated for region ' + region + ': ' + scorecardJSON);
            Region_Approver__c regionApprover;
            
            if (String.isNotBlank(recordId)) {
                // Update existing record
                regionApprover = new Region_Approver__c(
                    Id = recordId,
                    Region__c = region,
                    Approver_1__c = approver1Id,
                    Approver_2__c = String.isNotBlank(approver2Id) ? approver2Id : null
                );
                
                // Set ScoreCard_JSON__c field if it exists
                try {
                    regionApprover.put('ScoreCard_JSON__c', string.valueOf(scorecardJSON));
                    system.debug('Set ScoreCard_JSON__c for existing record: ' + string.valueOf(scorecardJSON));
                } catch (Exception e) {
                    System.debug('ScoreCard_JSON__c field may not exist: ' + e.getMessage());
                }
            } else {
                // Check if record exists for this region
                List<Region_Approver__c> existing = [
                    SELECT Id, Region__c, ScoreCard_JSON__c
                    FROM Region_Approver__c 
                    WHERE Region__c = :region 
                    LIMIT 1
                ];
                
                if (!existing.isEmpty()) {
                    // Update existing
                    regionApprover = new Region_Approver__c(
                        Id = existing[0].Id,
                        Region__c = region,
                        Approver_1__c = approver1Id,
                        Approver_2__c = String.isNotBlank(approver2Id) ? approver2Id : null
                    );
                    
                    // Set ScoreCard_JSON__c field if it exists
                    try {
                        regionApprover.put('ScoreCard_JSON__c', scorecardJSON);
                    } catch (Exception e) {
                        System.debug('ScoreCard_JSON__c field may not exist: ' + e.getMessage());
                    }
                } else {
                    // Check again if record was created between the check and now (race condition)
                    List<Region_Approver__c> checkAgain = [
                        SELECT Id 
                        FROM Region_Approver__c 
                        WHERE Region__c = :region 
                        LIMIT 1
                    ];
                    
                    if (!checkAgain.isEmpty()) {
                        // Update existing
                        regionApprover = new Region_Approver__c(
                            Id = checkAgain[0].Id,
                            Region__c = region,
                            Approver_1__c = approver1Id,
                            Approver_2__c = String.isNotBlank(approver2Id) ? approver2Id : null
                        );
                        
                        // Set ScoreCard_JSON__c field if it exists
                        try {
                            regionApprover.put('ScoreCard_JSON__c', scorecardJSON);
                        } catch (Exception e) {
                            System.debug('ScoreCard_JSON__c field may not exist: ' + e.getMessage());
                        }
                    } else {
                        // Create new
                        regionApprover = new Region_Approver__c(
                            Region__c = region,
                            Approver_1__c = approver1Id,
                            Approver_2__c = String.isNotBlank(approver2Id) ? approver2Id : null
                        );
                        
                        // Set ScoreCard_JSON__c field if it exists
                        try {
                            regionApprover.put('ScoreCard_JSON__c', scorecardJSON);
                        } catch (Exception e) {
                            System.debug('ScoreCard_JSON__c field may not exist: ' + e.getMessage());
                        }
                    }
                }
            }
            
            upsert regionApprover;
            System.debug('Region Approver saved successfully with JSON. Record ID: ' + regionApprover.Id);
            return regionApprover.Id;
        } catch (Exception e) {
            System.debug('Error saving region approver: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error saving region approver: ' + e.getMessage());
        }
    }
    
    /**
     * Send confirmation email to customer after form submission
     * Uses HTML template from static resource
     * This method calls the @future method to send email asynchronously
     */
    private static void sendSubmissionConfirmationEmail(String submissionId, String leadId) {
        try {
            // Call @future method to send email asynchronously
            sendSubmissionConfirmationEmailAsync(submissionId, leadId);
        } catch (Exception e) {
            System.debug('Error calling sendSubmissionConfirmationEmailAsync: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            // Don't throw - email failure shouldn't break the submission process
        }
    }
    
    /**
     * @future method to send confirmation email asynchronously
     * This ensures emails are sent immediately after the transaction commits
     */
    @future
    private static void sendSubmissionConfirmationEmailAsync(String submissionId, String leadId) {
        try {
            // Query Lead with email
            List<Scorecard_Lead__c> leads = [
                SELECT Id, Name, Email__c, FirstName__c, LastName__c, Company__c
                FROM Scorecard_Lead__c
                WHERE Id = :leadId
                AND Email__c != null
                LIMIT 1
            ];
            
            if (leads.isEmpty()) {
                System.debug('No Scorecard_Lead__c found with email address for ID: ' + leadId);
                return;
            }
            
            Scorecard_Lead__c lead = leads[0];
            
            // Query Submission with Smart_Form_URL__c if available
            List<Scorecard_Submission__c> submissions = [
                SELECT Id, Scorecard_Lead__c, Smart_Form_URL__c
                FROM Scorecard_Submission__c
                WHERE Id = :submissionId
                LIMIT 1
            ];
            
            if (submissions.isEmpty()) {
                System.debug('Submission not found with ID: ' + submissionId);
                return;
            }
            
            Scorecard_Submission__c submission = submissions[0];
            
            // Get HTML email template from static resource
            String htmlBody = getEmailTemplateFromStaticResource('ScorecardSubmissionConfirmationEmailTemplate');
            
            if (String.isBlank(htmlBody)) {
                System.debug('Email template not found in static resource: ScorecardSubmissionConfirmationEmailTemplate');
                return;
            }
            
            // Replace merge fields in HTML template
            String emailBody = replaceMergeFieldsForConfirmation(htmlBody, lead, submission);
            
            // Create email message
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ lead.Email__c });
            email.setSubject('Distributor Scorecard Form Submission Confirmation');
            email.setHtmlBody(emailBody);
            email.setSaveAsActivity(false); // Set to false to avoid creating email activity
            
            // Send email
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
            
            if (results[0].isSuccess()) {
                System.debug('Confirmation email sent successfully to: ' + lead.Email__c);
            } else {
                System.debug('Failed to send confirmation email. Error: ' + JSON.serialize(results[0].getErrors()));
            }
            
        } catch (Exception e) {
            System.debug('Error in sendSubmissionConfirmationEmailAsync: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            // Don't throw - email failure shouldn't break the submission process
        }
    }
    
    /**
     * Get HTML email template from static resource
     */
    private static String getEmailTemplateFromStaticResource(String resourceName) {
        try {
            StaticResource resource = [
                SELECT Id, Body
                FROM StaticResource
                WHERE Name = :resourceName
                LIMIT 1
            ];
            
            if (resource != null && resource.Body != null) {
                return resource.Body.toString();
            }
            
            return null;
        } catch (Exception e) {
            System.debug('Error retrieving static resource ' + resourceName + ': ' + e.getMessage());
            return null;
        }
    }
    
    /**
     * Replace merge fields in HTML email template for submission confirmation
     * Merge fields:
     * {LeadFirstName} - First name of the lead
     * {SmartFormURL} - URL to view the submitted form
     */
    private static String replaceMergeFieldsForConfirmation(String htmlBody, Scorecard_Lead__c lead, Scorecard_Submission__c submission) {
        String result = htmlBody;
        
        // Replace Lead fields
        if (lead.FirstName__c != null) {
            result = result.replace('{LeadFirstName}', lead.FirstName__c);
        } else {
            result = result.replace('{LeadFirstName}', '');
        }
        
        // Replace Submission fields - Smart Form URL
        String smartFormUrl = '';
        if (submission.Smart_Form_URL__c != null && String.isNotBlank(submission.Smart_Form_URL__c)) {
            smartFormUrl = submission.Smart_Form_URL__c;
        } else {
            // Construct URL from org domain and lead ID
            // String orgUrl = URL.getOrgDomainUrl().toExternalForm();
            // smartFormUrl = orgUrl + '/lightning/n/Scorecard_Form?leadId=' + submission.Scorecard_Lead__c;
            System.debug('Smart_Form_URL__c is empty, using constructed URL: ' + smartFormUrl);
        }
        result = result.replace('{SmartFormURL}', smartFormUrl);
        
        return result;
    }

}