import ballerina/http;
import ballerina/log;
import ballerina/io;
import ballerinax/kubernetes;
import wso2/soap;
import ballerina/system;

@kubernetes:Ingress {
    hostname:"ballerina.guides.io",
    name:"soap-client",
    path:"/"
}

@kubernetes:Service {
    serviceType:"NodePort",
    name:"soap-client"
}

@kubernetes:Deployment {
    image:"ballerina.guides.io/soap-client:v1.0",
    name:"soap-client",
    //dockerHost: "tcp://192.168.99.100:2376",
    //dockerCertPath: "/home/bhashinee/.minikube",
    copyFiles: [{ target: "/home",
        source: "/home/bhashinee/ESB/wso2esb-4.8.1/repository/resources/security/client-truststore.p12" }]
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

//This is a passthrough service.
service SoapTestService on SoapTestEndpoint {
    //This resource allows all HTTP methods.
    @http:ResourceConfig {
        path: "/"
    }
    resource function sendSoapRequest(http:Caller caller, http:Request req) {

        xml body = xml `<m0:getQuote xmlns:m0="http://services.samples">
                        <m0:request>
                            <m0:symbol>WSO2</m0:symbol>
                        </m0:request>
                    </m0:getQuote>`;

        soap:UsernameToken usernameToken = {
            username: "admin",
            password: "admin",
            passwordType: soap:PASSWORD_DIGEST
        };

        soap:Options options = {
            usernameToken: usernameToken
        };

        var clientResponse = soapClient->sendReceive("/", "urn:mediate", body, options = options);

        log:printInfo("Request will be forwarded to Local Shop  .......");
        if (clientResponse is soap:SoapResponse) {
            //Sends the client response to the caller.
            var result = caller->respond("Hello Soap !!!");
            handleError(result);
        } else {
            //Sends the error response to the caller.
            http:Response res = new;
            res.statusCode = 500;
            res.setPayload(untaint <string>clientResponse.detail().message);
            var result = caller->respond(res);
            handleError(result);
        }
    }
}

function handleError(error? result) {
    if (result is error) {
        log:printError(result.reason(), err = result);
    }
}