({
    doInit: function (component, event, helper) {
        var pageRef = component.get("v.pageReference");
        if (pageRef && pageRef.state) {
            component.set("v.recordId", pageRef.state.c__recordId);
            // component.set("v.modalHeader", pageRef.state.c__modalHeader);
        }
    },
    handleClose: function (component, event, helper) {
           console.log('inside aura before');
       component.set("v.showScreen", false);
        console.log('inside aura after');
    }
})