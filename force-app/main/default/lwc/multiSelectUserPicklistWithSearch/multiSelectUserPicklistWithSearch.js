import { LightningElement, track, api, wire} from 'lwc';
import getUsers from "@salesforce/apex/calendarPlanningMobileController.getUsers"; 

export default class MultiSelectUserPicklistWithSearch extends LightningElement {
    @api selectedValue;
    @api selectedValues = [];
    @api label;
    @api labels = {}
    @api minChar = 2;
    @api disabled = false;
    @api multiSelect = false;
    @track value;
    @track values = [];
    @track optionData;
    @track searchString;
    @track message;
    @track showDropdown = false;
    searchProdKey=null;
    selectedProductValues = new Map();
    @track selectedUserValuesList;


    @wire(getUsers)
    getUsers({error, data}) {
        if (error) {
            console.log("Error in getUsers");
        } else if (data) {
         console.log('getUsers data ',data);
          var userData = data; 
          this.options = userData.map(val =>{
            return {label:val.Name,value:val.Id}
            });
        //   this.productsOptions = userData.map(val =>{
        //    return {label:val.Name,value:val.Id}
        //    });
        this.setUser();
       }
    }

    connectedCallback(){
        console.log('searchKey: ',this.searchProdKey);
    }

    setUser() {
        try {
        this.showDropdown = false;
        console.log('this.options ',this.options);
        var optionData = this.options ? (JSON.parse(JSON.stringify(this.options))) : null;
        console.log('optionData ',optionData);
        var value = this.selectedValue ? (JSON.parse(JSON.stringify(this.selectedValue))) : null;
        console.log('value ',value);
        var values = this.selectedValues ? (JSON.parse(JSON.stringify(this.selectedValues))) : null;
        console.log('values ',values);
		if(value || values) {
            var searchString;
        	var count = 0;
            for(var i = 0; i < optionData.length; i++) {
                if(this.multiSelect) {
                    if(values.includes(optionData[i].value)) {
                        optionData[i].selected = true;
                        count++;
                    }  
                } else {
                    if(optionData[i].value == value) {
                        searchString = optionData[i].label;
                    }
                }
            }
            if(this.multiSelect)
                this.searchString = count + ' '+this.labels.selected__c;
            else
                this.searchString = searchString;
        }
        this.value = (value!=null?value:this.value);
        this.values = (values!=null?values:this.values);
        this.optionData = optionData;
              
    } catch (error) {
        console.log('Error in setUser ',error);
    }
    }

    filterOptions(event) {
        try {
        this.searchString = event.target.value;
        this.searchProdKey = event.target.value;
        if( this.searchString && this.searchString.length > 0 ) {
            this.message = '';
            if(this.searchString.length >= this.minChar) {
                var flag = true;
                if(this.optionData!=undefined){
                    for(var i = 0; i < this.optionData.length; i++) {
                        if(this.optionData[i].label.toLowerCase().trim().startsWith(this.searchString.toLowerCase().trim())) {
                            this.optionData[i].isVisible = true;
                            flag = false;
                        } else {
                            this.optionData[i].isVisible = false;
                        }
                    }
                }
                if(flag) {
                    this.message = "No results found for '" + this.searchString + "'";
                }
            }
            this.showDropdown = true;
        } else {
            this.showDropdown = false;
        }
            
    } catch (error) {
        console.log('Error in filterOptions ',error);
    }
	}

    selectItem(event) {
        try {
        var selectedVal = event.currentTarget.dataset.id;
        if(this.selectedProductValues.has(selectedVal)){
            this.selectedProductValues.delete(selectedVal);
        }else{
            this.selectedProductValues.set(selectedVal, selectedVal);
        }
        this.selectedUserValuesList = Array.from(this.selectedProductValues.values());
        console.log('this.users_selected ',this.users_selected);
        console.log('selectedVal ',selectedVal);
        if(selectedVal) {
            var count = 0;
            console.log('this.optionData ',this.optionData);
            var options = JSON.parse(JSON.stringify(this.optionData));
            console.log('option ',options);
            for(var i = 0; i < options.length; i++) {
                //console.log('options[i].value ',options[i].value);
                if(options[i].value === selectedVal) {
                    if(this.multiSelect) {
                        console.log('this.values ',this.values);
                        if(this.values!=null) {
                            console.log('in if');
                            if(this.values.includes(options[i].value)){
                                this.values.splice(this.values.indexOf(options[i].value), 1);
                            }
                        } else {
                            this.values.push(options[i].value);
                        }
                        options[i].selected = options[i].selected ? false : true;   
                    } else {
                        this.value = options[i].value;
                        this.searchString = options[i].label;
                    }
                }
                if(options[i].selected) {
                    count++;
                }
            }
            this.optionData = options;
            if(this.multiSelect)
                this.searchString = count + ' '+this.labels.selected__c;
            if(this.multiSelect)
                event.preventDefault();
            else
                this.showDropdown = false;
        }
        console.log('selectedUserValuesList ',this.selectedUserValuesList);
        const selectedProduct = new CustomEvent(
            "selectuser",
           {detail:this.selectedUserValuesList}
        );
        this.dispatchEvent(selectedProduct);
    } catch (error) {
           console.log('Error in selectItem ',error);
    }
    }

    showOptions() {
        try {
        if(this.disabled == false && this.options) {
            this.message = '';
            this.searchString = '';
            var options = JSON.parse(JSON.stringify(this.optionData));
            for(var i = 0; i < options.length; i++) {
                options[i].isVisible = true;
            }
            if(options.length > 0) {
                this.showDropdown = true;
            }
            this.optionData = options;
        }
        } catch (error) {
            console.log('Error in showOptions ',error);
        }
	}

    removePill(event) {
        try {
        var value = event.currentTarget.name;
        var count = 0;
        var options = JSON.parse(JSON.stringify(this.optionData));
        for(var i = 0; i < options.length; i++) {
            if(options[i].value === value) {
                options[i].selected = false;
                this.values.splice(this.values.indexOf(options[i].value), 1);
            }
            if(options[i].selected) {
                count++;
            }
        }
        this.optionData = options;
        if(this.multiSelect)
            this.searchString = count + ' Option(s) Selected';
                 
        } catch (error) {
            console.log('Error in removePill ',error);
        }
    }

    blurEvent() {
        try {
        var previousLabel;
        var count = 0;
        console.log('optionData ',this.optionData);
        if(this.optionData!=undefined) {
            for(var i = 0; i < this.optionData.length; i++) {
                if(this.optionData[i].value === this.value) {
                    previousLabel = this.optionData[i].label;
                }
                if(this.optionData[i].selected) {
                    count++;
                }
            }
        }
        if(this.multiSelect)
        	this.searchString = count + ' '+this.labels.selected__c;
        else
        	this.searchString = previousLabel;
        
        this.showDropdown = false;

        this.dispatchEvent(new CustomEvent('select', {
            detail: {
                'payloadType' : 'multi-select',
                'payload' : {
                    'value' : this.value,
                    'values' : this.values
                }
            }
        }));
    } catch (error) {
        console.log('Error in blurEvent ',error);
    }
    }
}