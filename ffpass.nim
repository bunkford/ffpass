import httpclient, json, times, os

##
## Api Calls for Ford vehicles equipped with the fordpass app.
## 
## *example:*
## 
## .. code-block::nim
##  import ffpass
##  
##  var ford = Vehicle(username:"user@email.com", password:"myPassword", vin:"1FT#############")
##  
##  if ford.lock():
##    echo "Vehicle Locked"
##  else:
##    echo "Failed to lock Vehicle"

type 
  Vehicle* = object
    ## Username and password from fordpass app.
    ## 
    ## VIN from vehicle registered in app.
    username*, password*, vin*:string
    
  AccessToken = object
    token:string
    expires:DateTime

let baseUrl = "https://usapi.cv.ford.com/api"

proc newAccessToken(): AccessToken =
  result = AccessToken(token: "", expires: now())

var token = newAccessToken()

proc auth(self:Vehicle) =
  # Authenticate and store the token

  let client = newHttpClient()

  let headers = {
    "Accept": "*/*",
    "Accept-Language": "en-us",
    "User-Agent": "fordpass-na/353 CFNetwork/1121.2.2 Darwin/19.3.0",
    "Accept-Encoding": "gzip, deflate, br",
    "Content-Type": "application/x-www-form-urlencoded"
  }

  client.headers = newHttpHeaders(headers)

  let response = client.request("https://fcis.ice.ibmcloud.com/v1.0/endpoint/default/token", httpMethod = HttpPost, body = "client_id=9fb503e0-715b-47e8-adfd-ad4b7770f73b&grant_type=password&username=" & self.username & "&password=" & self.password)

  if response.status == "200 OK":
    # Successfully fetched token
    let json_result = parseJson(response.body)
    token.token = json_result["access_token"].getStr()
    token.expires = now() + initduration(seconds = json_result["expires_in"].getInt())
  else:
    echo response.status
    echo response.body

proc aquireToken(self:Vehicle) =
  if token.token == "" or now() >= token.expires:
    # No toekn, or has expired, requesting new token
    self.auth()
  else:
    # Token is valid, continuing
    discard

proc status*(self:Vehicle):JsonNode = 
  ## Returns jsonNode of vehicle status
  self.aquireToken()

  let client = newHttpClient()

  let headers = {
    "Accept": "*/*",
    "Accept-Language": "en-us",
    "User-Agent": "fordpass-na/353 CFNetwork/1121.2.2 Darwin/19.3.0",
    "Accept-Encoding": "gzip, deflate, br",
    "Application-Id": "71A3AD0A-CF46-4CCF-B473-FC7FE5BC4592",    
    "Content-Type": "application/json",
    "auth-token": token.token
  }

  client.headers = newHttpHeaders(headers)

  let response = client.request(baseUrl & "/vehicles/v4/" & self.vin & "/status", httpMethod = HttpGet)

  if response.status == "200 OK":
    return parseJson(response.body)
  else:
    echo response.status
    echo response.body

proc makeRequest(httpMethod:HttpMethod, url:string, data:JsonNode = %*"{}", params:string = ""):Response =
  # Make a request to the given URL, passing data/params as needed
  
  let client = newHttpClient()

  let headers = {
    "Accept": "*/*",
    "Accept-Language": "en-us",
    "User-Agent": "fordpass-na/353 CFNetwork/1121.2.2 Darwin/19.3.0",
    "Accept-Encoding": "gzip, deflate, br",
    "Application-Id": "71A3AD0A-CF46-4CCF-B473-FC7FE5BC4592",    
    "Content-Type": "application/json",
    "auth-token": token.token
  }

  client.headers = newHttpHeaders(headers)

  let response = client.request(url, httpMethod, body = $data)
  return response

proc pollStatus(url:string, id:string):bool =
  # Poll the given URL with the given command ID until the command is completed

  let client = newHttpClient()

  let headers = {
    "Accept": "*/*",
    "Accept-Language": "en-us",
    "User-Agent": "fordpass-na/353 CFNetwork/1121.2.2 Darwin/19.3.0",
    "Accept-Encoding": "gzip, deflate, br",
    "Application-Id": "71A3AD0A-CF46-4CCF-B473-FC7FE5BC4592",    
    "Content-Type": "application/json",
    "auth-token": token.token
  }

  client.headers = newHttpHeaders(headers)

  var status = 552

  while status == 552:
    let response = client.request(url & "/" & id, HttpGet)
    let request = parseJson(response.body)
    status = request["status"].getInt()
    # Command is pending, sleep
    sleep(5)

  if status == 200:
    # Command completed succesffuly
    return true
  else:
    echo "Command failed"
    return false

proc requestAndPoll(self:Vehicle, httpMethod:HttpMethod, url:string):bool =
  self.aquireToken()
  let command = makeRequest(httpMethod, url)

  if command.status == "200 OK":
    let json_result = parseJson(command.body)
    return pollStatus(url, json_result["commandId"].getStr())
  else:
    echo command.status
    echo command.body

proc lock*(self:Vehicle):bool =
  ## Locks the vehicle. Returns true if successful
  return self.requestAndPoll(HttpPut, baseUrl & "/vehicles/v2/" & self.vin & "/doors/lock")

proc unlock*(self:Vehicle):bool =
  ## Unlocks the vehicle. Returns true if successful
  return self.requestAndPoll(HttpDelete, baseUrl & "/vehicles/v2/" & self.vin & "/doors/lock")

proc start*(self:Vehicle):bool = 
  ## Starts the vehicle. Returns true if successful
  return self.requestAndPoll(HttpPut, baseUrl & "/vehicles/v2/" & self.vin & "/engine/start")

proc stop*(self:Vehicle):bool = 
  ## Stops the vehicle. Returns true if successful
  return self.requestAndPoll(HttpDelete, baseUrl & "/vehicles/v2/" & self.vin & "/engine/start")
