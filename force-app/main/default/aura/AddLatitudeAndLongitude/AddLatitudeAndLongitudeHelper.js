({
    showSpinner : function(component, event) {
        component.set("v.showSpinner",true);
    },
    hideSpinner : function(component, event) {
        component.set("v.showSpinner",false); 
    },
    showToast : function(params){
        var toastEvent = $A.get("e.force:showToast");
        if(toastEvent){
            toastEvent.setParams(params);
            toastEvent.fire();
        } else{
            alert(params.message);
        }
    },
    setLatLongValues : function(component){
        navigator.geolocation.getCurrentPosition(
            function(location) {
                let lat = location.coords.latitude;
                let long = location.coords.longitude;
                
                console.log('In AddLat&LongComp-->H-->setLatLongValues_M-->Lats-->'+lat);
                console.log('In AddLat&LongComp-->H-->setLatLongValues_M-->Longs-->'+long);
                console.log('In AddLat&LongComp-->H-->setLatLongValues_M-->Accuracy-->'+location.coords.accuracy);
                component.set("v.latitude",lat);
                component.set("v.longitude",long);
            }, 
            function(err) {
                switch (err.code) {
                    case err.PERMISSION_DENIED:
                        console.log('In AddLat&LongComp-->H-->setLatLongValues_M-->Error-->User denied the request for Geolocation.');
                        alert("User denied the request for Geolocation.");
                        break;
                    case err.POSITION_UNAVAILABLE:
                        alert("Location information is unavailable.");
                        break;
                    case err.TIMEOUT:
                        alert("The request to get user location timed out.");
                        break;
                    default:
                        alert("An unknown error occurred.");
                }
            }
        );
    },
})