
module Types {

  public type Timestamp = Nat64;
  
  //See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request
  public type HttpRequestArgs = {
    url : Text;
    max_response_bytes : ?Nat64;
    headers : [HttpHeader];
    body : ?[Nat8];
    method : HttpMethod;
    transform : ?TransformRawResponseFunction;
  };

  public type HttpHeader = {
    name : Text;
    value : Text;
  };

  public type HttpMethod = {
    #get;
    #post;
    #head;
  };

  public type HttpResponsePayload = {
    status : Nat;
    headers : [HttpHeader];
    body : [Nat8];
  };

  //2. HTTPS outcalls have an optional "transform" key. These two types help describe it.
  //"The transform function may, for example, transform the body in any way, add or remove headers,
  //modify headers, etc. "
  //See: https://internetcomputer.org/docs/current/references/ic-interface-spec/#ic-http_request
  public type TransformRawResponseFunction = {
      function : shared query TransformArgs -> async HttpResponsePayload;
      context : Blob;
  };

  // This Type defines the arguments the transform function needs.
  public type TransformArgs = {
      response : HttpResponsePayload;
      context : Blob;
  };
  
  public type IC = actor {
    http_request : HttpRequestArgs -> async HttpResponsePayload;
  };

  public type MainActor = actor {
    transform_response : shared query TransformArgs -> async HttpResponsePayload;    
  };
  

};