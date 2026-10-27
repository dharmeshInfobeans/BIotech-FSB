import { LightningElement, track, wire } from 'lwc';
import updateUserLanguage from '@salesforce/apex/UserLanguageController.updateUserLanguage';
//import getActiveLanguages from '@salesforce/apex/UserLanguageController.getActiveLanguages';
import getAvailableLanguages from '@salesforce/apex/UserLanguageController.getAvailableLanguages';
import getUserLanguage from '@salesforce/apex/UserLanguageController.getUserLanguage';

export default class LanguagePicker extends LightningElement {
    @track userLanguage  = 'en_US';
    @track selectedLanguage;
    @track languageOptions = [];

    @wire(getUserLanguage)
    wiredUserLanguage({ error, data }) {
        if (data) {
            this.userLanguage = data;
        } else if (error) {
            // Handle errors, e.g., show an error message
        }
    }

    @wire(getAvailableLanguages)
    wiredLanguages({ error, data }) {
        if (data) {
            this.languageOptions = data.map(option => ({
                label: option.MasterLabel,
                value: option.LanguageCode__c
            }));
        } else if (error) {
            // Handle errors, e.g., show an error message
        }
        console.log('BG >>> this.languageOptions : ',this.languageOptions);
    }

    // Fetch active languages using the wire service
  /*  @wire(getActiveLanguages)
    wiredActiveLanguages({ error, data }) {
        if (data) {
            this.languageOptions = data.map(lang => ({
                label: lang,
                value: lang
            }));
        } else if (error) {
            // Handle the error, e.g., show an error message
        }
    } */

    handleLanguageChange(event) {
        this.selectedLanguage = event.detail.value;
        updateUserLanguage({ language: this.selectedLanguage })
            .then(() => {
                // Refresh the community page after language change
                location.reload();
            })
            .catch(error => {
                // Handle errors, e.g., show an error message
            });
    }
}