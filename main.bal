import ballerina/http;
import ballerina/log;
import ballerinax/googleapis_calendar as calendar;
import ballerinax/googleapis_calendar.'listener;
import ballerinax/twilio;

configurable int port = ?;

configurable string clientId = ?;
configurable string clientSecret = ?;
configurable string refreshToken = ?;
configurable string refreshUrl = ?;
configurable string calendarId = ?;
configurable string address = ?;

configurable string fromMobile = ?;
configurable string toMobile = ?;
configurable string accountSId = ?;
configurable string authToken = ?;

calendar:CalendarConfiguration calendarConfig = {
    oauth2Config: {
        clientId: clientId,
        clientSecret: clientSecret,
        refreshToken: refreshToken,
        refreshUrl: refreshUrl
    }
};

calendar:Client calendarClient = check new (calendarConfig);

twilio:TwilioConfiguration twilioConfig = {
    accountSId: accountSId,
    authToken: authToken
};

twilio:Client twilioClient = new (twilioConfig);

listener 'listener:Listener googleListener = new (port, calendarClient, calendarId, address);

service /calendar on googleListener {
    resource function post events(http:Caller caller, http:Request request) returns error? {
        'listener:EventInfo payload = check googleListener.getEventType(caller, request);
        if (payload?.eventType is string && payload?.event is calendar:Event) {
            if (payload?.eventType == 'listener:CREATED) {
                var event = payload?.event;
                string? summary = event?.summary;
                string? startTime = (event?.'start?.dateTime.toString() != "") ? (event?.'start?.dateTime) : (event?.
                    'start?.date);
                string? endTime = (event?.end?.dateTime.toString() != "") ? (event?.end?.dateTime) : (event?.end?.date);
                if (startTime is string && endTime is string) {
                    string message = "Hi, You are invited to an event " + " that starts on " + startTime + 
                        " and ends on " + endTime;
                    if (summary is string) {
                        message = "Hi, You are invited to an event " + summary + " that starts on " + startTime + 
                            " and ends on " + endTime;
                    }
                    twilio:SmsResponse details = check twilioClient->sendSms(fromMobile, toMobile, message);
                    log:print("SMS has been sent to user");
                }
            }
        }
    }
}
