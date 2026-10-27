/* eslint-disable eqeqeq */
/* eslint-disable @lwc/lwc/no-inner-html */
/* eslint-disable vars-on-top */
/* eslint-disable no-console */
/**
 * @File Name          : s howCalendar.js
 * @Description        : 
 * @Author             : ChangeMeIn@UserSettingsUnder.SFDoc
 * @Group              : 
 * @Last Modified By   : ChangeMeIn@UserSettingsUnder.SFDoc
 * @Last Modified On   : 07-09-2020
 * @Modification Log   : 
 * Ver       Date            Author      		    Modification
 * 1.0    10/9/2019   Jyoti Singh     Initial Version
**/
import { LightningElement, track, api ,wire} from 'lwc';
import { fireEvent } from 'c/pubsub';
import { CurrentPageReference } from 'lightning/navigation';
import { registerListener, unregisterAllListeners } from 'c/pubsub';
import getUserHolidays from '@salesforce/apex/calendarPlanningMobileController.getUserHolidays';

export default class showCalendar extends LightningElement {
    @track month;
    @track year;
    @api inputLabel = 'Select Date';
    @api dateMap;
    @track dataMap;
    jsCalInit = false;

    
    @wire(CurrentPageReference) pageRef;
    selectedUserId
    renderedCallback() {
    registerListener('userSelected', this.handleUserSelected, this);
        if (this.jsCalInit && this.dateMap) {
            return;
        }
        this.jsCalInit = true;
        //this.initializeJsCalendar();
    }
    handleUserSelected(payload) {
        this.selectedUserId = payload.userId;
        console.log('Received User ID:', this.selectedUserId);

        // Call Apex after getting the User ID
        if(this.selectedUserId) {
            this.spinner = true; // optional: show spinner
            getUserHolidays({ userId: this.selectedUserId })
                .then(result => {
                    this.dataMap = Array.isArray(result) ? result : [];  // force array
                    //console.log('holidays:', JSON.stringify(this.dataMap));
                    this.initializeJsCalendar();
                })
                .catch(error => {
                    console.error('Error fetching user holidays:', error);
                })
                .finally(() => {
                    this.spinner = false;
                });

        }
    }

    disconnectedCallback() {
        unregisterAllListeners(this);
    }


  // LWC mein connectedCallback update karein
connectedCallback(){
    console.log('Fetching holidays for user:', this.selectedUserId);
    
    getUserHolidays({ userId: this.selectedUserId })
        .then(result => {
            console.log('✅ Raw holiday data from Apex:', result);
            console.log('✅ Number of holidays:', Object.keys(result).length);
            
            if (Object.keys(result).length === 0) {
                console.log('No holidays found in Apex response');
                //this.useTestHolidayData();
              //  return;
            }
            
            // Convert map {"date": "type|desc"} into array [{date, type, description}]
            this.dataMap = Object.entries(result).map(([date, value]) => {
                console.log('Processing date:', date, 'value:', value);
                
                let type, description;
                if (value && value.includes('|')) {
                    [type, description] = value.split('|');
                } else {
                    type = value;
                    description = 'No description available';
                }
                
                return { 
                    date: date, 
                    type: type ? type.trim() : '', 
                    description: description ? description.trim() : '' 
                };
            });

            console.log('✅ Final processed holidays:', this.dataMap);
            this.initializeJsCalendar();
        })
        .catch(error => {
            console.error('Error fetching user holidays:', error);
            // Fallback to test data
            //this.useTestHolidayData();
        });
}



    initializeJsCalendar() {
            this.displayed_date = new Date()                    //date wich calendar displays now
            this.current_day    = this.displayed_date.getDate() //current world time
            this.selected_date  = this.displayed_date           //date that user's selected
            
            this.body_node  = this.template.querySelector('.calendar__body');
            this.year_node  = this.template.querySelector('.calendar-year');
            this.month_node = this.template.querySelector('.calendar-month');
            this.setDateTo(this.displayed_date);
            this.date = this.selected_date.toLocaleDateString("en-US");
        }

        createDaysArray(date) {
            let 
                prev_month_last_day = new Date( //number of the last day of the previous month
                    date.getFullYear(),
                    date.getMonth(),
                    0
                ).getDate(),
    
                first_week_day = new Date( //number of the first day of the current month f.e. monday->1, wednesday->3
                    date.getFullYear(),
                    date.getMonth(),
                    1
                ).getDay(),
    
                current_month_last_day = new Date(
                    date.getFullYear(),
                    date.getMonth() + 1,
                    0
                ).getDate(),
    
                days_array = new Array(42),
    
                i = 0 // iterator for all three parts of array
    
            if (first_week_day == 0) first_week_day = 7 //if it was sunday
    
            let first_array_element = prev_month_last_day - first_week_day + 2
    
            //adds last days of previous month 
            for (i = 0; i < first_week_day - 1; ++i){
                days_array[i] = {
                    number: first_array_element + i,
                    from: 'prev month'
                }
            }
    
            //adds days of current month
            for (let k = 1; k <= current_month_last_day; ++k) {
                days_array[i] = {
                    number: k,
                    from: 'currnet month',
                    weekend: i % 7 > 4
                }
                i++
            }
    
            //adds days of next month
            for (let k = 0; i < days_array.length; ++k) {
                days_array[i] = {
                    number: k + 1,
                    from: 'next month'
                }
                i++
            }
    
            return days_array
        }
        
        //returns a  fulfilled and styled table DOM element
        createCalendarBody(date, current_month = false ) {
            var currentMonth =  date.getMonth()+1;
            if(currentMonth<10){
                currentMonth = '0'+currentMonth;
            }
            let 
                days_array = this.createDaysArray(date),   
                table = document.createDocumentFragment(),
                i = 0
    
            for (let j = 0; j < 6; ++j) {
                let tr = document.createElement('tr');
                for (let k = 0; k < 7; ++k) {
                    //date created to get scheduled events
                    var currentDay = days_array[i].number;
                    if(currentDay<10){
                        currentDay = '0'+currentDay;
                    }
                    var currentDate = date.getFullYear()+'-'+currentMonth+'-'+currentDay;
                    var eventsForCurrentDate = this.dateMap.has(currentDate);
                    //-----------------Added by Yogi-----------------//
                    var eventObj = null;
                    if (Array.isArray(this.dataMap) && this.dataMap.length > 0) {
                        eventObj = this.dataMap.find(h => h.date === currentDate);
                    }

                    //----------------------------------------------//
                    let td = document.createElement('td');
                    let span = document.createElement('span');
                    // eslint-disable-next-line @lwc/lwc/no-inner-html
                    span.classList.add('slds-day');
                    span.innerHTML = days_array[i].number;
                    td.appendChild(span);
                  //  td.innerHTML = days_array[i].number;
                    tr.appendChild(td)
    
                    //add the styles that depend on what month the day belongs to
                   // td.classList.add('calendar-cell')
                  //  td.classList.add('slds-text-align_center')
                     td.setAttribute('role', 'gridcell');
                    if (days_array[i].from !== 'currnet month') {
                        span.classList.add('slds-disabled-text');
                        td.classList.add('slds-disabled-text')
                        td.setAttribute('aria-disabled', 'true')
                        td.setAttribute('aria-selected', 'false')
                    } else {
                        if (current_month && this.selected_date.getDate() == days_array[i].number) {
                            td.setAttribute('aria-selected', 'true');
                         //   td.classList.add('selected_date');
                            span.classList.add('current_date');
                          //  td.classList.add('slds-theme_shade')
                        }
                        if(eventsForCurrentDate){
                            td.setAttribute('aria-selected', 'true');
                            //   td.classList.add('selected_date');
                               span.classList.add('selected_date');
                        }
                        //---------------Added by Yogi---------------------// 
                        if (eventObj) {
                            if (eventObj.type === 'H') {
                                span.classList.add('holiday-date');
                            }
                            if (eventObj.type === 'WO') {
                                span.classList.add('weekoff-date');
                            }
                            if (eventObj.description) {
                                td.setAttribute('title', eventObj.description);

                                let desc = document.createElement('div');
                                desc.textContent = eventObj.description;
                                desc.classList.add('holiday-desc');
                                td.appendChild(desc);
                               
                            }
                        }

                        //-------------------------------------------------//
                        if (days_array[i].weekend)
                        // eslint-disable-next-line eqeqeq
                        // eslint-disable-next-line no-empty
                        if (current_month && this.current_day == days_array[i].number) {                        
                        }
                    }
                    ++i
                }
                table.appendChild(tr);
            }
    
            return table
        }
        //returns month name from date 
        getMonthName(date) {
            const month_names = [
                'January',
                'February',
                'March',
                'April',
                'May',
                'June',
                'July',
                'August',
                'September',
                'October',
                'November',
                'December'
            ]
    
            return month_names[date.getMonth()]
        }
    
        //if the received date corresponds to the current month and year returns true
        isThisMonthCurrent(date) {
            let current = new Date()
            if (
                current.getFullYear() == date.getFullYear() &&
                current.getMonth() == date.getMonth()
            )
                return true
            else 
                // eslint-disable-next-line no-else-return
                return false;
        }
        
        //redraws the body according to the received date
        setDateTo(date) {
            let 
                current_month = this.isThisMonthCurrent(date), //if it is current month, current day will be highlighted
                new_body      = this.createCalendarBody(date, current_month)
    
            // this.year_node.innerHTML  = date.getFullYear()
            // this.month_node.innerHTML = this.getMonthName(date)
            
            this.year = date.getFullYear()
            this.month = this.getMonthName(date)
            this.body_node.innerHTML  = ''
            this.body_node.appendChild(new_body)
        }
            
        //redraws the calendar a month in backward
        moveLeft() {
            this.displayed_date = new Date( //set the day to prev month
                this.displayed_date.getFullYear(),
                this.displayed_date.getMonth() - 1,
                1
            )
            this.setDateTo(this.displayed_date)
        }
    
        //redraws the calendar a month in forward
        moveRight() {
            this.displayed_date = new Date( //set the day to next month
                this.displayed_date.getFullYear(),
                this.displayed_date.getMonth() + 1,
                1
            )
            this.setDateTo(this.displayed_date)
        }
        // focusDate(){
        //     const calendar_body = this.template.querySelector('.slds-media__body');
        //     calendar_body.classList.toggle("slds-hide");
        // }
        //handles user clicks on cells
        selectHandler(e) {
            console.log(e);
            console.log(e.target.innerHTML);
            if (e.target.classList.contains('slds-disabled-text')) return
            if (!e.target.classList.contains('slds-day')) return //only days of current month can be selected
           // if (!e.target.getAttribute('role')) return //if it was   n't a click on a cell
    
            let prev_selected = this.template.querySelector('.slds-is-selected')
            if (prev_selected) { 
                prev_selected.classList.remove('slds-is-selected')
            //    prev_selected.classList.remove('selected_date')
               prev_selected.classList.remove('slds-theme_shade')
            } 
    
            this.selected_date = new Date(
                this.displayed_date.getFullYear(),
                this.displayed_date.getMonth(),
                e.target.innerHTML
            )

            // e.target.classList.add('selected_date');
            e.target.classList.add('calendar-cell-selected');
            e.target.classList.add('slds-theme_shade')
            e.target.classList.add('slds-is-selected')
            var date = this.selected_date.toLocaleDateString("en-US");
            console.log('date',this.date);
            console.log('date2',this.selected_date);
            console.log("Selected Date ",date);
            fireEvent(this.pageRef, 'selectedDate',{'date':date, 'fulldate':this.selected_date});
           // this.focusDate();
        }
    }