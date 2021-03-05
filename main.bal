import ballerina/http;
import ballerina/log;
import ballerinax/googleapis_calendar as calendar;
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

const string GOOGLE_CHANNEL_ID = "X-Goog-Channel-ID";
const string GOOGLE_RESOURCE_ID = "X-Goog-Resource-ID";
const string GOOGLE_RESOURCE_STATE = "X-Goog-Resource-State";
const string SYNC = "sync";

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
string? syncToken = ();

function init() {
    calendar:WatchResponse res = checkpanic calendarClient->watchEvents(calendarId, watchConfig);
    resourceId = res.resourceId;
    log:print(resourceId);
}

listener http:Listener googleListener = checkpanic  new (port);

service /calendar on googleListener {
    resource function post events(http:Caller caller, http:Request request) returns error? {

        if (request.getHeader(GOOGLE_CHANNEL_ID) == channelId && request.getHeader(GOOGLE_RESOURCE_ID) == resourceId) {
            http:Response response = new;
            response.statusCode = http:STATUS_OK;
            if (request.getHeader(GOOGLE_RESOURCE_STATE) == SYNC) {
                calendar:EventStreamResponse|error resp = calendarClient->getEventResponse(calendarId);
                if (resp is calendar:EventStreamResponse) {
                    syncToken = <@untainted>resp?.nextSyncToken;
                }
                check caller->respond(response);
            } 
            else {
                calendar:EventStreamResponse resp = check calendarClient->getEventResponse(calendarId, 1, syncToken);
                syncToken = <@untainted>resp?.nextSyncToken;
                stream<calendar:Event>? events = resp?.items;
                check caller->respond(response);
                if (events is stream<calendar:Event>) {record {|calendar:Event value;|}? event = events.next();
                    if (event is record {|calendar:Event value;|}) {
                        string? created = event?.value?.created;
                        string? updated = event?.value?.updated;
                        calendar:Time? 'start = event?.value?.'start;
                        calendar:Time? end = event?.value?.end;
                        if (created is string && updated is string && 'start is calendar:Time && end is calendar:Time) {
                            if (created.substring(0, 19) == updated.substring(0, 19)) {
                                string? summary = event?.value?.summary;
                                string? startTime = ('start?.dateTime.toString() != "") ? ('start?.dateTime) : (
                                    'start?.date);
                                string? endTime = (end?.dateTime.toString() != "") ? (end?.dateTime) : (end?.date);
                                if (startTime is string && endTime is string) {
                                    string message = "Hi, You are invited to an event " + " that starts on " + startTime
                                        + " and ends on " + endTime;
                                    if (summary is string) {
                                        message = "Hi, You are invited to an event " + summary + " that starts on " + 
                                            startTime + " and ends on " + endTime;
                                    }
                                    var details = twilioClient->sendSms(fromMobile, toMobile, message);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
