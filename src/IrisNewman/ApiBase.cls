Class IrisNewman.ApiBase Extends %CSP.REST [ System = 3 ]
{

Parameter CHARSET = "utf-8";

Parameter CONTENTTYPE = "application/json";

Parameter HandleCorsRequest = 1;

Parameter PAGESIZE As INTEGER = 20;

Parameter ApiKey;

ClassMethod OnPreDispatch(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
  SET tSC = $$$OK
  TRY {

    /// Api Key Validation
    Set tSC=..ValidateApiKey(pUrl, pMethod, .pContinue)
    Return:(pContinue=0) ##class(%iKnow.REST.Base).%ErrorHandler(tSC, .pContinue)
    
    // Set the return type according to the Accept type in the request. Default is application/json.
    IF ('..AcceptsContentType(..#CONTENTTYPEJSON)) {
      SET tSC = ..ReportHttpStatusCode(..#HTTP406NOTACCEPTABLE), pContinue=0
      QUIT 
        } ELSE {   
      // This always returns json
      SET %response.ContentType=..#CONTENTTYPEJSON
        }
        
        
        // read request object into %DynamicObject format
    IF ((pMethod'="POST") && (pMethod'="PUT")) || (%request.Content="") {
      SET %request.Content = {}
    } ELSE {
      IF '$isobject(%request.Content) {
        SET tContent = %request.Content
      } ELSE {
        SET tContent = ""
        WHILE '%request.Content.AtEnd {
          SET tContent = tContent_%request.Content.Read()
        }
      }
      IF (tContent="") {
        SET %request.Content = {}
      } ELSE {
        SET tContent = $zconvert(tContent, "I", "UTF8")
        SET %request.Content = ##class(%Library.DynamicObject).%FromJSON(tContent)
      }
    }
        
  } CATCH ex {
    SET tSC = ex.AsStatus()
  }
  QUIT ##class(%iKnow.REST.Base).%ErrorHandler(tSC, .pContinue)
}

ClassMethod ValidateApiKey(pUrl As %String, pMethod As %String, ByRef pContinue As %Boolean) As %Status
{
  SET tSC = $$$OK

  QUIT:(..MustCheckApiKey(pUrl, pMethod)=0) tSC

  IF (..#ApiKey '= "")
    {
      IF ($D(%request.CgiEnvs("HTTP_API_KEY"))'=0)
      {

        SET apiKey=%request.CgiEnvs("HTTP_API_KEY")
        IF (apiKey'=..#ApiKey)
        {
          SET pContinue = 0
          DO ..ReportHttpStatusCode(..#HTTP401UNAUTHORIZED)
          SET tSC=$$$ERROR(..#HTTP401UNAUTHORIZED)
         
        }

      }Else{
        DO ..ReportHttpStatusCode(..#HTTP401UNAUTHORIZED)
        SET tSC=$$$ERROR(..#HTTP401UNAUTHORIZED)
         
      }
    }
  Quit tSC
}

ClassMethod MustCheckApiKey(pUrl As %String, pMethod As %String) As %Boolean
{
  Quit 1
}

ClassMethod %ProcessResult(pStatus As %Status = {$$$OK}, pResult As %DynamicObject = "") As %Status [ Internal ]
{
  #dim %response As %CSP.Response
  SET tSC = $$$OK
  IF $$$ISERR(pStatus) {
    SET %response.Status = 500
    SET tSC = ..StatusToJSON(pStatus, .tJSON)
    IF $isobject(tJSON) {
      SET pResult = tJSON
    } ELSE {
      SET pResult = { "errors": [ { "error": "Unknown error parsing status code" } ] }
    }
  } 
  ELSEIF pStatus=1 {
    IF '$isobject(pResult){
      SET pResult = {
      }
    }
  }
  ELSE {
    SET %response.Status = pStatus
    SET error = $PIECE(pStatus, " ", 2, *)
    SET pResult = {
      "error": (error)
    }
  }
  
  IF pResult.%Extends("%Library.DynamicAbstractObject") {
    WRITE pResult.%ToJSON()
  }
  ELSEIF pResult.%Extends("%JSON.Adaptor") {
    DO pResult.%JSONExport()
  }
  ELSEIF pResult.%Extends("%Stream.Object") {
    DO pResult.OutputToDevice()
  }
  
  QUIT tSC
}

ClassMethod ReportHttpStatusCode(pHttpStatus, pSC As %Status = {$$$OK}) As %Status
{
  Set %response.Status=pHttpStatus
  
  If $$$ISERR(pSC) Do ..outputStatus(pSC)
      
  Return $$$OK
}

}
