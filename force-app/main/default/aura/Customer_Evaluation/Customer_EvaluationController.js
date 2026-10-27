({
    doInit: function(component, event, helper){
        helper.fetchLastCE(component);
    },
    saveCE: function(component, event, helper){
        helper.saveCE(component);
    },
    closeModel: function(component, event, helper){
    	$A.get("e.force:closeQuickAction").fire()
    },
    hideToast : function(component, event, helper) {
        component.set("v.isError",false);
    }
})