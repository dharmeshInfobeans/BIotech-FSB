import { LightningElement, api, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getApprovalChain from '@salesforce/apex/ApprovalHistoryController.getApprovalChain';
import getCustomLabels from '@salesforce/apex/ApprovalHistoryController.getCustomLabels';

export default class ApprovalHistory extends LightningElement {

    @api recordId;
    @track rawSteps = [];
    @track isLoading = true;
    @track errorMessage = '';
    @track labels = {};

    _resolvedRecordId;

    @wire(getCustomLabels)
    getLabels({ data, error }) {
        if (data) { this.labels = data; }
        if (error) console.log('error', error);
    }

    get approvals() {
        const statusLabelMap = {
            'Approved': this.labels.Approved__c,
            'Rejected': this.labels.Rejected__c,
            'Pending': this.labels.Pending__c,
            'No Action': this.labels.No_Action__c
        };

        return this.rawSteps.map(step => {
            let actionLabel = '';
            let showActionLabel = false;

            if (step.isApproved) {
                actionLabel = `${this.labels.Approved_By__c}: ${step.approvedByRole}`;
                showActionLabel = true;
            } else if (step.isRejected) {
                actionLabel = `${this.labels.Rejected_By__c}: ${step.rejectedByRole}`;
                showActionLabel = true;
            }

            return {
                ...step,
                statusLabel: statusLabelMap[step.status],
                actionLabel,
                showActionLabel
            };
        });
    }

    @wire(CurrentPageReference)
    pageRef(ref) {
        if (ref && ref.attributes && ref.attributes.recordId) {
            this._resolvedRecordId = ref.attributes.recordId;
            console.log('recordId from PageRef:', this._resolvedRecordId);
            this.loadData();
        }
    }

    connectedCallback() {
        if (this.recordId) {
            this._resolvedRecordId = this.recordId;
            this.loadData();
        }
    }

    loadData() {
        if (!this._resolvedRecordId) {
            this.errorMessage = 'recordId is missing';
            this.isLoading = false;
            return;
        }

        getApprovalChain({ recordId: this._resolvedRecordId })
            .then(data => {
                if (data.length === 0) {
                    this.errorMessage = 'No records found for: ' + this._resolvedRecordId;
                } else {
                    this.buildTimeline(data);
                }
            })
            .catch(error => {
                this.errorMessage = error.body ? error.body.message : JSON.stringify(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    buildTimeline(records) {
        const levelMap = new Map();

        records.forEach(rec => {
            if (!levelMap.has(rec.Level__c)) {
                levelMap.set(rec.Level__c, []);
            }
            levelMap.get(rec.Level__c).push(rec);
        });

        this.rawSteps = [...levelMap.values()].map((group, index) => {
            const label = group.map(r => r.Role__c).join(' / ');
            const status = this.resolveStatus(group);
            const approvedRole = group.find(r => r.Status__c === 'Approved');
            const rejectedRole = group.find(r => r.Status__c === 'Rejected');

            return {
            id             : index + 1,
            label          : label,
            status         : status,
            approvedByRole : approvedRole ? approvedRole.Role__c : null,
            rejectedByRole : rejectedRole ? rejectedRole.Role__c : null,
            isApproved     : !!approvedRole,
            isRejected     : !!rejectedRole,
            icon           : this.getIcon(status),
            cssClass       : 'step-icon ' + this.getCssClass(status),
            size           : this.getSize(status)
        };
    });
    }

    resolveStatus(group) {
        const statuses = group.map(r => r.Status__c);

        if (statuses.includes('Approved')) return 'Approved';
        if (statuses.includes('Rejected')) return 'Rejected';
        if (statuses.includes('Pending')) return 'Pending';
        return 'No Action';
    }

    getIcon(status) {
        const icons = {
            'Approved': 'action:approval',
            'Rejected': 'action:close',
            'Pending': 'action:more'
        };
        return icons[status] || 'utility:ban';
    }

    getCssClass(status) {
        const classes = {
            'Approved': 'approved',
            'Rejected': 'rejected',
            'Pending': 'pending'
        };
        return classes[status] || 'custom-icon-ban';
    }
    getSize(status) {
        const classes = {
            'Approved': 'small',
            'Rejected': 'small',
            'Pending': 'small'
        };
        return classes[status] || 'medium';
    }
}