({
	 doInit: function (component, event, helper) {
        var pageRef = component.get("v.pageReference");
         console.log('pageRef: ',pageRef);
        if (pageRef && pageRef.state) {
            component.set("v.recordId", pageRef.state.c__recordId);
            component.set("v.activityType",pageRef.state.c__activityType);
        }
    }
})