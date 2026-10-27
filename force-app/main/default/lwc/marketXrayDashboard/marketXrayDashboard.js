import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import retUserId from '@salesforce/apex/MarketXRayController.retUserId';
export default class MarketXrayDashboard extends LightningElement {

    @track recordId;
    @track isEditable = false;
    @track loading = true;
    @track userId;

    connectedCallback() {
        console.log('MarketXrayDashboard Loaded');
    }

    @wire(CurrentPageReference)
    setCurrentPageReference(currentPageReference) {
        if (currentPageReference) {
            console.log('Page Reference:>>>>> ', currentPageReference);
            let userId = currentPageReference?.state?.userId;
            console.log('OUTPUT : userId >> ', userId);
            this.settingUserId(userId);
        }
    }

    settingUserId(userId) {
        retUserId({ userId: userId })
            .then(result => {
                console.log('Result ::::: >> ', result);
                this.userId = result;
            })
            .catch(error => {
                console.error('Error:', error);
            });
    }


    async handleSumbit(event) {
        const sectionA = this.template.querySelector('c-market-xray-section-a');
        if (sectionA) {
            await sectionA.handleSaveButton();
            setTimeout(() => {
                sectionA.loadExistingData();
            }, 1000);
        }
    }

}