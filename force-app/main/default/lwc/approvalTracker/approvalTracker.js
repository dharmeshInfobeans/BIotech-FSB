import { LightningElement, wire, api, track } from 'lwc';
import getApprovalStatus from '@salesforce/apex/OpportunityApprovalTrackerController.getApprovalStatus';
import { refreshApex } from '@salesforce/apex';
import { subscribe, unsubscribe, onError } from 'lightning/empApi';

import getCustomLabels from '@salesforce/apex/OpportunityApprovalTrackerController.getCustomLabels';

const APPROVAL_FIELDS = new Set([
    'RSM_Approve__c',
    'RSM_Not_Approve__c',
    'ZSM_Approve__c',
    'ZSM_Not_Approve__c',
    'GM_NSM_Approve__c',
    'GM_NSM_Not_Approve__c',
    'Admin_Approve__c',
    'Admin_Not_Approve__c'
]);

export default class ApprovalTracker extends LightningElement {
    @api recordId;
    @track approvals = [];
    wiredResult;
    isLoading = false;
    @track isUploaded=false;

    @track labels = {};

    @wire(getCustomLabels)
    getLabels({ data, error }) {
        if (data) { this.labels = data; }
        if (error) console.log('error', error);
    }



    channelName = '/data/Opportunity__ChangeEvent';
    subscription = null;
    connectedCallback() {
        this.registerErrorListener();
        this.subscribeToCDC();
    }

    disconnectedCallback() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {
                console.log('Unsubscribed from Platform Event');
            });
        }
    }
    subscribeToCDC() {
        const messageCallback = (event) => {
            const payload = event.data.payload;
            const header = payload.ChangeEventHeader;
            console.log('header',header);
            console.log('payload',payload);

            if (header.changeType !== 'UPDATE') {
                return;
            }

            const changedFields = header.changedFields || [];

            const hasApprovalChange = changedFields.some(field =>
                APPROVAL_FIELDS.has(field)
            );

            if (!hasApprovalChange) {
                console.log('CDC ignored – non approval field change');
                return;
            }

            console.log('CDC approval field change detected');
            console.log('Changed Fields:', changedFields);

            this.refreshComponent();
        };

        subscribe(this.channelName, -1, messageCallback)
            .then(response => {
                console.log('Subscribed to:', response.channel);
                this.subscription = response;
            });
    }


    disconnectedCallback() {
        this.unsubscribeFromCDC();
    }

    unsubscribeFromCDC() {
        if (this.subscription) {
            unsubscribe(this.subscription, () => {
                console.log('Unsubscribed from CDC');
            });
        }
    }

    registerErrorListener() {
        onError(error => {
            console.error('CDC Error:', JSON.stringify(error));
        });
    }
    @wire(getApprovalStatus, { recordId: '$recordId' })
    wiredOpportunity(result) {
        this.wiredResult = result;

        if (result.data) {
            console.log('prepareTimeline',result.data);
            this.isUploaded=result?.data?.is_Uploaded__c || false;
            this.prepareTimeline(result.data);
           
            this.isLoading = false;
        } else if (result.error) {
            console.error(result.error);
            this.isLoading = false;
        }
    }

    refreshComponent() {
        console.log('OUTPUT : refresh called ');
        this.isLoading = true;
        refreshApex(this.wiredResult)
            .then(() => {
                console.log('Approval status refreshed');
            })
            .catch(error => {
                console.error('Refresh error', error);
                this.isLoading = false;
            });
    }
    prepareTimeline(data) {
        const rsmApproved = data.RSM_Approve__c;
        const zsmApproved = data.ZSM_Approve__c;
        const gmApproved = data.GM_NSM_Approve__c;
         console.log('this.isUploaded',this.isUploaded);
        this.approvals = [
            this.createStep(this.labels.Approver_1__c, data.RSM_Approve__c, data.RSM_Not_Approve__c, 'RSM_Approve__c'),
            this.createStep(this.labels.Approver_2__c, data.ZSM_Approve__c, data.ZSM_Not_Approve__c, rsmApproved, 'ZSM_Approve__c'),
            //this.createStep('GM / NSM', data.GM_NSM_Approve__c, data.GM_NSM_Not_Approve__c, zsmApproved, 'GM_NSM_Approve__c'),
            this.createStep(this.labels.Admin_Operations__c, data.Admin_Approve__c, data.Admin_Not_Approve__c, zsmApproved, 'Admin_Approve__c')
        ];
        console.log('approvals',this.approvals)
    }

    createStep(label, approved, rejected, previousApproved, approveField) {
        if (rejected === true) {
            return { label, icon: 'action:close', cssClass: 'rejected', status: this.labels.Rejected__c,icon_class:'my-custom-icon-reject' };
        }
        if (approved === true) {
            return { label, icon: 'action:approval', cssClass: 'approved', status: this.labels.Approved__,icon_class:'my-custom-icon-approved' };
        }
        if (previousApproved === true) {
            return { label, icon: 'action:more', cssClass: 'pending', status: this.labels.Pending__c, approveField };
        }
        // 'my-custom-icon'
        return { label, icon: 'action:question_post_action', cssClass: 'no-action', status:this.isUploaded?this.labels.Pending__c: this.labels.No_Action__c,icon_class:this.isUploaded?'my-custom-icon':'my-custom-icon-yellow' };
    }
    handleApprove(event) {
        const fieldName = event.currentTarget.dataset.field;
        if (!fieldName) {
            return;
        }


        updateApprovalStatus({
            recordId: this.recordId,
            fieldName: fieldName
        })
            .then(() => {

            })
            .catch(error => {
                console.error(error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

}