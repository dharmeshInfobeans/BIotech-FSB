import { LightningElement, wire, track } from 'lwc';
import getDashboardData from '@salesforce/apex/SAPDashboardController.getDashboardData';
import getQuarterSummary from '@salesforce/apex/SAPDashboardController.getQuarterSummary';
import getAvailableYears from '@salesforce/apex/SAPDashboardController.getAvailableYears';

export default class SapZohoDashboard extends LightningElement {

    @track dashboard = {};
    @track quarterSummary = [];
    @track yearOptions = [{ label: 'All Years', value: '' }];

    selectedYear = '';   // string shown in the combobox ('' = All Years)
    yearForApex = null;  // plain reactive field passed into @wire params

    @wire(getAvailableYears)
    wiredYears({ data, error }) {
        if (data) {
            const options = data.map((y) => ({ label: String(y), value: String(y) }));
            this.yearOptions = [{ label: 'All Years', value: '' }, ...options];
        }
    }

    @wire(getDashboardData, { year: '$yearForApex' })
    dashboardData({ data, error }) {
        if (data) {
            this.dashboard = data;
        }
    }

    @wire(getQuarterSummary, { year: '$yearForApex' })
    summaryData({ data, error }) {
        if (data) {
            this.quarterSummary = data;
        }
    }

    handleYearFilterChange(event) {
        this.selectedYear = event.detail.value;
        this.yearForApex = this.selectedYear ? parseInt(this.selectedYear, 10) : null;
    }
}