import { LightningElement,api,track,wire } from 'lwc';
import getProducts from "@salesforce/apex/calendarPlanningMobileController.getProducts";


/** The delay used when debouncing event handdlers before invoking functions. */
const delay = 350;
export default class SearchableSelectList extends LightningElement {

     //functional properties
     @api fieldLabel;
     @api disabled = false;
     @track openDropDown = false;
     @track inputValue = "";
     @api placeholder = "";
     @api options;
     @api optionsToDisplay;
     @api value = "";
     @track label = "";
     delaytimeout;
     @track productsOptions;
 
     //constructor
     constructor() {
         super();
     }
 
     connectedCallback() {
         //this.setOptionsAndValues();
     }
 
     renderedCallback() {
        //  if (this.openDropDown) {
        //      this.template.querySelectorAll('.search-input-class').forEach(inputElem => {
        //          inputElem.focus();
        //      });
        //  }
     }

     @wire(getProducts)
    getProducts({error, data}) {
        if (error) {
            console.log("Error in getProducts");
           this.productsOptions = null;
        } else if (data) {
         console.log(data);
          var userData = data; 
          this.productsOptions = userData.map(val =>{
           return {label:val.Name,value:val.Name}
           });
       }
    }
 
     //Public Method to set options and values
    //  @api setOptionsAndValues() {
    //      try {
    //         this.optionsToDisplay = (this.options && this.options.length > 0 ? this.options : []);
    //         if (this.value && this.value != "") {
    //             let label = this.getLabel(this.value);
    //             if (label && label != "") {
    //                 this.label = label;
    //             }
    //         }
    //         else {
    //             this.label = "";
    //         }
    //      } catch (error) {
    //          console.log('error ',error);
    //      }
    //  }
 
     //Method to get Label for value provided
    //  getLabel(value) {
    //     try {
    //         let selectedObjArray = this.optionsToDisplay.filter(obj => obj.value === value);
    //         if (selectedObjArray && selectedObjArray.length > 0) {
    //             return selectedObjArray[0].label;
    //         }
    //         return null;
    //     } catch (error) {
    //         console.log('error ',error);
    //     }
        
    //  }
 
     //Method to open listbox dropdown
    //  openDropDown(event) {
    //      console.log('openDropDown');
    //      this.toggleOpenDropDown(true);
    //  }
 
     //Method to close listbox dropdown
     closeDropdown(event) {
        console.log('closeDropdown');
        try {
            window.setTimeout(() => {
                this.toggleOpenDropDown(false);
            }, 300);
            // if (event.relatedTarget && event.relatedTarget.tagName == "UL" && event.relatedTarget.className.includes('customClass')) {
            //     console.log(JSON.stringify(event.relatedTarget.className));
            //     if (this.openDropDown) {
            //         this.template.querySelectorAll('.search-input-class').forEach(inputElem => {
            //             inputElem.focus();
            //         });
            //     }
            // }
            // else {
            //     window.setTimeout(() => {
            //         this.toggleOpenDropDown(false);
            //     }, 300);
            // }
        } catch (error) {
            console.log('error ',error);
        }
     }
 
     //Method to handle readonly input click
     handleInputClick(event) {
        console.log('handleInputClick');
        try {
           // this.resetParameters();
            this.toggleOpenDropDown(true);
        } catch (error) {
            console.log('error ',error);
        }
     }
 
     //Method to handle key press on text input
     handleKeyPress(event) {
        console.log('handleKeyPress');
        try {
            const searchKey = event.target.value;
            console.log('searchKey ',searchKey);
            this.inputValue = searchKey;
            //this.setInputValue(searchKey);
            getProducts({searchKey:this.inputValue})
            .then(result =>{
                console.log('search result ',result);
                this.productsOptions = result.map(val =>{
                    return {label:val.Name,value:val.Id}
                    });
            })
            .catch(error => {
                console.log('error ', error);
            });
            // if (this.delaytimeout) {
            //     window.clearTimeout(this.delaytimeout);
            // }
    
            // this.delaytimeout = setTimeout(() => {
            //     //filter dropdown list based on search key parameter
            //   //this.filterDropdownList(searchKey);
            // }, delay);
        } catch (error) {
            console.log('error ',error);
        }
     }
 
     //Method to filter dropdown list
    //  filterDropdownList(key) {
    //     try {
    //         console.log('filtered this.options ',this.options);
    //         // const filteredOptions = this.options.filter(item => item.label.toLowerCase().includes(key.toLowerCase()));
    //         // this.optionsToDisplay = filteredOptions;
    //     } catch (error) {
    //         console.log('error ',error);
    //     }
    //  }
 
     //Method to handle selected options in listbox
     optionsClickHandler(event) {
        console.log('optionsClickHandler');
        try {
            const value = event.target.closest('li').dataset.value;
            const label = event.target.closest('li').dataset.label;
            //this.setValues(value, label);
            //this.toggleOpenDropDown(false);
            const detail = {};
            detail["value"] = value;
            detail["label"] = label;
            console.log('detail ',detail);
           // this.dispatchEvent(new CustomEvent('change', { detail: detail }));
        } catch (error) {
            console.log('error ',error);
        }
     }
 
     //Method to reset necessary properties
    //  resetParameters() {
    //     try {
    //         this.setInputValue("");
    //         this.optionsToDisplay = this.options;
    //     } catch (error) {
    //         console.log('error ',error);
    //     }
    //  }
 
     //Method to set inputValue for search input box
    //  setInputValue(value) {
    //      try {
    //         this.inputValue = value;
    //         console.log('this.inputValue ',this.inputValue);
    //         const selectedValue = new CustomEvent('search', { detail: this.inputValue });
    //        // Dispatches the event.
    //        this.dispatchEvent(selectedValue);
    //      } catch (error) {
    //          console.log('error ',error);
    //      }
    //  }
 
     //Method to set label and value based on
     //the parameter provided
    //  setValues(value, label) {
    //     console.log('setValues');
    //     try {
    //         this.label = label;
    //         this.value = value;
    //     } catch (error) {
    //         console.log('error ',error);
    //     }
    //  }
 
     //Method to toggle openDropDown state
     toggleOpenDropDown(toggleState) {
        console.log('toggleOpenDropDown');
         this.openDropDown = toggleState;
     }
 
     //getter setter for labelClass
     get labelClass() {
         return (this.fieldLabel && this.fieldLabel != "" ? "slds-form-element__label slds-show" : "slds-form-element__label slds-hide")
     }
 
     //getter setter for dropDownClass
     get dropDownClass() {
         return (this.openDropDown ? "slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click slds-is-open" : "slds-combobox slds-dropdown-trigger slds-dropdown-trigger_click");
     }
 
     //getter setter for isValueSelected
     get isValueSelected() {
         return (this.label && this.label != "" ? true : false);
     }
 
     get isDropdownOpen() {
         return (this.openDropDown ? true : false);
     }
 
}