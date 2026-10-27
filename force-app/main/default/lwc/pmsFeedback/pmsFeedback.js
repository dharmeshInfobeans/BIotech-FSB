import { LightningElement, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import ACCOUNT_ID_FIELD from '@salesforce/schema/User.AccountId';
import SAP_CODE_FIELD from '@salesforce/schema/Account.SAP_Code__c';
import ACCOUNT_NAME_FIELD from '@salesforce/schema/Account.Name';

const USER_FIELDS = [ACCOUNT_ID_FIELD];

const ACCOUNT_FIELDS = [SAP_CODE_FIELD, ACCOUNT_NAME_FIELD];

export default class PmsFeedback extends LightningElement {

    accountId;
    sapCode;

    @wire(getRecord, { recordId: USER_ID, fields: USER_FIELDS })
    wiredUser({ error, data }) {
        if (data) {
            this.accountId = data.fields.AccountId.value;
            console.log('this.accountiD ===> ', this.accountId)
        } else if (error) {
            console.error('Error loading user:', error);
        }
    }

    @wire(getRecord, { recordId: '$accountId', fields: ACCOUNT_FIELDS })
    wiredAccount({ error, data }) {
        if (data) {
            this.sapCode = data.fields.SAP_Code__c.value;
            console.log('this.sapCode ===> ', this.sapCode)

        } else if (error) {
            console.error('Error loading account:', error);
        }
    }

    get iframeUrl() {
        if (this.sapCode) {
            return `https://pms.biotechhealthcare.com/customer-dashboard/${this.sapCode}`;
        }
        return '';
    }

}