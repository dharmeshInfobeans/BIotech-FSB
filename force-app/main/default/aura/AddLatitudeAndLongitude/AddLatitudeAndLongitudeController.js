({
    
    handleLoad : function(component, event, helper) {
        var firstLoad = component.get("v.firstLoad");
        if(firstLoad){
            helper.hideSpinner(component, event);
            var lat = event.getParams().recordUi.record.fields.BillingLatitude.value;
            var long = event.getParams().recordUi.record.fields.BillingLongitude.value;
            if(!$A.util.isEmpty(lat) && !$A.util.isEmpty(long)){
                component.set("v.showError",true);
            }
            console.log('In AddLat&LongComp-->C-->handleLoad_M-->EMP BillingLatitude Vals-->'+JSON.stringify(lat));
            console.log('In AddLat&LongComp-->C-->handleonLoad_M-->EMp BillingLongitude Val-->'+JSON.stringify(long));
            if (navigator.geolocation) {
                // Request the current position
                // If successful, call getPosSuccess; On error, call getPosErr
                helper.setLatLongValues(component);   
            } else {
                helper.showToast({
                    "title": "Oops!!",
                    "type": "error",
                    "message": "Geolocation is not supported by this browser.."
                });
                //alert('Geolocation is not supported by this browser.');
                // IP address or prompt for city?
            }   
        }
        
    },
    handleSubmit : function(component, event, helper) {
        helper.showSpinner(component, event);
        event.preventDefault();       // stop the form from submitting
        
        var storedLat = component.find("billLat").get("v.value");
        var storedLong = component.find("billLong").get("v.value");    
        console.log('In AddLat&LongComp-->C-->handleSubmit_M-->lati Vals-->'+JSON.stringify(storedLat));
        console.log('In AddLat&LongComp-->C-->handleSubmit_M-->longi Vals-->'+JSON.stringify(storedLong));
        if(!$A.util.isUndefinedOrNull(storedLat) && !$A.util.isUndefinedOrNull(storedLong)){
            var fields = event.getParam('fields');
            console.log('In AddLat&LongComp-->C-->handleSubmit_M-->Field Vals-->'+JSON.stringify(fields));    
            component.find('accLocForm').submit(fields);
            component.set("v.firstLoad",false);
        }else{
            helper.showToast({
                "title": "Oops!!",
                "type": "error",
                "message": "Location coordinates are empty."
            });
        } 
    },
    handleSuccess : function(component, event, helper) {
        console.log('In AddLat&LongComp-->C-->In handleSuccess_M !!!');
        helper.hideSpinner(component, event);
        $A.get("e.force:closeQuickAction").fire();
        helper.showToast({
            "title": "Success!!",
            "type": "success",
            "message": "Current Location is added successfully to the account."
        });
              
        var payload = event.getParams().response;
        console.log('In AddLat&LongComp-->C-->handleSubmit_M-->updated RecID-->'+payload.id);
        
        
        
        
        
    },
    handleError : function(component, event, helper) {
        helper.hideSpinner(component, event);
        helper.showToast({
            "title": "Oops!!",
            "type": "error",
            "message": "Error occurred while saving the record."
        });
    },
})