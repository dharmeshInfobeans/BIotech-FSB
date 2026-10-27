import { LightningElement, wire, track,api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import getScorecardStructure from '@salesforce/apex/ScorecardFormController.getScorecardStructure';
import submitScorecardForm from '@salesforce/apex/ScorecardFormController.submitScorecardForm';
import saveDraftScorecard from '@salesforce/apex/ScorecardFormController.saveDraftScorecard';
import getSubmissionStatus from '@salesforce/apex/ScorecardFormController.getSubmissionStatus';
import getLeadDetails from '@salesforce/apex/ScorecardFormController.getLeadDetails';
import getDraftSubmissionData from '@salesforce/apex/ScorecardFormController.getDraftSubmissionData';
import getSubmissionData from '@salesforce/apex/ScorecardFormController.getSubmissionData';
import getRegionScorecardJSON from '@salesforce/apex/ScorecardFormController.getRegionScorecardJSON';
import { QUESTION_TEXT_TRANSLATIONS, SECTION_LABEL_TRANSLATIONS } from './top_Score_Card_TransLang';
import biotechLogo from '@salesforce/resourceUrl/biotech_Logo';
import hasEditSubmittedPermission from '@salesforce/customPermission/Edit_Submitted_Scorecard';


export default class Top_Score_Card extends LightningElement {
    logoUrl = biotechLogo;
   
    @track regionalScorecardJson;
    @track sections = [];
    @track selectedSectionKey = '';
    @track formData = {};
    @track isLoading = true;
    @track accountName = '';
    @track contactName = '';
    @track contactEmail = '';
    @track contactPhone = '';
    @track region = ''; // Track region from Lead
    @track leadId = '';
    @track showConfirmModal = false;
    @track isSubmitted = false;
    @track submissionStatus = null;
    @track validationErrors = [];
    @track showThankYou = false; // Track if form was just submitted successfully
    @track isInitialLoad = true; // Track if this is the initial page load
    @track isReadOnly = false; // Track if form should be in read-only mode
    hasEditPermission = hasEditSubmittedPermission; // <-- Make sure this line exists
    isInternalUser = '';
    connectedCallback() {
        this.userLang = this.getUserLanguage();
        this.getUrlParameters();
        // checkSubmissionStatus will be called from getUrlParameters if leadId is available

    }

        _recordId;
    @api
    get recordId() {
        return this._recordId;
    }
    set recordId(value) {
        this._recordId = value;
        if (value) {
            this.leadId = value;
            this.fetchLeadDetails();
            this.checkSubmissionStatus();
        }
    }
    // Add this helper method inside the class:
    handleCloseModal() {
        if (this.recordId) {
            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }
    
    checkSubmissionStatus() {
    if (!this.leadId) {
        return;
    }
    
    getSubmissionStatus({ leadId: this.leadId })
        .then(status => {
            this.submissionStatus = status;
            console.error(' checking submission status:');
            
            if (this.showThankYou) {
                return;
            }
            
            if (!status) {
                this.isSubmitted = false;
                this.showThankYou = false;
                this.isReadOnly = false;
            } else {
                const normalizedStatus = status.trim();
                const statusLower = normalizedStatus.toLowerCase();
                
                this.isSubmitted = false;
                this.showThankYou = false;
                
                // Determine if this is an internal Salesforce user (opened via Quick Action button)
                const isInternalUserYes = !!this.isInternalUser; 
                
                if (isInternalUserYes) {
                    // Salesforce User Rules:
                    console.log('this.hasEditPermission',this.hasEditPermission);
                    if (this.hasEditPermission) {
                        this.isReadOnly = false; // User has the Permission Set -> Can Edit
                    } else {
                        this.isReadOnly = true;  // User does NOT have the Permission Set -> View Only
                    }
                } else {
                    // Portal User Rules (remains exactly as it is now):
                    if (statusLower === 'draft' || statusLower === 'send') {
                        this.isReadOnly = false; // Portal users can edit Draft/Send
                    } else {
                        this.isReadOnly = true;  // Portal users cannot edit other statuses
                    }
                }
            }
            this.isInitialLoad = false;
        })
        .catch(error => {
            console.error('Error checking submission status:', error);
            this.isInitialLoad = false;
        });
}
    // checkSubmissionStatus() {
    //     if (!this.leadId) {
    //         return;
    //     }
        
    //     getSubmissionStatus({ leadId: this.leadId })
    //         .then(status => {
    //             this.submissionStatus = status;
    //             console.log('Submission Status received:', status, 'Type:', typeof status, 'isInitialLoad:', this.isInitialLoad);
                
    //             // Don't overwrite thank you message if form was just submitted
    //             if (this.showThankYou) {
    //                 console.log('Thank you message is showing, not checking status again');
    //                 return;
    //             }
                
    //             // Show form for all statuses - editable only for "Draft" or "Send", read-only for others
    //             // Allow editing if status is "Draft", "Send", or null (no submission exists)
                
    //             if (!status) {
    //                 // No status - show form as editable
    //                 this.isSubmitted = false;
    //                 this.showThankYou = false;
    //                 this.isReadOnly = false;
    //             } else {
    //                 // Normalize status for comparison (trim and case-insensitive)
    //                 const normalizedStatus = status.trim();
    //                 const statusLower = normalizedStatus.toLowerCase();
                    
    //                 // Show form for all statuses
    //                 this.isSubmitted = false; // Always show form, not the "already submitted" message
    //                 this.showThankYou = false;
                    
    //                 // Set read-only mode based on status
    //                 if (statusLower === 'draft' || statusLower === 'send') {
    //                     // Editable for Draft or Send status
    //                     this.isReadOnly = false;
    //                 } else {
    //                     // Read-only for Submitted or any other status
    //                     this.isReadOnly = true;
    //                 }
    //             }
                
    //             // Mark that initial load is complete
    //             this.isInitialLoad = false;
                
    //             console.log('Final isSubmitted value:', this.isSubmitted, 'showThankYou:', this.showThankYou, 'for status:', status);
    //         })
    //         .catch(error => {
    //             console.error('Error checking submission status:', error);
    //             // Continue loading form if status check fails
    //             this.isInitialLoad = false;
    //         });
    // }

    getUrlParameters() {
        // Get URL parameters from the current page URL
        const urlParams = new URLSearchParams(window.location.search);
        console.log('URL Parameters:', urlParams.toString());
        // Extract Lead ID (can be 'leadId', 'LeadId', 'id', or 'Id')
        this.leadId = urlParams.get('c__recordId') || urlParams.get('leadId') || urlParams.get('LeadId') || 
                      urlParams.get('id') || urlParams.get('Id') || '';
        
        this.isInternalUser = urlParams.get('c__recordId');
        // Extract Account name (handle both "Account name" and "Account%20name" formats)
        const accountNameParam = urlParams.get('Account name') || urlParams.get('Account%20name') || '';
        
        // Extract First name and Last name
        const firstName = urlParams.get('First name') || urlParams.get('First%20name') || '';
        const lastName = urlParams.get('Last name') || urlParams.get('Last%20name') || '';
        
        // Extract email and phone
        this.contactEmail = urlParams.get('email') || '';
        this.contactPhone = urlParams.get('phone') || '';
        
        // Combine First name + Last name for Contact Name
        const nameParts = [];
        if (firstName) nameParts.push(firstName);
        if (lastName) nameParts.push(lastName);
        this.contactName = nameParts.join(' ').trim();
        
        // Set Account Name from URL parameter or use default
        this.accountName = accountNameParam || 'Acme Private Limited';
        
        console.log('URL Parameters extracted - Lead ID:', this.leadId);
        
        console.log('URL Parameters:', {
            accountName: this.accountName,
            firstName: firstName,
            lastName: lastName,
            contactName: this.contactName,
            email: this.contactEmail,
            phone: this.contactPhone
        });
        
        // Fetch Lead details and check submission status after extracting leadId
        if (this.leadId) {
            this.fetchLeadDetails();
            this.checkSubmissionStatus();
        }
    }
    
    fetchLeadDetails() {
        if (!this.leadId) {
            return;
        }
        
        getLeadDetails({ leadId: this.leadId })
            .then(result => {
                console.log('Lead Details fetched:', result);
                
                // Update account information from Lead record
                if (result.accountName) {
                    this.accountName = result.accountName;
                }
                
                if (result.contactName) {
                    this.contactName = result.contactName;
                }
                
                if (result.email) {
                    this.contactEmail = result.email;
                }
                
                if (result.phone) {
                    this.contactPhone = result.phone;
                }
                
                if (result.region) {
                    this.region = result.region;
                }
            })
            .catch(error => {
                console.error('Error fetching lead details:', error);
                // Continue with form load even if lead details fetch fails
            });
    }
    decodeHtml(htmlString) {
    const txt = document.createElement('textarea');
    txt.innerHTML = htmlString;
    return txt.value;
}
    loadSubmissionData() {
        if (!this.leadId) {
            return;
        }
        
        // Ensure sections are loaded before populating form data
        if (!this.sections || this.sections.length === 0) {
            console.log('Sections not loaded yet, waiting...');
            setTimeout(() => {
                this.loadSubmissionData();
            }, 100);
            return;
        }
        
        getSubmissionData({ leadId: this.leadId, draftOnly: false })
            .then(submissionJson => {
                if (!submissionJson) {
                    console.log('No submission data found');
                    return;
                }
                
                console.log('Loading submission data for read-only mode');
                this.populateFormFromJson(submissionJson);
            })
            .catch(error => {
                console.error('Error loading submission data:', error);
                this.showToast('Error', 'Failed to load submission data: ' + (error.body?.message || error.message), 'error');
            });
    }

    loadDraftData() {
        if (!this.leadId) {
            return;
        }
        
        getDraftSubmissionData({ leadId: this.leadId })
            .then(draftJson => {
                if (!draftJson) {
                    console.log('No draft data found');
                    return;
                }
                
                this.populateFormFromJson(draftJson);
            })
            .catch(error => {
                console.error('Error loading draft data:', error);
            });
    }
    
    populateFormFromJson(jsonString) {
        try {
            //console.log('JSON received:', JSON.stringify(jsonString));
            
            // Clean the JSON string before parsing (handle HTML entities and malformed JSON)
            const decodedJson = this.decodeHtml(jsonString);
            
            // Parse the cleaned JSON string
           // console.log('Cleaned JSON:', decodedJson);
            const submissionData = JSON.parse(decodedJson);
            
            // console.log('Answers count:', submissionData.answers ? submissionData.answers.length : 0);
            // console.log('First answer:', submissionData.answers ? submissionData.answers[0] : null);
            // console.log('Parsed submission data:', submissionData);
            
            // Populate formData with submission answers
            if (submissionData.answers && Array.isArray(submissionData.answers)) {
                submissionData.answers.forEach(answer => {
                    const questionKey = answer.questionKey;
                    if (questionKey) {
                        // Get the question to determine question type
                        // Use originalOptions if available (before filtering), otherwise use options
                        const question = this.findQuestionByKey(questionKey);
                                
                        if (question) {
                            // Get original options (before filtering) for matching
                            const optionsToMatch = question.originalOptions || question.options || [];
                            
                            // Use selectedOptionValues if available (contains optionKey directly)
                            // Otherwise fallback to selectedOptionKeys (contains labels)
                            if (answer.selectedOptionValues && Array.isArray(answer.selectedOptionValues) && answer.selectedOptionValues.length > 0) {
                                // Use selectedOptionValues which has optionKey
                                if (question.questionType === 'Picklist' || question.questionType === 'Radio') {
                                    // Single select - use first option key
                                    const firstOption = answer.selectedOptionValues[0];
                                    if (firstOption && firstOption.optionKey) {
                                        this.formData[questionKey] = firstOption.optionKey;
                                    }
                                } else if (question.questionType === 'Checkbox') {
                                    // Multi-select - use array of option keys
                                    const selectedOptions = answer.selectedOptionValues
                                        .map(opt => opt.optionKey)
                                        .filter(key => key != null);
                                    if (selectedOptions.length > 0) {
                                        this.formData[questionKey] = selectedOptions;
                                    }
                                }
                            } else if (answer.selectedOptionKeys && Array.isArray(answer.selectedOptionKeys) && answer.selectedOptionKeys.length > 0) {
                                // Fallback: Match labels to find option keys using original options
                                if (question.questionType === 'Picklist' || question.questionType === 'Radio') {
                                    // Single select - find option by label
                                    const selectedLabel = answer.selectedOptionKeys[0];
                                    const matchingOption = optionsToMatch.find(opt => 
                                        opt.optionLabel === selectedLabel || opt.Answer === selectedLabel || opt.optionKey === selectedLabel
                                    );
                                    if (matchingOption) {
                                        this.formData[questionKey] = matchingOption.optionKey;
                                    }
                                } else if (question.questionType === 'Checkbox') {
                                    // Multi-select - find options by labels
                                    const selectedOptions = [];
                                    answer.selectedOptionKeys.forEach(label => {
                                        const matchingOption = optionsToMatch.find(opt => 
                                            opt.optionLabel === label || opt.Answer === label || opt.optionKey === label
                                        );
                                        if (matchingOption) {
                                            selectedOptions.push(matchingOption.optionKey);
                                        }
                                    });
                                    if (selectedOptions.length > 0) {
                                        this.formData[questionKey] = selectedOptions;
                                    }
                                }
                            }
                            
                            // Store score if available
                            if (answer.score !== undefined && answer.score !== null) {
                                if (!this.formData.scores) {
                                    this.formData.scores = {};
                                }
                                this.formData.scores[questionKey] = answer.score;
                            }
                            
                            // Handle ifYesCount (for "If Yes, How many" text input)
                            if (answer.ifYesCount !== undefined && answer.ifYesCount !== null && answer.ifYesCount !== '') {
                                const countKey = questionKey + '_count';
                                this.formData[countKey] = answer.ifYesCount;
                            }
                        }
                    }
                });
                
                // Trigger re-render to update checked states after formData is populated
                // This must be called after formData is fully populated
                this.updateCheckedStates();
                this.updateQuestionClasses();
                
               // console.log('Form data populated from submission:', JSON.stringify(this.formData));
                if (!this.isReadOnly) {
                    this.showToast('Info', 'Draft data loaded successfully', 'info');
                }
            }
        } catch (error) {
            console.error('Error parsing submission JSON:', error);
            console.error('Error details:', error.message, error.stack);
            this.showToast('Error', 'Failed to load submission data', 'error');
        }
    }
    
    findQuestionByKey(questionKey) {
        for (const section of this.sections) {
            if (section.questions) {
                const question = section.questions.find(q => q.questionKey === questionKey);
                if (question) {
                    return question;
                }
            }
        }
        return null;
    }
    
    /**
     * Clean JSON string to handle HTML entities and malformed JSON
     * Similar to the Apex cleanJsonString method in ScorecardReviewController
     */
    // cleanJsonString(jsonString) {
    //     if (!jsonString || typeof jsonString !== 'string') {
    //         return jsonString;
    //     }
        
    //     let cleaned = jsonString.trim();
        
    //     console.log('Original JSON string length:', cleaned.length);
    //     console.log('Original JSON starts with:', cleaned.substring(0, 100));
    //     console.log('Original JSON ends with:', cleaned.substring(Math.max(0, cleaned.length - 100)));
        
    //     // First, decode HTML entities using textarea element
    //     // This is the most reliable method for decoding HTML entities
    //     try {
    //         const textarea = document.createElement('textarea');
    //         textarea.innerHTML = cleaned;
    //         cleaned = textarea.value || textarea.textContent || cleaned;
    //         console.log('After HTML entity decoding, length:', cleaned.length);
    //     } catch (e) {
    //         console.warn('Failed to decode HTML entities using textarea, using manual replacement:', e);
    //         // Fallback: Manual replacement of HTML entities (order matters)
    //         cleaned = cleaned.replace(/&amp;/g, '&');  // Must be first
    //         cleaned = cleaned.replace(/&quot;/g, '"');
    //         cleaned = cleaned.replace(/&lt;/g, '<');
    //         cleaned = cleaned.replace(/&gt;/g, '>');
    //         cleaned = cleaned.replace(/&apos;/g, "'");
    //         cleaned = cleaned.replace(/&#39;/g, "'");
    //         cleaned = cleaned.replace(/&#x27;/g, "'");
    //         cleaned = cleaned.replace(/&#x2F;/g, '/');
    //         cleaned = cleaned.replace(/&nbsp;/g, ' ');
    //     }
        
    //     // Remove any leading/trailing whitespace or non-printable characters
    //     cleaned = cleaned.replace(/^[\s\u00A0]+/, '').replace(/[\s\u00A0]+$/, '');
        
    //     // Find the start of JSON (first { character)
    //     if (!cleaned.startsWith('{')) {
    //         const startIndex = cleaned.indexOf('{');
    //         if (startIndex >= 0) {
    //             cleaned = cleaned.substring(startIndex);
    //             console.log('Trimmed to start at index:', startIndex);
    //         }
    //     }
        
    //     // Find the proper end of JSON by counting braces and brackets
    //     // This handles nested objects and arrays correctly
    //     // The JSON structure is typically: { "answers": [...] }
    //     // So we need to find the } that closes the root object when both counts are 0
    //     let braceCount = 0;
    //     let bracketCount = 0;
    //     let inString = false;
    //     let escapeNext = false;
    //     let endIndex = -1;
        
    //     // Track the positions where we have balanced brackets but not yet closed root object
    //     // This helps us find the correct end when JSON might be cut off
    //     let lastBalancedBracketIndex = -1;
    //     let lastBalancedBraceIndex = -1;
        
    //     for (let i = 0; i < cleaned.length; i++) {
    //         const char = cleaned[i];
            
    //         if (escapeNext) {
    //             escapeNext = false;
    //             continue;
    //         }
            
    //         if (char === '\\') {
    //             escapeNext = true;
    //             continue;
    //         }
            
    //         if (char === '"') {
    //             inString = !inString;
    //             continue;
    //         }
            
    //         if (inString) {
    //             continue;
    //         }
            
    //         if (char === '{') {
    //             braceCount++;
    //         } else if (char === '}') {
    //             braceCount--;
    //             // Track the last } where we still have balanced brackets
    //             if (bracketCount === 0 && braceCount >= 0) {
    //                 lastBalancedBraceIndex = i;
    //             }
    //             // When we close the root object (braceCount === 0) and all brackets are closed, this is the end
    //             if (braceCount === 0 && bracketCount === 0) {
    //                 endIndex = i;
    //                 break; // Found the end of root JSON object
    //             }
    //         } else if (char === '[') {
    //             bracketCount++;
    //         } else if (char === ']') {
    //             bracketCount--;
    //             // Track the last ] where brackets are balanced (bracketCount === 0)
    //             // This helps us identify where arrays close before the root object closes
    //             if (bracketCount === 0 && braceCount > 0) {
    //                 lastBalancedBracketIndex = i;
    //             }
    //         }
    //     }
        
    //     // If we found a proper end (all braces and brackets closed), use it
    //     if (endIndex >= 0) {
    //         cleaned = cleaned.substring(0, endIndex + 1);
    //         console.log('Found proper JSON end at index:', endIndex, 'ending with:', cleaned.substring(Math.max(0, cleaned.length - 5)));
    //     } else {
    //         // We didn't find a perfect match - JSON might be cut off or malformed
    //         // Try to reconstruct it based on what we found
            
    //         // If we have a balanced bracket and a brace after it, use that brace
    //         if (lastBalancedBracketIndex >= 0 && lastBalancedBraceIndex > lastBalancedBracketIndex) {
    //             cleaned = cleaned.substring(0, lastBalancedBraceIndex + 1);
    //             console.log('Using balanced brace after bracket at index:', lastBalancedBraceIndex);
    //         } 
    //         // If we only found a balanced bracket but no brace after, try to append }
    //         else if (lastBalancedBracketIndex >= 0 && cleaned.startsWith('{')) {
    //             // We have an array that closed, but the root object hasn't closed
    //             // Check if there's a } after the last bracket
    //             const braceAfterBracket = cleaned.indexOf('}', lastBalancedBracketIndex);
    //             if (braceAfterBracket >= 0) {
    //                 cleaned = cleaned.substring(0, braceAfterBracket + 1);
    //                 console.log('Using brace found after balanced bracket at index:', braceAfterBracket);
    //             } else {
    //                 // Append the missing }
    //                 cleaned = cleaned.substring(0, lastBalancedBracketIndex + 1) + '}';
    //                 console.log('Appended missing } after bracket at index:', lastBalancedBracketIndex);
    //             }
    //         }
    //         // Fallback: use last closing brace
    //         else if (lastBalancedBraceIndex >= 0) {
    //             cleaned = cleaned.substring(0, lastBalancedBraceIndex + 1);
    //             console.log('Using last balanced brace at index:', lastBalancedBraceIndex);
    //         }
    //         // Last resort: find the last } or ]
    //         else {
    //             const lastBraceIndex = cleaned.lastIndexOf('}');
    //             const lastBracketIndex = cleaned.lastIndexOf(']');
                
    //             if (lastBraceIndex >= 0 && lastBracketIndex >= 0) {
    //                 // We have both, use the later one (but should be brace for root object)
    //                 if (lastBracketIndex > lastBraceIndex) {
    //                     // Bracket comes after brace - might be malformed, but append }
    //                     cleaned = cleaned.substring(0, lastBracketIndex + 1) + '}';
    //                     console.log('Appended } after last bracket');
    //                 } else {
    //                     // Brace comes after bracket - this is correct structure
    //                     cleaned = cleaned.substring(0, lastBraceIndex + 1);
    //                     console.log('Using last brace at index:', lastBraceIndex);
    //                 }
    //             } else if (lastBraceIndex >= 0) {
    //                 cleaned = cleaned.substring(0, lastBraceIndex + 1);
    //                 console.log('Using last brace at index:', lastBraceIndex);
    //             } else if (lastBracketIndex >= 0 && cleaned.startsWith('{')) {
    //                 // We have a bracket but need to append }
    //                 cleaned = cleaned.substring(0, lastBracketIndex + 1) + '}';
    //                 console.log('Appended } after last bracket');
    //             }
    //         }
    //     }
        
    //     // Final verification: ensure JSON ends with } for object or ] for array
    //     if (cleaned.startsWith('{') && !cleaned.endsWith('}')) {
    //         // Try to append } if missing
    //         if (!cleaned.endsWith(']}')) {
    //             cleaned = cleaned + '}';
    //             console.log('Appended missing } at the end');
    //         }
    //     } else if (cleaned.startsWith('[') && !cleaned.endsWith(']')) {
    //         cleaned = cleaned + ']';
    //         console.log('Appended missing ] at the end');
    //     }
        
    //     // Final validation - ensure JSON structure starts correctly
    //     if (!cleaned.startsWith('{') && !cleaned.startsWith('[')) {
    //         console.warn('Cleaned JSON does not start with { or [, returning original');
    //         return jsonString.trim();
    //     }
        
    //     console.log('Final cleaned JSON length:', cleaned.length);
    //     console.log('Final cleaned JSON ends with:', cleaned.substring(Math.max(0, cleaned.length - 50)));
        
    //     return cleaned;
    // }

    getUserLanguage() {
        const parts = window.location.pathname.split('/');
        const langFull = parts[2];   // e.g. nl-NL, pt-PT, fr-FR

        if (!langFull) {
            return 'en';
        }

        // Extract first 2 letters
        const langShort = langFull.substring(0, 2);

        return langShort;
    }



    applyTranslations(sections) {
    sections.forEach(section => {
        // Translate section label
        const originalSectionLabel = section.sectionLabel;
        if (
            SECTION_LABEL_TRANSLATIONS[originalSectionLabel] &&
            SECTION_LABEL_TRANSLATIONS[originalSectionLabel][this.userLang]
        ) {
            section.sectionLabel =
                SECTION_LABEL_TRANSLATIONS[originalSectionLabel][this.userLang];
        }
        
        // Translate question text
        section.questions.forEach(q => {
            const original = q.questionText;
            if (
                QUESTION_TEXT_TRANSLATIONS[original] &&
                QUESTION_TEXT_TRANSLATIONS[original][this.userLang]
            ) {
                q.questionText =
                    QUESTION_TEXT_TRANSLATIONS[original][this.userLang];
            }
        });
    });
    }

    // Getter for region to use in wire method (reactive parameter)
    get regionParam() {
        return this.region;
    }

    // Wire method to fetch region scorecard JSON
    @wire(getRegionScorecardJSON, { region: '$regionParam' })
    wiredRegionScorecardJSON({ error, data }) {
        if (data) {
            try {
                // data is already a JSON string from Apex, so parse it directly
                let regionalScorecardJson;
                if (typeof data === 'string') {
                    // Clean HTML entities if present
                    const cleanedJson = this.decodeHtml(data);
                    regionalScorecardJson = JSON.parse(cleanedJson);
                } else {
                    // If it's already an object, use it directly
                    regionalScorecardJson = data;
                }
                
                // Apply translations
                this.applyTranslations(regionalScorecardJson);
               // console.log('Region Scorecard JSON fetched:', regionalScorecardJson);
                
                // Process the JSON and build sections
                // Filter to show only active questions
                this.sections = regionalScorecardJson.map(section => ({
                ...section,
                tabClass: section.sectionKey === this.selectedSectionKey ? 'tab-item tab-active' : 'tab-item',
                questions: section.questions
                    .filter(question => question.isActive === true) // Only show active questions
                    .map(question => {
                        // Check if this question has "If Yes, How many" option - filter it out from display
                        const hasIfYesOption = this.hasIfYesHowManyOption(question);
                        let filteredOptions = question.options || [];
                        
                        if (hasIfYesOption && filteredOptions.length > 0) {
                            // Filter out the "If Yes, How many" option
                            filteredOptions = filteredOptions.filter(opt => {
                                const isIfYesOption = (opt.Answer && opt.Answer.toLowerCase().includes('if yes')) ;
                                                     //||(opt.optionLabel && opt.optionLabel.toLowerCase().includes('if yes'));
                                                    //  ||(opt.optionKey && opt.optionKey.includes('_O3'));
                                return !isIfYesOption;
                            });
                        }
                        
                     //   console.log('Question:', question.questionKey, 'Original options:', question.options?.length, 'Filtered options:', filteredOptions.length);
                        
                        return {
                        ...question,
                            originalOptions: question.options, // Store original options for hasIfYesHowManyOption check
                        isPicklist: question.questionType === 'Picklist',
                        isCheckbox: question.questionType === 'Checkbox',
                        questionClass: 'question-container',
                        labelClass: 'question-label',
                            showTextInput: false, // Will be updated by updateCheckedStates
                            options: filteredOptions.map(option => ({
                            ...option,
                                isSelected: this.getOptionSelectedState(option, question),
                                isYesOption: this.isYesOption(option) // Add flag to identify "Yes" option
                        }))
                        };
                    })
            }));
            
            // Update showTextInput property after initial mapping
            this.updateCheckedStates();
            
            if (this.sections.length > 0) {
                this.selectedSectionKey = this.sections[0].sectionKey;
                this.updateTabClasses();
            }
            this.isLoading = false;
           // console.log('getScorecardStructure data:', JSON.stringify(this.sections));
            
            // Load submission data after sections are loaded
            // If status is Draft, load as editable draft
            // If status is other than Draft/Send, load in read-only mode
            if (this.submissionStatus) {
                const statusLower = this.submissionStatus.toLowerCase().trim();
                // Use setTimeout to ensure sections are fully processed
                setTimeout(() => {
                    if (statusLower === 'draft') {
                        this.loadDraftData();
                    } else {
                        // Load submission data for read-only mode
                        this.loadSubmissionData();
                    }
                }, 300);
            }
            } catch (parseError) {
                console.error('Error parsing region scorecard JSON:', parseError);
                console.error('Data received:', data);
                this.isLoading = false;
                // If parsing fails, fallback to default structure (would need to call getScorecardStructure)
            }
        } else if (error) {
            console.error('Error fetching region scorecard JSON:', error);
            this.isLoading = false;
        } else if (data === null || data === undefined || data === '') {
            // No data returned (region might not be set or no JSON exists)
            // This is expected if region is empty or JSON doesn't exist yet
           // console.log('No region scorecard JSON found for region:', this.region);
            this.isLoading = false;
            // Note: If region JSON doesn't exist, sections will remain empty
            // You may want to fallback to default structure in this case
        }
    }

    // @wire(getScorecardStructure)
    // wiredCoreCard({ error, data }) {
    //     if (data) {
    //         let parseData = JSON.parse(JSON.stringify(data));
    //         console.log('getScorecardStructure Beforedata:', JSON.stringify(parseData));
    //         if(this.regionalScorecardJson){
    //             console.log('Using regional scorecard JSON override');
    //             parseData = this.regionalScorecardJson;
    //         }
    //         this.applyTranslations(parseData);
    //         console.log('getScorecardStructure data:', JSON.stringify(parseData));
    //         // Process data to add question type flags and checked states
    //         // Filter to show only active questions
    //         // if(this.regionalScorecardJson){
    //         //     console.log('Using regional scorecard JSON override');
    //         //     parseData = this.regionalScorecardJson;
    //         // }
    //         this.sections = parseData.map(section => ({
    //             ...section,
    //             tabClass: section.sectionKey === this.selectedSectionKey ? 'tab-item tab-active' : 'tab-item',
    //             questions: section.questions
    //                 .filter(question => question.isActive === true) // Only show active questions
    //                 .map(question => {
    //                     // Check if this question has "If Yes, How many" option - filter it out from display
    //                     const hasIfYesOption = this.hasIfYesHowManyOption(question);
    //                     let filteredOptions = question.options || [];
                        
    //                     if (hasIfYesOption && filteredOptions.length > 0) {
    //                         // Filter out the "If Yes, How many" option
    //                         filteredOptions = filteredOptions.filter(opt => {
    //                             const isIfYesOption = (opt.Answer && opt.Answer.toLowerCase().includes('if yes')) ;
    //                                                  //||(opt.optionLabel && opt.optionLabel.toLowerCase().includes('if yes'));
    //                                                 //  ||(opt.optionKey && opt.optionKey.includes('_O3'));
    //                             return !isIfYesOption;
    //                         });
    //                     }
                        
    //                     console.log('Question:', question.questionKey, 'Original options:', question.options?.length, 'Filtered options:', filteredOptions.length);
                        
    //                     return {
    //                     ...question,
    //                         originalOptions: question.options, // Store original options for hasIfYesHowManyOption check
    //                     isPicklist: question.questionType === 'Picklist',
    //                     isCheckbox: question.questionType === 'Checkbox',
    //                     questionClass: 'question-container',
    //                     labelClass: 'question-label',
    //                         showTextInput: false, // Will be updated by updateCheckedStates
    //                         options: filteredOptions.map(option => ({
    //                         ...option,
    //                             isSelected: this.getOptionSelectedState(option, question),
    //                             isYesOption: this.isYesOption(option) // Add flag to identify "Yes" option
    //                     }))
    //                     };
    //                 })
    //         }));
            
    //         // Update showTextInput property after initial mapping
    //         this.updateCheckedStates();
            
    //         if (this.sections.length > 0) {
    //             this.selectedSectionKey = this.sections[0].sectionKey;
    //             this.updateTabClasses();
    //         }
    //         this.isLoading = false;
    //         console.log('getScorecardStructure data:', JSON.stringify(this.sections));
            
    //         // Load submission data after sections are loaded
    //         // If status is Draft, load as editable draft
    //         // If status is other than Draft/Send, load in read-only mode
    //         if (this.submissionStatus) {
    //             const statusLower = this.submissionStatus.toLowerCase().trim();
    //             // Use setTimeout to ensure sections are fully processed
    //             setTimeout(() => {
    //                 if (statusLower === 'draft') {
    //                     this.loadDraftData();
    //                 } else {
    //                     // Load submission data for read-only mode
    //                     this.loadSubmissionData();
    //                 }
    //             }, 300);
    //         }
    //     } else if (error) {
    //         console.error('getScorecardStructure error:', error);
    //         this.isLoading = false;
    //     }
    // }

    updateTabClasses() {
        this.sections = this.sections.map(section => ({
            ...section,
            tabClass: section.sectionKey === this.selectedSectionKey ? 'tab-item tab-active' : 'tab-item',
            questions: section.questions.map(question => {
                const hasError = this.validationErrors.some(err => err.questionKey === question.questionKey);
                return {
                    ...question,
                    questionClass: hasError ? 'question-container question-error' : 'question-container',
                    labelClass: hasError ? 'question-label question-label-error' : 'question-label'
                };
            })
        }));
    }

    getOptionSelectedState(option, question) {
        if (question.questionType === 'Picklist') {
            return this.formData[question.questionKey] === option.optionKey;
        } else if (question.questionType === 'Checkbox') {
            const selectedOptions = this.formData[question.questionKey] || [];
            return selectedOptions.includes(option.optionKey);
        }
        return false;
    }

    get selectedSection() {
        return this.sections.find(section => section.sectionKey === this.selectedSectionKey);
    }

    get currentSectionIndex() {
        return this.sections.findIndex(
            section => section.sectionKey === this.selectedSectionKey
        );
    }

    get isFirstSection() {
        return this.currentSectionIndex === 0;
    }

    get isLastSection() {
        return this.currentSectionIndex === this.sections.length - 1;
    }

    handleTabClick(event) {
        const sectionKey = event.currentTarget.dataset.sectionKey;
        if (sectionKey) {
            this.selectedSectionKey = sectionKey;
            this.updateTabClasses();
        }
    }


    handleOptionChange(event) {
        const questionKey = event.target.dataset.questionKey;
        const optionKey = event.target.value;
        const score = parseFloat(event.target.dataset.score);

        // For radio buttons, store single value
        this.formData = { ...this.formData, [questionKey]: optionKey };
        
        // Store score for calculation
        if (!this.formData.scores) {
            this.formData.scores = {};
        }
        this.formData.scores[questionKey] = score;

        // Clear validation error for this question if it exists
        this.clearValidationError(questionKey);

        // If "Yes" is not selected, clear the "If Yes, How many" text input value
        const question = this.findQuestionByKey(questionKey);
        if (question && this.hasIfYesHowManyOption(question)) {
            const isYes = this.isYesSelected(questionKey);
            if (!isYes) {
                // "Yes" is not selected, clear the count value
                const countKey = questionKey + '_count';
                this.formData = { ...this.formData, [countKey]: '' };
            }
        }

        // Update checked state by re-rendering (this will update showTextInput property)
        // Force reactive update by reassigning sections
        this.updateCheckedStates();

        console.log('Form Data:', JSON.stringify(this.formData));
        console.log('Question:', questionKey, 'Option:', optionKey, 'Has IfYes Option:', question ? this.hasIfYesHowManyOption(question) : false, 'Is Yes Selected:', this.isYesSelected(questionKey));
    }

    handleTextInputChange(event) {
        const questionKey = event.target.dataset.questionKey;
        const value = event.target.value;
        const countKey = questionKey + '_count';
        
        this.formData = { ...this.formData, [countKey]: value };
        
        // Update the textInputValue property on the question object for template reactivity
        this.updateCheckedStates();
        
        // Clear validation error for this question if it exists
        this.clearValidationError(questionKey);
        
        console.log('Form Data:', JSON.stringify(this.formData));
    }

    hasIfYesHowManyOption(question) {
        if (!question) {
            return false;
        }
        // Check original options if available, otherwise check current options
        // This ensures we check before filtering happens
        const optionsToCheck = question.originalOptions || question.options;
        if (!optionsToCheck || optionsToCheck.length === 0) {
            return false;
        }
        // Check if any option has "If Yes, How many" in optionLabel, Answer, or optionKey pattern (_O3)
        return optionsToCheck.some(opt => {
            // const hasIfYesInLabel = opt.optionLabel && (
            //     opt.optionLabel.toLowerCase().includes('if yes') || 
            //     opt.optionLabel.toLowerCase().includes('how many') ||
            //     opt.optionLabel === 'If Yes, How many' ||
            //     opt.optionLabel === 'SMS-Q5-O3' ||
            //     opt.optionLabel === 'SMS-Q2-O3' ||
            //     opt.optionLabel === 'SMS-Q1-O3'
            // );
            const hasIfYesInAnswer = opt.Answer && (
                opt.Answer.toLowerCase().includes('if yes') ||
                opt.Answer === 'If Yes, How many'
            );
            //const hasO3Pattern = opt.optionKey && opt.optionKey.includes('_O3');
            
          //  return hasIfYesInLabel || hasIfYesInAnswer; // || hasO3Pattern;
          return hasIfYesInAnswer;
        });
    }

    isYesSelected(questionKey) {
        const selectedValue = this.formData[questionKey];
        if (!selectedValue) {
            return false;
        }
        
        const question = this.findQuestionByKey(questionKey);
        if (!question) {
            return false;
        }
        
        // Find the selected option by optionKey (check original options if available, otherwise use current options)
        const allOptions = question.originalOptions || question.options || [];
        const selectedOption = allOptions.find(opt => opt.optionKey === selectedValue);
        if (!selectedOption) {
            return false;
        }
        
        // Check if the selected option is "Yes" by checking Answer, optionLabel, or optionKey pattern
        // O2 typically means "Yes", O3 means "If Yes, How many"
        const isYes = selectedOption.Answer === 'Yes' || 
                      selectedOption.optionLabel === 'Yes' ||
                      selectedOption.optionLabel === 'SMS-Q5-O2' ||
                      selectedOption.optionLabel === 'SMS-Q2-O2' ||
                      selectedOption.optionLabel === 'SMS-Q1-O2' ||
                      (selectedOption.optionKey && 
                       selectedOption.optionKey.includes('_O2') && 
                       !selectedOption.optionKey.includes('_O3') &&
                       !selectedOption.optionKey.includes('_O1'));
        
        console.log('isYesSelected - Question:', questionKey, 'Selected Value:', selectedValue, 'Is Yes:', isYes, 'Selected Option:', selectedOption);
        return isYes;
    }
    
    isYesOption(option) {
        // Check if an option is the "Yes" option
        return option.Answer === 'Yes' || 
               option.optionLabel === 'Yes' ||
               option.optionLabel === 'SMS-Q5-O2' ||
               option.optionLabel === 'SMS-Q2-O2' ||
               option.optionLabel === 'SMS-Q1-O2' ||
               (option.optionKey && 
                option.optionKey.includes('_O2') && 
                !option.optionKey.includes('_O3') &&
                !option.optionKey.includes('_O1'));
    }

    getTextInputValue(questionKey) {
        const countKey = questionKey + '_count';
        return this.formData[countKey] || '';
    }

    handleCheckboxChange(event) {
        const questionKey = event.target.dataset.questionKey;
        const optionKey = event.target.value;
        const score = parseFloat(event.target.dataset.score);
        const isChecked = event.target.checked;

        // Initialize array if not exists
        if (!this.formData[questionKey]) {
            this.formData[questionKey] = [];
        }

        let updatedOptions = [...(this.formData[questionKey] || [])];

        if (isChecked) {
            // Add option
            if (!updatedOptions.includes(optionKey)) {
                updatedOptions.push(optionKey);
            }
            // Add to score (for checkboxes, we might sum scores)
            if (!this.formData.scores) {
                this.formData.scores = {};
            }
            if (!this.formData.scores[questionKey]) {
                this.formData.scores[questionKey] = 0;
            }
            this.formData.scores[questionKey] += score;
        } else {
            // Remove option
            updatedOptions = updatedOptions.filter(key => key !== optionKey);
            // Subtract from score
            if (this.formData.scores && this.formData.scores[questionKey]) {
                this.formData.scores[questionKey] -= score;
            }
        }

        this.formData = { ...this.formData, [questionKey]: updatedOptions };
        
        // Clear validation error for this question if it exists and has at least one answer
        if (updatedOptions.length > 0) {
            this.clearValidationError(questionKey);
        }
        
        this.updateCheckedStates();

        console.log('Form Data:', JSON.stringify(this.formData));
    }

    updateCheckedStates() {
        // Update checked states in sections
        this.sections = this.sections.map(section => ({
            ...section,
            questions: section.questions.map(question => {
                const hasIfYesOption = this.hasIfYesHowManyOption(question);
                const yesSelected = hasIfYesOption && this.isYesSelected(question.questionKey);
                const countKey = question.questionKey + '_count';
                const textInputValue = this.formData[countKey] || '';
                
                // Filter out "If Yes, How many" option from display if it exists
                const filteredOptions = hasIfYesOption 
                    ? question.options.filter(opt => {
                        const isIfYesOption = (opt.Answer && opt.Answer.toLowerCase().includes('if yes')) ||
                                             (opt.optionLabel && opt.optionLabel.toLowerCase().includes('if yes')) ||
                                             (opt.optionKey && opt.optionKey.includes('_O3'));
                        return !isIfYesOption;
                    })
                    : question.options;
                
                return {
                ...question,
                    originalOptions: question.originalOptions || question.options, // Preserve original options
                    showTextInput: yesSelected, // Show text input if "Yes" is selected and question has "If Yes, How many" option
                    textInputValue: textInputValue, // Store text input value directly on question object for template access
                    options: filteredOptions.map(option => ({
                    ...option,
                        isSelected: this.getOptionSelectedState(option, question),
                        isYesOption: this.isYesOption(option) // Add flag to identify "Yes" option
                }))
                };
            })
        }));
    }

    async handleNext() {
        // Save current form data as draft before navigating (no validation on Next button)
        try {
            await this.saveDraft();
            this.showToast('Draft Saved', 'Your progress has been saved.', 'success');
            
            // Navigate to next section only after draft is saved successfully
            const currentIndex = this.currentSectionIndex;
            
            if (currentIndex < this.sections.length - 1) {
                // Move to next section
                this.selectedSectionKey = this.sections[currentIndex + 1].sectionKey;
                // Update tab classes to reflect the new selected tab
                this.updateTabClasses();
            }
        } catch (error) {
            // If draft save fails, show error but still allow navigation
            console.error('Error saving draft:', error);
            this.showToast('Warning', 'Failed to save draft. Your progress may not be saved. Please try again.', 'warning');
            
            // Still navigate to next section even if draft save fails
            const currentIndex = this.currentSectionIndex;
            if (currentIndex < this.sections.length - 1) {
                this.selectedSectionKey = this.sections[currentIndex + 1].sectionKey;
                this.updateTabClasses();
            }
        }
    }

    handlePrevious() {
        // Navigate to previous section
        const currentIndex = this.currentSectionIndex;
        
        if (currentIndex > 0) {
            // Move to previous section
            this.selectedSectionKey = this.sections[currentIndex - 1].sectionKey;
            // Update tab classes to reflect the new selected tab
            this.updateTabClasses();
        }
    }

    handleSubmit() {
        // Show confirmation modal
        this.showConfirmModal = true;
    }

    handleConfirmSubmit() {
        // Validate mandatory questions before submitting
        if (!this.validateMandatoryQuestions()) {
            // Close modal to show validation errors
            this.showConfirmModal = false;
            return;
        }

        // Close modal first
        this.showConfirmModal = false;
        
        // Submit form (this will save all data as final submission)
        // No need to save draft here since drafts are already saved on Next button clicks
        this.submitForm();
    }

    validateMandatoryQuestions() {
        this.validationErrors = [];
        
        // Check all sections for mandatory questions
        this.sections.forEach(section => {
            if (section.questions) {
                section.questions.forEach(question => {
                    if (question.isMandatory && question.isActive) {
                        const questionKey = question.questionKey;
                        const answer = this.formData[questionKey];
                        
                        // Check if question is answered
                        if (question.isPicklist) {
                            // Radio button - should have a single value
                            if (!answer || answer === '') {
                                this.validationErrors.push({
                                    questionKey: questionKey,
                                    questionText: question.questionText,
                                    sectionKey: section.sectionKey,
                                    sectionLabel: section.sectionLabel
                                });
                            }
                        } else if (question.isCheckbox) {
                            // Checkbox - should have at least one value selected
                            if (!answer || (Array.isArray(answer) && answer.length === 0)) {
                                this.validationErrors.push({
                                    questionKey: questionKey,
                                    questionText: question.questionText,
                                    sectionKey: section.sectionKey,
                                    sectionLabel: section.sectionLabel
                                });
                            }
                        }
                    }
                });
            }
        });

        // If there are validation errors, show them
        if (this.validationErrors.length > 0) {
            const errorCount = this.validationErrors.length;
            const errorMessage = errorCount === 1 
                ? 'Please answer the mandatory question before submitting.' 
                : `Please answer ${errorCount} mandatory questions before submitting.`;
            this.showToast('Validation Error', errorMessage, 'error');
            
            // Update question classes to show errors
            this.updateQuestionClasses();
            
            // Navigate to the first section with an error
            if (this.validationErrors.length > 0) {
                const firstErrorSection = this.validationErrors[0].sectionKey;
                this.selectedSectionKey = firstErrorSection;
                this.updateTabClasses();
            }
            
            return false;
        }

        return true;
    }

    handleCancelSubmit() {
        // Close modal without submitting
        this.showConfirmModal = false;
    }

    saveDraft() {
        // Prepare JSON for draft save (same structure but marked as draft)
        const draftData = this.prepareScorecardAnswerJSON();
        draftData.submissionInfo.isDraft = true;
        
        console.log('Saving draft data:', JSON.stringify(draftData, null, 2));
        
        // Call Apex method to save draft and return promise
        return saveDraftScorecard({ 
            scorecardDataJSON: JSON.stringify(draftData),
            leadId: this.leadId || null
        })
            .then(submissionId => {
                console.log('Draft saved successfully. Submission ID:', submissionId);
                // Only show toast if not called from handleNext (to avoid duplicate messages)
                // The toast will be shown by handleNext if needed
                return submissionId;
            })
            .catch(error => {
                console.error('Error saving draft:', error);
                // Re-throw error so handleNext can handle it
                throw error;
            });
    }

    prepareScorecardAnswerJSON() {
        // Prepare JSON structure for Scorecard_Answer DML operations
        const answerData = {
            // Account and Contact Information
            accountInfo: {
                accountName: this.accountName || '',
                contactName: this.contactName || '',
                contactEmail: this.contactEmail || '',
                contactPhone: this.contactPhone || '',
                language: this.userLang || 'en'
            },
            
            // Submission metadata
            submissionInfo: {
                submittedDate: new Date().toISOString(),
                submittedDateTime: new Date().toISOString(),
                isDraft: false
            },
            
            // Answers array - one record per question
            answers: [],
            
            // Summary scores by section
            sectionScores: {},
            
            // Total score
            totalScore: 0
        };

        // Process each section and question
        this.sections.forEach(section => {
            let sectionScore = 0;
            
            if (section.questions && section.questions.length > 0) {
                section.questions.forEach(question => {
                    if (question.isActive) {
                        const questionKey = question.questionKey;
                        const answerValue = this.formData[questionKey];
                        const questionScore = this.formData.scores && this.formData.scores[questionKey] ? this.formData.scores[questionKey] : 0;
                        
                        // Skip if no answer provided
                        if (answerValue === undefined || answerValue === null || answerValue === '') {
                            return;
                        }
                        
                        // Get selected option values first
                        const selectedOptionValues = this.getSelectedOptionValues(question, answerValue);
                        
                        // Extract option labels from selected options
                        const selectedOptionLabels = selectedOptionValues.map(opt => opt.optionLabel || opt.answerText || '');
                        
                        // Prepare answer record
                        const answerRecord = {
                            // Question Information
                            questionKey: questionKey,
                            questionLabel: question.questionLabel || '',
                            questionText: question.questionText || '',
                            questionType: question.questionType || '',
                            sectionKey: section.sectionKey || '',
                            sectionLabel: section.sectionLabel || '',
                            sectionWeightage: section.weightage || 0,
                            
                            // Answer Information
                            selectedOptionKeys: selectedOptionLabels, // Now contains option labels
                            selectedOptionValues: selectedOptionValues,
                            score: questionScore,
                            
                            // If Yes, How many count value (if applicable)
                            ifYesCount: null,
                            
                            // Metadata
                            isMandatory: question.isMandatory || false,
                            answeredDate: new Date().toISOString()
                        };
                        
                        // Check if this question has "If Yes, How many" option and "Yes" is selected
                        if (this.hasIfYesHowManyOption(question) && this.isYesSelected(questionKey)) {
                            const countKey = questionKey + '_count';
                            const countValue = this.formData[countKey];
                            if (countValue !== undefined && countValue !== null && countValue !== '') {
                                answerRecord.ifYesCount = countValue;
                            }
                        }
                        
                        answerData.answers.push(answerRecord);
                        sectionScore += questionScore;
                    }
                });
            }
            
            // Store section score
            if (section.sectionKey) {
                answerData.sectionScores[section.sectionKey] = {
                    sectionKey: section.sectionKey,
                    sectionLabel: section.sectionLabel || '',
                    weightage: section.weightage || 0,
                    totalScore: sectionScore,
                    weightedScore: section.weightage ? (sectionScore * section.weightage / 100) : sectionScore
                };
                
                // Add to total score
                answerData.totalScore += answerData.sectionScores[section.sectionKey].weightedScore;
            }
        });

        return answerData;
    }

    getSelectedOptionValues(question, answerValue) {
        const values = [];
        const optionKeys = Array.isArray(answerValue) ? answerValue : [answerValue];
        
        optionKeys.forEach(optionKey => {
            question.options.forEach(option => {
                if (option.optionKey === optionKey) {
                    values.push({
                        optionKey: option.optionKey,
                        optionLabel: option.optionLabel || '',
                        answerText: option.Answer || '',
                        score: option.score || 0
                    });
                }
            });
        });
        
        return values;
    }

    submitForm() {
        // Prepare JSON for DML operations
        const scorecardAnswerJSON = this.prepareScorecardAnswerJSON();
        
        console.log('Scorecard Answer JSON for DML:', JSON.stringify(scorecardAnswerJSON, null, 2));
        console.log('Form Data:', JSON.stringify(this.formData));
        
        // Call Apex method to submit scorecard form data
        this.isLoading = true;
        
        console.log('Calling submitScorecardForm with:');
        console.log('leadId:', this.leadId);
        console.log('JSON length:', JSON.stringify(scorecardAnswerJSON).length);
        
        submitScorecardForm({ 
            scorecardDataJSON: JSON.stringify(scorecardAnswerJSON),
            leadId: this.leadId || ''
        })
            .then(submissionId => {
                console.log('Scorecard submitted successfully. Submission ID:', submissionId);
                this.showToast('Success', 'Scorecard submitted successfully!', 'success');
                
                // Show thank you message instead of immediately showing "already submitted"
                this.showThankYou = true;
                this.isSubmitted = false; // Hide the form but show thank you message
                this.isLoading = false;
                this.isInitialLoad = false; // Mark that initial load is complete
                
                // Update status to "Submitted" for future reference
                this.submissionStatus = 'Submitted';

                  setTimeout(() => {
        this.handleCloseModal();
    }, 2000);
            })
            .catch(error => {
                 this.showToast('Error', 'Failed to submit scorecard: ' + (error.body?.message || error.message), 'error');
                console.error('Error submitting scorecard:', error);
               
                this.isLoading = false;
            });
    }

    handleModalClick(event) {
        // Prevent modal from closing when clicking inside the modal container
        event.stopPropagation();
    }

    hasValidationError(questionKey) {
        return this.validationErrors.some(err => err.questionKey === questionKey);
    }

    clearValidationError(questionKey) {
        this.validationErrors = this.validationErrors.filter(err => err.questionKey !== questionKey);
        this.updateQuestionClasses();
    }

    updateQuestionClasses() {
        this.sections = this.sections.map(section => ({
            ...section,
            questions: section.questions.map(question => {
                const hasError = this.validationErrors.some(err => err.questionKey === question.questionKey);
                return {
                    ...question,
                    questionClass: hasError ? 'question-container question-error' : 'question-container',
                    labelClass: hasError ? 'question-label question-label-error' : 'question-label'
                };
            })
        }));
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
    
    // Getter to check if form should be shown
    get showForm() {
        return !this.isSubmitted && !this.showThankYou;
    }
    
    // Getter to check if "already submitted" message should be shown
    get showAlreadySubmitted() {
        return this.isSubmitted && !this.showThankYou;
    }
}