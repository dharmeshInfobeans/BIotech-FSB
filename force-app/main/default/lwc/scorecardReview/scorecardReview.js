import { LightningElement, wire, api, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import { CurrentPageReference } from 'lightning/navigation';
import getSubmissionDetails from '@salesforce/apex/ScorecardReviewController.getSubmissionDetails';
import approveSubmission from '@salesforce/apex/ScorecardReviewController.approveSubmission';
import rejectSubmission from '@salesforce/apex/ScorecardReviewController.rejectSubmission';

const FIELDS = ['Scorecard_Submission__c.Id'];

export default class ScorecardReview extends NavigationMixin(LightningElement) {
    @api recordId; // Submission record ID passed from Quick Action or Record Page
    
    @track submissionData = null;
    @track answersBySection = {};
    @track sectionList = [];
    @track isLoading = true;
    @track isProcessing = false;
    @track comment = '';
    @track showCommentError = false;
    @track actualRecordId = null;
    @track dataLoaded = false;
    
    /**
     * Invoke method for Quick Actions
     * This method is called when the component is invoked as a Quick Action
     */
    @api invoke() {
        // For Quick Actions, recordId should be automatically available
        console.log('Component invoked. recordId:', this.recordId);
        
        if (this.recordId && !this.dataLoaded) {
            this.actualRecordId = this.recordId;
            this.loadSubmissionData();
        } else if (!this.dataLoaded) {
            // Try to get from URL or other sources
            this.getRecordIdFromUrl();
        }
    }
    
    // Wire adapter to get record ID from page context
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data && !this.dataLoaded) {
           // alert('Wired record data: ' + this.recordId);
            this.actualRecordId = this.recordId || data.id;
            if (this.actualRecordId) {
                this.loadSubmissionData();
            }
        } else if (error && !this.dataLoaded) {
            console.error('Error getting record:', error);
            // Try to get recordId from URL parameters
            this.getRecordIdFromUrl();
        }
    }
    
    // Wire adapter to get record ID from page reference
    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference && !this.dataLoaded) {
            console.log('CurrentPageReference:', JSON.stringify(currentPageReference, null, 2));
            
            // Try to get recordId from page state (for Lightning navigation)
            const state = currentPageReference.state || {};
            if (state.recordId) {
                this.actualRecordId = state.recordId;
                console.log('Found recordId in state:', this.actualRecordId);
            } else if (state.c__recordId) {
                this.actualRecordId = state.c__recordId;
                console.log('Found recordId in state.c__recordId:', this.actualRecordId);
            }
            
            // Check all state properties for recordId (sometimes it's in different keys)
            if (!this.actualRecordId && state) {
                for (let key in state) {
                    if (key.toLowerCase().includes('recordid') || key.toLowerCase().includes('record_id')) {
                        this.actualRecordId = state[key];
                        console.log('Found recordId in state key:', key, '=', this.actualRecordId);
                        break;
                    }
                }
            }
            
            // Also check URL attributes for Lightning page navigation
            if (!this.actualRecordId && currentPageReference.attributes) {
                const attrs = currentPageReference.attributes;
                if (attrs.recordId) {
                    this.actualRecordId = attrs.recordId;
                    console.log('Found recordId in attributes:', this.actualRecordId);
                }
                // Check all attributes
                for (let key in attrs) {
                    if (key.toLowerCase().includes('recordid') || key.toLowerCase().includes('record_id')) {
                        this.actualRecordId = attrs[key];
                        console.log('Found recordId in attributes key:', key, '=', this.actualRecordId);
                        break;
                    }
                }
            }
            
            // Check the page reference type and attributes
            if (currentPageReference.type === 'standard__navItemPage' || currentPageReference.type === 'comm__namedPage') {
                // For Lightning navigation, check the full URL
                if (!this.actualRecordId) {
                    const fullUrl = window.location.href;
                    const urlMatch = fullUrl.match(/[?&]recordId=([^&?#]+)/i);
                    if (urlMatch && urlMatch[1]) {
                        this.actualRecordId = decodeURIComponent(urlMatch[1].trim());
                        console.log('Found recordId from URL in page reference:', this.actualRecordId);
                    }
                }
            }
            
            // If we still don't have recordId, try to get it from the recordId property
            if (!this.actualRecordId && this.recordId) {
                this.actualRecordId = this.recordId;
                console.log('Using recordId from property:', this.actualRecordId);
            }
            
            // Load data if we have recordId
            if (this.actualRecordId && !this.dataLoaded) {
                console.log('Loading data with recordId:', this.actualRecordId);
                this.loadSubmissionData();
            } else if (!this.actualRecordId) {
                // If no recordId from page reference, try URL after a delay
                setTimeout(() => {
                    this.getRecordIdFromUrl();
                }, 200);
            }
        }
    }
    
    connectedCallback() {
        console.log('Current URL:', window.location.href);
        console.log('URL Search:', window.location.search);
        const params = new URLSearchParams(window.location.search);
        this.recordId = params.get('c__recordId');
       // alert('Fallback recordId:', this.recordId);
        // First try to use the recordId property (for Quick Actions)
        if (this.recordId && !this.dataLoaded) {
            this.actualRecordId = this.recordId;
            console.log('Using recordId from property:', this.actualRecordId);
            this.loadSubmissionData();
        } else if (!this.dataLoaded) {
            // Try to get from URL (for Lightning page navigation)
            // Use setTimeout to ensure URL is fully loaded
            setTimeout(() => {
                this.getRecordIdFromUrl();
            }, 100);
        }
    }
    
    getRecordIdFromUrl() {
        console.log('Extracting recordId from URL...');
        console.log('Full URL:', window.location.href);
        console.log('Search params:', window.location.search);
        console.log('Hash:', window.location.hash);
        
        let recordIdParam = null;
        
        // Method 1: Try URLSearchParams (standard query parameters)
        try {
            const urlParams = new URLSearchParams(window.location.search);
            recordIdParam = urlParams.get('recordId') || urlParams.get('id');
            console.log('From URLSearchParams:', recordIdParam);
        } catch (e) {
            console.log('URLSearchParams error:', e);
        }
        
        // Method 2: Parse full URL with regex (handles /lightning/n/Evaluation_Form?recordId=xxx)
        if (!recordIdParam) {
            const fullUrl = window.location.href;
            // Match recordId in URL: ?recordId=xxxxx or &recordId=xxxxx
            const urlMatch = fullUrl.match(/[?&]recordId=([^&?#]+)/i);
            if (urlMatch && urlMatch[1]) {
                recordIdParam = decodeURIComponent(urlMatch[1].trim());
                console.log('From URL regex match:', recordIdParam);
            }
        }
        
        // Method 3: Check hash/fragment
        if (!recordIdParam && window.location.hash) {
            const hash = window.location.hash;
            const hashMatch = hash.match(/[?&]recordId=([^&]+)/i);
            if (hashMatch && hashMatch[1]) {
                recordIdParam = decodeURIComponent(hashMatch[1].trim());
                console.log('From hash:', recordIdParam);
            }
        }
        
        if (recordIdParam) {
            // Clean the recordId (remove any trailing characters)
            recordIdParam = recordIdParam.split('&')[0].split('#')[0].split('?')[0].trim();
            this.actualRecordId = recordIdParam;
            console.log('Final recordId extracted:', this.actualRecordId);
            this.loadSubmissionData();
        } else {
            // Wait a bit more and try again (sometimes URL takes time to update in Lightning)
            setTimeout(() => {
                const retryUrl = window.location.href;
                const retryMatch = retryUrl.match(/[?&]recordId=([^&?#]+)/i);
                if (retryMatch && retryMatch[1]) {
                    const retryRecordId = decodeURIComponent(retryMatch[1].trim()).split('&')[0].split('#')[0].split('?')[0].trim();
                    this.actualRecordId = retryRecordId;
                    console.log('RecordId found on retry:', this.actualRecordId);
                    this.loadSubmissionData();
                } else {
                    this.isLoading = false;
                    console.error('Record ID not found after retry. Available properties:', {
                        recordId: this.recordId,
                        url: window.location.href,
                        search: window.location.search,
                        hash: window.location.hash,
                        pathname: window.location.pathname
                    });
                    this.showToast('Error', 'Submission ID is required. Please ensure the URL contains recordId parameter. Current URL: ' + window.location.href, 'error');
                }
            }, 500);
        }
    }
    
    loadSubmissionData() {
        const submissionId = this.actualRecordId || this.recordId;
        
        if (!submissionId) {
            this.isLoading = false;
            this.showToast('Error', 'Submission ID is required', 'error');
            return Promise.resolve();
        }
        
        // Prevent duplicate loads unless explicitly forced (dataLoaded = false)
        if (this.dataLoaded) {
            return Promise.resolve();
        }
        
        this.isLoading = true;
        
        return getSubmissionDetails({ submissionId: submissionId })
            .then(result => {
                this.submissionData = result;
                console.log('Full submission data:', JSON.stringify(result, null, 2));
                console.log('Answers array:', JSON.stringify(result.answers, null, 2));
                if (result.answers && result.answers.length > 0) {
                    console.log('First answer:', JSON.stringify(result.answers[0], null, 2));
                    console.log('First answer selectedOptionLabels:', result.answers[0].selectedOptionLabels);
                }
                this.organizeAnswersBySection();
                this.isLoading = false;
                this.dataLoaded = true;
                console.log('Submission data loaded successfully. RecordId:', submissionId);
                return result;
            })
            .catch(error => {
                console.error('Error loading submission:', error);
                this.showToast('Error', 'Failed to load submission details: ' + (error.body?.message || error.message), 'error');
                this.isLoading = false;
                throw error;
            });
    }
    
    organizeAnswersBySection() {
        if (!this.submissionData || !this.submissionData.answers) {
            return;
        }
        
        const sectionMap = {};
        console.log('Organizing answers by section. Total answers:',JSON.stringify(this.submissionData.answers));
        this.submissionData.answers.forEach(answer => {
            const sectionKey = answer.sectionKey || 'Other';
            
            // Add displayQuestionText property for template use (only question text, not label/key)
            answer.displayQuestionText = answer.questionText || '';
            
            if (!sectionMap[sectionKey]) {
                sectionMap[sectionKey] = {
                    sectionKey: sectionKey,
                    sectionLabel: answer.sectionLabel || sectionKey,
                    sectionWeightage: answer.sectionWeightage || 0,
                    answers: [],
                    sectionScore: 0,
                    sectionWeightedScore: 0,
                    formattedWeightedScore: '0.00'
                };
            }
            
            sectionMap[sectionKey].answers.push(answer);
            sectionMap[sectionKey].sectionScore += answer.score || 0;
            sectionMap[sectionKey].sectionWeightedScore += answer.weightedScore || 0;
        });
        
        // Format weighted scores for all sections (ensure 2 decimal places)
        Object.keys(sectionMap).forEach(key => {
            const section = sectionMap[key];
            const weightedScore = parseFloat(section.sectionWeightedScore) || 0;
            section.formattedWeightedScore = weightedScore.toFixed(2);
        });
        
        // Convert to array and sort
        this.sectionList = Object.values(sectionMap);
        this.sectionList.sort((a, b) => {
            return (a.sectionLabel || '').localeCompare(b.sectionLabel || '');
        });
        
        this.answersBySection = sectionMap;
    }
    
    handleCommentChange(event) {
        this.comment = event.target.value;
        this.showCommentError = false;
    }
    
    handleApprove() {
        if (!this.validateComment()) {
            return;
        }
        
        const submissionId = this.actualRecordId || this.recordId;
        if (!submissionId) {
            this.showToast('Error', 'Submission ID is required', 'error');
            return;
        }
        
        this.isProcessing = true;
        
        approveSubmission({ 
            submissionId: submissionId,
            comment: this.comment,
            approverId: null
        })
            .then(result => {
                this.showToast('Success', 'Submission approved successfully!', 'success');
                // Clear comment field
                this.comment = '';
                // Clear submission data to force reload
                this.submissionData = null;
                this.dataLoaded = false;
                // Reload submission data immediately to update the UI and refresh getters
                this.loadSubmissionData().then(() => {
                    this.isProcessing = false;
                    // Force UI refresh
                    if (this.actualRecordId || this.recordId) {
                        getRecordNotifyChange([{ recordId: this.actualRecordId || this.recordId }]);
                    }
                });
            })
            .catch(error => {
                console.error('Error approving submission:', error);
                this.showToast('Error', 'Failed to approve submission: ' + (error.body?.message || error.message), 'error');
                this.isProcessing = false;
            });
    }
    
    handleReject() {
        if (!this.validateComment(true)) {
            return;
        }
        
        const submissionId = this.actualRecordId || this.recordId;
        if (!submissionId) {
            this.showToast('Error', 'Submission ID is required', 'error');
            return;
        }
        
        this.isProcessing = true;
        
        rejectSubmission({ 
            submissionId: submissionId,
            comment: this.comment,
            rejectorId: null
        })
            .then(result => {
                this.showToast('Success', 'Submission rejected successfully!', 'success');
                // Clear comment field
                this.comment = '';
                // Clear submission data to force reload
                this.submissionData = null;
                this.dataLoaded = false;
                // Reload submission data immediately to update the UI and refresh getters
                this.loadSubmissionData().then(() => {
                    this.isProcessing = false;
                    // Force UI refresh
                    if (this.actualRecordId || this.recordId) {
                        getRecordNotifyChange([{ recordId: this.actualRecordId || this.recordId }]);
                    }
                });
            })
            .catch(error => {
                console.error('Error rejecting submission:', error);
                this.showToast('Error', 'Failed to reject submission: ' + (error.body?.message || error.message), 'error');
                this.isProcessing = false;
            });
    }
    
    validateComment(isRequired = false) {
        if (isRequired && !this.comment || this.comment.trim() === '') {
            this.showCommentError = true;
            return false;
        }
        this.showCommentError = false;
        return true;
    }
    
    closeAndRefresh() {
        // Close the modal/action and refresh the record page
        const submissionId = this.actualRecordId || this.recordId;
        if (submissionId) {
            // Notify that the record has changed
            getRecordNotifyChange([{ recordId: submissionId }]);
        }
        // Close the modal by navigating back or reloading
        setTimeout(() => {
            window.location.reload();
        }, 500);
    }
    
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }
    
    get canApprove() {
        if (!this.submissionData) {
            return false;
        }
        
        // Check if submission is already fully approved or rejected
        if (this.submissionData.status === 'Approved' || this.submissionData.status === 'Rejected') {
            return false;
        }
        
        // Check if current user has already made a decision
        const currentUserId = this.submissionData.currentUserId;
        const approver1Id = this.submissionData.approver1Id;
        const approver2Id = this.submissionData.approver2Id;
        const statusApprover1 = this.submissionData.statusApprover1;
        const statusApprover2 = this.submissionData.statusApprover2;
        
        console.log('canApprove check - currentUserId:', currentUserId, 'approver1Id:', approver1Id, 'approver2Id:', approver2Id);
        console.log('canApprove check - statusApprover1:', statusApprover1, 'statusApprover2:', statusApprover2);
        
        // Check if current user is Approver 1
        if (currentUserId === approver1Id) {
            // If Approver 1 has already decided, they cannot approve again
            if (statusApprover1 === 'Approved' || statusApprover1 === 'Rejected') {
                console.log('Approver 1 has already decided, cannot approve');
                return false;
            }
            // Approver 1 can approve if they haven't decided yet
            return true;
        }
        
        // Check if current user is Approver 2
        if (currentUserId === approver2Id) {
            // If Approver 2 has already decided, they cannot approve again
            if (statusApprover2 === 'Approved' || statusApprover2 === 'Rejected') {
                console.log('Approver 2 has already decided, cannot approve');
                return false;
            }
            // Approver 2 can approve only if Approver 1 has approved first
            if (statusApprover1 !== 'Approved') {
                console.log('Approver 1 has not approved yet, Approver 2 cannot act');
                return false;
            }
            return true;
        }
        
        // User is not an approver
        return false;
    }
    
    get canReject() {
        if (!this.submissionData) {
            return false;
        }
        
        // Check if submission is already fully approved or rejected
        if (this.submissionData.status === 'Approved' || this.submissionData.status === 'Rejected') {
            return false;
        }
        
        // Check if current user has already made a decision
        const currentUserId = this.submissionData.currentUserId;
        const approver1Id = this.submissionData.approver1Id;
        const approver2Id = this.submissionData.approver2Id;
        const statusApprover1 = this.submissionData.statusApprover1;
        const statusApprover2 = this.submissionData.statusApprover2;
        
        // Check if current user is Approver 1 and has already decided
        if (currentUserId === approver1Id) {
            if (statusApprover1 === 'Approved' || statusApprover1 === 'Rejected') {
                return false;
            }
        }
        
        // Check if current user is Approver 2 and has already decided
        if (currentUserId === approver2Id) {
            if (statusApprover2 === 'Approved' || statusApprover2 === 'Rejected') {
                return false;
            }
        }
        
        // User can reject if they are an approver and haven't decided yet
        return (currentUserId === approver1Id || currentUserId === approver2Id);
    }
    
    get statusBadgeClass() {
        if (!this.submissionData) return '';
        const status = this.submissionData.status;
        if (status === 'Approved') return 'status-approved';
        if (status === 'Rejected') return 'status-rejected';
        if (status === 'Send') return 'status-send';
        if (status === 'Draft') return 'status-draft';
        return '';
    }
    
    get commentErrorClass() {
        return this.showCommentError ? 'comment-error' : '';
    }
    
    get formattedCreatedDate() {
        if (!this.submissionData || !this.submissionData.createdDate) {
            return '';
        }
        const date = new Date(this.submissionData.createdDate);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
    }
    
    get formattedTotalScore() {
        if (!this.submissionData || this.submissionData.totalScore == null) {
            return '0.00';
        }
        return this.submissionData.totalScore.toFixed(2);
    }
    
    get statusLowerCase() {
        if (!this.submissionData || !this.submissionData.status) {
            return '';
        }
        return this.submissionData.status.toLowerCase();
    }
}