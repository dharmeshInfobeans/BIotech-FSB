import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentUserAndSettings  from '@salesforce/apex/loginlogoutcontroller.getCurrentUserAndSettings';
import insertDailyActivity from '@salesforce/apex/loginlogoutcontroller.insertDailyActivity';
import getloginlogoutmodule from '@salesforce/apex/loginlogoutcontroller.getCustomLabels';
//import PAST_DAYS_LEAVE_POLICY from '@salesforce/label/c.Past_days_Leave_policy';
import logouttDailyActivity from '@salesforce/apex/loginlogoutcontroller.logoutActivity';
import getBeatPlanStatus  from '@salesforce/apex/loginlogoutcontroller.getBeatPlanStatus';
import getUpcomingBeatPlans from '@salesforce/apex/loginlogoutcontroller.getUpcomingBeatPlans';
import applyleavedata  from '@salesforce/apex/loginlogoutcontroller.applyLeave';
import getLeaveType from "@salesforce/apex/calendarPlanningMobileController.getLeaveType";
import getHolidayRecord from "@salesforce/apex/calendarPlanningMobileController.getHolidayRecord";
import applyleavefuturedate from '@salesforce/apex/loginlogoutcontroller.applyLeavefuturedate';


const columns = [
    { label: 'Select', fieldName: 'isSelect', type : 'checkbox'},
    { label: 'Date', fieldName: 'Date', type: 'date' },
    {label: 'Type', fieldName: 'Type', type:'picklist'}
    
];
export default class AttendanceScreen extends NavigationMixin(LightningElement) {
    @track username = '';  // Initialize username
    user;
    latitude;
    longitude;
    @track leaveOptions;
    columns = columns;
    minDate
    @track selectedDate ;
     @track beatPlans =[];
    @track currentDatenew;
    @track getloginlogoutlabel ={};
    @track disablelogin = false;

   /* label = {
        pastDaysLeavePolicy: PAST_DAYS_LEAVE_POLICY
    };*/

@track compensationDate=null;//changes by yogi

    selectedLeaveOption = '';
    reason = '';
    @track selectedRowsData = [];
    @track cofscreen = false;

    @track cofopenscreen = false;
    @track saveButtonDisabled = false;
    @track leavedata = false;
    @track Attendance = true;
    @track startmyday = false;
    @track Startday = true;
    @track logoutday = false;
    @track loginday = false;
    @track Endday = false;
    @track endmyday = false;
    @track isModalOpen = false;
    @track endModalOpen = false;
    @track isLeave = false;
    @track Approvedreject = false;
    @track currentTime;
    @track currentDate = this.getFormattedDate();
    @track beatPlanStatus ={};
    @track noactivity =false;
    @track validdate = false;
    @track userDetails = {};
    @track countrySettings = [];
    @track dtDif=0;
     @track managerName;
    @track managerEmail;
    timeInterval;
    error;



@wire(getUpcomingBeatPlans)
wiredData({ data, error }) {
    if (data) {
        this.managerName = data.managerName;
        this.managerEmail = data.managerEmail;
        this.beatPlans = data.beatPlans.map(plan => ({
            ...plan,
            CreatedDate: this.formatDate(plan.CreatedDate),
            Beat_Date__c: this.formatDate(plan.Beat_Date__c),
            rowStyle: this.getRowStyle(plan.Approval_status__c)
        }));
    }
}

 getRowStyle(status) {
        switch (status) {
            case 'Approved':
                return 'approved-row';
            case 'Pending':
                return 'pending-row';
            case 'Rejected':
            case 'Reject':
                return 'rejected-row';
            default:
                return 'default-row';
        }
    }

    // ✅ Utility method to convert ISO datetime → simple date (YYYY-MM-DD)
    formatDate(dateString) {
        try {
            return new Date(dateString).toISOString().split('T')[0];
        } catch (e) {
            return dateString;
        }
    }


    handleCancel(event) {
        const recordId = event.target.dataset.id;
        // TODO: Call Apex to cancel beat plan
        this.showToast('Cancelled', `Beat plan ${recordId} has been cancelled`, 'success');
    }

@wire(getloginlogoutmodule)
getloginlogout(result) {
    this.spinner = true;
    if (result.data) {
        this.getloginlogoutlabel = result.data;
        console.log('Translation getloginlogoutlabel', this.getloginlogoutlabel);
        if (this.getloginlogoutlabel != undefined) {
            this.spinner = false;
        }
    }
    if (result.error) {
        console.log('error', result.error);
    }
}       

@wire(getBeatPlanStatus)
wiredBeatPlanStatus({ data, error }) {
    if (data) {
        this.beatPlanStatus = data;
        console.log('Result---->:', this.beatPlanStatus);

        // Initialize flags
        this.Startday = false;
        this.Endday = false;
        this.loginday = false;
        this.logoutday = false;
        this.leavedata = false;
        this.Approvedreject = false;

        if(!this.beatPlanStatus.Login_Time__c){
            this.Startday = true;
        }else{
            this.Startday = false;
        }

        if(this.beatPlanStatus.Approval_status__c !=null && this.beatPlanStatus.Approval_status__c !=undefined){
            this.leavedata = true;
        }

        // Check if approval status is approved and event type is leave
        if (this.beatPlanStatus.Approval_status__c === 'Approved' && 
            (this.beatPlanStatus.Event_type_Name__c === 'First Half Leave' || 
            this.beatPlanStatus.Event_type_Name__c === 'Second Half Leave') && 
            !this.beatPlanStatus.Login_Time__c) {
                this.leavedata = true;
                this.Startday = true;
        }

        // Handle 'Full Day' event type and approved status
        if (this.beatPlanStatus.Event_type_Name__c === 'Full Day Leave' && this.beatPlanStatus.Approval_status__c === 'Approved') {
            this.leavedata = true;
            this.loginday = false;
            this.logoutday = false;
            this.Startday = false;
            this.Endday = false;
        }

        // Check for Login and Logout times
        if (this.beatPlanStatus.Login_Time__c && !this.beatPlanStatus.Logout_Time__c && this.beatPlanStatus.Event_type_Name__c != 'Full Day Leave') {
            this.loginday = true;
            this.Endday = true;
            this.Startday = false;
        } else if (this.beatPlanStatus.Login_Time__c && this.beatPlanStatus.Logout_Time__c && this.beatPlanStatus.Event_type_Name__c != 'Full Day Leave') {
            this.Startday = false;
            this.loginday = true;
            this.logoutday = true;
        }

        // If Event_type_Name__c is not 'Compensation off'
        if (this.beatPlanStatus.Event_type_Name__c && this.beatPlanStatus.Event_type_Name__c !== 'Compensation off') {
            this.leavedata = true;
            this.Approvedreject = true;

            if (this.beatPlanStatus.Approval_status__c === 'Rejected' || 
                this.beatPlanStatus.Approval_status__c === 'Reject' || 
                this.beatPlanStatus.Approval_status__c === 'Pending') {
                this.Startday = true;
                this.Endday = false;
                if (this.beatPlanStatus.Login_Time__c) {
                    this.Startday = false;
                    this.loginday = true;
                    this.Endday = true;
                    if(this.beatPlanStatus.Logout_Time__c){
                         this.logoutday = true;
                         this.Endday = false;
                    }
                }
            }
        }

        // Handle scenario when Event_type_Name__c is 'Compensation off'
        if (this.beatPlanStatus.Event_type_Name__c === 'Compensation off') {
            this.leavedata = true;
            if (this.beatPlanStatus.Approval_status__c === 'Approved') {
                this.loginday = false;
                this.logoutday = false;

                this.Startday = false;
                this.Endday = false;
            } else if (this.beatPlanStatus.Approval_status__c === 'Rejected' || 
                       this.beatPlanStatus.Approval_status__c === 'Reject') {
                if (!this.beatPlanStatus.Login_Time__c) {
                    this.Startday = true;
                } else {
                    this.Startday = false;
                }
            } else if (this.beatPlanStatus.Approval_status__c === 'Pending') {
                this.Startday = true;
                this.Endday = false;
            }
        }

        console.log('Beat Plan Status:', this.beatPlanStatus);
    } else if (error) {
        this.noactivity = true;
        this.error = error;
        console.error('Error fetching Beat Plan Status:', error);
    }
}



// Getter to format Login Time with both date and time
    get formattedLoginTime() {
        return this.getFormattedDateTime(this.beatPlanStatus.Login_Time__c);
    }

    // Getter to format Logout Time with both date and time
    get formattedLogoutTime() {
        return this.getFormattedDateTime(this.beatPlanStatus.Logout_Time__c);
    }

    get statusStyle() {
        const status = this.beatPlanStatus?.Approval_status__c;
        if (status === 'Approved') {
            return 'color: #28a745; background-color: #d4edda;';
        } else if (status === 'Pending') {
            return 'color: #ffc107; background-color: #fff3cd;';
        } else if (status === 'Rejected') {
            return 'color: #dc3545; background-color: #f8d7da;';
        }else if (status === 'Reject') {
            return 'color: #dc3545; background-color: #f8d7da;';
        }
        return 'color: #6c757d; background-color: #e2e3e5;';
    }

   // Method to format DateTime to show custom format: "09, Nov 2024 at 3:48PM"
getFormattedDateTime(dateTime) {
    if (dateTime) {
        const date = new Date(dateTime); // Convert to Date object

        // Extract day, month, year, hour, minute
        const day = date.getDate().toString().padStart(2, '0'); // "09"
        const month = date.toLocaleString('default', { month: 'short' }); // "Nov"
        let hour = date.getHours(); // Hour in 24-hour format
        const minute = date.getMinutes().toString().padStart(2, '0'); // "48"
        const period = hour >= 12 ? 'PM' : 'AM'; // AM/PM
        if (hour > 12) hour -= 12; // Convert to 12-hour format
        if (hour === 0) hour = 12; // Handle midnight case (0 hours)

        // Return the formatted date and time
        return `${day}, ${month} at ${hour}:${minute} ${period}`;
    }
    return ''; // Return empty if no data
}

// Method to get the formatted date (Day, Date, Month) as "Wednesday, 06 November"
getFormattedDate() {
    const date = new Date();
    
    // Options for each part of the date
    const weekdayOptions = { weekday: 'long' };
    const dayOptions = { day: '2-digit' };
    const monthOptions = { month: 'long' };
    
    // Extract each part of the date
    const weekday = date.toLocaleDateString('en-US', weekdayOptions);
    const day = date.toLocaleDateString('en-US', dayOptions);
    const month = date.toLocaleDateString('en-US', monthOptions);
    
    // Combine them into the desired format
    return `${weekday}, ${day} ${month}`;
}

// Update time every second
updateTime() {
    this.timeInterval = setInterval(() => {
        const now = new Date();
        this.currentTime = now.toLocaleTimeString(); // Format: HH:MM:SS AM/PM
    }, 1000); // Update every second
}

// Clean up the interval when the component is destroyed
disconnectedCallback() {
   
    clearInterval(this.timeInterval); 
     // Clear the interval when the component is destroyed
}

connectedCallback() {
    this.dtDif=0;
    console.log('Date diff',this.dtDif);

     // Fetch current user and custom setting data
        getCurrentUserAndSettings()
            .then((result) => {

                console.log('result---->>>',result);
               this.user = result.currentUser;
                this.username = result.currentUser.Name;
                this.userDetails = result.currentUser;
               this.dtDif=result.dtDiff;
               console.log('Datediff',this.dtDif);
            })
            .catch((error) => {
                console.error('Error fetching data:', error);
                this.error = error;
            });

     const today = new Date();
        this.minDate = today.toISOString().split('T')[0];
         const options = { weekday: 'short', day: '2-digit', month: 'short', year: 'numeric' };
        this.currentDatenew = new Date().toLocaleDateString('en-GB', options).replace(',', '');
    // Wire the Apex method
    this.getUserLocation();
    this.updateTime();
}


    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(event);
    }


 @wire(getLeaveType)
    getLeaveType({
        error,
        data
    }) {
        if (error) {
            console.log("Error in getMeetingType");
            this.leaveOptions = null;
        } else if (data) {
            console.log(data);
           // var leaveOptions = data;
            this.leaveOptions = Object.keys(data).map(label => {
            return {
                label: label,      // Display label (e.g., "Sick Leave")
                value: data[label] // API value (e.g., "SICK")
            };
        });
            
            console.log('leaveOptions ', this.leaveOptions);
        }
    }

   /* // Wire the current user
    @wire(getCurrentUser)
    wiredUser({ error, data }) {
        if (data) {
            this.user = data;
            this.username = this.user.Name;
            this.currentusercountry = this.user.country__c
            console.log('Name', this.user.Name);
        } else if (error) {
            this.error = error;
            console.error('Error fetching user data:', error);
        }
    }*/

    // Get user location
    getUserLocation() {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                (position) => {
                    this.latitude = position.coords.latitude;
                    this.longitude = position.coords.longitude;
                    console.log('Latitude:', this.latitude);
                    console.log('Longitude:', this.longitude);
                },
                (error) => {
                    console.error('Error getting location', error);
                }
            );
        }
    }

    // Log in activity (capture time, latitude, and longitude)
    logInActivity() {
        this.disablelogin = true;
        console.log('Latitude:', this.latitude);
        console.log('Longitude:', this.longitude);
        
        insertDailyActivity({ 
            latitude: this.latitude, 
            longitude: this.longitude 
        })
        .then(() => {
            console.log('User activity logged successfully.');
            this.Startday = false;
            this.Endday = true;
            this.isModalOpen = false;
            this.startmyday = false;
            window.location.reload();
        })
        .catch((error) => {
            this.disablelogin = false;
            console.error('Error logging user activity:', error);
        });
    }

    logOutActivity() {
        this.disablelogin = true;
        console.log('Latitude:', this.latitude);
        console.log('Longitude:', this.longitude);
        

        logouttDailyActivity({ 
            latitude: this.latitude, 
            longitude: this.longitude 
        })
        .then(() => {
            console.log('User activity logout successfully.');
     this.startmyday = false;
     this.Endday = false;
    this.Startday = false;
    this.endmyday = true;
    this.isModalOpen = false;
    this.endModalOpen = false;
    window.location.reload();
        })
        .catch((error) => {
            this.disablelogin = false;
            console.error('Error logging user activity:', error);
        });
    }

    get userPhotoUrl() {
        return this.user ? this.user.SmallPhotoUrl : null;
    }

    get userName() {
        return this.user ? this.user.Name : 'User'; // Adjust based on how you want to show the name
    }

    // Handle start and end of the day
    handlestartday(event) {
        console.log('Handle start day');
        if(this.beatPlanStatus.Approval_status__c =='Pending'){
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.getloginlogoutlabel.Warning__c,
                    message: this.getloginlogoutlabel.Please_contact_manager_for_reject_or_app__c,
                    variant: this.getloginlogoutlabel.Warning__c,
                })
            );
            return;
        }
        this.startmyday = true;
        this.isModalOpen = true;

        this.endModalOpen = false;
    }

    handleendday() {
        if(this.beatPlanStatus.Approval_status__c == 'Pending' && this.beatPlanStatus.Login_Time__c && !this.beatPlanStatus.Logout_Time__c){
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.getloginlogoutlabel.Warning__c,
                        message: this.getloginlogoutlabel.Please_contact_manager_for_Approved_your__c,
                        variant: this.getloginlogoutlabel.Warning__c,
                })
            );
            return;
        }else{
        this.startmyday = false;
        this.Startday = false;
        this.endmyday = true;
        this.Endday = true;
        this.isModalOpen = false;
        this.endModalOpen = true;
        }
    }

    // Close modal if clicking on the overlay
    handleOverlayClick(event) {
        this.closeModal();
    }

    closeModal() {
        this.isModalOpen = false;
        this.endModalOpen = false;
    }

    // Prevent clicks inside the modal from closing it
    stopPropagation(event) {
        event.stopPropagation();
    }

    handleleave(){
        // if(this.beatPlanStatus.Approval_status__c =='Pending'||this.beatPlanStatus.Approval_status__c =='Rejected'||this.beatPlanStatus.Approval_status__c =='Approved'){
        //     this.dispatchEvent(
        //         new ShowToastEvent({
        //             title: 'Warning',
        //             message: 'Leave is already Applied.',
        //             variant: 'warning'
        //         })
        //     );
        //     this.Attendance = true;
        // this.isLeave = false;
        //     return;
        // }
        /*if(this.beatPlanStatus.Login_Time__c){
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Warning',
                    message: 'You are Log In in the system so could not apply leave.',
                    variant: 'warning'
                })
            );
            this.Attendance = true;
        this.isLeave = false;
            return;
        }*/
        this.Attendance = false;
        this.isLeave = true;
        //this.saveButtonDisabled = false;
    }
    handleSubmit(event){


         this.validdate = true;
        console.log('handlesubmit');
        console.log('this.reason',this.reason);


          // Regex to disallow numbers and special characters
           

            // Check if the reason is at least 10 characters long
           
        
        if(this.reason=='' || this.reason ==undefined || this.reason == null){
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.getloginlogoutlabel.Error__c,
                    message: this.getloginlogoutlabel.Please_Enter_reason__c,
                    variant: this.getloginlogoutlabel.Error__c,
                })
            );
            this.validdate = false;
            return;
        }
         /*if (this.reason.length < 10) {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Reason must be at least 10 characters long.',
                        variant: 'error',
                    })
                );
                return;
            }*/
           console.log('this.selectedLeaveOption',this.selectedLeaveOption);
        if (!this.selectedLeaveOption) {
            // Show error toast if no leave option is selected
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.getloginlogoutlabel.Error__c,
                        message: this.getloginlogoutlabel.Please_select_leave_type__c,
                        variant: this.getloginlogoutlabel.Error__c,
                })
            );
            this.validdate = false;
            return; // Prevent further processing
        }
        this.validdate = true;
       
       if (new Date(this.selectedDate) > new Date() || new Date(this.selectedDate) < new Date()) {
                        
       applyleavefuturedate({ reason: this.reason, leaveType: this.selectedLeaveOption , futureDate: this.selectedDate,holidayDate:this.compensationDate})
             .then(result => {
                // Success toast
                console.log('result:--->',result);
                if(result==='Success'){
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: this.getloginlogoutlabel.Success__c,
                            message: `${this.selectedLeaveOption} ${this.getloginlogoutlabel.Leave_type_applied_successfully__c}`, // Use backticks for template literals
                            variant: this.getloginlogoutlabel.Success__c,
                        })
                    );
                    this.validdate = true;
                    this.Attendance = true;
                    this.isLeave = false;
                    this.saveButtonDisabled = true;
                    window.location.reload();
                }if(result === 'Already'){
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: this.getloginlogoutlabel.Warning__c,
                            message: `${this.getloginlogoutlabel.Leave_is_already_Applied_for_that_date__c} ${this.selectedDate}`,
                            variant: this.getloginlogoutlabel.Warning__c,
                        })

                    );

                }
                
            })
            
            .catch(error => {
                // Error toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            });
    
} else {
    console.log('Selected date is today or in the past.');

        applyleavedata({ reason: this.reason, leaveType: this.selectedLeaveOption})
             .then(result => {
                // Success toast
                if(result ==='Already'){
                    this.dispatchEvent(
                    new ShowToastEvent({
                        title: this.getloginlogoutlabel.Warning__c,
                        message: this.getloginlogoutlabel.Leave_is_already_Applied__c,
                        variant: this.getloginlogoutlabel.Warning__c,
                    })
                );
                }
                if(result ==='Success'){
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: this.getloginlogoutlabel.Success__c, // Assuming this property holds a valid string
                        message: `${this.selectedLeaveOption} ${this.getloginlogoutlabel.Leave_type_applied_successfully__c}`, // Use backticks for template literals
                        variant: this.getloginlogoutlabel.Success__c
                    })
                );
                this.validdate = true;
               this.Attendance = true;
               this.isLeave = false;
               this.saveButtonDisabled = true;
               window.location.reload();
            }
            })
            
            .catch(error => {
                // Error toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: error.body.message,
                        variant: 'error',
                    })
                );
            });
    
        }
    }



  // Current date to autofill the date field
    currentDate = this.getCurrentDate();
    getCurrentDate() {
        let today = new Date();
        let dd = String(today.getDate()).padStart(2, '0');
        let mm = String(today.getMonth() + 1).padStart(2, '0'); // January is 0!
        let yyyy = today.getFullYear();
        return yyyy + '-' + mm + '-' + dd;
    }
        

    handleCancel(){
        this.Attendance = true;
        this.selectedDate = '';
        this.reason = '';
        this.isLeave = false;
        this.cofopenscreen = false;
        this.selectedLeaveOption = '';


    }

    handleChangeField(event){
      const fieldName = event.target.name;

        
        if (fieldName === 'Reason') {
          
            this.reason = event.target.value;
        } else if (fieldName === 'leaveOptions') {
            this.selectedLeaveOption = event.target.value;
            console.log('this.selectedLeaveOption',this.selectedLeaveOption);
            if(event.target.value =='Compensation off'){
                
                this.cofscreen = true;


            }else{
                this.cofscreen = false;
            }

        }
       
    
    }

handleDateChange(event) {
    // Get the selected date from the date picker
    this.selectedDate = event.target.value;

    // Convert the selected date to a Date object
    const selectedDateObj = new Date(this.selectedDate);

    // Calculate the difference in days between the current date and the selected date
    const currentDate = new Date();
    const timeDifference = currentDate - selectedDateObj;
    const dtDif = timeDifference / (1000 * 3600 * 24); // Convert milliseconds to days

    console.log('allow days', dtDif); // Log the calculated date difference

    // Get the threshold (number of past days allowed) from some source, e.g., custom setting or label
    const pastDaysThreshold = this.dtDif || 20; // Example threshold if dtDif is undefined or invalid

    // Calculate the earliest allowed date based on the threshold
    const allowedPastDate = new Date();
    allowedPastDate.setDate(allowedPastDate.getDate() - pastDaysThreshold);
    
    // Log the dates for debugging
    console.log('Allowed Past Date:', allowedPastDate.toISOString().split('T')[0]);
    console.log('Selected Date:', this.selectedDate);

    // Compare the selected date with the allowed past date
    if (selectedDateObj < allowedPastDate) {
        // If the selected date is earlier than the threshold, show an error
        this.showError(
            `The selected date cannot be more than ${pastDaysThreshold} days in the past. Please select a valid date.`
        );
        this.validdate = true;
    } else {
        // If the selected date is valid
        this.hideError();
        this.saveButtonDisabled = false;
        this.validdate = false;
        console.log('Valid Date:', this.selectedDate);
    }
}


// Helper methods to show/hide error
showError(message) {
    const errorElement = this.template.querySelector('.error-message');
    if (errorElement) {
        errorElement.textContent = message;
        errorElement.style.display = 'block';
    }
}

hideError() {
    const errorElement = this.template.querySelector('.error-message');
    if (errorElement) {
        errorElement.textContent = '';
        errorElement.style.display = 'none';
    }
}


    handleNavigateToCustomTab() {
        if((this.beatPlanStatus.Approval_status__c =='Pending' ||this.beatPlanStatus.Approval_status__c =='Approved') && this.beatPlanStatus.Event_type_Name__c =='Full Day Leave'){
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.getloginlogoutlabel.Warning__c,
                    message: this.getloginlogoutlabel.You_have_already_applied_for_leave_so_p__c,
                    variant: this.getloginlogoutlabel.Warning__c
                })
            );
            return;
            }
            if(this.beatPlanStatus.Approval_status__c == 'Pending'){
            this.dispatchEvent(
                new ShowToastEvent({
                    title: this.getloginlogoutlabel.Warning__c,
                    message: this.getloginlogoutlabel.Your_leave_request_still_pending_so_plan__c,
                    variant: this.getloginlogoutlabel.Warning__c
                })
            );
            return;
            }
            if((this.noactivity == true ||this.beatPlanStatus == undefined || this.beatPlanStatus == null || !this.beatPlanStatus.Login_Time__c)||((this.beatPlanStatus.Approval_status__c == 'Rejected' || this.beatPlanStatus.Approval_status__c == 'Reject') && !this.beatPlanStatus.Login_Time__c)||(this.beatPlanStatus.Approval_status__c == 'Approved' && !this.beatPlanStatus.Login_Time__c)){
                this.dispatchEvent(
                new ShowToastEvent({
                    title: this.getloginlogoutlabel.Warning__c,
                    message: this.getloginlogoutlabel.Kindly_please_start_your_day_before_plan__c,
                    variant: this.getloginlogoutlabel.Warning__c
                })
            );
            return;
            }

        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: {
                apiName: 'Event_Planner_Details'
            },
        });
    }


    holidaylist =[];
    handlenext(){
        if(this.selectedDate==undefined || this.selectedDate==''){
            this.selectedDate = this.getCurrentDate();

        }
        this.saveButtonDisabled = true;
        getHolidayRecord({}).then(result=>{
            console.log('---693---->Result ', result);
            this.holidaylist = result.holidays;
           // this.weeklydata = result.WeeklyOff;
            console.log('holidaylist',this.holidaylist);
 if (!this.holidaylist || this.holidaylist.length === 0) {
    console.log('Holiday list is either null, undefined, or empty.');
    this.saveButtonDisabled = true;

} else {
    
    console.log('Holiday list has items:', this.holidaylist);
    //this.saveButtonDisabled = false;
}
        })
        this.isLeave = false;
        this.cofopenscreen = true;
        this.cofscreen = false;
        
        
       
    }

    @track selectedRowsData = [];
    handleRowSelection(event) {
        
        const selectionvalue = event.detail.selectedRows;
//----------------------added start by yogi---------------------//
            selectionvalue.forEach(row => {
                this.compensationDate = row.Date;
            });
//----------------------added end by yogi---------------------//
        console.log('this.selectedRowsData.length : ',this.selectedRowsData.length);
        console.log('selectionvalue : ',selectionvalue.length);
        if(selectionvalue.length > 1){
            console.log('715');
            this.showToast('Error', 'Only one row can be selected at a time.', 'error');
            this.saveButtonDisabled = true;
        }
        if(selectionvalue.length > 0 && this.selectedRowsData.length > 0){
            console.log('716 :');
            this.showToast('Error', 'Only one row can be selected at a time.', 'error');
            this.saveButtonDisabled = true;
            if(this.selectedRowsData.length == 1){
                this.saveButtonDisabled = false;
            }
            
        }else{
            if(selectionvalue.length === 0 && this.selectedRowsData.length >0){
                console.log('714');
                this.selectedRowsData = selectionvalue;
                if(this.selectedRowsData.length > 1 || this.selectedRowsData.length == 0 || this.selectedRowsData.length == 1){
                    this.saveButtonDisabled = true;
                }
             }else if(this.selectedRowsData.length == 0 && selectionvalue.length == 1){
                 console.log('719');
                 this.selectedRowsData = selectionvalue;
                 this.saveButtonDisabled = false;
             }
        }
       
        console.log('Selected Rows:**********--717', JSON.stringify(this.selectedRowsData));
    }
}