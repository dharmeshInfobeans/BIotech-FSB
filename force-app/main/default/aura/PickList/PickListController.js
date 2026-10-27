({
    doInit : function(component) {
        var action = component.get("c.getPickListValues");
        action.setParams({
            objectType: component.get("v.sObjectName"),
            selectedField: component.get("v.fieldName")
        });
        action.setCallback(this, function(response) {
            var list = response.getReturnValue();
           //console.log("In PickListCmp-->doInit_M-->FROM APEX-->"+JSON.stringify(list));
            component.set("v.picklistValues", list);
        })
        $A.enqueueAction(action);
    }
})