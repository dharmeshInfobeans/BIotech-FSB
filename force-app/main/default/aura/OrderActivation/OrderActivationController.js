({
  closeQuickAction: function (component, event, helper) {
    $A.get("e.force:refreshView").fire();
    var dismissActionPanel = $A.get("e.force:closeQuickAction");
    dismissActionPanel.fire();
  }

});