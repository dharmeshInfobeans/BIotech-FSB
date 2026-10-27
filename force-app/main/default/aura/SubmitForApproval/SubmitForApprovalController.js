({
    doInit : function(component, event, helper) {
        helper.onInit(component,event);
    },
    onSubmit : function(component, event, helper) {
    	helper.updateAccount(component,event);
    },
    onCancel : function(component, event, helper) {
        $A.get("e.force:closeQuickAction").fire();
        location.reload();
    },
    
})