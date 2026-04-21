# read-for-me-backend
Backend for ReadForMe Project.

Issues faced:
CORS:
when file upload is done using the html, it failed due to cors,
this is because the browser sees one domain (your html path), and the request is done for a different domain (api gateway call
for the pre-signed url generation).
To fix this:
- If we use HTTP api, cors is automatically taken care of
- But if we use REST Api, then we have to do 2 things:
    1) Create an OPTIONS method under your api resource and integrate with a mock integration. Here we should configure both integration response and method response. In Integration response you say what are all the headers and it's static values, for e.g. allow-headers, allow-origins, allow-content-types etc. with their corresponding mapping values. In method response (which is what goes finally to the client should include all those headers you defined in integration response). This first step is needed for the initial browser handshake with our server (as browser first sends this options request to see if the request can be made). Note that every resource you have in your api should have its own options method.
    2) If you use Lambda Proxy Integration, then your lambda should also return Access-Control-Allow-Origin header in its response

- But if you try to upload a file to s3 directly using a pre-signed url - then there's no api involved here. This will also fail as the browser sees the request is going to a different domain. Simple fix is to just enable CORS in s3 bucket permissions.
