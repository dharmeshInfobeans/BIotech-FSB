({
  closeQuickAction: function (component, event, helper) {
    $A.get("e.force:refreshView").fire();
    var dismissActionPanel = $A.get("e.force:closeQuickAction");
    dismissActionPanel.fire();
  }

  // doInit: function (component, event, helper) {
  //   var opts = [];
  //   var recordId = component.get('v.recordId');
  //   var shipToCode = component.find("ShipToCode");

  //   var action = component.get("c.fetchDetails");

  //   action.searchParams({ orderId: recordId });
  //   action.setCallback(this, function (result) {
  //     console.log('result' + result);
  //     var state = result.getState();
  //     if (state === 'SUCCESS') {
  //       console.log('result' + result.getReturnValue());

  //       opts.push({
  //         class: "optionClass",
  //         label: "--- None ---",
  //         value: ""
  //       });
  //       for (var i = 0; i < result.getReturnValue().length; i++) {
  //         opts.push({ "class": "optionClass", label: result.getReturnValue()[i].Ship_To_Code__c, value: result.getReturnValue()[i].Ship_To_Code__c });
  //       }
  //       shipToCode.set("v.options", opts);
  //     }
  //   });


  // }
});