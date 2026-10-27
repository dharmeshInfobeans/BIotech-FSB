({
    closeModal : function(component) {

        component.set("v.isOpen", false);

        var recId = component.get("v.recordId");

        // recordId aayegi = Campaign Id (when coming from campaign)
        if(recId){

            var navEvt = $A.get("e.force:navigateToSObject");
            navEvt.setParams({
                recordId: recId,
                slideDevName: "detail"
            });
            navEvt.fire();

        }else{
            // fallback
            window.location.href = '/lightning/o/Campaign_Member__c/list?filterName=__Recent';
        }
    }
})