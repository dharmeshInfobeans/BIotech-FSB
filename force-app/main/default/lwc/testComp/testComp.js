import { LightningElement, track,wire } from 'lwc';

export default class TestComp extends LightningElement {

    @track recordId;  
    @track isEditable = false;
    @track loading = true;

    connectedCallback() {
        console.log('OUTPUT : testtt');
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