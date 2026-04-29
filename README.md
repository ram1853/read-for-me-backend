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

- Here 'origin' refers to the domain from where the request originates from. Here - the domain loaded by browser,
so instead of giving wildcard in allow-origin from your server response, you can restrict to specific domains if needed.
Browser -> Server (Browser checks if the response header from server is having the cors header with its domain allowed - if yes requests succeed, else cors issue). e.g browser is loaded in https://myapp.com -> then this is the origin.

- Also cors is mainly a browser issue. If you try do the same request from curl or postman it will succeed (e.g. your upload.sh)

- if you want to add custom header while uploading an object using the s3 pre-signed url, then the entity which generates the pre-signed url (e.g python or java sdk) should include 'Metadata' in the params. Now while using the pre-signed url, you can set
this custom header using the header key 'x-amz-meta-<custom-header-key>: <value>'.
<custom-header-key> should be exactly the same that is used while generating the pre-signed url.
Later this header can be fetched using 's3_client.head_object(Bucket=bucket, Key=key)' when needed.
TODO: Test if this works without explictly setting the 'Metadata' while generating pre-signed url (if you get 403, it likely
means aws sees signature mismatch -> No job_id header while generating url, but seeing job_id header while client uploads!)

-- AWS Cognito --
User logs in with username & password => if valid, authentication is success & cognito returns a 'code'
Our app should exchange this code for tokens. The api returns the following tokens:
    id_token: tells about the user identity (frontend authentication)
    access_token: for authorization (what the user can access) - backend api access
    refresh_token: for session continuity (id_token & session_token are short lived - typically 1 hour. We don't want to ask the user
    to login every 1 hour. So we use the refresh_token to get fresh id_token and access_token. refresh_token is long lived)

Why don't cognito return the tokens directly instead of code? This is to reduce the blast radius.
When the authentication is success, you see 'code' in the browser url path parameter.
This code itself is useless unless it is exchanged for tokens. So even if someone peeks your code, he/she must know the cognito client id and cognito domain to get the tokens.
Now imagine if cognito returned tokens directly - now your browser will store the history of all urls you visited which will now
have these tokens - This is dangerous, and if someone gets hold of access token, he can call your API.
All these security practises are to reduce the blast radius (even if someone gets the access token, he can use it for 1 hour only
after which it expires). Also if a 'code' is used to get the tokens, the same code cannot be used to get another set of tokens.
A code is a one time use.

It will be our frontend app's responsibility to ensure the tokens are valid.
e.g. before calling your API, check if access token is not expired, if expired then use the refresh token to get new tokens.
If you don't do this, your api might fail as your api is also secured with access token based authorization.
If you send expired access token to your api, then your api-gw endpoint secured with cognito access token will reject the request.
Also you can add custom 'scopes' for your api endpoint authorization ('admin', 'creator', 'viewer' etc.)

Note: This app is supposed to be a public app, so we don't need any role based access to api endpoints or specific authorization needs. Simply if a user is authenticated, then he can access the APIs as well. This means when you attach cognito authorizer to
api endpoint, you won't be choosing any 'scopes'. Now when you don't attach any scopes api-gw knows, there's no authorization needed, hence it will expect 'id_token' in Authorization header (Bearer <id_token>) instead of 'access_token'.
But if your app needs authorization flow, then create custom scopes under resource server and then configure authorizer based on business needs (now you will send access_token in header)

TODO:
Running terraform apply after api changes is not automatically re-deploying the api.