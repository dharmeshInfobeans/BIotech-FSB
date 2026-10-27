import { api, LightningElement, track } from 'lwc';
import modal from "@salesforce/resourceUrl/custommodalcss";
import { CloseActionScreenEvent } from "lightning/actions";
import { loadStyle } from "lightning/platformResourceLoader";
import fetchAgreementProductData from '@salesforce/apex/AddEditAgreementProductController.fetchAgreementProductData';
import fetchPicklist from '@salesforce/apex/AddEditAgreementProductController.fetchPicklist';
import saveAgreementProducts from '@salesforce/apex/AddEditAgreementProductController.saveAgreementProducts';
import fetchPlantValue from '@salesforce/apex/AddEditAgreementProductController.fetchPlantValue';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
export default class QuickActionLWC extends LightningElement {


@api recordId;
@track isShowModal = true;
@track isLoading = true;
@track agreementProducts = [];  
@track masterAgreementRec;  
@track picklistValues = {};
@track updatedProducts = [];
@track currencyOptions=[];
@track paymentTermOptions=[];
@track incotermOptions=[];
@track renewedFrom;

masterAgrementVersion ; // Replace with dynamic value as needed


productMatchingInfo = {
primaryField: { fieldPath: "Name" },
additionalFields: [{ fieldPath: "Dummy_Product_Code__c" }],
};

productDisplayInfo = {
additionalFields: ["Name,Dummy_Product_Code__c"],
};

// Dynamically set product filter based on master agreement vertical
get productFilter() {
    return {
        criteria: [
            {
                fieldPath: "Vertical__c",
                operator: "eq",
                value: this.masterAgreementRec?.Vertical__c
            },
            {
                fieldPath: "Active__c",
                operator: "eq",
                value: true
            }
        ],
            filterLogic: '(1 AND 2)',

    };
}


get lockComponent() {
return this.agreementProducts.length > 0 ? this.agreementProducts[0].isDisabled : false;
}
connectedCallback() {
this.fetchPicklistValues();
loadStyle(this, modal);
}

fetchPicklistValues() {
fetchPicklist()
    .then((result) => {
        console.log(result);
        
        this.currencyOptions=result["currencyOptions"];
        this.paymentTermOptions=result["paymentTermOptions"];
        this.incotermOptions=result["incotermOptions"];
        this.fetchAgreementProducts();
    })
    .catch((error) => {
        this.showToast("Error", "Error fetching picklist values", error);
console.log('error',error);

        this.isLoading = false;
    });
}

fetchAgreementProducts() {
this.isLoading = true; // Show spinner during the fetch
fetchAgreementProductData({ MasterAgreementId: this.recordId })
.then((result) => {
    console.log("result", JSON.stringify(result));

    if (result.masterAgreement) {
        this.masterAgreementRec=JSON.parse(JSON.stringify(result.masterAgreement));
        console.log("this.masterAgreementRec",JSON.stringify(this.masterAgreementRec));
        
        
    } else {
        console.error("Master Agreement data not found.");
    }

    this.agreementProducts = result.agreementProducts.map((product) => {
        const cssClass = product.Is_Canceled__c
            ? "canceled-row"
            : product.Is_Amended__c
            ? "amended-row"
            : "default-row";

        return {
            ...product,
            cssClass: cssClass,
            isDisabled: result.masterAgreement ? result.masterAgreement.Is_Active__c : false,
            NotIsCanceled: !product.Is_Canceled__c,
            Is_Backup__c:product.Is_Backup__c ? true:false

        };
    });

if (this.agreementProducts.length <=0) {
    let  newRow = this.createEmptyRecord();
this.agreementProducts.push(newRow);      
}

console.log("agreementProducts:->", JSON.stringify(this.agreementProducts));

    this.isLoading = false; // Hide spinner
})
.catch((error) => {
    console.log("Error fetching agreement products:-->", error);
    this.showToast("Error", "Error fetching agreement products", "error");
    this.isLoading = false;
});
        
}

handleAddRow() {
let  newRow = this.createEmptyRecord();
this.agreementProducts.push(newRow);  
}
async handleValueChange(event){
const index = event.currentTarget.dataset.index;
const fieldName = event.currentTarget.dataset.fieldName;
const updatedValue = fieldName=='Product__c'? event.detail.recordId : event.target.type === "toggle" ? event.target.checked : event.target.value; 
const updatedRecords = JSON.parse(JSON.stringify(this.agreementProducts));
console.log("fieldName,updatedValue,index",fieldName,updatedValue,index);

if (fieldName === "Product__c") {
    try {
        let product = await this.fetchPlantValue(updatedValue);
        console.log("product --> " + JSON.stringify(product));

        updatedRecords[index] = {
            ...updatedRecords[index],
            ['Plant__c']: product?.plantName || null,  // Use the correct key from Apex response

        };
    } catch (error) {
        console.error("Error fetching product:", error);
    }
}

updatedRecords[index] = {
    ...updatedRecords[index],
    [fieldName]: updatedValue,
    'Is_Amended__c':  this.determineAmendment(), 
    'cssClass':  this.determineAmendment() ? 'amended-row' : 'cssClass'
};

this.agreementProducts = updatedRecords;

}
handleDelete(event) {
try {
    const Index = event.currentTarget.dataset.index;
    const updatedRecords = JSON.parse(JSON.stringify(this.agreementProducts));
    if(updatedRecords[Index].Id){
    updatedRecords[Index] = {
        ...updatedRecords[Index],
        'Is_Canceled__c': true,
        'NotIsCanceled':false,
        'Is_Amended__c':false,
        'cssClass':"canceled-row"
    };
    }
    else{
        updatedRecords.splice(Index, 1); // Remove the record from the array

    }
    this.agreementProducts = updatedRecords;
} catch (error) {
}
}

handleSave() {

if (this.IsDataValid()) {
    this.isLoading = true;
    console.log("this.agreementProducts",JSON.stringify(this.agreementProducts));
 
    
    saveAgreementProducts({ updatedAgreementProducts: this.agreementProducts })
        .then(() => {
            this.showToast("success","Changes has been saved", "success");
            // this.updatedProducts = [];   
            //this.fetchAgreementProducts();
            this.closeAction();
        })
        .catch((error) => {
            this.showToast("Error", "Error saving changes", 'error');
            console.log(error);
            

        })
        .finally(() => {
            this.isLoading = false;
        });   

    
}
else{
    this.showToast("Error", "Please fill in all required fields with valid values", 'error');

}

}

handleCancel(){
const closeModalEvent = new CustomEvent("modalclose");
this.dispatchEvent(closeModalEvent);
}
IsDataValid() {
try {
    // Select only inputs inside rows that are NOT canceled
    const inputElements = this.template.querySelectorAll(
        'tr:not(.canceled-row) lightning-input, ' +
        'tr:not(.canceled-row) lightning-combobox, ' +
        'tr:not(.canceled-row) lightning-textarea, ' +
        'tr:not(.canceled-row) lightning-record-picker'
    );

    // Check the validity of each input element
    for (const inputElement of inputElements) {
        if (!inputElement.checkValidity()) {
            console.log('Invalid input:', inputElement);
            return false;
        }
    }
    
    // If all inputs and lookups are valid, return true
    return true;
} catch (error) {
    console.error('Error in IsDataValid:', error);
    return false;
}
}

fetchPlantValue(productID) {
try {
    if (productID) {
        this.isLoading = true;

        return fetchPlantValue({ productID: productID })
            .then(response => {
                console.log(response);
                return response;
            })
            .catch(error => {
                throw error; // Throw the error to propagate it to the caller
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

} catch (error) {

}
finally {

}


}

showToast(title, message, variant) {
const toastEvent = new ShowToastEvent({
    title: title,
    message: message,
    variant: variant,
});
this.dispatchEvent(toastEvent);
}
closeAction() {
this.dispatchEvent(new CloseActionScreenEvent());
}
createEmptyRecord() {
return {

    "Id":null,
    "Master_Agreement__c":"",
    "Name":"",
    "Product__c":"",
    "Price__c":"",
    "FOC_Text__c":"",
    "Plant__c":"",//evn thou its formula field i am using it for namw
    "CurrencyIsoCode":"",
    "Payment_Terms_options__c":"",
    "Incoterms__c":"",
    "Is_Amended__c": false,
    "Is_Canceled__c": false,
    "Master_Agreement__c": this.recordId,
    "cssClass": this.determineAmendment()?"amended-row":"default-row",
    "isDisabled": false,
    "Is_Amended__c":this.determineAmendment(),
    "NotIsCanceled": true

};
}

determineAmendment(){
console.log("this.masterAgrementVersion ==", this.masterAgreementRec.version__c);

console.log("this.renewedFrom ? true:",this.masterAgreementRec.Renewed_From__c ? true:false);

console.log("return", this.masterAgreementRec.version__c === "V1" ? (this.masterAgreementRec.Renewed_From__c ? true:false ): true);

return this.masterAgreementRec.version__c === "V1" ? (this.masterAgreementRec.Renewed_From__c ? true:false ): true;
}
}