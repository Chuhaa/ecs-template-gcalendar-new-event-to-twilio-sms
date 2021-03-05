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
configurable string channelId = ?;
configurable string token = ?;
configurable string calendarId = ?;
configurable string address = ?;
configurable string ttl = ?;

configurable string fromMobile = ?;
configurable string toMobile = ?;
configurable string accountSId = ?;
configurable string authToken = ?;

calendar:CalendarConfiguration calendarConfig = {oauth2Config: {
        clientId: clientId,
        clientSecret: clientSecret,
        refreshToken: refreshToken,
        refreshUrl: refreshUrl
    }};

calendar:Client calendarClient = new (calendarConfig);

twilio:TwilioConfiguration twilioConfig = {
    accountSId: accountSId,
    authToken: authToken
};

twilio:Client twilioClient = new (twilioConfig);

calendar:WatchConfiguration watchConfig = {
    id: channelId,
    token: token,
    'type: "webhook",
    address: address,
    params: {ttl: ttl}
};

string resourceId = "";

function init() {
    calendar:WatchResponse res = checkpanic calendarClient->watchEvents(calendarId, watchConfig);
    resourceId = res.resourceId;
    log:print(resourceId);
}

listener 'listener:Listener googleListener = new (port, calendarClient, channelId, resourceId, calendarId);

service /calendar on googleListener {
    resource function post events(http:Caller caller, http:Request request) {
        'listener:EventInfo payload = checkpanic googleListener.getEventType(caller, request);
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
                    var details = twilioClient->sendSms(fromMobile, toMobile, message);
                }
            }
        }
    }
}
