import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getCRMCertificateQueue from '@salesforce/apex/CertificateVerificationController.getCRMCertificateQueue';

export default class CrmCertificateQueue extends NavigationMixin(LightningElement) {
    @track items = [];
    @track isLoading = true;
    @track hasError = false;

    @wire(getCRMCertificateQueue)
    wiredQueue({ data, error }) {
        this.isLoading = false;
        if (data) {
            this.items = data.map(item => {
                const hasPending  = item.pendingCount > 0;
                const hasUnlocked = (item.unlockedCount || 0) > 0;
                let badgeLabel, badgeClass;
                if (hasPending) {
                    badgeLabel = item.pendingCount + ' product' + (item.pendingCount === 1 ? '' : 's') + ' pending';
                    badgeClass = 'card-pending-badge';
                } else if (hasUnlocked) {
                    badgeLabel = 'Order Unlocked';
                    badgeClass = 'card-unlocked-badge';
                } else {
                    badgeLabel = '';
                    badgeClass = '';
                }
                return {
                    ...item,
                    formattedDate: item.submittedDate || '',
                    badgeLabel,
                    badgeClass
                };
            });
            this.hasError = false;
        } else if (error) {
            this.hasError = true;
        }
    }

    get hasItems()      { return this.items.length > 0; }
    get noItems()       { return !this.isLoading && !this.hasError && this.items.length === 0; }
    get pendingCount()  { return this.items.filter(i => i.pendingCount > 0).length; }
    get hasPending()    { return this.pendingCount > 0; }

    handleCardClick(event) {
        const requestId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: { url: '/s/crm-certificate-detail?recordId=' + requestId }
        });
    }
}