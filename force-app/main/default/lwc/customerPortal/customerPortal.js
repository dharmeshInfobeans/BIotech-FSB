import { LightningElement, track } from 'lwc';
import BIOTECH_LOGO from '@salesforce/resourceUrl/CompanyLogo';
export default class CustomerPortal extends LightningElement {
    @track activeTab = 'fetch-ledger';
    logoUrl = BIOTECH_LOGO;

    handleNavigateToPending() {
    this.activeTab = 'pending-request';
    }
    get tabList() {
        const tabs = [
            { id: 'home', label: 'Dashboard', iconName: 'utility:home' },
            { id: 'fetch-ledger', label: 'Import Ledger', iconName: 'utility:download' },
            { id: 'pending-request', label: 'Pending Signatures', iconName: 'utility:clock' },
            { id: 'signed-request', label: 'Signed Documents', iconName: 'utility:collection_alt' },
            { id: 'future-tab', label: 'Failed Ledgers', iconName: 'utility:forward' },
            { id: 'admin', label: 'Admin Setting', iconName: 'utility:settings' }
        ];

        return tabs.map(tab => ({
            ...tab,
            className: `portal-tab ${this.activeTab === tab.id ? 'active' : ''}`
        }));
    }

    get isHome() {
        return this.activeTab === 'home';
    }

    get isAdmin() {
        return this.activeTab === 'admin';
    }

    get isFetchLedger() {
        return this.activeTab === 'fetch-ledger';
    }

    get isSignedRequest() {
        return this.activeTab === 'signed-request';
    }

    get isPendingRequest() {
        return this.activeTab === 'pending-request';
    }

    get isFutureTab() {
        return this.activeTab === 'future-tab';
    }

    handleTabClick(event) {
        this.activeTab = event.currentTarget.dataset.tab;
    }
}