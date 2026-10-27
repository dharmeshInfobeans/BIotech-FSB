import { LightningElement, api, wire, track } from "lwc";
import { NavigationMixin } from "lightning/navigation";
import getParentAndChildSchemes from "@salesforce/apex/SchemeInformationController.getParentAndChildSchemes";
export default class SchemeDetails extends NavigationMixin(LightningElement) {

    @api recordId;

    @track parentschemelist = [];
    @track childschemelist = [];

    parentaccountscheme = false;
    childaccountscheme = false;

    isLoading = true;
    noSchemeFound = false;

    error;

    @wire(getParentAndChildSchemes, { accountId: "$recordId" })
    wiredSchemeData({ data, error }) {

        this.isLoading = true;

        if (data) {

            // ✅ Parent Schemes
            if (data.parentSchemes && data.parentSchemes.length > 0) {
                this.parentschemelist = data.parentSchemes;
                this.parentaccountscheme = true;
            } else {
                this.parentschemelist = [];
                this.parentaccountscheme = false;
            }

            // ✅ Child Schemes
            if (data.childSchemes && data.childSchemes.length > 0) {
                this.childschemelist = data.childSchemes;
                this.childaccountscheme = true;
            } else {
                this.childschemelist = [];
                this.childaccountscheme = false;
            }

            // ✅ No Data Case
            if (!this.parentaccountscheme && !this.childaccountscheme) {
                this.noSchemeFound = true;
            } else {
                this.noSchemeFound = false;
            }

            this.error = undefined;
            this.isLoading = false;
        }

        else if (error) {

            this.error = error;
            this.parentschemelist = [];
            this.childschemelist = [];

            this.parentaccountscheme = false;
            this.childaccountscheme = false;

            this.noSchemeFound = false;

            this.isLoading = false;
        }
    }

      handleSchemeRedirect(event) {
        const schemeId = event.currentTarget.dataset.id;

        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: schemeId,
                objectApiName: "Scheme_Request__c",
                actionName: "view"
            }
        });
    }

    // ✅ Redirect to Account Record
    handleAccountRedirect(event) {
        const accountId = event.currentTarget.dataset.id;

        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                recordId: accountId,
                objectApiName: "Account",
                actionName: "view"
            }
        });
    }
}