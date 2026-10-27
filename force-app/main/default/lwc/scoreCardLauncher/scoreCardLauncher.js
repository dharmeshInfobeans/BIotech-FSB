import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class ScorecardLauncher extends NavigationMixin(LightningElement) {

    @api recordId;

    @api invoke() {

        const pageReference = {
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Score_Card_Lead_Page'
            },
            state: {
                c__recordId: this.recordId
            }
        };

        this[NavigationMixin.GenerateUrl](pageReference)
            .then(url => {
                window.open(url, '_blank');
            })
            .catch(error => {
                console.error('Error generating URL:', error);
            });
    }
}