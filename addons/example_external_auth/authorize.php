<?php
  error_log("Starting authorization");
  // The source sends the fields as a form (default) or as a JSON object
  $params = $_POST;
  if (isset($_SERVER["CONTENT_TYPE"]) && stripos($_SERVER["CONTENT_TYPE"], "application/json") === 0) {
    $params = json_decode(file_get_contents("php://input"), true);
    if (!is_array($params)) {
      $params = array();
    }
  }
  foreach ($params as $key => $value){
    error_log("Param, $key : " . (is_array($value) ? json_encode($value) : $value));
  }
  if (
      isset($params["SSID"]) && $params["SSID"] === "PF-Test" &&
      isset($params["mac"]) && $params["mac"] === "00:11:22:33:44:55"
     ) {
    echo json_encode(array("category" => "default", "access_duration" => "1Y"));
  }else{  
    echo json_encode(array("category" => "guest", "access_duration" => "1D"));
  }
