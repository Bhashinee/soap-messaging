import ballerina/http;
import ballerina/io;
import ballerina/log;
import ballerinax/kubernetes;
import wso2/soap;

@kubernetes:Ingress {
    hostname:"ballerina.soap.io",
    name:"soap-client",
    path:"/"
}

@kubernetes:Service {
    serviceType:"NodePort",
    name:"soap-client"
}

@kubernetes:Deployment {
    image:"ballerina.soap.io/soap-client:v1.0",
    name:"soap-client",
    copyFiles: [{ target: "/home",
        source: "soap-client/resources/client-truststore.p12" }],
    username:"<USERNAME>",
    password:"<PASSWORD>",
    push:true,
    imagePullPolicy:"Always"
}

listener http:Listener SoapTestEndpoint = new(9090);

soap:SoapConfiguration soapConfig = {
    clientConfig: {
        secureSocket:{
            trustStore:{
                path: "/home/client-truststore.p12",
                password: "wso2carbon"
            },
            verifyHostname: false
        }
    }
};

soap:Soap11Client soapClient = new("https://soap-service:8243/services/passwordDigest", soapConfig = soapConfig);

service SoapTestService on SoapTestEndpoint {
    @http:ResourceConfig {
        path: "/sendSoapRequest"
    }
    resource function sendSoapRequest(http:Caller caller, http:Request req) {

        xml body = xml `<body/>`;

        soap:UsernameToken usernameToken = {
            username: "admin",
            password: "admin",
            passwordType: soap:PASSWORD_DIGEST
        };

        soap:Options options = {
            usernameToken: usernameToken
        };

        var clientResponse = soapClient->sendReceive("/", "urn:mediate", body, options = options);

        log:printInfo("Request will be forwarded soap backend  .......");
        if (clientResponse is soap:SoapResponse) {
            var respPayload = clientResponse["payload"];
            if (respPayload is xml) {
                xml payload = xml `<hello>world</hello>`;
                if (respPayload == payload) {
                    string soapVersion = clientResponse.soapVersion;
                    string response = soapVersion + " is working !";
                    var result = caller->respond(untaint response);
                    handleError(result);
                }
            }
        } else {
            sendError(<string>clientResponse.detail().message, caller);
        }
    }

    @http:ResourceConfig {
        path: "/sendErrorSoapRequest"
    }
    resource function sendErrorSoapRequest(http:Caller caller, http:Request req) {

        xml body = xml `<body/>`;

        soap:UsernameToken usernameToken = {
            username: "admin",
            password: "admin1",
            passwordType: soap:PASSWORD_DIGEST
        };

        soap:Options options = {
            usernameToken: usernameToken
        };

        var clientResponse = soapClient->sendReceive("/", "urn:mediate", body, options = options);

        log:printInfo("Request will be forwarded soap backend  .......");
        if (clientResponse is soap:SoapResponse) {
            var respPayload = clientResponse["payload"];
            if (respPayload is xml) {
                xml payload = xml `<faultstring>The security token could not be authenticated or authorized</faultstring>`;
                if (respPayload["faultstring"] == payload) {
                    http:Response errorResponse = new;
                    errorResponse.statusCode = 401;
                    errorResponse.setTextPayload("Authentication failure");
                    var result = caller->respond(errorResponse);
                    handleError(result);
                }
            }
        } else {
            sendError(<string>clientResponse.detail().message, caller);
        }
    }
}

function handleError(error? result) {
    if (result is error) {
        log:printError(result.reason(), err = result);
    }
}

function sendError(string message, http:Caller caller) {
    // Sends the error response to the caller.
    http:Response res = new;
    res.statusCode = 500;
    res.setPayload(untaint message);
    var result = caller->respond(res);
    handleError(result);
}