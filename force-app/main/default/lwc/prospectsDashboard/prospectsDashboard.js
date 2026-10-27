import { LightningElement, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';

const CHARTS = [
    { key: 'opportunityToEvaluationRatio', title: 'Opportunity to Evaluation Ratio' },
    { key: 'opportunityEvaluationToConversionRatio', title: 'Opportunity Evaluation to Conversion Ratio' },
    { key: 'prospectToConversionRatio', title: 'Prospect to Opp Conversion Ratio' },
    { key: 'opportunityTrend', title: 'Opportunity Trend' },
    { key: 'overallReporting', title: 'Overall Reporting Prospect' },
    { key: 'overallReportingOpp', title: 'Overall Reporting Opp' },
    { key: 'prospectToUnqualifiedRatio', title: 'Prospect to Unqualified Ratio' },
    { key: 'prospectToUntouchRatio', title: 'Prospect to Untouch Ratio' },
    { key: 'opportunityToUntouchRatio', title: 'Opportunity to Untouch Ratio' },
    { key: 'endToEndVisibility', title: 'End to End Visibility Prospect' },
    { key: 'opportunityEndToEndVisibility', title: 'Opportunity End to End Visibility' },
    { key: 'expiredOpportunity', title: 'Expired Opportunity' },
    { key: 'expiredProspects', title: 'Expired Prospects' },
    { key: 'inClinicTarget', title: 'In-Clinic Target Activities' },
    { key: 'marketingTarget', title: 'Marketing Target Campaign Members' }
];

export default class ProspectsDashboard extends LightningElement {
    filters = {};
    charts = CHARTS;
    currentUserName;

    @wire(getRecord, { recordId: USER_ID, fields: [NAME_FIELD] })
    wiredCurrentUser({ data, error }) {
        if (data) {
            this.currentUserName = data.fields.Name.value;
        } else if (error) {
            this.currentUserName = null;
        }
    }

    handleFiltersChange(event) {
        this.filters = event.detail;
    }
}