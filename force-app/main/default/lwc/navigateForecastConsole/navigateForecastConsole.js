import { LightningElement, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class NavigateForecastConsole extends NavigationMixin(LightningElement) {
    @api recordId; // Receives the Contact record ID from the page context

    @api invoke() {

        const pageReference = {
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Forecast_Console_Tab'
            },
            state: {
                c__contactId: this.recordId
            }
        };

        this[NavigationMixin.GenerateUrl](pageReference)
            .then(url => {
                window.open(url, '_blank');
            })
            .catch(error => {
                console.log('This is the error', error);
                console.error('Error generating URL:', error);
            });
    }

}