import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getRecordNotifyChange } from 'lightning/uiRecordApi';
import getApprovalHistory from '@salesforce/apex/ScorecardReviewController.getApprovalHistory';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const FIELDS = [
    'Scorecard_Submission__c.Id',
    'Scorecard_Submission__c.Status__c',
    'Scorecard_Submission__c.Approver_1__c',
    'Scorecard_Submission__c.Approver_2__c',
    'Scorecard_Submission__c.Smart_Form_Data__c'
];

export default class ScorecardApprovalHistory extends LightningElement {
    @api recordId; // Automatically populated when on record page
    
    @track approvalHistory = null;
    @track isLoading = true;
    @track approver1Data = null;
    @track approver2Data = null;
    @track currentStatus = '';
    @track rounds = [];
    @track currentRound = 1;
    
    // Wire to get record data
    @wire(getRecord, { recordId: '$recordId', fields: FIELDS })
    wiredRecord({ error, data }) {
        if (data) {
            this.currentStatus = data.fields.Status__c.value;
            this.loadApprovalHistory();
        } else if (error) {
            console.error('Error loading record:', error);
            this.isLoading = false;
        }
    }
    
    // Load approval history from Apex
    loadApprovalHistory() {
        if (!this.recordId) {
            this.isLoading = false;
            return;
        }
        
        getApprovalHistory({ submissionId: this.recordId })
            .then(result => {
                console.log('Approval History Result:', JSON.stringify(result, null, 2));
                this.approvalHistory = result;
                this.approver1Data = result.approver1 || null;
                this.approver2Data = result.approver2 || null;
                this.currentStatus = result.currentStatus || this.currentStatus;
                this.currentRound = result.currentRound || 1;
                
                // Load rounds array if available
                if (result.rounds && Array.isArray(result.rounds)) {
                    // Mark current round and format dates
                    this.rounds = result.rounds.map(round => {
                        const processedRound = {
                            ...round,
                            isCurrentRound: round.roundNumber === this.currentRound
                        };
                        
                        // Format dates for approver1
                        if (round.approver1) {
                            processedRound.approver1 = {
                                ...round.approver1,
                                formattedDate: this.formatDate(round.approver1.approvedDate || round.approver1.rejectedDate),
                                badgeClass: this.getRoundApproverBadgeClass(round.approver1.status),
                                displayName: round.approver1.approverName || 'N/A'
                            };
                        }
                        
                        // Format dates for approver2
                        if (round.approver2) {
                            processedRound.approver2 = {
                                ...round.approver2,
                                formattedDate: this.formatDate(round.approver2.approvedDate || round.approver2.rejectedDate),
                                badgeClass: this.getRoundApproverBadgeClass(round.approver2.status),
                                displayName: round.approver2.approverName || 'N/A'
                            };
                        }
                        
                        return processedRound;
                    });
                } else {
                    this.rounds = [];
                }
                
                this.isLoading = false;
                console.log('Approver1 Data:', this.approver1Data);
                console.log('Approver2 Data:', this.approver2Data);
                console.log('Rounds:', this.rounds);
            })
            .catch(error => {
                console.error('Error loading approval history:', error);
                this.showToast('Error', 'Failed to load approval history: ' + (error.body?.message || error.message), 'error');
                this.isLoading = false;
            });
    }
    
    // Refresh when record is updated
    handleRecordUpdate() {
        getRecordNotifyChange([{ recordId: this.recordId }]);
        setTimeout(() => {
            this.loadApprovalHistory();
        }, 500);
    }
    
    get hasApprovalHistory() {
        return this.rounds.length > 0 || this.approver1Data || this.approver2Data;
    }
    
    get hasRounds() {
        return this.rounds && this.rounds.length > 0;
    }
    
    get showApprover1() {
        return this.approvalHistory && this.approvalHistory.approver1Id;
    }
    
    get showApprover2() {
        return this.approvalHistory && this.approvalHistory.approver2Id;
    }
    
    get approver1Status() {
        if (!this.approver1Data) return 'Pending';
        return this.approver1Data.status || 'Pending';
    }
    
    get approver2Status() {
        if (!this.approver2Data) return 'Pending';
        return this.approver2Data.status || 'Pending';
    }
    
    get approver1Comment() {
        return this.approver1Data?.comment || '';
    }
    
    get approver2Comment() {
        return this.approver2Data?.comment || '';
    }
    
    get hasApprover1Comment() {
        return this.approver1Data && this.approver1Data.comment && String(this.approver1Data.comment).trim() !== '';
    }
    
    get hasApprover2Comment() {
        return this.approver2Data && this.approver2Data.comment && String(this.approver2Data.comment).trim() !== '';
    }
    
    get approver1Date() {
        if (!this.approver1Data) return null;
        return this.formatDate(this.approver1Data.approvedDate || this.approver1Data.rejectedDate);
    }
    
    get approver2Date() {
        if (!this.approver2Data) return null;
        return this.formatDate(this.approver2Data.approvedDate || this.approver2Data.rejectedDate);
    }
    
    get hasApprover1Date() {
        return this.approver1Data && (this.approver1Data.approvedDate || this.approver1Data.rejectedDate);
    }
    
    get hasApprover2Date() {
        return this.approver2Data && (this.approver2Data.approvedDate || this.approver2Data.rejectedDate);
    }
    
    get approver1Name() {
        if (!this.approvalHistory || !this.approvalHistory.approver1Id) return 'N/A';
        return this.approver1Data?.approverName || this.approver1Data?.approvedBy || this.approver1Data?.rejectedBy || 'N/A';
    }
    
    get approver2Name() {
        if (!this.approvalHistory || !this.approvalHistory.approver2Id) return 'N/A';
        return this.approver2Data?.approverName || this.approver2Data?.approvedBy || this.approver2Data?.rejectedBy || 'N/A';
    }
    
    get statusBadgeClass() {
        if (this.currentStatus === 'Approved') return 'slds-badge_success';
        if (this.currentStatus === 'Rejected') return 'slds-badge_error';
        if (this.currentStatus === 'Approver 1' || this.currentStatus === 'Approver 2') return 'slds-badge_warning';
        return '';
    }
    
    get approver1BadgeClass() {
        const status = this.approver1Status;
        if (status === 'Approved') return 'slds-badge_success';
        if (status === 'Rejected') return 'slds-badge_error';
        return 'slds-badge_warning';
    }
    
    get approver2BadgeClass() {
        const status = this.approver2Status;
        if (status === 'Approved') return 'slds-badge_success';
        if (status === 'Rejected') return 'slds-badge_error';
        return 'slds-badge_warning';
    }
    
    formatDate(dateString) {
        if (!dateString) return 'N/A';
        try {
            const date = new Date(dateString);
            return date.toLocaleString();
        } catch (e) {
            return dateString;
        }
    }
    
    getRoundApproverBadgeClass(status) {
        if (!status) return 'slds-badge_warning';
        if (status === 'Approved') return 'slds-badge_success';
        if (status === 'Rejected') return 'slds-badge_error';
        return 'slds-badge_warning';
    }
    
    isCurrentRound(roundNumber) {
        return roundNumber === this.currentRound;
    }
    
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }
}